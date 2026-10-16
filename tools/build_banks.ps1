<#
build_banks.ps1 — 把一个目录里的任意音频打成饥荒能播的 FMOD 采样库（.fsb），一次重打整个 mod 的全部槽位。

用法（在本仓库根目录跑）:
    powershell -ExecutionPolicy Bypass -File tools\build_banks.ps1 -In "D:\我的歌"
    powershell -ExecutionPolicy Bypass -File tools\build_banks.ps1 -Mod "C:\路径\我的mod" -In "C:\路径\我的mod\music_in" -Bitrate 192

它做什么：
  1. 读 <Mod>\sound\ 里现有的每一对 .fsb（采样名表）+ .fbp.fev（事件顺序），算出每个槽位对应哪个事件号；
  2. 用 ffmpeg 把 <In> 里的音频统一转成 MPEG-1 Layer III / CBR / 44100Hz / 立体声；
  3. 按 donor 的头重建每个 .fsb，空槽位填 0.25 秒静音（旧那一份先备份到 <Mod>\_build\prev\）；
  4. 写 <Mod>\music\tracks.txt —— 每行 "<事件路径> <秒数>"，给需要按曲目时长收尾的引擎读。

槽位上限 = <Mod>\sound\ 里 .fsb 的个数 × 每份壳的事件数（我自己用的壳是每份 4 个事件，5 份 = 20）。
要更多槽位得自己用 FMOD Designer 建壳，见 README「自定义音乐」的路线 2，不要改这个脚本。

为什么音频规格由脚本强制统一：饥荒运行时不能播 mp3/wav/ogg 裸文件，只能走 FMOD 的
事件壳(.fev) + 采样库(.fsb)。而 .fsb 里实测唯一能被游戏播放的形态是 MPEG-1 Layer III CBR ——
Vorbis / PCM / 非 CBR 都是静默失败：不报错、playing=true、没声音。

这个脚本不碰 .fev（FEV4 只有 FMOD Designer 能写），也不做同步进游戏目录那一步；
打完之后用 sh tools/sync_to_game.sh，它只增不删并且逐文件 md5 自证。
#>
param(
    [string]$In = "",
    [string]$Mod = (Split-Path $PSScriptRoot -Parent),
    [string]$Ffmpeg = "",
    [int]$Bitrate = 160
)
$ErrorActionPreference = 'Stop'

Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

public static class FsbTool
{
    class Samp
    {
        public string name; public int freqIdx; public int channels;
        public long dataOff; public long nSmp; public byte[] data;
    }

