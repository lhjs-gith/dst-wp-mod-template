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
   第 1、2 步可以用 `sh tools/new_mod.sh <新目录> "<显示名>" "<作者>"` 一次做完：它复制整个模板、
   删 `.git`、换一份全新 UUID、改掉那四个字段、把槽位清空，流水线和工具原样带走。
3. **放素材。** 把任意 Theora 视频拷成 `movies/1.ogv`（游戏不认 mp4），旁边放一个 `movies/1.cfg` 写它的时长和比例。
   首帧垫图可选，但缺了它接缝处会垫黑，见下。**只有一张静帧图**（插画、截图、照片）时不用手动做这四件事，
   `sh art/from_image.sh 图.jpg` 一条命令出全套，见「素材流水线」。
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
| `art/` | 三张演示壁纸的**生成脚本**与滤镜图，以及图标源图 `modicon.png`；`from_image.sh` 吃你自己的静帧图，`common.sh` 是两者共用的构件 |
| `tools/` | 无 GUI 生成 `.tex` 的两个 PowerShell 脚本 + Flags 补丁；**自己打 `.fsb` 的两个 Node 脚本**（`fsb5.mjs` 读写器 + `mkbank.mjs` 构建器，见路线 5）；`new_mod.sh` 一键开新 mod；`sync_to_game.sh` 同步进游戏目录并逐文件自证 |
| `sound/` | 空。自定义音乐要的一对 `mymusic.fsb` + `mymusic.fbp.fev` 里，前者现在可以用 `tools/mkbank.mjs` 自己生成（路线 5），后者由 FMOD Designer 建工程产出 —— Designer 不用另外下载，科雷的 Don't Starve Mod Tools 里自带（见路线 2） |
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

上面这四步已经写成脚本了，两种入口：

- **手里是一段现成的视频** → 按上面四步手动做，或者照抄 `art/generate.sh` 里 `build_slot` 的后半段。
- **手里只有一张静帧图**（插画、截图、照片）→ `sh art/from_image.sh 图.jpg`，一条命令出 `ogv + cfg + tex + xml` 四件。
  它会：探源图尺寸 → 不放大、且不超出 1920x1080 地定下输出尺寸 → 把图放大到"输出尺寸 + 两圈平移余量"→
  用 `sin(2*t*PI/T)` 驱动的 crop 窗口做无缝循环 → 取视频真正的第 0 帧做首帧垫图 → 写好这个槽位自己的 `duration`/`aspect`。

```sh
export FFMPEG='X:/.../ffmpeg.exe'                    # 带 libtheora 的 7.x 构建
export TEXCREATOR_EXE='X:/.../TEXCreator.exe'        # 不设就跳过 .tex，只打印该手动执行的命令
sh art/from_image.sh --batch 我的图/ --from 1         # 按文件名顺序做连续槽位
sh art/from_image.sh 一张.jpg --slot 5 --t 20 --q 9   # 指定槽位、20 秒一圈、真 24fps
sh art/from_image.sh 一张.jpg --slot 5 --motion none  # 完全不动，只要一张会循环的静帧
sh art/from_image.sh --info 一张.jpg                  # 只探测尺寸，不做转换
```

常用开关：`--t` 一圈秒数（默认 14，越长越慢越省体积）、`--ax/--ay` 平移幅度像素（默认 48/26）、
`--w/--h` 强制输出尺寸、`--q` Theora 质量、`--force` 覆盖已有槽位（不加就跳过，不会悄悄毁掉你的素材）。
不指定 `--slot` 时写进第一个空槽；1~8 全满会明确报错而不是覆盖。

**跑完必须重启游戏**才看得到新槽位；要拷进游戏目录就 `sh tools/sync_to_game.sh`
（只拷运行时那一套文件，`art/`、`tools/`、`README.md` 留在开发目录，免得将来上架时一起传上去；
比完还会报出"游戏目录里有、开发目录里没有"的残留槽位，那些同样会被游戏读进去）。

`art/generate.sh`（生成仓库自带那三张）和 `art/from_image.sh` 共用 `art/common.sh` 里的
`png2tex` / `write_xml` / `probe_size` / `find_texcreator`，改一处两边都生效。

