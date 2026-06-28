-------------------------------------------------
--  HYPER = CAPS LOCK (mapped via Karabiner)
--  Caps giữ = cmd + alt + ctrl + shift
-------------------------------------------------
local hyper = {"cmd", "alt", "ctrl", "shift"}

-------------------------------------------------
--  HELPER FUNCTIONS
-------------------------------------------------

-- Cửa sổ đang được focus
local function focused()
    return hs.window.focusedWindow()
end

-- Màn hình bên trái (Extended Display)
local function getLeftScreen()
    local screens = hs.screen.allScreens()
    if #screens == 0 then return nil end
    local leftMost = screens[1]
    for _, s in ipairs(screens) do
        local f = s:frame()
        local lf = leftMost:frame()
        if f.x < lf.x then
            leftMost = s
        end
    end
    return leftMost
end

-- Di chuyển cửa sổ theo unit (0-1), optional screen
local function moveUnit(win, unit, screen)
    if not win then return end
    if screen then
        win:moveToUnit(unit, screen)
    else
        win:moveToUnit(unit)
    end
end

-- Mở app + lấy window chính rồi callback
local function ensureAppWindow(appName, cb)
    hs.application.launchOrFocus(appName)
    hs.timer.doAfter(0.4, function()
        local app = hs.application.get(appName)
        if not app then return end
        local win = app:mainWindow()
        if not win then
            local wins = app:allWindows()
            win = wins and wins[1] or nil
        end
        if win and cb then
            cb(win)
        end
    end)
end

-------------------------------------------------
--  A) HYPER LAUNCHER (MESSENGER / ZALO / TRELLO)
-------------------------------------------------

-- Caps + 1 → mở Messenger
hs.hotkey.bind(hyper, "1", function()
    hs.application.launchOrFocus("Messenger")
end)

-- Caps + 2 → mở Zalo
hs.hotkey.bind(hyper, "2", function()
    hs.application.launchOrFocus("Zalo")
end)

-- Caps + 3 → mở Trello
hs.hotkey.bind(hyper, "3", function()
    hs.application.launchOrFocus("Trello")
end)

-------------------------------------------------
--  B) LAYOUT TRÊN MÀN HÌNH THỨ 2 (BÊN TRÁI)
--  - Messenger: nửa trái
--  - Zalo: nửa phải
--  - Trello: full ngang, 60% phía dưới
--  (App tự được assign vào Desktop 2/3 bằng Mission Control)
-------------------------------------------------

-- Layout Chat: Messenger + Zalo chia đôi trên màn hình trái
local function layoutChat()
    local s = getLeftScreen() or hs.screen.primaryScreen()

    -- Messenger: nửa trái
    ensureAppWindow("Messenger", function(win)
        moveUnit(win, {x = 0.0, y = 0.0, w = 0.5, h = 1.0}, s)
    end)

    -- Zalo: nửa phải
    ensureAppWindow("Zalo", function(win)
        moveUnit(win, {x = 0.5, y = 0.0, w = 0.5, h = 1.0}, s)
    end)
end

-- Layout Trello: full ngang, 60% phía dưới màn hình trái
local function layoutTrello()
    local s = getLeftScreen() or hs.screen.primaryScreen()

    -- Trello: từ 40% chiều cao trở xuống (60% phía dưới)
    ensureAppWindow("Trello", function(win)
        moveUnit(win, {x = 0.0, y = 0.35, w = 1.0, h = 0.65}, s)
    end)
end

-- Caps + C → layout Messenger + Zalo
hs.hotkey.bind(hyper, "C", function()
    layoutChat()
    hs.alert.show("Chat layout (Messenger + Zalo)")
end)

-- Caps + T → layout Trello
hs.hotkey.bind(hyper, "T", function()
    layoutTrello()
    hs.alert.show("Trello bottom 60%")
end)

-- Caps + L → apply cả Chat + Trello
hs.hotkey.bind(hyper, "L", function()
    layoutChat()
    layoutTrello()
    hs.alert.show("Full layout applied")
end)