    static uint U32(byte[] b, int o) { return (uint)(b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)); }
    static ulong U64(byte[] b, int o)
    {
        return (ulong)b[o] | ((ulong)b[o + 1] << 8) | ((ulong)b[o + 2] << 16) | ((ulong)b[o + 3] << 24)
             | ((ulong)b[o + 4] << 32) | ((ulong)b[o + 5] << 40) | ((ulong)b[o + 6] << 48) | ((ulong)b[o + 7] << 56);
    }
    static void Put32(byte[] b, int o, uint v)
    {
        b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); b[o + 2] = (byte)(v >> 16); b[o + 3] = (byte)(v >> 24);
    }
    static void Put64(byte[] b, int o, ulong v)
    {
        for (int i = 0; i < 8; i++) b[o + i] = (byte)(v >> (8 * i));
    }

    static int[] BR_MPEG1 = { 0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0 };
    static int[] FR_MPEG1 = { 44100, 48000, 32000, 0 };
    static int[] FREQIDX = { 0, 8000, 11000, 11025, 16000, 22050, 24000, 32000, 44100, 48000 };

    // 返回帧起始与长度；不是 MPEG-1 Layer III 帧则 -1
    static int Frame(byte[] d, int o, out int len, out int freq, out int ch)
    {
        len = 0; freq = 0; ch = 0;
        if (o + 4 > d.Length) return -1;
        if (d[o] != 0xFF || (d[o + 1] & 0xE0) != 0xE0) return -1;
        int b1 = d[o + 1], b2 = d[o + 2];
        if (((b1 >> 3) & 3) != 3) return -1;      // MPEG-1
        if (((b1 >> 1) & 3) != 1) return -1;      // Layer III
        int br = BR_MPEG1[(b2 >> 4) & 0xF];
        int fr = FR_MPEG1[(b2 >> 2) & 3];
        if (br == 0 || fr == 0) return -1;
        len = (int)(144000L * br / fr) + ((b2 >> 1) & 1);
        freq = fr; ch = ((b2 >> 6) & 1) == 1 ? 1 : 2;
        return len;
    }

    static byte[] StripId3(byte[] d)
    {
        if (d.Length < 10 || d[0] != (byte)'I' || d[1] != (byte)'D' || d[2] != (byte)'3') return d;
        int size = ((d[6] & 0x7F) << 21) | ((d[7] & 0x7F) << 14) | ((d[8] & 0x7F) << 7) | (d[9] & 0x7F);
        int o = 10 + size; int t, f, c;
        if (Frame(d, o, out t, out f, out c) < 0)
        {
            for (o = 10; o + 4 <= d.Length; o++) { if (Frame(d, o, out t, out f, out c) > 0) break; }
        }
        byte[] r = new byte[d.Length - o];
        Array.Copy(d, o, r, 0, r.Length);
        return r;
    }

    // 曲目时长（秒）：帧数 × 1152 / 采样率。引擎在"playing=true 也不采信"时靠它收尾
    public static double Sec(string mp3Path)
    {
        byte[] d = StripId3(File.ReadAllBytes(mp3Path));
        int t, fq, chc;
        if (Frame(d, 0, out t, out fq, out chc) < 0) return 0;
        int frames = 0, o = 0;
        while (true)
        {
            int len, f2, c2;
            if (Frame(d, o, out len, out f2, out c2) < 0) break;
            if (f2 != fq || c2 != chc || o + len > d.Length) break;
            frames++; o += len;
        }
        return (double)frames * 1152 / fq;
    }

    // 外壳里事件的发声顺序。Designer 把 sound 名字按创建先后写进 FEV 字符串池，
    // 第 k 个 "xxx.wav" 就是 untitled 组的第 k 个事件；而 FSB 的名字表是字母序的。
    // 两者不能直接对号，否则歌会被放进静音占位的事件里（症状 = 从头到尾没声音）。
    public static string[] SoundOrder(string fevPath)
    {
        byte[] b = File.ReadAllBytes(fevPath);
        List<string> found = new List<string>();
        int i = 0;
        while (i < b.Length)
        {
            if (b[i] < 32 || b[i] > 126) { i++; continue; }
            int s = i;
            while (i < b.Length && b[i] >= 32 && b[i] <= 126) i++;
            string run = Encoding.UTF8.GetString(b, s, i - s);
            if (!run.EndsWith(".wav", StringComparison.OrdinalIgnoreCase)) continue;
            string nm = Path.GetFileNameWithoutExtension(run.Replace('\\', '/'));
            if (nm.Length > 0 && !found.Contains(nm)) found.Add(nm);
        }
        return found.ToArray();
    }

    public static string[] Names(string path)
    {
        byte[] b = File.ReadAllBytes(path);
        if (b.Length < 60 || U32(b, 0) != 0x35425346) throw new Exception("not FSB5: " + path);
        int n = (int)U32(b, 8);
        int hdr = 60 + (U32(b, 4) == 0 ? 4 : 0);
        int o = hdr;
        for (int i = 0; i < n; i++)
        {
            o += 8;
            ulong w = U64(b, o - 8);
            int next = (int)(w & 1);
            while (next != 0)
            {
                uint c = U32(b, o); o += 4;
                next = (int)(c & 1);
                o += (int)((c >> 1) & 0xFFFFFF);
            }
        }
        string[] names = new string[n];
        for (int i = 0; i < n; i++)
        {
            int so = o + (int)U32(b, o + i * 4);
            int e = so; while (b[e] != 0) e++;
            names[i] = Encoding.UTF8.GetString(b, so, e - so);
        }
        return names;
    }

    public static string Build(string donorPath, string outPath, string[] names, string[] mp3Paths,
                               int loopDelta, int align)
    {
        byte[] donor = File.ReadAllBytes(donorPath);
        if (donor.Length < 60 || U32(donor, 0) != 0x35425346) throw new Exception("donor is not FSB5");
        if (U32(donor, 0x18) != 11) throw new Exception("donor is not MPEG (mode 11); refusing");
        int hdrSize = 60 + (U32(donor, 4) == 0 ? 4 : 0);
        if (names.Length != mp3Paths.Length) throw new Exception("names/mp3 count mismatch");

        List<Samp> list = new List<Samp>();
        long cursor = 0;
        StringBuilder rep = new StringBuilder();
        for (int i = 0; i < names.Length; i++)
        {
            byte[] d = StripId3(File.ReadAllBytes(mp3Paths[i]));
            int t, fq, chc;
            if (Frame(d, 0, out t, out fq, out chc) < 0)
                throw new Exception(names[i] + ": no MPEG-1 Layer III frame at offset 0 (需要 CBR mp3)");
            List<int[]> frames = new List<int[]>();
            int o = 0;
            while (true)
            {
                int len, f2, c2;
                if (Frame(d, o, out len, out f2, out c2) < 0) break;
                if (f2 != fq || c2 != chc || o + len > d.Length) break;
                frames.Add(new int[] { o, len });
                o += len;
            }
            if (frames.Count == 0) throw new Exception(names[i] + ": no walkable CBR frame run");

            int total = 0;
            foreach (int[] fr in frames) total += (fr[1] + 3) & ~3;   // pad4：每帧补到 4 的倍数
            byte[] payload = new byte[total];
            int p = 0;
            foreach (int[] fr in frames)
            {
                Array.Copy(d, fr[0], payload, p, fr[1]);
                p += (fr[1] + 3) & ~3;
            }
            int pad = (align - (total % align)) % align;
            byte[] data = new byte[total + pad];
            Array.Copy(payload, data, total);

            Samp s = new Samp();
            s.name = names[i];
            int fi = 0;
            for (int q = 1; q < FREQIDX.Length; q++) if (FREQIDX[q] == fq) fi = q;
            if (fi == 0) throw new Exception(names[i] + ": unsupported sample rate " + fq);
            s.freqIdx = fi; s.channels = chc;
            s.dataOff = cursor; s.nSmp = (long)frames.Count * 1152; s.data = data;
            list.Add(s);
            cursor += data.Length;
            double sec = (double)s.nSmp / fq;
            rep.Append("  " + s.name + " frames=" + frames.Count + " samples=" + s.nSmp +
                       " sec=" + sec.ToString("0.0") + " " + fq + "Hz " + chc + "ch bytes=" + data.Length + "\n");
        }

        // 采样头：每条 8 字节 + loop chunk(4 字节头 + 8 字节体) = 20
        int shLen = list.Count * 20;
        byte[] nmBuf;
        {
            int strs = 0;
            foreach (Samp s in list) strs += Encoding.UTF8.GetByteCount(s.name) + 1;
            int bare = list.Count * 4 + strs;
            int baseOff = hdrSize + shLen + bare;
            int nmPad = (align - (baseOff % align)) % align;
            int nmSize = bare + nmPad;
            nmBuf = new byte[nmSize];
            int p = list.Count * 4;
            for (int i = 0; i < list.Count; i++)
            {
                Put32(nmBuf, i * 4, (uint)p);
                byte[] sb = Encoding.UTF8.GetBytes(list[i].name);
                Array.Copy(sb, 0, nmBuf, p, sb.Length);
                p += sb.Length + 1;
            }
        }

        byte[] head = new byte[hdrSize];
        Array.Copy(donor, head, hdrSize);
        Put32(head, 0x0C, (uint)shLen);
        Put32(head, 0x10, (uint)nmBuf.Length);
        Put32(head, 0x14, (uint)cursor);

        byte[] sh = new byte[shLen];
        int w = 0;
        foreach (Samp s in list)
        {
            ulong bit = 1UL;                                       // 有 chunk
            bit |= ((ulong)s.freqIdx & 0xFUL) << 1;
            bit |= ((ulong)(s.channels - 1) & 1UL) << 5;
            bit |= ((ulong)(s.dataOff / 16) & 0x0FFFFFFFUL) << 6;
            bit |= (ulong)s.nSmp << 34;
            Put64(sh, w, bit); w += 8;
            Put32(sh, w, (uint)((8 << 1) | (3 << 25))); w += 4;     // chunk: type=3 LOOP, size=8, 无后继
            Put32(sh, w, 0);                                        // loop start
            Put32(sh, w + 4, (uint)Math.Max(0, s.nSmp - loopDelta)); // loop end
            w += 8;
        }

        byte[] outBuf = new byte[hdrSize + shLen + nmBuf.Length + cursor];
        Array.Copy(head, 0, outBuf, 0, hdrSize);
        Array.Copy(sh, 0, outBuf, hdrSize, shLen);
        Array.Copy(nmBuf, 0, outBuf, hdrSize + shLen, nmBuf.Length);
        long dp = hdrSize + shLen + nmBuf.Length;
        foreach (Samp s in list) { Array.Copy(s.data, 0, outBuf, dp, s.data.Length); dp += s.data.Length; }
        File.WriteAllBytes(outPath, outBuf);
        rep.Append("  dataStart=" + (hdrSize + shLen + nmBuf.Length) + " total=" + outBuf.Length + "\n");
        return rep.ToString();
    }
}
'@

