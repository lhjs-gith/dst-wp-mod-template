# 饥荒联机版主菜单壁纸 mod 模板 / DST Main-Menu Wallpaper Mod Template

一个能直接跑的**纯客户端**饥荒联机版（Don't Starve Together）mod 骨架：把主菜单背景换成循环播放的视频。
自带三张程序化绘制的演示壁纸（不含任何第三方素材），代码里所有的坑都是实测踩过来的。
做一个新主题的壁纸 mod，正常情况下只需要换 `movies/` 里的素材、改 `modmain.lua` 顶部那一小段常数。

它从一个已经更新到第 12 版、有真实订阅者的 mod（工坊条目 3812384622）里剥出来，
剥掉了所有版权画面和音频，只留引擎 + 自产示例。

---

## 五分钟起步

1. **改名字。** `modinfo.lua` 的 `name` / `tagline` / `author`，和 `mod.manifest` 的 `title` / `author_name`。
2. **换 UUID。** `mod.manifest` 里那个 `uuid` 必须换成你自己的新值（`powershell -Command "[guid]::NewGuid()"`）。
   同一个 UUID 并存两份时游戏会自己去重，抄别人的 UUID 会和已订阅的工坊版撞车。
3. **放素材。** 把任意 Theora 视频拷成 `movies/1.ogv`（游戏不认 mp4），旁边放一个 `movies/1.cfg` 写它的时长和比例。
   首帧垫图可选，但缺了它接缝处会垫黑，见下。
4. **进游戏看一眼。** 拷到 `Don't Starve Together/mods/<你的目录名>/`，模组列表里启用，回主菜单。
   日志 `<文档>/Klei/DoNotStarveTogether/client_log.txt` 里应有 `Loading mod: <名字> Version:1`。
   **先把其它同类壁纸 mod 关掉**（尤其是本模板的另一个副本）。实测：两个都启用时只能看到其中一个的画面，
   而且谁在上面**与模组加载顺序无关**（改目录名调整先后、把 `MoveToBack` 换成 `MoveToFront` 都没能翻过来），
   所以"看不到自己的壁纸"通常是层级被另一个 mod 顶了，不是素材没加载。
   关掉另一个之后本模板一切正常：1 号槽的画面会动、按 `s` 干净地切到 2 号槽（中间不闪黑）、
   主菜单 logo 和按钮列始终在壁纸之上。
5. **改文案。** `modinfo.lua` 的 `description` 就是游戏内模组列表看到的说明；工坊页的描述是另一套，要单独写。

**默认状态就能加载**：`MUSIC_TRACK_COUNT = 0`，也就是不带音频包、保留原版 BGM。
不需要动任何代码就能看到壁纸转起来。

## 目录里有什么

| 路径 | 说明 |
| --- | --- |
| `modmain.lua` | 全部逻辑。顶部「改这里」那一段常数就是唯一的参数面，下面的引擎部分不用动 |
| `modinfo.lua` | 元信息 + 配置项（每项都有 hover）。音乐那一整项是注释掉的，加音频包时取消注释 |
| `mod.manifest` | Klei 打包用的清单，必须是**纯 JSON** + **你自己的新 UUID** |
| `movies/` `images/` | 素材：`N.ogv` + `N.cfg`（参数）+ `N.tex`/`N.xml`（首帧垫图） |
| `art/` | 三张演示壁纸的**生成脚本**与滤镜图，以及图标源图 `modicon.png` |
| `tools/` | 无 GUI 生成 `.tex` 的两个 PowerShell 脚本 + Flags 补丁 |
| `sound/` | 空。要放自定义音乐就得自己打 FMOD 音色库（`mymusic.fsb` + `mymusic.fbp`） |
| `preview.jpg` | 工坊条目的展示图（ModUploader 只认这个位置这一张） |
| `modicon.tex` `modicon.xml` | 模组图标 |

## 「改这里」常数（`modmain.lua` 顶部）