-------------------------------------------------
--  NHÓM 1: SNAP CỬA SỔ BẰNG ARROW (TRÊN MÀN HÌNH HIỆN TẠI)
--  Caps + ← : nửa trái
--  Caps + → : nửa phải
--  Caps + ↑ : full màn
--  Caps + ↓ : center (60% rộng, 70% cao)
-------------------------------------------------

-- Caps + ← : nửa trái màn hình hiện tại
hs.hotkey.bind(hyper, "Left", function()
    moveUnit(focused(), {x = 0.0, y = 0.0, w = 0.5, h = 1.0})
end)

-- Caps + → : nửa phải màn hình hiện tại
hs.hotkey.bind(hyper, "Right", function()
    moveUnit(focused(), {x = 0.5, y = 0.0, w = 0.5, h = 1.0})
end)

-- Caps + ↑ : full màn hình
hs.hotkey.bind(hyper, "Up", function()
    moveUnit(focused(), {x = 0.0, y = 0.0, w = 1.0, h = 1.0})
end)

-- Caps + ↓ : center (60% rộng, 70% cao)
hs.hotkey.bind(hyper, "Down", function()
    local win = focused()
    if not win then return end
    local screen = win:screen()
    local f = screen:frame()
    local w = f.w * 0.6
    local h = f.h * 0.7
    win:setFrame({
        x = f.x + (f.w - w) / 2,
        y = f.y + (f.h - h) / 2,
        w = w,
        h = h
    })
end)

-------------------------------------------------
-- STACK TẤT CẢ CỬA SỔ CỦA APP HIỆN TẠI VÀO 1/2 BÊN PHẢI
-- Hyper + Down  (Caps + ↓)
-------------------------------------------------

local function stackWindowsRightOfFocusedApp()
    -- Cửa sổ đang focus
    local frontWin = hs.window.focusedWindow()
    if not frontWin then return end

    -- App hiện tại
    local app = frontWin:application()
    if not app then return end

    -- Lọc các cửa sổ chuẩn & visible
    local allWins = app:allWindows()
    local wins = {}
    for _, w in ipairs(allWins) do
        if w:isStandard() and w:isVisible() then
            table.insert(wins, w)
        end
    end
    local n = #wins
    if n == 0 then return end

    -- Sắp: cửa sổ phụ trước, cửa sổ focus cuối (để focus nằm "trái nhất & thấp nhất")
    local ordered = {}
    local frontId = frontWin:id()
    for _, w in ipairs(wins) do
        if w:id() ~= frontId then
            table.insert(ordered, w)
        end
    end
    table.insert(ordered, frontWin)

    -- Màn hình chứa cửa sổ focus
    local screen = frontWin:screen()
    local sf = screen:frame()

    -- Thoát full screen nếu có
    for _, w in ipairs(ordered) do
        if w:isFullScreen() then
            w:setFullScreen(false)
        end
    end

    -- Đợi macOS thoát full screen xong rồi mới sắp layout
    hs.timer.doAfter(0.15, function()
        -- Khu vực 1/2 màn hình bên phải
        local marginRight  = sf.w * 0.03
        local marginTop    = sf.h * 0.05
        local marginBottom = sf.h * 0.05

        local rightHalfX   = sf.x + sf.w / 2
        local regionWidth  = sf.w / 2 - marginRight
        local baseWidth    = regionWidth * 0.95
        local baseHeight   = (sf.h - marginTop - marginBottom) * 0.9

        -- Độ lệch giữa các cửa sổ trong stack
        local dx = math.min(regionWidth * 0.08, 80)  -- dịch sang phải
        local dy = math.min(sf.h * 0.04, 60)         -- dịch xuống dưới

        -- Mức thu nhỏ dần theo độ sâu
        local shrinkW = 0.08   -- mỗi lớp sâu hơn rộng hơn ~8%
        local shrinkH = 0.06   -- mỗi lớp sâu hơn cao hơn ~6%

        for index, w in ipairs(ordered) do
            local k = index - 1      -- 0..n-1, frontWin là index=n → k=n-1

            -- Cửa sổ sâu nhất (index=1, k=0) → to nhất
            local widthFactor  = math.max(0.55, 1.0 - k * shrinkW)
            local heightFactor = math.max(0.50, 1.0 - k * shrinkH)

            local wWidth  = baseWidth * widthFactor
            local wHeight = baseHeight * heightFactor

            -- X càng sâu càng lệch sang phải,
            -- cửa sổ focus (k lớn nhất) sẽ có x nhỏ nhất (trái nhất trong nửa phải)
            local xOffset = (n - 1 - k) * dx
            local x = rightHalfX + xOffset
            local maxX = sf.x + sf.w - marginRight - wWidth
            if x > maxX then x = maxX end

            -- Y: cửa sổ càng phía "trước" (gần front) càng thấp hơn
            local yTop = sf.y + marginTop
            local y = yTop + k * dy
            local maxY = sf.y + sf.h - marginBottom - wHeight
            if y > maxY then y = maxY end

            w:setFrame({
                x = x,
                y = y,
                w = wWidth,
                h = wHeight
            })
            w:raise()
        end

        -- Đảm bảo quay lại focus cửa sổ đang làm việc
        frontWin:focus()
    end)