if (-not (Test-Path $Mod)) { throw "找不到 mod 目录 $Mod（用 -Mod 指定，或在仓库根目录跑）" }
if ($In -eq "") { $In = Join-Path $Mod "music_in" }
if (-not (Test-Path $In)) { throw "找不到输入目录 $In（把你的歌放进去再跑，或用 -In 指定）" }

if ($Ffmpeg -eq "") {
    $onPath = (Get-Command ffmpeg -ErrorAction SilentlyContinue)
    if ($onPath) { $Ffmpeg = $onPath.Source }
    else {
        $cands = @((Join-Path $Mod "_tools\ffmpeg.exe"), (Join-Path $PSScriptRoot "ffmpeg.exe"))
        $Ffmpeg = ($cands | Where-Object { Test-Path $_ } | Select-Object -First 1)
    }
}
if (-not $Ffmpeg -or -not (Test-Path $Ffmpeg)) {
    throw "没找到 ffmpeg。装一个（或从 imageio-ffmpeg 的 wheel 里取 exe）后用 -Ffmpeg <路径> 指定"
}
Write-Output ("FFMPEG " + $Ffmpeg)
Write-Output ("MOD " + $Mod)

$soundDir = Join-Path $Mod "sound"
$donors = Get-ChildItem "$soundDir\*.fsb" -File | Sort-Object Name
if (-not $donors) { throw "$soundDir 里没有 .fsb（外壳没到位？见 README 路线 2 自己建一份）" }