| 常数 | 作用 | 注意 |
| --- | --- | --- |
| `MOVIE_SLOTS` | 壁纸槽位数，默认 8 | 改了要同步改 `modinfo.lua` 的壁纸档位；档位 `data` 必须从 1 连到 N，`N+1` 是"轮换"，`0` 是"关闭" |
| `VIDEO_ASPECT` | "保持比例"模式下的默认宽高比 | 引擎拿不到片子原生尺寸，只能靠这里或素材自带 `aspect=` |
| `DURATION_HINTS` | 各槽位的时长种子（秒） | 让接缝在**播完之前**就盖上，而不是等播完才知道周期；素材有 `duration=` 时种子被顶掉 |
| `MUSIC_TRACK_COUNT` | 自定义音乐曲目数，**模板默认 0** | 0 = 整段音乐逻辑短路，`sound/` 可以完全为空 |
| `SOUND_BANK` / `SOUND_FEV` / `SOUND_EVENT_ROOT` | FMOD 音色库名 / 工程名 / 事件路径前缀 | 三个名字必须和工程内部名逐字对应，见「自定义音乐」 |
| `ROTATE_KEY` | 轮换进度在存档里的键名 | **每个 mod 要用自己命名空间的值**，否则几个同源 mod 会互相顶掉进度 |

## 素材流水线

```sh
# 1) 转成 Theora .ogv（游戏只认这个；-an 去掉音轨，否则素材的声音会和背景音乐叠着响）
ffmpeg -i input.mp4 -an -c:v libtheora -q:v 3 -s 1920x1020 movies/1.ogv

# 2) 首帧垫图：必须取视频真正的第 0 帧，不能拿原静帧（那样接缝会跳一下）
ffmpeg -i movies/1.ogv -vf "select=eq(n\,0)" -frames:v 1 -update 1 art/frame1.png

# 3) png -> 游戏认的 tex（Klei TEXCreator 没有命令行版，只能反射调；必须 32 位 PowerShell）
export TEXCREATOR_EXE='C:/搜出来的/TEXCreator.exe'   # 正斜杠、单引号，全路径见本节末尾
/c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File tools/png2tex.ps1 -InPng art/frame1.png -OutTex images/1.tex -Exe "$TEXCREATOR_EXE"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/patch_tex_flags.ps1 -Tex images/1.tex

# 4) 参数文件
printf 'duration=12\naspect=1920x1020\n' > movies/1.cfg
```

上面这四步就是 `art/generate.sh` 做的事，仓库自带的三张演示素材是它跑出来的：除 `.ogv` 里的
Ogg 流序号（每次编码随机，连带 CRC 一起变，解码出来的每一帧逐字节相同）之外，重跑一遍与仓库里的
文件逐字节一致，`cfg`、`tex`、`xml` 全等。想验证自己的环境能不能跑通，就在临时目录里跑一次再 `cmp`。

`images/N.xml` 手写就行，元素名固定 `<槽位>.tex`，uv 各留半个纹素内缩
（`u1 = 0.5/宽`，`u2 = 1 - u1`，v 同理）——`art/generate.sh` 里有一段 awk 直接算好写文件的写法，抄它。

**`-q:v 3` 会被 libtheora 悄悄丢帧**，实测（ffmpeg 7.1，2 秒 24fps 输入 = 48~50 帧）：
低运动的慢速平移只落 **35** 帧，完全静止的输入只剩 **8** 帧，换成 `-q:v 9` 就是 **48** 帧全留（体积 3.3 倍）。
丢的是时间轴上的洞、总时长不变，所以接缝位置和 `duration=` 都不受影响，平移类素材肉眼也看不出掉帧——
但你要真 24fps 就把 `-q:v` 调到 9。模板自带的三张是 `-q:v 3` 生成的，等于约 17fps。
本机没有 ffprobe，数帧就用这个（`-c copy` 不解码，`frame=` 就是包数）：

```sh
ffmpeg -i movies/1.ogv -map 0:v -c copy -f null - 2>&1 | grep -oE 'frame= *[0-9]+' | tail -1
```

**TEXCreator 的位置随 Mod Tools 版本而变，别照抄路径**（这台机器上 `mod_tools/` 里就没有它）。
先搜：`where /r "…\Don't Starve Mod Tools" TEXCreator.exe`。找不到就注意它是 .NET 窗体程序，
反射调用时 `KleiLib.dll`、`SquishNET.dll`、`NativeSquish_x86.dll`、`NativeSquish_x64.dll`、
`Cyotek.Windows.Forms.ImageBox.dll` 必须和 exe 同目录，凑齐这一个文件夹就能用。

想要**看不出接缝**的循环，两条路：
选首尾画面接近、结尾不要淡出到黑的片子；或者用正弦驱动的镜头位移，位移周期等于片子时长，
那么第 T 秒的画面严格等于第 0 秒，接缝在数学上就是连续的（`art/generate.sh` 就是这么生成演示素材的，
不需要"正放 + 倒放"那种来回摆的剪法）。

### 素材缺件时的退化行为（2026-10-07 用 5 个探针副本实测，不是读代码猜的）