关于"重跑能不能复现仓库素材"：`cfg` 和 `xml` 是逐字节复现的（实测），但 **`.ogv` 和由它解出来的
`tex` 不保证**——2026-10-09 在改动前的原始脚本上做过 A/B：三张里只有 2 号槽的首帧能逐字节复现，
1 号和 3 号每次重跑解出来的第 0 帧都不一样（`-q:v` 的 VBR 码控不是确定性的）。所以拿 `cmp` 验环境时
**只比 `cfg`/`xml`**，`tex` 不同不代表你这边坏了。

`images/N.xml` 手写就行，元素名固定 `<槽位>.tex`，uv 各留半个纹素内缩
（`u1 = 0.5/宽`，`u2 = 1 - u1`，v 同理）——`art/generate.sh` 里有一段 awk 直接算好写文件的写法，抄它。

**`-q:v 3` 会被 libtheora 悄悄丢帧**，实测（ffmpeg 7.1，2 秒 24fps 输入 = 48~50 帧）：
低运动的慢速平移只落 **35** 帧，完全静止的输入只剩 **8** 帧，换成 `-q:v 9` 就是 **48** 帧全留（体积 3.3 倍）。
丢的是时间轴上的洞、总时长不变，所以接缝位置和 `duration=` 都不受影响，平移类素材肉眼也看不出掉帧——
但你要真 24fps 就把 `-q:v` 调到 9。模板自带的三张是 `-q:v 3` 生成的，等于约 17fps。
**画面越平丢得越狠**（2026-10-09 补测：800x600 的纯渐变 14s/24fps 只落 **28** 帧 ≈ 2fps，同一张换
`-q:v 9` 落 **300** 帧）——2fps 的平移是看得出来的，所以 `art/from_image.sh` 在帧数掉到一半以下时会
主动打印这一条告警（`--motion none` 的静帧素材不告警，那种情况下少帧是好事）。
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
- **别删 `modmain.lua` 开头那两行 `GLOBAL.setmetatable(env, {__index = ...})`**：mod 的沙盒环境里
  `pcall` 是靠它从真全局取到的，删掉之后 `Asset` / `TheSim` / `AddClassPostConstruct` 全都照常工作，
  只有跑到第一次 `pcall` 时才炸出 `attempt to call global 'pcall' (a nil value)`（实测踩过，2026-10-08）。
  如果那次调用在 `OnUpdate` 里，异常会一路抛到 `scripts/frontend.lua:889 Update`，游戏直接
  `Force aborting` 退出——症状和上面那条一模一样，但根因是这个前导。
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

- **不能**直接丢裸音频进去。饥荒没有任何播放 mp3/ogg/wav 的接口；实测把纯音轨的 `.ogg` 放进 `movies/`
  彻底不认——`Video` 部件要求存在 Theora 画面轨，只有 Vorbis 的话一帧都解不出来，完全没声。
  但"不能用自己的歌"这一条 2026-10-08 已经被推翻了：**mp3 可以自己打包成 `.fsb`**，不需要任何 FMOD 工具，
  见下面路线 5，本仓库 `tools/` 里直接带着能用的构建器。
- 想换背景音乐只有一条路：**随 mod 打包 FMOD 音色库**（采样库 `.fsb` + 事件库 `.fev` 一对），
  然后用 `GLOBAL.FE_MUSIC = <事件路径>` 顶掉原版主菜单音乐。这一对怎么来，见下一节的路线对比表。
- 想用别的歌又不想打音色库，唯一取巧的办法是把音频封进一个带画面的 `.ogv` 当壁纸素材（素材自带音轨的话
  游戏会连声音一起放出来，和背景音乐叠着响；那一轨本身没有音量控制，但背景音乐可以用「主菜单音量」档压下去）。
- 事件路径**和你存的文件名无关**，取决于工程内部名：
  `事件路径 = <工程内部名>/<事件组名>/<事件名>`。两条命名惯例必须满足，否则游戏静音且不报错：
  `.fev` 文件名必须等于工程内部名，`.fsb` 文件名必须等于音色库内部名。
  本模板的三个常数就是按 `mymusic.fbp` / `mymusic` 这套写的；拿到别人的音色库先按 RIFF chunk
  把 `PROP`（工程名）、`LGCY`（音色库名）、`STRR`（事件组/事件名）读出来核对。
- 启用步骤：把音色库放进 `sound/` → `MUSIC_TRACK_COUNT` 改成曲目数 → 取消 `modinfo.lua` 里 `music` 那一整项的注释
  并按 `data = 1~N` 填曲目名、`N+1` 是"随机播放"、`0` 是原版。
