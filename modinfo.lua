name = "我的主菜单动态壁纸"
description = "感谢订阅。想要加的功能、或者碰到了问题，欢迎在评论区留言。\n\n致谢：循环衔接处“播完前用首帧图盖住再重播”的处理思路，参考创意工坊 mod「温蒂动态壁纸」（作者 zzzzzzzs、临夏听舟，条目 3547896422）。借的是思路，不是代码。\n\n【改这里】把主菜单背景换成循环播放的视频。这一段要写清楚：自带几张壁纸、每张素材的出处和署名。素材不是你自己做的，就必须逐个署名到原条目；用了商业游戏的画面，也要照实说明（不要写“本 mod 不含来自该游戏的素材”，这类话一旦被对着包里的文件验出来就是差评事故）。\n\n纯客户端 mod，房主不需要装。\n\n换自己的素材：视频按 movies/1.ogv ~ movies/8.ogv 放进 mod 目录（共 8 个槽位，Theora .ogv，游戏不认 mp4）。每张素材可以写自己的参数：同目录放一个 movies/N.cfg 纯文本，一行 duration=20.5、一行 aspect=16:9（比例也接受 1920x1080 或 1.777），它优先于配置项里的“视频时长/视频比例”。想要循环看不出接缝，请选首尾画面接近、结尾不要淡出到黑的片子，再配一张同名首帧图 images/N.tex + images/N.xml（缺图时接缝处会垫黑）。没有文件的槽位会自动回落到可用的那一个。每张壁纸在一个进程里的第一圈，接缝处会多停一下首帧图（约 6 秒）：那段片子是第一次解码，引擎在最后一帧之后还要 1~2 秒只输出黑帧，只能用首帧图顶到确实出画面为止；从第二圈起只停约 2.7 秒，肉眼基本看不出来。把 duration= 填成片子实际长度可以让尾巴在播完之前就盖上，而不是等播完才知道周期。\n\n素材自带音轨的话，游戏会连声音一起放出来（和背景音乐叠着响，视频音量不能单独调，但可以用配置项“主菜单音量”把背景音乐压低）。但背景音乐不能换成你自己的文件：饥荒没有播放 mp3/ogg/wav 这类裸音频的接口，纯音轨的 .ogg 就算放进 movies/ 也一帧都解不出来（实测），自定义音乐只能是随 mod 打包发布的 FMOD 音色库。想用别的歌，只有把声音封进带画面的 .ogv 当壁纸素材这一条路。\n\n配置项：壁纸槽位（含“轮换”和“关闭”档）、画面铺满/保持比例、画面压暗、视频时长、视频比例、原版黑边/左侧菜单底色/公告栏的显示隐藏、主菜单音量、切换快捷键。\n\n在主菜单直接按键就能换壁纸，不用点进任何菜单：W/S 是上一张/下一张。这一档可以在配置项“切换快捷键”里改成方向键或关掉；想用别的键或者只留其中一两个，在 mod 目录放一个 keys.cfg（一行一项 wp_prev / wp_next / ms_prev / ms_next，值写 w、up、f9 这样，或者 none）。你占用的那一组键不会再顺带移动菜单选中框，另一组照常。\n\n“轮换”按槽位顺序每次重新构造主菜单界面时过一张，只算你实际放了文件的槽位，并且进度记在你的存档里：关掉游戏再开是接着上次往下走，不会连着两次同一张（实测在子界面之间来回不算重新构造，所以基本就是每次启动游戏换一张）。用快捷键手动切到的那一张也算进度。“画面压暗”是在壁纸最上层蒙一层半透明黑（10/20/30/45%，默认不压暗），素材太亮、菜单按钮和文字看不清时开一档；它同时盖住接缝处的首帧垫图，所以接缝不会忽明忽暗。\n\n--- English ---\nThank you for subscribing - feature requests and bug reports in the comments are welcome.\n\nCredits: the seam trick (cover the video with its own first frame just before the clip ends, then replay) follows the workshop mod Wendy Animated Wallpaper (zzzzzzzs, 临夏听舟, item 3547896422) - the approach, not the code.\n\n[EDIT THIS] Replace the main menu background with a looping video. Say here how many wallpapers ship with your mod and where every asset comes from. Anything you did not make has to be credited to its source item, and if you used footage from a commercial game you have to say so plainly.\n\nClient-only: only you need to install it, the host does not.\n\nBring your own assets: drop videos into movies/1.ogv ~ movies/8.ogv (8 slots, Theora .ogv only, mp4 is not supported). Each clip can carry its own settings via a plain-text movies/N.cfg next to it - one line duration=20.5, one line aspect=16:9 (1920x1080 or 1.777 also work); the cfg wins over the Video duration / Video aspect options. For a loop you cannot see, use footage whose last frame resembles its first and that does not fade to black at the end, then add a matching first-frame cover images/N.tex + images/N.xml (without it the seam falls back to black). Slots with no file fall back to the first available wallpaper. On each wallpaper's first loop inside a process the seam holds the first-frame still for about 6 s - the widget outputs pure black for 1-2 s after the media's last frame, so the still has to bridge it. From the second loop on it is about 2.7 s and the seam is invisible. A duration= line covering the real clip length covers the tail before the clip ends instead of only once the period has been measured.\n\nSound: if your footage carries an audio track, the widget plays it too (it layers over the menu music and has no separate volume - use the Menu volume option to duck the music instead). Your own music files are NOT supported: Don't Starve Together has no way to play a bare audio file, and an audio-only .ogg dropped into movies/ decodes nothing (verified in-game), so custom music can only ever ship as a pre-baked FMOD bank inside the mod. The one workaround is to mux your song into a video-bearing .ogv and use it as a wallpaper.\n\nOptions: wallpaper slot (including Rotate and Off switches), fit (fill screen / keep aspect), shade, video duration, video aspect, vanilla letterbox, sidebar, MOTD panel, menu music volume, switch shortcuts.\n\n\"Rotate\" walks through your wallpapers in order, one per main-menu build (moving between sub-screens inside the same session does not rebuild the menu, so in practice it is one step per game launch). The position is saved in your profile, so a restart picks up where it left off, and stepping with the keyboard counts as progress too. \"Shade\" dims the video with a translucent black layer on top of it (10/20/30/45%, off by default), and it also covers the first-frame still used at the seam, so the seam never flickers.\n\nKeyboard shortcuts on the main menu, no clicking required: W/S steps through the wallpapers. The Switch shortcut option also offers the arrow keys or Off, and a keys.cfg file in the mod folder lets you bind any key you like (one line each for wp_prev / wp_next / ms_prev / ms_next, values like w, up, f9 or none). The keys you claim stop nudging the menu selection frame as a side effect; the other set keeps working normally."
tagline = "主菜单循环视频背景"
author = "你的名字"
version = 1
forumthread = ""