| 情况 | 引擎实际做法 |
| --- | --- |
| 只放了 `movies/1.ogv`，槽位数仍是 8 | 正常加载：`n=1`、`assets=3`；"轮换"档退化成永远这一张，W/S 因为 `n < 2` 直接空转，不报错 |
| 配置项选了没有文件的槽位 | 自动回落到**第一个可用槽位**（实测 wanted=5 → pick=1），和 modinfo 里承诺的一致 |
| 有 `movies/N.cfg` 但没有 `images/N.tex` | 槽位仍然登记（视频照播），只是首帧垫图关掉：`atlas=N`、`still=N`、`first=false`，接缝处改垫黑，**不崩** |
| cfg 里 `duration=0` / `duration=9999` / `aspect=abc` / `aspect=100` | 逐个静默丢弃（有效区间是 0<duration<3600、0.2<aspect<8），该槽位回落到配置项档位、再回落到 `VIDEO_ASPECT` 常数 |
| cfg 的 key 写成大写 `DURATION = 6` | **照样生效**（解析时 `key:lower()`），值两侧的空白也吃；`#` 注释行里带的 `duration=99` 不会被误读 |

"保持比例"档的黑边数学也一并量过（1920x1080 屏，设计坐标 1280x720）：`aspect=4:3` → 960x720（左右留边），
`aspect=21:9` → 1280x548.57（上下留边），cfg 里 aspect 无效时 → 用常数 1.882353 → 1280x680。

## 实现要点（全部实测过，动这些之前先读完）

`Video` 部件的约束比预期多，下面每一条都对应一次崩溃或一段黑屏：

- **没有循环 API，没有 `SetTint`**；`GetSize()` 在 `Load` 之后一律返回 `(0, 0)`，拿不到片子原生尺寸。
- **接缝处理**：在预计播完前把首帧贴图盖在视频上层，再重新 `Play()`；等 `IsDone()` 才盖就漏黑了。
  更麻烦的是引擎的 `IsDone()` 比片子的**最后一帧**还晚 1~2 秒（实测 44.63 秒的素材到 45.7 秒才翻真），
  而这段"排水期"里只要这个片子是本进程第一次解码，部件就只输出纯黑（录屏量到 YAVG 7.63，持续 2.07 秒；
  第 2 圈起有缓存，hold 住最后一帧，所以不黑）。因此揭盖只允许走**一个**闸门：
  `盖着 && 到了期限 && IsDone 为假`。尾巴盖上去之后代码里不许有第二处揭盖，也不能靠"每帧重新盖"来维持盖子——
  那个触发条件（时长种子）一过期，停止重盖本身就等于揭盖，黑就是这么漏出来的。
  冷启动那一档垫 4 秒，之后各圈 0.35 秒；垫的那张图就是片子自己的第一帧，所以多垫一两秒看不出来。
- **同帧 `Kill()` 一个正在播的 `Video`，一秒后必 `abort()`**。所以换素材拆成两帧：当帧只 `Stop()`+`Hide()` 旧的，
  下一帧由一个独立的空壳 ticker 部件来 `Kill()`。这正是原版 `screens/moviedialog.lua` 的做法。
- **不要在主菜单的 `OnHide`/`OnShow` 里对 `Video` 调 `Stop`/`Play`**，会触发原生断言崩在 `util/Pool.h`。
  代码里注释标了这一点，别"顺手优化"回去。
- **压暗**：`Video` 不支持 `SetTint`，所以在壁纸部件最上层蒙一张 `images/global.xml` 的 `square.tex`，
  用 `SetTint(0,0,0,alpha)` 当半透明黑。这层必须加在**首帧垫图之上**，否则接缝换帧那一下画面会跟着忽明忽暗。
- **改 `FrontEnd` 的行为必须用 `AddGlobalClassPostConstruct("frontend", "FrontEnd", fn)`**：
  `frontend.lua` 只把 `FrontEnd` 定义成全局、文件末尾没有 `return`，用 `AddClassPostConstruct` 会踩中
  modutil 的 `assert(type(classdef) == "table")`，症状是 `MOD ERROR` + 模组被自动关掉 + `Force aborting`，
  看起来像"游戏无故崩溃"。
- **客户端 mod 的配置界面只渲染 list 型选项**，`type="number"` 的根本不出现 —— 所以每素材的数值参数走
  `movies/N.cfg` 旁路文件（沙盒里 `io.open` + `softresolvefilepath` 实测可用）。