end

-- Hotkey: Hyper + Down (Caps + ↓)
hs.hotkey.bind(hyper, "s", function()
    stackWindowsRightOfFocusedApp()
    hs.alert.show("Stack windows on right half")
end)

-------------------------------------------------
-- Hyper + G : mở panel Tags... trong Finder
-------------------------------------------------
-- Bind Hyper + T để mở Tags trong Finder
hs.hotkey.bind(hyper, "g", function()
  local finder = hs.appfinder.appFromName("Finder")
  if finder then
    -- Kích hoạt cửa sổ Finder trước
    finder:activate()
    
    -- Chọn menu File -> Tags...
    -- Lưu ý: Nếu macOS tiếng Việt, đổi "Tags..." thành "Thẻ..."
    -- Nếu macOS tiếng Anh, giữ nguyên "Tags..."
    finder:selectMenuItem({"File", "Tags..."}) 
  end
end)
-------------------------------------------------
-- Hyper + N : tạo file .txt nhanh trong Finder
-------------------------------------------------

local function createNewTextFile()
    local app = hs.application.frontmostApplication()
    if not app or app:name() ~= "Finder" then
        hs.alert.show("Không phải Finder")
        return
    end

    -- Lấy đường dẫn thư mục hiện tại bằng AppleScript
    local script = [[
        tell application "Finder"
            if (count of windows) = 0 then
                return POSIX path of (desktop as alias)
            else
                return POSIX path of (target of front window as alias)
            end if
        end tell
    ]]

    local ok, path = hs.osascript.applescript(script)
    if not ok or not path then
        hs.alert.show("Không lấy được thư mục")
        return
    end

    -- Tạo tên file tránh trùng
    local filename = "New File.txt"
    local fullpath = path .. filename

    local i = 1
    while hs.fs.attributes(fullpath) do
        filename = "New File " .. i .. ".txt"
        fullpath = path .. filename
        i = i + 1
    end

    -- Tạo file
    local file = io.open(fullpath, "w")
    if file then
        file:close()
    else
        hs.alert.show("Lỗi tạo file")
        return
    end

    -- Refresh Finder + chọn file mới để rename luôn
    hs.timer.doAfter(0.2, function()
        local revealScript = string.format([[
            tell application "Finder"
                reveal POSIX file "%s"
                activate
                delay 0.1
                tell application "System Events"
                    keystroke return
                end tell
            end tell
        ]], fullpath)

        hs.osascript.applescript(revealScript)
    end)
end

-- Hotkey: Hyper + N
hs.hotkey.bind(hyper, "N", function()
    createNewTextFile()
end)
---- 