api_version = 6
api_version_dst = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
hamlet_compatible = false
all_clients_require_mod = false
client_only_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "主菜单", "壁纸" }

configuration_options = {
    {
        name = "wallpaper",
        label = "壁纸",
        hover = "视频文件放在 mod 目录的 movies/1.ogv ~ movies/8.ogv。\n没有对应文件的选项会自动回落到第一个可用壁纸。\n选“轮换”则每次回到主菜单换一张，按槽位顺序一张一张过，进度记在存档里，所以关掉游戏再开也是接着上次往下走、不会连着两次同一张（只在你实际放了文件的槽位之间轮；用快捷键手动切过也算进度）。\n选“关闭”则不加载视频，主菜单恢复原样，此时其他选项仍然生效。\n素材若自带音轨，游戏会连声音一起放出来（跟背景音乐叠着响，没有单独的视频音量控制）；想只要画面就用纯画面轨的 .ogv，模板自带的那张就是这样所以不响。\n多槽位时建议在 movies/<槽位>.cfg 里写这个素材自己的时长和比例，例：\nduration=20.5\naspect=16:9",
        default = 1,
        options = {
            { description = "壁纸 1", data = 1 },
            { description = "壁纸 2", data = 2 },
            { description = "壁纸 3", data = 3 },
            { description = "壁纸 4", data = 4 },
            { description = "壁纸 5", data = 5 },
            { description = "壁纸 6", data = 6 },
            { description = "壁纸 7", data = 7 },
            { description = "壁纸 8", data = 8 },
            { description = "轮换 / Rotate", data = 9 },
            { description = "关闭 / Off", data = 0 },
        },
    },
    {
        name = "video_duration",
        label = "视频时长",
        hover = "循环衔接用。选“自动”时，第一圈要等播完才知道周期，可能露一次尾巴；\n填上自己素材的实际时长，第一圈就能提前盖住接缝。\n模板自带壁纸 1 已内置实测时长 12s（写在 modmain.lua 的 DURATION_HINTS 里），一般不用改。\n填小了最多多闪一次垫图（约 2 秒后自动放弃纠正），填大了不会有任何影响。\n这里是对当前选中壁纸的全局设置；多个槽位素材各自的时长不同，请改用 movies/<槽位>.cfg 里的 duration=秒数（它优先于本档位）。",
        default = 0,
        options = {
            { description = "自动 / Auto", data = 0 },
            { description = "5 s", data = 5 },
            { description = "10 s", data = 10 },
            { description = "15 s", data = 15 },
            { description = "20 s", data = 20 },
            { description = "30 s", data = 30 },
            { description = "45 s", data = 45 },
            { description = "60 s", data = 60 },
            { description = "90 s", data = 90 },
        },
    },
    {
        name = "video_aspect",
        label = "视频比例",
        hover = "只在“保持比例”模式下起作用。\n默认比例是 modmain.lua 里的 VIDEO_ASPECT 常数，模板自带素材是 1920x1020（≈16:8.5）。\n引擎没有读取片子原生尺寸的接口，所以换素材后若画面被压扁/拉扁，请在这里手动指定比例。\n多个槽位素材比例不同，请改用 movies/<槽位>.cfg 里的 aspect=16:9 或 aspect=1920x1080（它优先于本档位）。",
        default = 0,
        options = {
            { description = "默认 / Default", data = 0 },
            { description = "16:9", data = 1 },
            { description = "16:10", data = 2 },
            { description = "16:8.5", data = 3 },
            { description = "4:3", data = 4 },
            { description = "21:9", data = 5 },
            { description = "1:1", data = 6 },
        },
    },
    {
        name = "fill",
        label = "画面适配",
        hover = "铺满：视频拉伸到整个屏幕，非 16:9 屏幕会有变形。\n保持比例：视频不变形，多出来的部分留黑。",
        default = 1,
        options = {
            { description = "铺满屏幕", data = 1 },
            { description = "保持比例", data = 2 },
        },
    },
    {
        name = "shade",
        label = "画面压暗",
        hover = "在壁纸最上层蒙一层半透明黑，让主菜单的按钮和文字看得清。\n档位就是这层黑的不透明度：20% 即压掉两成亮度。\n压暗同时盖住循环接缝的首帧垫图，所以接缝处不会忽明忽暗。\n素材本身很暗、或者只想看原画，就选“不压暗”。",
        default = 0,
        options = {
            { description = "不压暗 / None", data = 0 },
            { description = "10%", data = 1 },
            { description = "20%", data = 2 },
            { description = "30%", data = 3 },
            { description = "45%", data = 4 },
        },
    },
    {
        name = "letterbox",
        label = "原版黑边",
        hover = "主菜单前景的上下/左右黑色遮罩。",
        default = 2,
        options = {
            { description = "显示", data = 1 },
            { description = "隐藏", data = 2 },
        },
    },
    {
        name = "sidebar",
        label = "左侧菜单栏底色",
        default = 1,
        options = {
            { description = "显示", data = 1 },
            { description = "隐藏", data = 2 },
        },
    },
    {
        name = "motd",
        label = "公告栏",
        hover = "主菜单右侧的活动/新闻面板。",
        default = 2,
        options = {
            { description = "显示", data = 1 },
            { description = "隐藏", data = 2 },
        },
    },
    -- 自定义主菜单音乐。模板默认不带音频包（modmain.lua 里 MUSIC_TRACK_COUNT = 0），
    -- 所以这一整项是注释掉的：没有它主菜单照常放原版 BGM。
    -- 要做带音乐的 mod：
    --   1) 把 FMOD 音色库放到 sound/，并让 SOUND_BANK / SOUND_FEV / SOUND_EVENT_ROOT
    --      三个常数与 .fbp 工程内部名、.fsb 音色库内部名逐字对应（见 README 的音频一节）
    --   2) 把 modmain.lua 的 MUSIC_TRACK_COUNT 改成曲目数
    --   3) 取消下面的注释，把曲目档位换成你自己的歌名（data 必须从 1 连到 N），
    --      并把"随机播放"档位的 data 改成 N+1
    -- {
    --     name = "music",
    --     label = "主菜单音乐",
    --     hover = "选“原版”则保留游戏自带的主菜单音乐。\n“随机播放”会在上面几首之间洗牌，每首播完接下一首，不会连着放同一首。\n这里不能换成自己的音乐文件：游戏没有播放 mp3/ogg/wav 的接口，自定义音乐必须打成 FMOD 音色库随 mod 发布。\n想用别的歌，只能把声音封进带画面的 .ogv 里当壁纸素材（见壁纸说明）。",
    --     default = 1,
    --     options = {
    --         { description = "1. 你的歌名", data = 1 },
    --         { description = "2. 你的歌名", data = 2 },
    --         { description = "随机播放 / Shuffle", data = 3 },
    --         { description = "原版 / Vanilla", data = 0 },
    --     },
    -- },
    {
        name = "music_volume",
        label = "主菜单音量",
        hover = "只压主菜单这一首的音量。游戏选项里的“音乐音量”调的是总音量，这一档是在它基础上再压低，两者叠乘。\n选“默认”就是不动它。\n没有自带音频包时这一档压的是原版主菜单音乐，同样生效。\n壁纸素材自带音轨、跟背景音乐叠着嫌吵时，用它把背景音乐压低一档。",
        default = 0,
        options = {
            { description = "默认 / Default", data = 0 },
            { description = "25%", data = 1 },
            { description = "50%", data = 2 },
            { description = "75%", data = 3 },
        },
    },
    {
        name = "key_scheme",
        label = "切换快捷键",
        hover = "在主菜单里不用点进任何菜单就能换壁纸、换歌：W/S 是上一张/下一张壁纸，A/D 是上一首/下一首音乐。\n没有自带音频包时 A/D 没有作用，W/S 照常换壁纸。\n只在主菜单这一屏响应，进了存档这些键仍旧是游戏自己的。\n饥荒主菜单的选中框同时听方向键和 WASD（原版按键表里 W 就是“上”），所以本 mod 会把你占用的那一组键顺带的导航关掉：默认方案下 WASD 换壁纸换歌、方向键照常导航；选“方向键”这一档则反过来。\n只想留其中一两个键、或者想换别的键：在 mod 目录放一个 keys.cfg，一行一项：\nwp_prev=W\nwp_next=S\nms_prev=A\nms_next=D\n值可以是字母、数字、up/down/left/right、f1~f12；写 none 表示这一项不用了。没写的行沿用这里选的档位。",
        default = 1,
        options = {
            { description = "WASD", data = 1 },
            { description = "方向键 / Arrows", data = 2 },
            { description = "不使用按键", data = 3 },
        },
    },
}
