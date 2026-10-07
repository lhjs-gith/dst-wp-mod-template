-- 主菜单视频壁纸模板：多槽位 .ogv 壁纸 + 可选的自定义主菜单音乐
--
-- 做一个新 mod 只需要改下面这一段常数，再往 movies/ images/ sound/ 里放素材；
-- 引擎部分（循环接缝处理、首帧垫图、轮换进度持久化、快捷键）不用动。
--
-- 代码来源标注：整体结构、以及"循环衔接处用首帧图盖在视频上层"的做法，参考创意工坊 mod
-- 「温蒂动态壁纸」（作者 zzzzzzzs、临夏听舟，published file id 3547896422）；
-- 多槽位壁纸扫描、首帧贴图与图集生成、音频包接入、配置项为自行实现。

GLOBAL.setmetatable(env, {
    __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})

-- 壁纸槽位数。配置项里 1~MOVIE_SLOTS 是定向槽位，改这里要同步改 modinfo.lua 的壁纸档位
local MOVIE_SLOTS = 8

-- 画面比例只能靠这个常数：游戏里实测 Video 部件的 GetSize 在 Load 之后一律返回 (0, 0)，
-- 拿不到片子原生尺寸。模板自带的 1.ogv 是 1920x1020（不是 16:9），换素材时改这里，
-- 或者用配置项"视频比例"、movies/N.cfg 里的 aspect= 覆盖
local VIDEO_ASPECT = 1920 / 1020

-- 各槽位的时长种子（秒）。填了片子实际长度，第一圈就能提前盖住循环接缝；不填也能用，
-- 只是第一圈要等播完才知道周期，接缝处会多露一次尾巴。
-- 种子在"到点还没播完"之后自动作废，所以用户换成别的片子也不会把画面冻住
local DURATION_HINTS = { [1] = 12, [2] = 8, [3] = 16 }

-- 自定义主菜单音乐的曲目数。0 表示这个 mod 不带音频包，主菜单保留原版 BGM，
-- 下面所有音乐逻辑（Assets 注册、音量档、快捷键切歌）都会整段短路。
-- 非 0 时必须是预先打好的 FMOD 音色库：饥荒没有播放裸 mp3/ogg/wav 的接口
local MUSIC_TRACK_COUNT = 0

-- 音频包：音色库名决定 .fsb 文件名，工程名决定 .fev 文件名与事件路径前缀。
-- 这两个名字必须与 FMOD Designer 工程里的内部名字逐字对应，否则游戏里不响也不报错
local SOUND_BANK = "sound/mymusic"
local SOUND_FEV = "sound/mymusic.fbp"
local SOUND_EVENT_ROOT = "mymusic.fbp/untitled/"

-- 轮换进度的存档键：跨启动记住"下一次该放第几张"（写在 TheSim 的持久化字符串里，
-- 落在 Documents/Klei/DoNotStarveTogether/<SteamID>/client_save/）。每个 mod 要用自己
-- 命名空间的键名，否则几个基于本模板做的 mod 会互相顶掉进度
local ROTATE_KEY = "wpmod_rotate_next"

-- 配置项里的时长/比例档位：0 走各自默认（时长=实测循环周期，比例=上面的 VIDEO_ASPECT 常数）
local duration_cfg = GetModConfigData("video_duration")
local aspect_cfg = GetModConfigData("video_aspect")
local forced_duration = type(duration_cfg) == "number" and duration_cfg > 0 and duration_cfg or nil
-- 比例存成整数档，避开浮点 data 经存档序列化后回读不等的坑
local ASPECT_TIERS = { [1] = 16 / 9, [2] = 16 / 10, [3] = 1920 / 1020, [4] = 4 / 3, [5] = 21 / 9, [6] = 1 }
local forced_aspect = type(aspect_cfg) == "number" and ASPECT_TIERS[aspect_cfg] or nil

PrefabFiles = {}

local function modfile(relpath)
    local ok, path = pcall(softresolvefilepath, (MODROOT or "") .. relpath)
    return ok and path or nil
end