- **按键只认 `keyup`**：长按时系统连发 `keydown`，一次物理按键的 `keyup` 只来一回，否则一按跳好几张。
  动作也不在回调里当场做，只记一笔到队列，交给下一帧的 `OnUpdate` 消费，
  并且只在主菜单确实是栈顶屏幕时才消费（`FrontEnd` 每帧只更新栈顶那一屏）。
- **方向键和 WASD 在原版里都是菜单导航键**（`frontend.lua` 同时听 `CONTROL_MOVE_*` 和 `CONTROL_FOCUS_*`），
  所以本 mod 会把自己占用的那几个键从导航里摘出去：按 W 只换壁纸、选中框不跳，
  而你没占用的那一组（以及手柄十字键）照常导航。
- **轮换的进度是异步读的**：`TheSim:GetPersistentString` 的回调可能比第一次构造还晚到，
  那种情况就先随机一张、把进度写下去，并且回调后到也不覆盖自己刚写的值。
  落在 `Documents/Klei/DoNotStarveTogether/<SteamID>/client_save/`，每个 profile 一份、重装 mod 不丢。
- **散包 `mods/<name>` 与已订阅的工坊版 UUID 相同时，谁生效以模组列表的勾选为准**（两份都启用时工坊版顶掉散包）。
  日志里 `Loading mod:` 那一行才是唯一判据。
- **日志里中文 `print` 会被剥掉**，排错要靠 ASCII 探针行。发布前记得删掉探针。

## 自定义音乐：能做和不能做

- **不能**用你自己的 mp3/ogg/wav。饥荒没有任何播放裸音频文件的接口；实测把纯音轨的 `.ogg` 放进 `movies/`
  彻底不认——`Video` 部件要求存在 Theora 画面轨，只有 Vorbis 的话一帧都解不出来，完全没声。
- 想换背景音乐只有一条路：**随 mod 打包预烘焙的 FMOD 音色库**（`.fsb` + `.fev`），
  然后用 `GLOBAL.FE_MUSIC = <事件路径>` 顶掉原版主菜单音乐。
- 想用别的歌又不想打音色库，唯一取巧的办法是把音频封进一个带画面的 `.ogv` 当壁纸素材（素材自带音轨的话
  游戏会连声音一起放出来，和背景音乐叠着响；那一轨本身没有音量控制，但背景音乐可以用「主菜单音量」档压下去）。
- 事件路径**和你存的文件名无关**，取决于工程内部名：
  `事件路径 = <工程内部名>/<事件组名>/<事件名>`。两条命名惯例必须满足，否则游戏静音且不报错：
  `.fev` 文件名必须等于工程内部名，`.fsb` 文件名必须等于音色库内部名。
  本模板的三个常数就是按 `mymusic.fbp` / `mymusic` 这套写的；拿到别人的音色库先按 RIFF chunk
  把 `PROP`（工程名）、`LGCY`（音色库名）、`STRR`（事件组/事件名）读出来核对。
- 启用步骤：把音色库放进 `sound/` → `MUSIC_TRACK_COUNT` 改成曲目数 → 取消 `modinfo.lua` 里 `music` 那一整项的注释
  并按 `data = 1~N` 填曲目名、`N+1` 是"随机播放"、`0` 是原版。
- 音量挂在**事件标签**上：`SoundEmitter:SetVolume("FEMusic", 0.5)`。它和游戏选项里的"音乐音量"是两条链
  （后者调 FMOD 的 `set_music` 总线），两者**叠乘**而不是互相覆盖。游戏每次重新 `PlaySound` 都可能把它顶回默认值，
  而 mod 的钩子在 post-construct、抢不到起播那一刻，所以要在"从没在响 → 在响"这个沿上补一次。
- 上面这一整条分支 2026-10-07 在游戏里实测过（副本 `z-tt-m`，`MUSIC_TRACK_COUNT = 4`）：注册出
  `assets=11`（9 条壁纸 + `FILE(.fsb)` + `SOUNDPACKAGE(.fev)`），看门狗回报事件真的在响，
  四首逐个切过去都是 `playing=true`，50% 音量档在起播沿上补到了。改这些之前照着这段断言复现即可。

### 这一对 `.fev`/`.fsb` 到底怎么做出来（2026-10-07 调研；除路线 1 外，**没有一条跑到"游戏里能响"**）

先说结论：**事件库（`.fev`，FEV4）到今天仍然只有 FMOD Designer 这一条路**，而 Designer 早在 FMOD Studio
出现时就停更、也从官网下架了。采样库（`.fsb`，FSB5）反而是现在还能拿到工具生成的那半。所以三条路按门槛排：