- **`sound/` 为什么是空的**：`.fsb` 现在能自己生成（路线 5），但本模板不能把别人的 `.fev` 壳随仓库分发
  （那是别人的工程），所以一对都不带。自己产出 `.fev` 的那一步现在也不卡了 —— **FMOD Designer 随科雷的
  Don't Starve Mod Tools 免费分发，本机就有 4.44.07，命令行版构建已在 2026-10-08 跑通**（见路线 2 那节）。
- 音量挂在**事件标签**上：`SoundEmitter:SetVolume("FEMusic", 0.5)`。它和游戏选项里的"音乐音量"是两条链
  （后者调 FMOD 的 `set_music` 总线），两者**叠乘**而不是互相覆盖。游戏每次重新 `PlaySound` 都可能把它顶回默认值，
  而 mod 的钩子在 post-construct、抢不到起播那一刻，所以要在"从没在响 → 在响"这个沿上补一次。
- 上面这一整条分支 2026-10-07 在游戏里实测过（副本 `z-tt-m`，`MUSIC_TRACK_COUNT = 4`）：注册出
  `assets=11`（9 条壁纸 + `FILE(.fsb)` + `SOUNDPACKAGE(.fev)`），看门狗回报事件真的在响，
  四首逐个切过去都是 `playing=true`，50% 音量档在起播沿上补到了。改这些之前照着这段断言复现即可。

### 这一对 `.fev`/`.fsb` 到底怎么做出来（2026-10-07 调研；2026-10-08 补上路线 5，同日深夜路线 2 用全新工程补测完成，**现在游戏里响过的是路线 1、路线 2 和路线 5**）

先说结论：**事件库（`.fev`，FEV4）到今天仍然只有 FMOD Designer 这一条路**，而 Designer 早在 FMOD Studio
出现时就停更、也从官网下架了 —— 但**科雷的 Don't Starve Mod Tools 里打包了一份 4.44.07，同目录还有命令行版，
2026-10-08 已在本机无 GUI 跑通构建**，并且用**全新工程**建出的库已经在游戏里响过（见下面「路线 2 已在本机跑通」）。
采样库（`.fsb`，FSB5）这一半 2026-10-08 起**连工具都不需要了**——
本仓库 `tools/` 里带了一个约 120 行的 Node 写入器，直接用你自己的 mp3 打出游戏能响的包（路线 5）。
所以五条路按门槛排：

| 路线 | 要不要旧版工具 | 状态 |
| --- | --- | --- |
| 1. 音频封进带画面的 `.ogv` 当壁纸素材 | 完全不用 FMOD | **本仓库实测过**，见上一条与「能做和不能做」 |
| 2. FMOD Designer 建工程 → Build 出 `.fev` + `.fsb` | **不用下载**：科雷的 Don't Starve Mod Tools 自带 FMOD Designer 4.44.07（含命令行版） | **2026-10-08 游戏里实测通过**：先用现成工程无 GUI 构建出与 p3r 现用库逐字节相同的 `.fsb`，再用**全新工程**（自产音频 + 自命名）建库、进游戏 4 个事件全部出声，见下面「路线 2 已在本机跑通」 |
| 3. 先借到一个 `.fev` 壳，之后只用 `fsbankcl.exe` 重打 `.fsb` | 需要 FMOD Engine 里的 `fsbankcl.exe`（fmod.com 是登录墙 SPA，本机下不到） | 机制在本地取证里成立，但**已被路线 5 和路线 2 双重取代**：Designer 自带的 `fmod_designercl.exe -c <格式>` 就能只重打采样库 |
| 4. 同样借壳，但采样库用 **FMOD Studio** 构建后从 `.bank` 里切出来 | 只需要 Studio（本机就有） | **本机实测过：游戏里播不出来**，Vorbis 和 PCM 两种压缩都试过，见本节末尾 |
| 5. 借壳 + **自己写 `.fsb`**（`tools/mkbank.mjs`，只要 ffmpeg 和 node） | 完全不用 FMOD | **2026-10-08 本机游戏里实测通过**：四次启动、零冲突 A/B、含 p3r 原库当对照，见下面「路线 5」一节 |

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
<_PC_format>MP3 + <_PC_quality>50       → 入包编码由这两行决定（不是 banktype，见下面的更正）
<filename>want_to_be_close.wav           → sounddef 只按文件名去 fsb 里找采样
```

所以"改一个现成壳工程"是看得见摸得着的：`.fdp` 是文本，改名、改 `<filename>` 指向自己的音频都行，
**只要装得上 Designer 就能 Build**。

#### 路线 2 已在本机跑通（2026-10-08 更正，之前这里写的"本机装不上 Designer"是错的）

**工具根本不用去 fmod.com 下载 —— 科雷的免费 Mod Tools 里就打包了一份完整的 FMOD Designer。**
安装位置（Steam 里装 *Don't Starve Mod Tools*，appid 245850，就是那个 `ModUploader.exe` 所在的工具包）：

```
<Steam>\steamapps\common\Don't Starve Mod Tools\mod_tools\FMOD_Designer\
    fmod_designer.exe      图形界面，打开 .fdp 工程
    fmod_designercl.exe    命令行构建（本节用的就是它）
    fmod_eventplayer.exe   进游戏前先听一遍 .fev
    README.TXT             版本头：FMOD Designer 4.44.07
    ass.bat                把 .fdp/.fev 注册成上面两个程序的关联文件
    documentation\fmod_designer.pdf
