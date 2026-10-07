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
set TEXCREATOR_EXE=<Steam 库>\steamapps\common\Don't Starve Mod Tools\mod_tools\TEXCreator.exe
/c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File tools/png2tex.ps1 -InPng art/frame1.png -OutTex images/1.tex -Exe "$TEXCREATOR_EXE"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/patch_tex_flags.ps1 -Tex images/1.tex

# 4) 参数文件
printf 'duration=12\naspect=1920x1020\n' > movies/1.cfg
```

`images/N.xml` 手写就行，元素名固定 `<槽位>.tex`，uv 各留半个纹素内缩
（`u1 = 0.5/宽`，`u2 = 1 - u1`，v 同理）——`art/generate.sh` 里有一段 awk 直接算好写文件的写法，抄它。

想要**看不出接缝**的循环，两条路：
选首尾画面接近、结尾不要淡出到黑的片子；或者用正弦驱动的镜头位移，位移周期等于片子时长，
那么第 T 秒的画面严格等于第 0 秒，接缝在数学上就是连续的（`art/generate.sh` 就是这么生成演示素材的，
不需要"正放 + 倒放"那种来回摆的剪法）。

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
- 事件路径**和文件名无关**，取决于 `.fbp` 工程内部名：
  `事件路径 = <工程内部名>/<事件组名>/<事件名>`。两条命名惯例必须满足，否则游戏静音且不报错：
  `.fev` 文件名必须等于工程内部名，`.fsb` 文件名必须等于音色库内部名。
  本模板的三个常数就是按 `mymusic.fbp` / `mymusic` 这套写的；拿到别人的音色库先按 RIFF chunk
  把 `PROP`（工程名）、`LGCY`（音色库名）、`STRR`（事件组/事件名）读出来核对。
- 启用步骤：把音色库放进 `sound/` → `MUSIC_TRACK_COUNT` 改成曲目数 → 取消 `modinfo.lua` 里 `music` 那一整项的注释
  并按 `data = 1~N` 填曲目名、`N+1` 是"随机播放"、`0` 是原版。
- 音量挂在**事件标签**上：`SoundEmitter:SetVolume("FEMusic", 0.5)`。它和游戏选项里的"音乐音量"是两条链
  （后者调 FMOD 的 `set_music` 总线），两者**叠乘**而不是互相覆盖。游戏每次重新 `PlaySound` 都可能把它顶回默认值，
  而 mod 的钩子在 post-construct、抢不到起播那一刻，所以要在"从没在响 → 在响"这个沿上补一次。

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
