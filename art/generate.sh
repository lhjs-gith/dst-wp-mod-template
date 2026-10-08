#!/bin/sh
# 重新生成模板自带的三张演示壁纸，直接写进 ../movies 和 ../images。
# 画面全部由 ffmpeg 程序化绘制（gradients + geq），不含任何第三方素材，可以放心分发。
#
#   槽位 1：月夜山海   1920x1020  12s    槽位 2：黄昏天际线 1280x720  8s    槽位 3：极光 2016x864  16s
#
# 需要带 libtheora 编码器的 ffmpeg（7.x 官方构建即可）：
#   设环境变量 FFMPEG 指向 ffmpeg.exe，或者让 PATH 里能找到 ffmpeg
# 循环做法：镜头位置用 sin(2*PI*t/T) 驱动，T 就是片子时长，所以第 T 秒的画面严格等于第 0 秒。
# 接缝在数学上就是连续的，不需要"正放+倒放"那种来回摆的剪法。
set -e
FF=${FFMPEG:-ffmpeg}
cd "$(dirname "$0")"
MOVERS=../movies
IMAGES=../images
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 把 png 转成游戏认的 .tex。这一步只能靠 Klei 官方 TEXCreator（没有命令行版），
# 用 32 位 PowerShell 反射调它；没装 Mod Tools 就跳过，脚本会把该手动执行的命令打出来。
# 注意打出来的命令不能引用 $WORK（trap 在脚本退出时就把它删了），所以第一步是从刚生成的
# 视频里把第 0 帧取回来，这样用户事后照抄也还能跑通。
png2tex() {
    if [ -z "$TEXCREATOR_EXE" ]; then
        n=$(basename "$2" .tex)
        echo "SKIP tex: 没有 TEXCreator，$2 没生成。设好 TEXCREATOR_EXE 再跑一次本脚本最省事；"
        echo "  要手动做就照抄这三条（第一条从视频取回第 0 帧，因为脚本的临时目录已经删掉了）："
        echo "  $FF -y -i $3 -frames:v 1 -update 1 frame_$n.png"
        echo "  /c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass \\"
        echo "    -File ../tools/png2tex.ps1 -InPng frame_$n.png -OutTex $2 -ExE \"\$TEXCREATOR_EXE\""
        echo "  powershell -NoProfile -ExecutionPolicy Bypass -File ../tools/patch_tex_flags.ps1 -Tex $2"
        return 1
    fi
    /c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File ../tools/png2tex.ps1 -InPng "$1" -OutTex "$2" -Exe "$TEXCREATOR_EXE" >/dev/null
    powershell -NoProfile -ExecutionPolicy Bypass -File ../tools/patch_tex_flags.ps1 -Tex "$2" >/dev/null
}

# 一个槽位的全部产物：$1=槽位 $2=静帧 filter $3=静帧宽 $4=静帧高 $5=目标宽 $6=目标高
# $7=时长秒 $8=平移 x 幅度 $9=平移 y 幅度 $10=相位 $11=cfg 内容
build_slot() {
    slot=$1; filter=$2; sw=$3; sh=$4; w=$5; h=$6; T=$7; ax=$8; ay=$9; ph=${10}; cfg=${11}
    echo "--- slot $slot ($w x $h, ${T}s) ---"

    # 1) 先渲一张比目标尺寸大一圈的静帧，多出来的一圈留给平移，平移时不会露边
    $FF -loglevel error -y -filter_complex_script "$filter" -map "[out]" -frames:v 1 -update 1 "$WORK/still_$slot.png"

    # 2) 循环视频：crop 窗口的位置由正弦驱动，周期就是片子时长
    # 注意 -q:v 3 会被 libtheora 悄悄丢帧（实测 2 秒 24fps 的低运动画面只落 35/50 帧，
    # 完全静止的输入只剩 8 帧；换成 -q:v 9 就是 48/50 全留，代价是体积 3.3 倍）。
    # 丢的是时间轴上的空洞、不是时长，所以总长还是 T 秒、接缝位置不变，慢速平移也看不出来，
    # 但要真 24fps 就把这里的 3 调到 9。
    ox=$(( (sw - w) / 2 )); oy=$(( (sh - h) / 2 ))
    $FF -loglevel error -y -framerate 24 -loop 1 -t "$T" -i "$WORK/still_$slot.png" \
        -vf "crop=$w:$h:x='$ox+${ax}*sin(2*PI*t/${T})':y='$oy+${ay}*sin(2*PI*t/${T}+${ph})',format=yuv420p" \
        -c:v libtheora -q:v 3 "$MOVERS/$slot.ogv"

    # 3) 首帧垫图必须取视频真正的第 0 帧（不是静帧原图，否则接缝处会跳一下）
    $FF -loglevel error -y -i "$MOVERS/$slot.ogv" -vf "select=eq(n\,0)" -frames:v 1 -update 1 "$WORK/frame_$slot.png"

    # 4) cfg 与图集描述：uv 各留半个纹素内缩，元素名固定 "<槽位>.tex"
    printf '%s\n' "$cfg" > "$MOVERS/$slot.cfg"
    awk -v w="$w" -v h="$h" -v n="$slot" 'BEGIN {
        u1 = 0.5 / w; u2 = 1 - u1; v1 = 0.5 / h; v2 = 1 - v1
        printf "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Atlas>\n"
        printf "    <Texture filename=\"%d.tex\"/>\n", n
        printf "    <Elements>\n        <Element name=\"%d.tex\" u1=\"%.9f\" u2=\"%.9f\" v1=\"%.9f\" v2=\"%.9f\"/>\n    </Elements>\n", n, u1, u2, v1, v2
        printf "    <StraightAlpha>false</StraightAlpha>\n</Atlas>\n"
    }' > "$IMAGES/$slot.xml"
    png2tex "$WORK/frame_$slot.png" "$IMAGES/$slot.tex" "$MOVERS/$slot.ogv" || true
}

build_slot 1 still_A_moonlit.filter.txt 2048 1090 1920 1020 12 58 26 1.9 \
"# 模板自带壁纸（由 art/generate.sh 程序化绘制，不含任何第三方素材）
# 正弦缓慢平移，周期 12s，所以首尾画面严格相接

duration=12
aspect=1920x1020"

build_slot 2 still_B_dusk.filter.txt 1440 810 1280 720 8 72 38 2.4 \
"# 模板自带壁纸（由 art/generate.sh 程序化绘制，不含任何第三方素材）
# 16:9，8 秒一圈

duration=8
aspect=16:9"

build_slot 3 still_C_aurora.filter.txt 2160 928 2016 864 16 32 13 1.1 \
"# 模板自带壁纸（由 art/generate.sh 程序化绘制，不含任何第三方素材）
# 21:9 超宽，16 秒一圈
# aspect 也接受直接写比值，比如 2.333333

duration=16
aspect=21:9"

# 换掉 modmain.lua 里的 DURATION_HINTS = { [1] = 12, [2] = 8, [3] = 16 } 让第一圈也提前盖住接缝
#（不填也行：槽位 cfg 里的 duration= 已经优先于配置项，种子只是给没写 cfg 的槽位兜底）
echo "done. 改 modinfo.lua 的壁纸档位数量、modmain.lua 的 MOVIE_SLOTS 之前，这三张已经能直接进游戏试。"