同层还有 FMOD_Studio\FMOD Studio 1.10.10\（带一个 ONI 素材的 Template 工程）
```

这条来源是科雷论坛上的两处独立说法，都不是博客传言：

- **Cheerio（科雷自己的音频开发）2013 年的官方《Sound Mod Tutorial》**（论坛 topic 27721）写的前置条件就是
  "PC 版 + *Don't Starve Mod Tools*"，正文第一步原文是
  "To launch the designer, Double click on the 'Don't Starve Mod Tools' in steam"。
- **Ultroman 2019 年回帖**（论坛 topic 105114）：**"The version Klei used is 4.44.64"**，并挂了一个网盘镜像。
  本机到 Google Drive 整站不通，但不需要走那条路了。
- 想抄现成工程的话：论坛下载区有 Mobbstar 的 **Extended Sound Mod Tutorial**（就是基于 Cheerio 那份做的进阶示例，
  自带 `.fdp` + README）；注意下载区 2023-01-01 起只读，老文件还能下。

**无 GUI 构建实测**（拿上面那个 `mymusic.fbp.fdp.autosave` 当工程，全程没打开过任何窗口）：

```
$ fmod_designercl.exe                       # 不带参数就是完整用法
Usage: fmod_designer <-pc|xbox360|psp|ps3|wii|wiiu|3ds|ngp|android|ios> [-a|b|h|l|m|n|p|s|t|T|c|L|C|r|k|K] <project.fdp>
  -m  只列输入/输出文件，不构建        -a <目录>  素材源目录
  -b <目录>  输出到别的目录            -c <格式>  覆盖所有 bank 的压缩（-pcm/-mp3/-vorbis/…）
  -r  先清理再重建                     -n  只跑不产出 .fev/.fsb

$ fmod_designercl.exe -m -pc mymusic.fbp.fdp -a "<wav 目录>"      # 空跑，验解析
Input files:  <fdp> + chaning_seasons.wav color_your_night.wav wall_moon_full_life.wav want_to_be_close.wav
Output files: mymusic.fbp.fev  mymusic.fsb