| 路线 | 要不要旧版工具 | 状态 |
| --- | --- | --- |
| 1. 音频封进带画面的 `.ogv` 当壁纸素材 | 完全不用 FMOD | **本仓库实测过**，见上一条与「能做和不能做」 |
| 2. FMOD Designer 建工程 → Build 出 `.fev` + `.fsb` | 需要 Designer 4.3x（官网已下架） | 调研到的唯一正规做法，本机没跑过 |
| 3. 先借到一个 `.fev` 壳，之后只用 `fsbankcl.exe` 重打 `.fsb` | 只需要现在还能下载的 FMOD Engine | 机制在本地取证里成立，工具没跑过 |
| 4. 同样借壳，但采样库用 **FMOD Studio** 构建后从 `.bank` 里切出来 | 只需要 Studio（本机就有） | **本机实测过：游戏里播不出来**，Vorbis 和 PCM 两种压缩都试过，见本节末尾 |

**路线 2 的具体信息**（来自 2024-05 还在维护的同类游戏音频 mod 工程，作者明确写"官网已经找不到，
只能从 Internet Archive 拿"）：用的版本是 **FMOD Designer 4.30.06**；工程文件 `.fdp` 是**纯文本**，
可以用编辑器直接改，所以一个壳工程是可以随仓库分发的（那种做法见下一节"取证"）；Designer 附带
**FMOD Event Player**，可以在进游戏之前先听一遍自己 build 出来的 `.fev`；两条已知坑：
文件名超过 **30 个字符会被打进库里的名字截断**，以及**自己 build 出来的库没法再抽回音频**，
所以原版那对一定要留备份。饥荒社区里流传的中文教程（2018-06）给的操作顺序和本模板的三个常数正好对得上：
新建工程取名 `X` → 把 soundbank 也改名成 `X` → Build → 拿 `X.fev` + `X.fsb` 放进 `sound/`。

**路线 2 在本机有实物证据，不是道听途说**：游戏的 `mods/` 目录里留着一个 2026-09 做音乐 mod 时留下的
**完整 FMOD Designer 工程**（`mods/MyMusicMod/sound/mymusic.fbp.fdp.autosave`，纯文本），旁边就是它的
4 个 `.wav` 源文件、`.fsbcache` 构建缓存、以及 build 出来的 `mymusic.fbp.fev` + `mymusic.fsb`
——p3r 现在用的那对音频跟它**逐字节相同**（md5 `1bb502e1…` / `795486d6…`）。工程里的结构和本模板的三个常数一一对上：

```
<project><name>mymusic.fbp</name>        → 产出 mymusic.fbp.fev，也就是事件路径的前缀
<soundbank><name>mymusic</name>          → 产出 mymusic.fsb
<eventgroup><name>untitled</name>        → 事件 1 / 2 / 3 / 4，每个是一条 __simpleevent_sounddef__
<_PC_banktype>DecompressedSample         → 采样以 PCM 入包
<filename>want_to_be_close.wav           → sounddef 只按文件名去 fsb 里找采样
```

所以"改一个现成壳工程"是看得见摸得着的：`.fdp` 是文本，改名、改 `<filename>` 指向自己的音频都行，
**只要装得上 Designer 就能 Build**。本机现在装不上（只有 Studio，全盘也没有 Designer 和 `fsbankcl.exe`），
这一条卡在获取工具，不卡在方法。

**路线 3 的依据是本仓库自己那个包的取证结果**，不是别人的说法：

```
$ grep -a -oE '[ -~]{5,}' sound/mymusic.fbp.fev | head
FEV FMT / PROJOBCT: mymusic.fbp / LGCY: mymusic.fbp + mymusic / master, music, untitled
want_to_be_close.wav  wall_moon_full_life.wav  color_your_night.wav  chaning_seasons.wav
untitled  /__simpleevent_sounddef__/1_0 … /4_3  default

$ head -c 4096 sound/mymusic.fsb | grep -a -oE '[ -~]{6,}'
want_to_be_close  wall_moon_full_life  color_your_night  chaning_seasons
```

也就是说：`.fev` 里的 sounddef 只按**采样名**去 `.fsb` 里找人，而 `.fsb` 的名字表就是**不含扩展名的文件名**。
所以只要保持文件名一致，事件库不动、只重打采样库是成立的。有一个正在这么干的开源工具可以做参照：
`IZH318/FSB-BANK-Extractor-Rebuilder`（C#/.NET 4.8，GPL-3，GUI v3.0 起有 Rebuild，2025-12-30 还在更新），
它的源码里调的就是 FMOD 官方命令行工具：