$plan = @()
foreach ($d in $donors) {
    $ns = [FsbTool]::Names($d.FullName)
    $fev = Join-Path $soundDir ($d.BaseName + ".fbp.fev")
    if (-not (Test-Path $fev)) { throw "缺外壳 $fev（没有它就定不出事件号）" }
    $pool = @([FsbTool]::SoundOrder($fev))
    $orphan = @($ns | Where-Object { $pool -notcontains $_ })
    if ($pool.Count -eq 0 -or $orphan.Count -gt 0) {
        throw ("读不出 " + (Split-Path $fev -Leaf) + " 的事件顺序: pool=[" + ($pool -join ",") +
               "] 不在池里的采样=[" + ($orphan -join ",") + "]")
    }
    foreach ($n in $ns) {
        $ev = 1 + [array]::IndexOf($pool, $n)
        $plan += [pscustomobject]@{ Bank = $d.BaseName; Donor = $d.FullName; Sample = $n
                                    Event = ($d.BaseName + ".fbp/untitled/" + $ev); Index = $ev
                                    Src = $null; Real = $false; From = "" }
    }
}
Write-Output ("CAPACITY " + $plan.Count + " slots / " + $donors.Count + " banks")
foreach ($p in $plan) { Write-Output ("MAP " + $p.Bank + " sample " + $p.Sample + " -> event " + $p.Index) }

$exts = @("*.mp3", "*.wav", "*.flac", "*.m4a", "*.aac", "*.ogg", "*.opus", "*.wma")
$inputs = @(Get-ChildItem -Path $In -Include $exts -File -Recurse | Sort-Object Name)
Write-Output ("INPUT " + $inputs.Count + " files from " + $In)
if ($inputs.Count -gt $plan.Count) {
    $skipped = ($inputs | Select-Object -Skip $plan.Count | ForEach-Object { $_.Name }) -join ", "
    Write-Output ("OVERFLOW 只取前 " + $plan.Count + " 个，其余忽略: " + $skipped)
    $inputs = @($inputs | Select-Object -First $plan.Count)
}