-- 每槽位一个旁路配置 movies/<槽位>.cfg（纯文本，一行一项）：
--   duration=20.5      片子实际长度（秒），用来在第一圈就盖住接缝
--   aspect=16:9        画面比例，也接受 1920x1080 这种写法或直接写比值
-- 槽位多起来之后，全局档位就管不过来了（A 素材 20s、B 素材 60s 没法同时正确），
-- 所以让每个素材自带自己的参数；没这个文件时仍旧回落到配置项和内置种子。
local function read_cfg(relpath)
    local path = modfile(relpath)
    if path == nil then return nil end
    -- 沙盒里 io 不一定在，整段都包进 pcall，读不到就当作没有这个文件
    local ok, text = pcall(function()
        local f = io.open(path, "r")
        if f == nil then return nil end
        local data = f:read("*a")
        f:close()
        return data
    end)
    return ok and text or nil
end

local function parse_cfg(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for line in text:gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*(%a[%w_]*)%s*=%s*(.-)%s*$")
        if key and value ~= "" then
            local low = key:lower()
            if low == "duration" then
                local num = tonumber(value)
                if num and num > 0 and num < 3600 then out.duration = num end
            elseif low == "aspect" then
                local w, h = value:match("^(%d+)%s*[x:/%-,]%s*(%d+)$")
                local ratio = tonumber(value)
                if w and h and tonumber(h) > 0 then
                    ratio = tonumber(w) / tonumber(h)
                end
                if ratio and ratio > 0.2 and ratio < 8 then out.aspect = ratio end
            end
        end
    end
    return out
end

--------------------------------------------------------------------------
-- 资源注册：只登记实际存在的壁纸文件，空槽位自动跳过

local wallpapers = {}
local available_slots = {}
Assets = {}

for slot = 1, MOVIE_SLOTS do
    local movie = "movies/" .. slot .. ".ogv"
    if modfile(movie) then
        Assets[#Assets + 1] = Asset("PKGREF", movie)
        local cfgtext = read_cfg("movies/" .. slot .. ".cfg")
        local cfg = parse_cfg(cfgtext)
        local entry = {
            movie = movie,
            duration_hint = cfg.duration or forced_duration or DURATION_HINTS[slot],
            aspect = cfg.aspect,
        }
        -- 可选：images/<槽位>.tex 首帧垫底图，配套的 xml 由本 mod 自己写，元素名固定为 "<槽位>.tex"
        local atlas = "images/" .. slot .. ".xml"
        local tex = "images/" .. slot .. ".tex"
        if modfile(atlas) and modfile(tex) then
            entry.atlas = atlas
            entry.element = slot .. ".tex"
            -- 主菜单用的是预加载列表，不登记的话运行时 Atlas 表里查不到这张图
            Assets[#Assets + 1] = Asset("IMAGE", tex)
            Assets[#Assets + 1] = Asset("ATLAS", atlas)
        end
        wallpapers[slot] = entry
        available_slots[#available_slots + 1] = slot
    end
end

-- 只有真的带音频包时才登记：MUSIC_TRACK_COUNT 为 0 时这两个文件不存在，
-- 而 Assets 里登记缺失文件会在日志里留一条加载失败
if MUSIC_TRACK_COUNT > 0 then
    Assets[#Assets + 1] = Asset("FILE", SOUND_BANK .. ".fsb")
    Assets[#Assets + 1] = Asset("SOUNDPACKAGE", SOUND_FEV .. ".fev")
end

-- 随机数两处要用：壁纸轮换和音乐洗牌。os.time() 精度只到秒，但两者都是一次加载抽一次，够用
math.randomseed(os.time())

-- 轮换档：主菜单界面每被构造一次就换一张，进度跨启动记住（存档键见文件头的 ROTATE_KEY）。
-- 这样轮换就是按顺序一张一张过，关掉游戏再开也不会连着两次同一张。
-- 配置项里 1~MOVIE_SLOTS 是定向槽位、0 是关闭，所以轮换用 MOVIE_SLOTS+1
local WALLPAPER_ROTATE = MOVIE_SLOTS + 1

local rotate_next = 1      -- 下一次轮换该放 available_slots 里的第几个
local rotate_ready = false -- 读档回调回来了，上面的值才是从上次接着的
local rotate_written = false

local function load_rotate_progress()
    if TheSim == nil or TheSim.GetPersistentString == nil then return end
    pcall(function()
        TheSim:GetPersistentString(ROTATE_KEY, function(success, data)
            -- 回调可能比第一次构造还晚到，那时候我们自己的进度已经写出去了，不能拿旧值盖它
            if success and not rotate_written then
                rotate_next = tonumber(data) or rotate_next
                rotate_ready = true
            end
        end, false)
    end)
end

local function save_rotate_progress()
    if TheSim == nil or TheSim.SetPersistentString == nil then return end
    pcall(function() TheSim:SetPersistentString(ROTATE_KEY, tostring(rotate_next), false) end)
end

load_rotate_progress()

-- 谁在播就按谁记进度：轮换抽的、玩家按键挑的，都算"这张看过了，下次从下一张接着"
local function remember_slot(slot)
    local n = #available_slots
    local at
    for i = 1, n do
        if available_slots[i] == slot then
            at = i
            break
        end
    end
    if at == nil then return end
    rotate_next = at % n + 1
    rotate_written = true
    save_rotate_progress()
end

local function rotate_slot()
    local n = #available_slots
    if n == 0 then return nil end
    if n == 1 then return available_slots[1] end
    if not rotate_ready then return available_slots[math.random(n)] end
    return available_slots[(rotate_next - 1) % n + 1]
end

-- 选哪一张放在每次构造时算，不在文件作用域先定死：轮换档要靠这个，每次回主菜单才换得了
local function pick_initial_slot()
    local wanted = GetModConfigData("wallpaper")
    -- 关掉壁纸时不能回落到槽位 1，否则"关闭"这一档等于没生效
    if wanted == 0 then return nil end
    if wanted == WALLPAPER_ROTATE then return rotate_slot() end
    if wallpapers[wanted] then return wanted end
    return available_slots[1]
end

--------------------------------------------------------------------------
-- 主菜单音乐。曲目数 MUSIC_TRACK_COUNT 在文件头，为 0 时这一段整体不生效、保留原版 BGM

-- music 配置项里"随机播放"那一档的值；1~MUSIC_TRACK_COUNT 是定向曲目，0 是原版
local MUSIC_SHUFFLE = MUSIC_TRACK_COUNT + 1

local music_enabled = false
local music_shuffle = false
local music_track = nil

-- 洗牌时不让同一首连着放两次
local function pick_track()
    if MUSIC_TRACK_COUNT <= 1 then return 1 end
    local picked
    repeat
        picked = math.random(MUSIC_TRACK_COUNT)
    until picked ~= music_track
    return picked
end

if MUSIC_TRACK_COUNT > 0 then
    local song = GetModConfigData("music")
    if song == MUSIC_SHUFFLE then
        music_enabled, music_shuffle = true, true
        music_track = pick_track()
    elseif type(song) == "number" and song > 0 and song <= MUSIC_TRACK_COUNT then
        music_enabled = true
        music_track = song
    end
end

if music_enabled then
    GLOBAL.FE_MUSIC = SOUND_EVENT_ROOT .. music_track
    TheSim:PreloadFile(SOUND_BANK .. ".fsb")
end

-- 主菜单音量档位：只压标签 "FEMusic" 的这一个事件。游戏选项里的"音乐音量"调的是 FMOD 的
-- set_music 总线，总线音量 × 单事件音量是叠乘关系，所以这一档是在玩家设好的音量上再压低。
-- 素材 .ogv 自带音轨时，背景音乐不能单独调音量，但可以把这一首压下去让画面声更清楚。
local MUSIC_VOLUME_TIERS = { [1] = 0.25, [2] = 0.5, [3] = 0.75 }
local music_volume = MUSIC_VOLUME_TIERS[GetModConfigData("music_volume")]

local function duck_music(sound)
    if music_volume ~= nil then sound:SetVolume("FEMusic", music_volume) end
end

--------------------------------------------------------------------------
-- 壁纸部件用到的部件类

local Video = require "widgets/video"
local Widget = require "widgets/widget"
local Image = require "widgets/image"

--------------------------------------------------------------------------
-- 壁纸部件：视频循环播放

-- 压暗档：主菜单的按钮压在亮色壁纸上不好读，所以在壁纸最上层蒙一层半透明黑。
-- 这一层必须在首帧垫图之上，否则接缝换帧的那一下画面会跟着忽明忽暗。
local SHADE_TIERS = { [1] = 0.1, [2] = 0.2, [3] = 0.3, [4] = 0.45 }
local shade_alpha = SHADE_TIERS[GetModConfigData("shade")]

-- 揭盖只认一个闸门：既要到点（cover_off），又要引擎确实接下了这一轮播放（IsDone 为假）。
-- IsDone 为真期间必然还没有新帧，那时候揭盖露出来的就是黑，所以两个条件缺一不可。
local SEAM_REVEAL_DELAY = 0.35        -- 热缓存那一档，实测基本被 IsDone 翻假的时刻兜住
local SEAM_COLD_REVEAL_DELAY = 4.0    -- 片子在本进程里第一次解码时，第一帧要晚得多，多垫一点
local COLD_FIRST_FRAME = 2.6          -- 起播那一档：冷解码 Play 之后约 2.4 秒才吐第一帧
-- 实测循环周期倒数这么多秒就先把首帧图盖上去：片子结尾自己有一段淡出的黑，
-- 等 IsDone 才盖就漏黑了，必须提前盖住尾巴
local SEAM_PRE_COVER = 0.7
-- IsDone 一直为真说明重开没生效，到这个点就再试一次 Play
local SEAM_MAX_COVER = 3
-- 时长种子（素材自带的媒体时长）比"到点了还没播完"再多等这么多秒就判定种子无效。
-- 引擎的 IsDone 本来就比最后一帧晚 1~2 秒，所以这一档必须大于那段排水，否则种子会在
-- 接缝前一刻自己作废，白丢一段提前盖尾
local SEAM_GUESS_TOLERANCE = 3
-- 音乐停了多久之后重新触发。留出一点余量，避免起播/切场景那一瞬的假"没在响"造成重复叠播
local MUSIC_RESTART_DELAY = 1

local Wallpaper = Class(Widget, function(self, wallpaper)
    Widget._ctor(self, "Wallpaper")
    -- 槽位自带的比例优先（movies/N.cfg），其次才用配置项的档位
    self.aspect = wallpaper.aspect

    -- 黑底铺满整个视口，保证任何情况下都不会透出游戏场景
    self.backdrop = self:AddChild(Image("images/global.xml", "square.tex"))
    self.backdrop:SetHRegPoint(ANCHOR_MIDDLE)
    self.backdrop:SetVRegPoint(ANCHOR_MIDDLE)
    self.backdrop:SetTint(0, 0, 0, 1)

    -- 视频部件。全程从不 Hide，衔接靠首帧图浮在最上层顶住
    self.video = self:AddChild(Video("video"))
    self.video:Load(resolvefilepath(wallpaper.movie))
    self.video:SetHRegPoint(ANCHOR_MIDDLE)
    self.video:SetVRegPoint(ANCHOR_MIDDLE)

    if wallpaper.atlas then
        self.still = self:AddChild(Image(wallpaper.atlas, wallpaper.element))
        self.still:SetHRegPoint(ANCHOR_MIDDLE)
        self.still:SetVRegPoint(ANCHOR_MIDDLE)
        self.still:MoveToFront()
        self.still:Hide()
    end

    if shade_alpha then
        self.shade = self:AddChild(Image("images/global.xml", "square.tex"))
        self.shade:SetHRegPoint(ANCHOR_MIDDLE)
        self.shade:SetVRegPoint(ANCHOR_MIDDLE)
        self.shade:SetTint(0, 0, 0, shade_alpha)
    end

    self.playing = false
    self.restarting = false
    self.cover_time = 0
    self.uptime = 0
    self.covered = false
    -- 周期先用素材自带的时长种子顶上，第一次 IsDone 之后换成实测值
    self.period = wallpaper.duration_hint
    self.period_guess = self.period ~= nil
    self.loop_start = 0
    -- 本实例的第一圈按冷解码对待：先把首帧图盖上顶住起播那一段没有帧的黑，到点再交给闸门揭
    self.first_cycle = self.still ~= nil
    self.cover_off = nil
    if self.still then
        self:ShowCover()
        self.cover_off = COLD_FIRST_FRAME
    end
    -- 整棵壁纸子树都不吃点击：它铺满全屏，会把主菜单所有按钮挡在拾取之外
    self:SetClickable(false)
    self:UpdateWhilePaused(true)
    self:StartUpdating()
    self:Resize()
end)

-- fixed_root 按比例缩放，需把屏幕像素换算成设计坐标才能贴满
function Wallpaper:Resize()
    local screen_w, screen_h = TheSim:GetScreenSize()
    local scale = math.min(screen_w / RESOLUTION_X, screen_h / RESOLUTION_Y)
    local view_w, view_h = screen_w / scale, screen_h / scale
    local aspect = self.aspect or forced_aspect or VIDEO_ASPECT

    local w, h
    if GetModConfigData("fill") == 2 then
        w = math.min(view_w, view_h * aspect)
        h = math.min(view_h, view_w / aspect)
    else
        w, h = view_w, view_h
    end

    self.video:SetSize(w, h)
    -- 黑底铺满整个视口：保持比例模式下多出来的边也要盖住
    self.backdrop:SetSize(view_w, view_h)
    if self.still then self.still:SetSize(w, h) end
    -- 压暗层按视口铺满：保持比例模式下留出来的黑边也要一起盖，不然接缝处会亮出一圈边
    if self.shade then self.shade:SetSize(view_w, view_h) end
end

-- Video 部件有 SetTint（widgets/video.lua:33），但实测它对画面没有可见作用，
-- 所以不能用"把视频淡出"的办法露出底下的图
function Wallpaper:ShowCover()
    if self.covered or not self.still then return end
    self.covered = true
    self.still:Show()
end

function Wallpaper:HideCover()
    if not self.covered then return end
    self.covered = false
    self.still:Hide()
end

function Wallpaper:Play()
    if self.playing then return end
    self.playing = true
    self.video:Play()
end

-- 退役：换壁纸时先停掉再藏起来，真正的 Kill 留到下一帧（见 show_slot）
function Wallpaper:Retire()
    self.playing = false
    if self.video then self.video:Stop() end
    self:Hide()
end

-- 播完立刻在当前帧重开。原来用 inst:DoTaskInTime(0) 排任务，要等 scheduler 调度到，
-- 主菜单里这段时间不受控；重开越早，被垫住的时间就越短
function Wallpaper:OnUpdate(dt)
    self.uptime = self.uptime + dt
    if not self.playing then return end

    local done = self.video:IsDone()

    -- 唯一的揭盖出口：到点、且引擎确实接下了这一轮（不为 done）。
    -- 尾巴盖上之后除了这里没有任何地方会揭盖，所以引擎那段"播完了但还没重开"的排水期
    -- （实测最后一帧之后约 2 秒，冷解码时只给黑帧）一定整个被垫图盖掉。
    if self.covered and self.cover_off and not done and self.uptime >= self.cover_off then
        self.cover_off = nil
        self.restarting = false
        self.cover_time = 0
        self:HideCover()
    end

    if done then
        self.cover_time = self.cover_time + dt
        self:ShowCover()
        if not self.restarting then
            self.restarting = true
            -- 跑到第一次播完才知道这一轮实际多长，后面几轮就按这个周期提前盖尾巴
            self.period = self.uptime - self.loop_start
            self.period_guess = nil
            self.loop_start = self.uptime
            self.cover_time = 0
            self.video:Play()
            -- 本实例的第一圈按冷解码那一档多垫，之后各圈回到短档，免得每圈都冻一下
            self.cover_off = self.uptime
                + (self.first_cycle and SEAM_COLD_REVEAL_DELAY or SEAM_REVEAL_DELAY)
            self.first_cycle = nil
        elseif self.cover_time >= SEAM_MAX_COVER then
            -- 重开没生效、一直停在播完状态：再试一次，不能干等着
            self.cover_time = 0
            self.video:Play()
        end
        return
    end

    -- 还没播完但已经进了尾巴：这段片子自己是淡出的，等 IsDone 才盖就漏黑了，提前盖住
    if self.period then
        local elapsed = self.uptime - self.loop_start
        if elapsed >= self.period - SEAM_PRE_COVER then
            -- 盖上同时把期限清掉：尾巴一直盖到 IsDone 之后的那一档才揭，
            -- 中途按时间揭盖露出来的就是那约 2 秒排水黑帧（实测黑 2.07 秒正是这么来的）
            self.cover_off = nil
            self:ShowCover()
        end
        -- 用的是时长种子而到点还没播完，说明素材被换过了，这条作废，不能再拿它决定盖尾时机。
        -- 作废只是不再提前盖尾巴，盖子本身由上面那个闸门负责收，所以这里不会露黑。
        if self.period_guess and elapsed >= self.period + SEAM_GUESS_TOLERANCE then
            self.period, self.period_guess = nil, nil
        end
    end
end

--------------------------------------------------------------------------
-- 按键切换壁纸与音乐
--
-- 饥荒主菜单的按键导航监听了两组控制：方向键(FOCUS_*)和 WASD(MOVE_*)，实测原版按键表
-- move_up=W、focus_up=上方向键，所以这两组按下去选中框都会跳，而原生按键回调拦不住它
-- （Input:OnRawKey 不往 C++ 返回任何东西）。下面那层 FrontEnd:OnFocusMove 包装只把"由我们
-- 占用的那个物理键引起的"导航吃掉：默认方案下 WASD 专心换壁纸/换歌，方向键照常导航。
--
-- 配置界面只认列表项，给不了任意按键，所以留了 mod 目录下的 keys.cfg 做完全自定义，
-- 一行一项，值可以是字母、数字、up/down/left/right 或 f1~f12，写 none 表示关掉这一项：
--   wp_prev=W   上一张壁纸
--   wp_next=S   下一张壁纸
--   ms_prev=A   上一首音乐
--   ms_next=D   下一首音乐
-- 没写的行沿用配置项里选的那档预设。

local KEY_PRESETS = {
    { wp_prev = KEY_W, wp_next = KEY_S, ms_prev = KEY_A, ms_next = KEY_D },
    { wp_prev = KEY_UP, wp_next = KEY_DOWN, ms_prev = KEY_LEFT, ms_next = KEY_RIGHT },
}
local KEY_OFF = 3     -- 配置项里"不使用按键"那一档

local KEY_NAMES = { up = KEY_UP, down = KEY_DOWN, left = KEY_LEFT, right = KEY_RIGHT }
for c = 97, 122 do KEY_NAMES[string.char(c)] = c end
for c = 49, 57 do KEY_NAMES[string.char(c)] = c end
for i = 1, 12 do KEY_NAMES["f" .. i] = 281 + i end

local KEY_FIELDS = { wp_prev = true, wp_next = true, ms_prev = true, ms_next = true }

-- 一项都没认出来的键名当作"没写这一行"，认不出的填法不会把默认档位抹掉
local function parse_keys(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for line in text:gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*(%a[%w_]*)%s*=%s*(.-)%s*$")
        if key and value ~= "" and KEY_FIELDS[key:lower()] then
            local low = value:lower()
            local code
            if low == "none" or low == "off" then
                code = false
            else
                code = KEY_NAMES[low]
            end
            if code ~= nil then out[key:lower()] = code end
        end
    end
    return out
end

local function load_bindings()
    local b = {}
    local scheme = GetModConfigData("key_scheme")
    if scheme == nil then scheme = 1 end        -- 没保存过的配置项读回来是 nil
    if scheme ~= KEY_OFF then
        for k, v in pairs(KEY_PRESETS[scheme] or KEY_PRESETS[1]) do b[k] = v end
    end
    for k, v in pairs(parse_keys(read_cfg("keys.cfg"))) do b[k] = v end
    return b
end

local bindings = load_bindings()

-- 我们占用的那组键不能再顺带移动菜单选中框。实测原版按键表里 W/A/S/D 就是 MOVE_*、
-- 方向键是 FOCUS_*，而 frontend.lua:858-865 两组都监听，所以方向键和 WASD 都会跳；
-- 原生按键回调又拦不住（Input:OnRawKey 不往 C++ 返回任何东西），只能在这一层把
-- "由我们那个键引起的 focus move"吃掉。判定用的是物理键当前有没有按下，所以没被我们
-- 占用的那一组（比如默认方案下的方向键、手柄十字键）导航完全不受影响。
local NAV_DIR = { wp_prev = MOVE_UP, wp_next = MOVE_DOWN, ms_prev = MOVE_LEFT, ms_next = MOVE_RIGHT }

local swallow = {}
for field, dir in pairs(NAV_DIR) do
    local key = bindings[field]
    if key then swallow[dir] = key end
end

-- 这里必须用 AddGlobalClassPostConstruct：frontend.lua 只把 FrontEnd 定义成全局
-- （frontend.lua:42），文件末尾没有 return，所以 AddClassPostConstruct 的 require 断言会失败
AddGlobalClassPostConstruct("frontend", "FrontEnd", function(self)
    local orig = self.OnFocusMove
    function self:OnFocusMove(dir, down)
        local key = swallow[dir]
        if key ~= nil and TheInput ~= nil and TheInput:IsKeyDown(key) then
            return true
        end
        if orig then return orig(self, dir, down) end
    end
end)

--------------------------------------------------------------------------
-- 主菜单接入

-- 原版 FE_MUSIC 这个事件在 FMOD 里自己就是无限循环的，所以游戏只在主菜单构造时 PlaySound 一次；
-- 本 mod 盘里的歌是播一遍就结束，于是挂个看门狗：确认它响过之后，标签一旦不再 PlayingSound 就重新触发。
-- 需要借一个每帧 OnUpdate 的部件来跑
local function attach_music_watchdog(host)
    if not music_enabled then return end
    local sound = TheFrontEnd:GetSound()
    if not sound or type(sound.PlayingSound) ~= "function" then return end

    local heard, idle = false, 0
    local orig_update = host.OnUpdate
    function host:OnUpdate(dt)
        if sound:PlayingSound("FEMusic") then
            heard, idle = true, 0
        elseif heard then
            idle = idle + dt
            if idle >= MUSIC_RESTART_DELAY then
                idle = 0
                -- 洗牌档：每轮重开之前换一首，下一次 PlaySound 用的就是新事件路径
                if music_shuffle then
                    music_track = pick_track()
                    GLOBAL.FE_MUSIC = SOUND_EVENT_ROOT .. music_track
                end
                sound:PlaySound(FE_MUSIC, "FEMusic")
                duck_music(sound)
            end
        end
        if orig_update then return orig_update(self, dt) end
    end
end

-- 音量是挂在标签上的，游戏每次重新 PlaySound 都可能把它顶回默认值，而本 mod 的钩子在
-- post-construct，抢不到它起播的那一刻。所以盯"从没在响到在响"这个沿，起播当帧补一次
local function attach_music_volume(host)
    if music_volume == nil then return end
    local sound = TheFrontEnd:GetSound()
    if not sound or type(sound.SetVolume) ~= "function" then return end

    local was_playing = false
    local orig_update = host.OnUpdate
    function host:OnUpdate(dt)
        local playing = sound:PlayingSound("FEMusic")
        if playing and not was_playing then duck_music(sound) end
        was_playing = playing
        if orig_update then return orig_update(self, dt) end
    end
end

--------------------------------------------------------------------------
-- 换壁纸 / 换曲
--
-- 换壁纸要毁掉正在播的 Video 部件，这是全 mod 唯一会这么做地方。Klei 自己的 MovieDialog
-- 从不杀还在播的片子：要么等 IsDone（moviedialog.lua:41-45），要么只 Stop 然后等屏幕弹掉
-- 再连着 Kill（moviedialog.lua:71-76）。实测直接 Kill 播放中的视频，一秒后必 abort，
-- 所以这里分两帧：当帧 Stop+Hide 旧的、下一帧才 Kill（见 ticker 的 OnUpdate）。

local menu = nil
local keys_installed = false

local function show_slot(m, slot)
    local entry = wallpapers[slot]
    if entry == nil then return end
    -- 先建新的再停旧的：中间不能有一帧两张都不在
    local wp = m.root:AddChild(Wallpaper(entry))
    wp:MoveToBack()
    wp:Play()
    if m.wp then
        m.wp:Retire()
        m.dying = m.wp
    end
    m.wp, m.slot = wp, slot
    remember_slot(slot)
end

local function step_wallpaper(m, dir)
    local n = #available_slots
    if n < 2 or m.wp == nil then return end
    local at
    for i = 1, n do
        if available_slots[i] == m.slot then
            at = i
            break
        end
    end
    if at == nil then return end
    show_slot(m, available_slots[(at - 1 + dir) % n + 1])
end

local function switch_track(dir)
    if not music_enabled or MUSIC_TRACK_COUNT < 2 then return end
    music_track = ((music_track or 1) - 1 + dir) % MUSIC_TRACK_COUNT + 1
    -- 手动切过歌之后就不再自动洗牌，否则玩家挑的这一首下一轮就被随机顶掉了
    music_shuffle = false
    GLOBAL.FE_MUSIC = SOUND_EVENT_ROOT .. music_track
    local sound = TheFrontEnd:GetSound()
    if sound and type(sound.KillSound) == "function" then
        sound:KillSound("FEMusic")
        sound:PlaySound(FE_MUSIC, "FEMusic")
        duck_music(sound)
    end
end

-- 按键回调只记一笔，动作留到下一帧的 OnUpdate 再做。只认主菜单在最上面的时候：
-- FrontEnd 每帧只更新栈顶那一屏（frontend.lua:760），子界面开着时队列不会被消费
local function queue(kind, dir)
    local m = menu
    if m ~= nil and TheFrontEnd:GetActiveScreen() == m.screen then
        m[kind] = dir
    end
end

local function install_key_handlers()
    if keys_installed then return end
    if TheInput == nil or TheInput.AddKeyUpHandler == nil then return end
    keys_installed = true

    -- 认 keyup 不认 keydown：长按时系统会连发 keydown，一次按键能连跳好几张；
    -- 一次物理按键的 keyup 只来一回
    local specs = {
        { "wp_prev", "want_wp", -1 },
        { "wp_next", "want_wp", 1 },
        { "ms_prev", "want_ms", -1 },
        { "ms_next", "want_ms", 1 },
    }
    for _, s in ipairs(specs) do
        local key = bindings[s[1]]
        if key then
            local kind, dir = s[2], s[3]
            TheInput:AddKeyUpHandler(key, function() queue(kind, dir) end)
        end
    end
end

-- 开关类选项（黑边/菜单底色/公告栏）与壁纸、音乐互相独立，所以这个钩子无条件装
AddClassPostConstruct("screens/redux/multiplayermainscreen", function(self)
    if GetModConfigData("sidebar") == 2 and self.sidebar then self.sidebar:Hide() end
    if GetModConfigData("letterbox") == 2 and self.letterbox then self.letterbox:Hide() end
    if GetModConfigData("motd") == 2 and self.motd_panel then self.motd_panel:Hide() end

    local m = { screen = self, root = self.fixed_root }
    menu = m

    local slot = pick_initial_slot()
    if slot then
        if self.banner_root then self.banner_root:Hide() end
        show_slot(m, slot)
        -- 这里刻意不包装 OnHide/OnShow：子菜单打开时让视频继续解码，
        -- 返回主菜单就不会有重开门缝。在里面 Stop/Play 会直接让游戏 abort() 崩掉
    end

    -- 每帧的活都集中在这个空壳上：换壁纸毁掉的是壁纸自己的子树，看门狗和按键队列不受影响
    local ticker = self.fixed_root:AddChild(Widget("WPMusicTicker"))
    ticker:UpdateWhilePaused(true)
    ticker:StartUpdating()
    m.ticker = ticker
    function ticker:OnUpdate(dt)
        -- 上一帧停下来的那张，到这帧才真的毁掉
        if m.dying then
            m.dying:Kill()
            m.dying = nil
        end
        if m.want_wp then
            local d = m.want_wp
            m.want_wp = nil
            step_wallpaper(m, d)
        end
        if m.want_ms then
            local d = m.want_ms
            m.want_ms = nil
            switch_track(d)
        end
    end
    attach_music_watchdog(ticker)
    attach_music_volume(ticker)

    install_key_handlers()
end)