```
fsbankcl.exe -o <out.fsb> -format vorbis|fadpcm|pcm -q <N> <音频目录>
```

`fsbankcl.exe` 属于现在官网仍在提供的 FMOD Engine（该工具用 2.03.11），选 `vorbis` 或 `pcm` 而不是
`fadpcm`（后者是主机向的新格式，FMOD Ex 那代不一定认）。**注意它只解决采样库那半，`.fev` 它写不出来。**
换上的音频长度和原来差太多时，事件里记的时长/loop 点会对不上（那个工具的 UI 会直接标 `[LONG]`/`[SHORT]`
并警告循环可能被破坏），做背景音乐可以、做要精准衔接的音效就得自己核。

**取证方法（这一条本机实测过）**：`grep -a -oE '[ -~]{5,}' your.fev` 就能看到工程内部名、音色库内部名、
事件组/事件名和引用的采样名，三个常数照着抄即可。反过来 `.fsb` 头部第四个 4 字节是版本号，
`FSB5` 才是 FMOD Ex 那一代。

**顺带把"Studio 的包游戏为什么不认"取证清楚了**（本机有 FMOD Studio 2.03.14，命令行版可以**离线、不登录**构建）：

```
$ fmodstudiocl.exe -build -banks Vehicles .../Examples.fspro
Build completed successfully.

$ head -c 16  .../Build/Desktop/Vehicles.bank        # Studio 的产出
RIFF … FEV  FMT  …  0x92 (=146)
$ head -c 16  sound/mymusic.fbp.fev                 # 游戏认的那一份
RIFF … FEV  FMT  …  0x04 (=4)
```

也就是说 `.bank` 根本不是另一种容器，它**也是 RIFF/FEV**，只是 `FMT` 版本是 **146**；
游戏链接的 `fmod_event64.dll` 是 FMOD Ex 那一代、只认 **4**。扩展名骗人，版本字段不骗人，
**所以 `.fev` 那半用现代 FMOD 做出来仍然没用**。

有价值的是采样库那半：同一个 `.bank` 在偏移 18048 处嵌着一段 `FSB5`，把它和**游戏里已经能响的
`sound/mymusic.fsb` 差分对比**，布局完全同构——前缀装名字表、后面紧接样本数据、正好到文件尾：

| | 文件大小 | FSB5 起点 | 名字表位置 | 样本数据长度 | 前缀+数据 |
| --- | --- | --- | --- | --- | --- |
| `sound/mymusic.fsb`（游戏实测能响） | 16,893,024 | 0 | 209 | 16,892,768 | =16,893,024 ✓ |
| Studio 构建产物内嵌的 FSB5 | 222,624 | 18,048 | 相对 +796 | 203,264 | =204,576 = 剩余字节 ✓ |

两边头部的版本字段都是 `FSB5` + `1`，而且 Studio 存进名字表的就是**源文件名去掉扩展名**
（`veh_car_engine_190E_05845.ogg` → `veh_car_engine_190E_05845`），跟上面"FEV 按采样名找人"的规则严丝合缝。
所以 2026-10-07 深夜按这条做了一次实测，当时的记录是"不行"——**那一次其实是假阴性**（原因见下面 10-08 的补正），
真正的判定是第二天用零冲突的 A/B 做出来的。

做法：把示例工程里 4 个素材的路径改成按 `.fev` 要求命名的音频（`want_to_be_close.wav` 等），
`fmodstudiocl -build` → 从产出的 `.bank` 里切出 `FSB5` 魔数到文件尾那一段 → 命名成 `mymusic.fsb`，
配上借来的 `.fev` 壳进游戏。结果主菜单**一点声音都没有**，而 `PlayingSound("FEMusic")` 全程为 false；
同一个副本、同一行探针，只把 fsb 换成 p3r 原始那一份，33 秒后就打出 `playing confirmed`。
当时以为对照做完了 —— 其实没有：那两次启动里 `p3r` 也开着，两边登记的是**同一组资产名**，
"playing confirmed" 完全可能是 `p3r` 自己那份在响。

已经排除掉的：切片本身是自洽的（前缀装名字表 + 数据 = 文件长度，和能用的包同一个算法）；
`FSB5` 魔数后的版本字段所有包都是 `1`，不是差异点。