$work = Join-Path $Mod "_build\work"
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Convert-To([string]$src, [string]$dst) {
    $a = @("-hide_banner", "-loglevel", "error", "-y", "-i", $src, "-vn", "-map_metadata", "-1",
           "-c:a", "libmp3lame", "-b:a", "${Bitrate}k", "-ar", "44100", "-ac", "2", "-id3v2_version", "0", $dst)
    & $Ffmpeg @a 2>&1 | ForEach-Object { Write-Output ("FFMPEG " + $_) }
    if (-not (Test-Path $dst)) { throw "转码失败: $src" }
}

$silence = Join-Path $work "_silence.mp3"
& $Ffmpeg -hide_banner -loglevel error -y -f lavfi -i "anullsrc=r=44100:cl=stereo" -t 0.25 `
    -c:a libmp3lame -b:a "${Bitrate}k" -id3v2_version 0 $silence 2>&1 | Out-Null
if (-not (Test-Path $silence)) { throw "静音占位生成失败" }

for ($i = 0; $i -lt $plan.Count; $i++) {
    if ($i -lt $inputs.Count) {
        $dst = Join-Path $work ("in_" + $i + ".mp3")
        Convert-To $inputs[$i].FullName $dst
        $plan[$i].Src = $dst
        $plan[$i].Real = $true
        $plan[$i].From = $inputs[$i].Name
        Write-Output ("SLOT " + $plan[$i].Bank + "/" + $plan[$i].Sample + " <= " + $inputs[$i].Name)
    } else {
        $plan[$i].Src = $silence
        Write-Output ("SLOT " + $plan[$i].Bank + "/" + $plan[$i].Sample + " <= (silence)")
    }
}

$bak = Join-Path $Mod "_build\prev"
New-Item -ItemType Directory -Force -Path $bak | Out-Null
foreach ($d in $donors) {
    $rows = @($plan | Where-Object { $_.Bank -eq $d.BaseName })
    $names = [string[]]($rows | ForEach-Object { $_.Sample })
    $mp3s = [string[]]($rows | ForEach-Object { $_.Src })
    $tmp = Join-Path $work ($d.BaseName + ".fsb.new")
    Write-Output ("BUILD " + $d.BaseName)
    Write-Output ([FsbTool]::Build($d.FullName, $tmp, $names, $mp3s, 1152, 32))
    Copy-Item $d.FullName (Join-Path $bak ($d.BaseName + ".fsb")) -Force
    Copy-Item $tmp $d.FullName -Force
    $back = [FsbTool]::Names($d.FullName)
    if (($back -join "|") -ne ($names -join "|")) { throw "回读的名字表和 donor 不一致: " + $d.BaseName }
    Write-Output ("WROTE " + $d.FullName + " " + (Get-Item $d.FullName).Length + " B names=" + ($back -join ","))
}

# 清单：需要按曲目时长收尾的引擎在启动时读它，只播这里列出的槽位。
# 空文件 = 这个 mod 什么都不做，所以宁可写空的，也不要留上一次构建的残行
# （那会让游戏播一段已经不存在的静音）。
$musicDir = Join-Path $Mod "music"
New-Item -ItemType Directory -Force -Path $musicDir | Out-Null
$IC = [System.Globalization.CultureInfo]::InvariantCulture
$list = @("# generated by build_banks.ps1 - do not edit; one line per track: <event> <seconds>")
foreach ($r in $plan) {
    if (-not $r.Real) { continue }
    $sec = [FsbTool]::Sec($r.Src)
    $list += ($r.Event + " " + $sec.ToString("0.00", $IC))
    Write-Output ("TRACK " + $r.Event + " " + $sec.ToString("0.00", $IC) + "s <= " + $r.From)
}
[System.IO.File]::WriteAllLines((Join-Path $musicDir "tracks.txt"), $list)
Write-Output ("MANIFEST-TRACKS " + ($list.Count - 1) + " -> music/tracks.txt")

Write-Output "BUILD-DONE"
Write-Output "下一步：sh tools/sync_to_game.sh 同步进游戏目录，重启游戏，"
Write-Output "然后在 client_log.txt 里确认 'Loading mod:' 那一行加载的是你期望的那一份。"