$ fmod_designercl.exe -pc mymusic.fbp.fdp -a "<wav 目录>" -b "<输出目录>"
Building project 'mymusic.fbp'...  FEV file written ok
Encoded ... 4 个 wav ... Writing FSB... Finished building FSB
SUCCESS: .../mymusic.fbp.fev   SUCCESS: mymusic.fsb        Took 00:00:13
```

产出的 `mymusic.fsb` 与 p3r 现在用的那份、以及 9 月图形界面 build 出来的那份 **md5 全等**
（`795486d6…`，FSB5 `0x18` mode=11 即 MP3）。`.fev` 差 396 字节，原因是我喂的是 **autosave** 而不是当时保存的那版工程
（sounddef 编号整体错位），不是工具行为不稳定——**要可复现就用保存下来的 `.fdp`，别用 `.autosave`**。

两个坑记在这儿：

- 工程目录不要放在映射盘或提权/非提权混用的路径下，否则加进去的音频名会变成 `/`、播放报
  `Error starting event: File not found`、Build failed。科雷论坛 topic 118377 就是这个问题，
  2022 年的回帖给的解法是**把工程放 Documents 再拷回去**。
- 那句 `Qt: Untested Windows version 6.2 detected!` 是 Qt4 对新 Windows 的无害警告，构建照样 SUCCESS。

**修正后的结论**：路线 2 卡的地方不是"搞不到工具"，而是"没人想到工具已经在硬盘上"。
`.fev`（FEV4）这一半目前**只有 Designer 能写**这一点不变（Studio 的 `.bank` 是 FMT 版本 146，游戏不认）；
变化的是 Designer 本身随 Mod Tools 免费提供，且有命令行版，所以"改文本工程 → 脚本构建 → 进游戏"这条流水线
在本机是完整可跑的。

#### 用全新工程建库、进游戏实测通过（2026-10-08 深夜，路线 2 到此闭环）

上面那次只是"复现别人的库"。要证明第一次做音乐 mod 的人也走得通，得换一个**全新工程**：
自己的音频、自己的工程名/库名/事件组名，和 p3r 现用那对没有任何重名。

- **音频**：ffmpeg 现做 4 段 6 秒正弦和弦（`aevalsrc` + `tremolo` + 淡入淡出），44100 Hz / 双声道 / 16 bit PCM wav，
  取名 `zntone_a.wav` ~ `zntone_d.wav`。
- **工程**：拿上面那个参考工程当骨架，只替换名字（`mymusic.fbp`→`znewproj.fbp`、`mymusic`→`znewbank`、
  事件组 `untitled`→`slot`、4 个 wav 名），**GUID 一个都不动** —— sounddef 之间是**按名字**引用的，不是按 GUID。
- **构建**：同一条命令行，产出 `znewproj.fbp.fev`（2,164 B）+ `znewbank.fsb`（482,368 B）。
  先用 `-m` 空跑，它列出的输入就是自己那 4 个 wav、输出就是这两个文件名，不用真构建就能确认解析对不对。
- **编码方式这件事有个先前写错的结论，这里更正**：采样库头 `0x18` mode=**11（MP3）**，和 p3r 那份一致，
  而工程里 `_PC_banktype` 明明写着 `DecompressedSample`。真正决定编码的是 `<soundbank>` 末尾那两行
  **`<_PC_format>MP3</_PC_format>` + `<_PC_quality>50</_PC_quality>`**，不是 `banktype`。
  库里 4 个采样名就是不含扩展名的 `zntone_a`…，正是 FEV 引用的那串。
- **进游戏**：一次性副本 `mods/z-tt-new`，只登记自己那 2 个资产、只用私有标签 `ZNP1`~`ZNP4`，
  完全不碰 `FE_MUSIC`，所以和仍然启用的 p3r 互不干扰。主菜单构造后 t=10 s 把 4 个事件一起起来：

```
[00:00:04]: [ZNEW] modmain loaded assets=2
[00:00:38]: [ZNEW] fire i=1 ok=true err=nil
[00:00:38]: [ZNEW] fire i=2 ok=true err=nil
[00:00:38]: [ZNEW] fire i=3 ok=true err=nil
[00:00:38]: [ZNEW] fire i=4 ok=true err=nil
[00:00:43]: [ZNEW] t=015.0 p1=true p2=true p3=true p4=true femusic=true
[00:00:48]: [ZNEW] t=020.0 p1=false p2=false p3=false p4=false femusic=true
[00:01:08]: [ZNEW] killed t=040.0
```

  四个事件全部被 FMOD 报成正在播；同一行里 `femusic=true` 是**对照组**（p3r 自己那份此刻也在响），
  所以这一行同时证明了"新库响"和"不是新库顶掉了旧库"。之后 p1~p4 转 false 只是因为片子只有 6 秒、到点自己结束。
  随后让探针每 7 秒 `KillSound` 上一个再起下一个，四个事件轮着放到了第 39 圈（约 4.5 分钟），
  **耳朵确认过确实出声** ——
  这一步别省，`PlayingSound` 毕竟是状态位，只有听见过才敢说不是假阳性。
  上面这段是**最后一次启动**的原文（游戏每次启动都重写 `client_log.txt`，中间几次没留下）；
  这一次全程 0 条 `LUA ERROR`，但**前一次启动确实崩过**，原因就是我漏了上面那条 `pcall` 前导，
  日志被覆盖了，教训仍然按实写进上面的坑列表。

于是路线 2 是目前**唯一一对 `.fev` + `.fsb` 都能自己产出**的方案（路线 5 只解决采样库那一半，事件库仍然要借），
而"事件路径 = `<工程名>/<事件组>/<事件名>`"这条规则也被"改名字 → 路径跟着变、并且真响"正面验了一次。

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
它旁边那份 `.fdp` 工程里写着 `_PC_banktype = DecompressedSample`，说明**这一项并不决定最终编码**。
2026-10-08 当晚这条已经查实：起作用的是 `<soundbank>` 末尾的 `_PC_format` + `_PC_quality`，
而且就是这份 autosave 工程命令行构建出来的 `.fsb` 与发布版逐字节相同，
"发布的那一对不是它构建的"这个备选解释也已排除——一切以字节的实测结果为准。
顺带把 `f18` 标定清楚了：**2 = PCM16、11 = MP3、15 = Vorbis**，三份地面真值各自对过。

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

**结论：路线 4（FMOD Studio 切片）判死 —— 游戏里播不出来，与压缩方式无关（Vorbis、PCM 都试过）。**
当时能响的产出只有 FMOD Designer 4.3x 那一代（路线 2/3 的机制）——**不过 2026-10-08 晚些时候
路线 5 出来了：采样库这一半根本不需要任何 FMOD 工具，自己写就行，见下一节。**
留一句给后来人：附五那次 A/B 之后我又回头核过 Studio 切片的对齐，**19 个采样全部 32 字节对齐、
`dataStart` 也对齐**，所以路线 4 的失败不是踩了路线 5 发现的那条对齐坑；两个结果之间还剩
`0x24` 那 16 字节这一个没排掉的差别（能响的包全非零、Studio 切片全是 0），**没验证过，别当结论用**。
`fsbankcl.exe` 这条路本机确实拿不到——fmod.com 的下载页是要登录的 SPA，抓到的是 453 字节空壳，archive.org 不通。
**但这件事现在不重要了**：同一台机器上科雷的 Mod Tools 自带 FMOD Designer 4.44.07，它的命令行版
`fmod_designercl.exe -c <格式> -b <目录>` 干的正是"只重打采样库"这一件事（见上面路线 2 那节），
而路线 5 更连工具都不碰。当年在这里搜不到 Designer，是因为按 `fsbankcl`／带空格的 `FMOD Designer` 搜，
而实际目录和 exe 是下划线命名（`mod_tools\FMOD_Designer\fmod_designercl.exe`）——**假阴性，别再照抄这句**。
**`.fev` 那一半仍然请当作只有 FMOD Designer 能做**——本仓库自己的现成证据是：`.bank` 的 `FMT` 版本 146、
游戏链接的 `fmod_event64.dll` 只认 4。

### 路线 5：不用任何旧工具，自己写 `.fsb`（2026-10-08 游戏里实测通过）

`tools/mkbank.mjs`（约 120 行）+ `tools/fsb5.mjs`（FSB5 读写器，回环验过：读进来再写出去和原文件逐字节相同）
从你自己的 mp3 直接产出游戏能响的采样库。**只需要 ffmpeg 和 node**，不需要 FMOD Designer、
`fsbankcl.exe`、也不需要 FMOD Studio。`.fev` 那一半要么借一个 Designer 时代的壳，要么直接用科雷 Mod Tools
自带的 Designer 命令行版自建（路线 2）；借来之后**采样名都不用改**，
以后换歌只重跑这条命令。

```bash
# 0) 先确认借到的壳引用了哪些采样名（这三个常数就是 modmain.lua 顶部那三个的来源）
grep -a -oE '[ -~]{5,}' sound/mymusic.fbp.fev | grep -E 'wav|mp3|untitled'