**2026-10-08 补正两处判读，并把这条路线判死。**

先纠正一段写错的取证：p3r 那个能响的 `mymusic.fsb` **不是 PCM，是 MP3**（`f18=11`）。
按帧头 `FF FB A0 40` 解出来是 160 kbps / 44.1 kHz / joint stereo，规模也对得上：
4 个源 wav 共 148,545,164 字节裸 PCM = 842 秒，160 kbps × 842 s = 16.89 MB = 文件实际大小。
它旁边那份 `.fdp` 工程里写着 `_PC_banktype = DecompressedSample`，说明**这一项并不决定最终编码**
（或者发布的那一对不是这个 autosave 构建的）——以字节的实测结果为准。顺带把 `f18` 标定清楚了：
**2 = PCM16、11 = MP3、15 = Vorbis**，三份地面真值各自对过。

于是"差在编码方式上"这个假设当天就被自己推翻了：**Klei 原版自己的 `amb_stream.fsb`、`bat.fsb`
全是 `f18=15`（Vorbis），游戏里照常响。** 游戏不认 Vorbis 这个说法从来就不成立。

那还是不是 PCM 的问题？做了第二轮，并且把上一轮的混淆项一次拆干净：

- 把 Studio 工程的**平台级**压缩设置改成 PCM（不是素材属性，是 `Metadata/EncodingSetting/*.xml`
  里的 `encodingFormat`，`0` 就是 PCM；只改 Desktop 平台，HTML5 留着不动，构建产物自带对照）。
  `fmodstudiocl -build` 出来的 `Vehicles.bank` = 8,062,112 字节，切出的 FSB5 = 8,044,064 字节、
  `f18=2`、19 个采样，四个曲名（`want_to_be_close` 等）全在名字表里。
- **上一轮的假阴性**：那次只改了 4 个 `Metadata/AudioFile/*.xml` 的 `file` 路径，采样属性还写着
  原来的汽车引擎素材，294 KB 的包也装不下 4×8 秒的音乐，所以进游戏测的很可能是"用我们的名字
  打包的 Examples 汽车音"——那次"播不出来"证明不了什么。
- **资产名冲突**：`p3r` 与测试副本都登记 `Asset("FILE","sound/mymusic.fsb")` +
  `Asset("SOUNDPACKAGE","sound/mymusic.fbp.fev")` 时，任何结论都归不到具体那一份。
  修法是把 `.fev` 里的内部名做**等长改写**（`mymusic` → 7 字节的 `zctrl01` / `ztesttc`，
  偏移 324/356/400 三处），事件路径随之变成 `zctrl01.fbp/untitled/1`，再用私有标签
  （`Sound:PlaySound(event, tag)` 的第二参只是表键，随便起名），两份库在同一次启动里 A/B。

同一次启动、主菜单静止、每 5 秒一行心跳，11 行完全一致：

```
[FSB3] fired t=010.0
[FSB3] t=015.0 ctrl=true pcm=false femusic=true
...
[FSB3] t=060.3 ctrl=true pcm=false femusic=true
```

`ctrl=true` 是 p3r 原库套在改写后的壳里 —— 等长改写这招本身有效；`femusic=true` 是没动过的
`p3r` 那一对照常在响；`pcm=false` 就是这份 **PCM** 切片。日志里没有任何 FMOD 报错，
两个 `Asset` 都登记成功了，所以失败发生在 FMOD 侧而不是资源侧。

**结论：`.fsb` 用 FMOD Studio 构建（Vorbis 或 PCM 都试过）在 DST 里播不出来，与压缩方式无关。**
唯一在本机验证过的可用产出仍然是 FMOD Designer 4.3x 的 `.fev` + `.fsb` 那一对（路线 2/3）。
唯一还没排掉的观测差异：头部 `f24` 在两个能响的包里是非零（p3r `841600964`、Klei `1876034021`/`4066884513`），
在两份 Studio 切片里都是 `0`——**没验证过它是不是原因，别当结论用**。
要继续挖的话只剩 `fsbankcl.exe`（本机没有，得自己从 FMOD Engine 里拿）。
**请把 `.fev` 那半当作只有 FMOD Designer 能做**——下面这条是本仓库自己的现成证据。

## 上架创意工坊（ModUploader）

上传这一步只能手点，别指望脚本驱动它的 UI。清单：

1. **Target Game 下拉框默认停在单机版 `Don't Starve`（appid 219740）**，必须先切到 `Don't Starve Together`，
   否则 mod 传到另一个工坊去。
