# art/common.sh —— 素材流水线的共用构件，由 art/ 下的 generate.sh 等脚本 source 进来。不要直接执行它。
#
# 前置约定（调用方都照这个办）：
#   ART_DIR  = art/ 目录的绝对路径
#   FF       = ffmpeg 可执行文件（绝对路径或 PATH 里的名字）
#   WORK     = 一个临时目录，调用方负责清理
#   MOVERS / IMAGES = 输出目录（相对 ART_DIR 的 ../movies、../images，或绝对路径）

# TEXCreator 的位置随 Mod Tools 版本而变（这台机器的 mod_tools/ 里就没有），所以按优先级找：
# 环境变量 → 常见安装位置 → E 盘那份独立拷贝。找不到就返回非 0，由调用方决定是跳过还是报错。
find_texcreator() {
    if [ -n "$TEXCREATOR_EXE" ] && [ -f "$TEXCREATOR_EXE" ]; then
        printf '%s' "$TEXCREATOR_EXE"
        return 0
    fi
    for c in \
        "/d/SteamLibrary/steamapps/common/Don't Starve Mod Tools/mod_tools/TEXCreator.exe" \
        "/c/Program Files (x86)/Steam/steamapps/common/Don't Starve Mod Tools/mod_tools/TEXCreator.exe" \
        "/e/txtool1.4.2/txtool1.4.2/TEXCreator.exe"
    do
        if [ -f "$c" ]; then printf '%s' "$c"; return 0; fi
    done
    return 1
}

# 没有 ffprobe 的机器上取一张图/一段视频的像素尺寸：读 ffmpeg 自己打印的 Stream 行。
# 输出形如 2400x1350；认不出来就输出空并返回非 0。
probe_size() {
    "$FF" -i "$1" 2>&1 | grep -m1 ' Video: ' \
        | grep -oE '[0-9]{2,5}x[0-9]{2,5}' | head -1
}

# 把 png 转成游戏认的 .tex。这一步只能靠 Klei 官方 TEXCreator（没有命令行版），
# 用 32 位 PowerShell 反射调它；没装就跳过，并把该手动执行的命令原样打出来，别让人去猜。
png2tex() {
    _in=$1; _out=$2; _vid=$3
    _exe=$(find_texcreator) || _exe=""
    if [ -z "$_exe" ]; then
        _n=$(basename "$_out" .tex)
        echo "SKIP tex: 没找到 TEXCreator，$_out 没生成（接缝处会垫黑，画面本身不受影响）。"
        echo "  设好环境变量 TEXCREATOR_EXE 再跑一次最省事；要手动做就照抄这三条："
        echo "  $FF -y -i $_vid -frames:v 1 -update 1 frame_$_n.png"
        echo "  /c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass \\"
        echo "    -File $ART_DIR/../tools/png2tex.ps1 -InPng frame_$_n.png -OutTex $_out -ExE \"\$TEXCREATOR_EXE\""
        echo "  powershell -NoProfile -ExecutionPolicy Bypass -File $ART_DIR/../tools/patch_tex_flags.ps1 -Tex $_out"
        return 1
    fi
    /c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "$ART_DIR/../tools/png2tex.ps1" -InPng "$_in" -OutTex "$_out" -Exe "$_exe" >/dev/null
    powershell -NoProfile -ExecutionPolicy Bypass \
        -File "$ART_DIR/../tools/patch_tex_flags.ps1" -Tex "$_out" >/dev/null
}

# 图集描述：元素名固定 "<槽位>.tex"，uv 各留半个纹素内缩，否则接缝垫图会带上双线性插值的边。
# $1=xml 路径 $2=宽 $3=高 $4=槽位
write_xml() {
    awk -v w="$2" -v h="$3" -v n="$4" -v out="$1" 'BEGIN {
        u1 = 0.5 / w; u2 = 1 - u1; v1 = 0.5 / h; v2 = 1 - v1
        printf "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Atlas>\n" > out
        printf "    <Texture filename=\"%d.tex\"/>\n", n > out
        printf "    <Elements>\n        <Element name=\"%d.tex\" u1=\"%.9f\" u2=\"%.9f\" v1=\"%.9f\" v2=\"%.9f\"/>\n    </Elements>\n", n, u1, u2, v1, v2 > out
        printf "    <StraightAlpha>false</StraightAlpha>\n</Atlas>\n" > out
    }'
}