# 1) 素材统一转成 MPEG-1 Layer III、CBR、160 kbps、44.1 kHz、双声道
#    文件名必须等于 `.fev` 里 sounddef 引用的名字（不含扩展名）
ffmpeg -i in.wav -ac 2 -ar 44100 -c:a libmp3lame -b:a 160k -write_id3v2 0 want_to_be_close.mp3

# 2) 打包。<donor.fsb> 换任何一份"游戏里已经能响"的包都行，工具只抄它的 60 字节头部，
#    而且它声明的采样名列表就是第 1 步要交的那几个文件名（所以 donor 一般就是这个壳原来配套的那份 fsb）
node tools/mkbank.mjs ./mp3 mymusic.fsb <donor.fsb> nat 469 32
```

`mymusic.fsb` + `mymusic.fbp.fev` 摆进 `sound/`，把 `MUSIC_TRACK_COUNT` 改成曲目数、
取消 `modinfo.lua` 里 `music` 那一整项的注释，就是本模板那套了。

> 没装 node 也能跑：任何 Electron 程序（VSCode、各类桌面应用）都能当 node 用——
> `ELECTRON_RUN_AS_NODE=1 "<某个 Electron 主程序>.exe" tools/mkbank.mjs …`。
> 本机就是这么跑的（node v24.18.0，脚本只用 `node:fs` 和 `import.meta.url`）。

两个前提要说白：
- **`<donor.fsb>` 必须是 MP3（mode 11）的包**，工具遇到别的编码会直接拒。想换 Vorbis 入包得另外补
  `VORBISDATA` chunk（type 11），这条**没验证过**，别照着改。
- 如果不想和别人的包撞资产名（`Asset("FILE","sound/mymusic.fsb")` 撞了会分不清哪份在响），
  把 `.fev` 里那三处内部名 `mymusic` **等长改写**成自己的名字。先用
  `grep -a -bo 'mymusic' your.fev` 定位（本仓库这份是 `324`（PROP 工程名）/ `356`（LGCY）/ `400`（音色库名），
  **换一份工程就不是这三个偏移**，务必先 grep），事件路径随之变成 `<新名>.fbp/untitled/1`：

  ```js
  // 三处锚点都验过再落盘；长度不变，所以后面的偏移一个都不用动
  const fs = require('fs');
  const NEW = 'mymusic';                 // 换成自己的名字，必须恰好 7 个字符
  const b = fs.readFileSync('mymusic.fbp.fev');
  for (const o of [324, 356, 400]) {
    if (b.subarray(o, o + 7).toString('latin1') !== 'mymusic') throw new Error('anchor ' + o);
    b.write(NEW, o, 7, 'latin1');
  }
  fs.writeFileSync(`${NEW}.fbp.fev`, b);
  ```

  新名字必须**恰好 7 个字符**；文件名也要跟着改成 `<新名>.fbp.fev` + `<新名>.fsb`
  （`.fev` 文件名 = 工程内部名、`.fsb` 文件名 = 音色库内部名那两条惯例照样成立）。

#### 全部已验证的构造规则

| 位置 | 规则 | 怎么知道的 |
| --- | --- | --- |
| 头 60 字节 | **整份抄一份能响的包**，只改 `sampleHeadersSize / nameTableSize / dataSize` | 头部 `0x24` 起那 16 字节是构建期 id，跨包互不相同、看不出算法（见下面的"仍未排掉"） |
| `0x18` mode | 编码枚举：2=PCM16、11=MP3、15=Vorbis | 对 155 个包标定过 |
| `0x1C` u32 | 按编码固定的常数：**MP3=196608、Vorbis=1、PCM16=0** | 同上 155 个包，无一例外 |
| 采样头 | uint64 位域：bit0 有无 chunk、bit1-4 采样率枚举（8=44100）、bit5 声道−1、**bit6-33 `dataOffset/16`**、bit34-63 `samples` | 逐字节反解 + 重序列化回环 |
| chunk | MP3 包每个采样只有一条 `LOOP`（type 3，8 字节 = loopstart, loopend） | 六个能响的包都是 `chunks=3` |
| `samples` | MP3 用**帧数 × 1152**（MPEG-1 L3 每帧 1152 采样） | 和能响的包对得上 |
| 名字表 | `numSamples` 个 uint32 偏移 + NUL 结尾字符串，**名字 = FEV 里引用的文件名去掉扩展名** | 取证：`.fev` 写 `want_to_be_close.wav`，`.fsb` 存 `want_to_be_close` |
| **数据对齐** | **每个采样的 `dataOffset`（以及 `dataStart`）必须是 32 的倍数**，也就是位域里存的 `/16` 值必须是偶数 | 本节末尾的四次启动 A/B |

最后一条是唯一的坑，也是这条路线差点没走通的地方：**违反它不报任何错**——两个 `Asset` 照常登记、
`PlayingSound` 全程 false、日志里一条 FMOD 错误都没有。游戏里 6 份"本来就能响"的包全部满足它。

#### 游戏里的判定过程（副本 `z-fsbmine`，私有标签，与 `p3r` 零资产名冲突）

第一轮用 12/8/16/20 秒的短音，两种 mp3 摆法（帧紧挨着 `nat` / 每帧补零到 4 的倍数 `pad4`）：

```
[FMIN] fire stage=1 name=ctrl  path=zctrl01.fbp/untitled/1 ok=true res=nil playing=true
[FMIN] t=015.5 ctrl=true  plain=false pad4=false fem=true
[FMIN] fire stage=2 name=plain path=ztestb1.fbp/untitled/1 ok=true res=nil playing=true
[FMIN] t=025.6 ctrl=false plain=true  pad4=false fem=true     # nat 响
[FMIN] fire stage=3 name=pad4  path=ztestc1.fbp/untitled/1 ok=true res=nil playing=true
[FMIN] t=040.6 ctrl=false plain=false pad4=false fem=true     # pad4 不响，一直到 115.8 都是 false
```

当时第一反应是"FMOD 只认干净帧"——**这个结论是错的**。后面两次启动分别把播放顺序倒过来（`pad4` 放第一个，
排除"晚起播的吃亏"这种顺序混淆）、再把曲目换成整首长度（195/228/294/127 秒），
两次都还是只有 `nat` 那份响；最后把 `pad4` 的 `dataOffset` 补齐到 32 的倍数，**同一份补零数据立刻就响了**，
而那份整首长度的 `nat` 换成 16 对齐之后同样哑掉——变量从头到尾只有对齐
（`nat` 那一版是碰巧每个偏移都落在 32 的倍数上）：

```
# 第四次启动，两份都改成 32 对齐，同一次启动里 p3r 原库继续当对照
[FMIN] fire stage=1 name=long32 path=ztestd2.fbp/untitled/1 ok=true res=nil playing=true
[FMIN] t=015.0 long32=true  pad32=false ctrl=false fem=true
... 020.0 / 025.0 / 030.1 / 035.1 / 040.3 六拍全是 long32=true
[FMIN] fire stage=2 name=pad32 path=ztestc2.fbp/untitled/1 ok=true res=nil playing=true
[FMIN] t=045.3 long32=false pad32=true  ctrl=false fem=true
[FMIN] t=050.3 long32=false pad32=true  ctrl=false fem=true     # 补零帧 + 32 对齐 = 响
[FMIN] fire stage=3 name=ctrl  path=zctrl01.fbp/untitled/1 ok=true res=nil playing=true
[FMIN] t=112.1 long32=false pad32=false ctrl=true  fem=true
```

也就是说：采样数据怎么切、帧补不补零、曲目长或短都无所谓；**只有 32 字节对齐是硬的**。
输出工具还会自查一遍（`nonaligned` 必须为 0，否则直接报错）。
第一、四这两次启动的完整日志已存档在开发机 `p3r/_release/fsb5-evidence/`
（`client_log.fmin1.log`、`client_log.fmin4.log`，中间两次的日志被覆盖了，没留下）。

**仓库里这份 `tools/mkbank.mjs` 是可复现的**：拿第四次启动那一组输入重跑一遍

```bash
node tools/mkbank.mjs <那 4 个整首 mp3 的目录> out.fsb <donor.fsb> nat 469 32
```

产出的字节和游戏里实测响过的 `ztestd2.fsb` **md5 完全相同**（`d0f3876b535d7b98b703bea958df83a5`），
所以文档里那三行判据不是拿一个改过的脚本回头编的。

#### 仍未排掉的那一条（别把路线 5 的成立当成解释了一切）

FMOD Studio 切片出来的 FSB5（路线 4）**也满足 32 字节对齐**——19 个采样全部对齐、`dataStart` 也对齐，
但它进游戏照样不响。所以"对齐"不是 Studio 失败的原因，两者之间还剩一个没被排除的差别：

- `0x24` 那 16 字节：能响的包全非零（p3r `841600964`、Klei `1876034021`/`4066884513`），
  而两份 Studio 切片都是 `0`。本仓库自己手搓的那几份**非零**，因为是整份抄的 p3r 头部。

本工具是**整份抄头**绕开了这个问题，所以路线 5 成立；但要写"凭空造一个 FSB5"还差这一格，
**目前没人证明它到底参不参与加载**。想接着挖的话，做一次"只把那 16 字节填成非零"的 Studio 切片 A/B 就够了。

#### 三条使用上的注意

1. **短素材不会无缝循环**：事件时长是 `.fev` 里记着的，采样比它短就播到自身长度结束。
   本模板的音乐看门狗会把它重新起播，所以听起来是"重复播同一段"，不是无缝循环。
2. **`align` 参数默认 32，不要往下调**。工具会拒绝小于 32 或非 2 的幂的值。
3. **`<template.fsb>` 只贡献头部**，不要指望它带来任何音频；采样数据全部来自你给的 mp3。
   因此那条"事件时长/loop 点和采样长度要对上"的老限制照样在（见路线 3 那段）。

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