2. **展示图路径写死在 mod 目录内的 `preview.jpg`**，不接受外部路径、也不能是 png。它会被一起打进包里。
   工坊条目**只能有这一张图**（多图画廊要走网页端，且实测会让大图区渲染成纯黑）。
3. **`Upload redundant files` 必须勾上。** 不勾时上传器会自行过滤它认为冗余的文件，
   而 `images/N.xml` 这种运行时必需的图集描述正好会被误过滤 → 订阅者黑屏。
4. **`version` 每次上传都要和工坊上挂着的那一版不同**，哪怕你只改了展示图。
   相同会弹 `Update Error: The version specified in modinfo.lua needs to be different…`，
   而且这是**预检拒绝**，什么都不会传上去。
5. **Data 路径指向发布目录本身**，不要指到会带 `_tools/` `_backup/` `_inbox/` 的开发仓库根。
   注意 ModUploader 在注册表里把这个目录**绑定成绝对路径**（`HKCU\Software\Klei\Don't Starve Mod Uploader\MRU\<条目 id>`），
   所以别改名、别挪位置。
6. Tags 用的是饥荒 1 代那一套（art/character/creature/environment/interface/item/language/other/pet/scenario/tutorial）。
   `language` 是"翻译 mod"，壁纸类别勾。
7. **上传成功 = 三条独立判据**，缺一条都不能宣布"传完了"：
   - `<Steam>\logs\workshop_log.txt` 里有 `Upload finished for workshop item <id> : OK`
     （上传不会在本地留任何痕迹，`appworkshop_322330.acf` 也不动）；
   - 订阅回来的 `workshop/content/322330/<id>/` **逐文件 md5** 与发布目录全等，只允许 `mod.manifest` 不同
     （本地是 56 字节 JSON，工坊下载回来是 Klei 的 MNFS 二进制，属正常形态）；
   - `client_log.txt` 里 `Loading mod: workshop-<id> (<名字>) Version:<新版号>`。
8. 上传后本地工坊副本要等 Steam 重新同步才换新版，`workshop_log.txt` 里出现
   `Download item <id> result : OK` 才算落地；**验证自己的上传通常要两次启动游戏**
   （第一次仍打印旧版号，但它触发了下载；第二次才是新版）。
9. `Upload finished : Access Denied`（新建能过、改版被拒）：数据其实已经传上去了，被拒的是最后提交那一步。
   先彻底退出并**重启 Steam 客户端**（不只是游戏）再重试；仍然被拒就等 30~60 分钟——刚创建的条目连续改版会被限流。
10. 只改文字不用重传文件：Edit → `Update Details` 单独改工坊页的标题/描述/标签/补丁说明。
    反过来，**`Update Data` 不会刷新工坊页的描述**，只改游戏内列表。两个界面互相独立。

## 版权：这一条能毁掉一个 mod 的口碑

- 演示素材（`art/` 生成的那三张、`modicon.png`、`preview.jpg`）全部由 ffmpeg 滤镜程序化绘制，
  不含第三方内容，和代码一起按 MIT 许可发布。
- 换成自己的素材之后，**工坊页的署名义务跟着变**。凡是提取自商业游戏（《Persona 3 Reload》《原神》之类）
  或者别人在 Wallpaper Engine 上发布的二次创作，都要在描述里逐个写明出处；
  **绝对不要**写"本条目不含任何来自该游戏的素材"这类话——订阅者拿包里的文件一比就穿帮了，
  而且这条错误声明比素材本身更容易被截图挂出来。
- 源码仓库和工坊包是两套分发：常见做法是仓库只发代码 + 自产示例，把有版权的 `movies/`、`images/`、
  `preview.jpg`、`modicon.tex` 写进 `.gitignore`，而工坊包用 `Update Data` 把它们发出去。
  本模板的 `.gitignore` 里留了这一段注释掉的写法。
- 上游致谢：整体结构与"接缝处用首帧图盖住再重播"的做法参考创意工坊 mod「温蒂动态壁纸」
  （作者 zzzzzzzs、临夏听舟，条目 3547896422）。**借的是思路，不是代码**——
  逐行比对下来同源 mod 里只有通用样板（`require "widgets/…"` 那几行、`*_compatible` 标志块）相同。
  这条致谢请保留在你做出来的 mod 的 README 和工坊描述里。

## 许可

代码与本仓库所有示例素材按 MIT 发布（见 `LICENSE`）。用这个模板做出来的 mod 不需要再附许可声明，
但换进去的素材的版权不在这里。
