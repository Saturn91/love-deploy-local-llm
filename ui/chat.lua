-- Chat UI: message history + text input.
local client = require("llm.client")
local cfg    = require("config").llm
local chat   = {}

local PAD        = 16
local INPUT_H    = 56
local LINE_GAP   = 6
local CURSOR_HZ  = 1.5   -- blink frequency

local font, font_sm
local messages   = {}   -- { role="user"|"assistant"|"system", content="..." }
local input_text = ""
local scroll_y   = 0
local is_waiting = false

-- colours
local C = {
    bg       = { 0.10, 0.10, 0.12 },
    bg_input = { 0.14, 0.14, 0.18 },
    border   = { 0.28, 0.28, 0.38 },
    user     = { 0.45, 0.82, 1.00 },
    ai       = { 0.60, 1.00, 0.55 },
    system   = { 0.55, 0.55, 0.65 },
    input    = { 0.90, 0.90, 0.95 },
    dim      = { 0.40, 0.40, 0.50 },
}

function chat.init()
    font    = love.graphics.newFont(15)
    font_sm = love.graphics.newFont(12)

    -- seed with optional system prompt
    if cfg.system_prompt and cfg.system_prompt ~= "" then
        messages[#messages + 1] = { role = "system", content = "System: " .. cfg.system_prompt }
    end
    messages[#messages + 1] = { role = "system", content = "Connected. Type a message and press Enter." }
end

function chat.addMessage(role, content)
    messages[#messages + 1] = { role = role, content = content }
    scroll_y = math.huge  -- auto-scroll to bottom
end

function chat.setWaiting(v)
    is_waiting = v
end

function chat.update(dt)
    -- nothing yet; extend here for animations
end

-- ── draw ─────────────────────────────────────────────────────────────────────

local function set_color(t) love.graphics.setColor(t[1], t[2], t[3]) end

local function msg_color(role)
    if role == "user" then return C.user
    elseif role == "assistant" then return C.ai
    else return C.system end
end

local function msg_prefix(role)
    if role == "user" then return "You:  "
    elseif role == "assistant" then return "AI:   "
    else return "      " end
end

function chat.draw()
    local W, H = love.graphics.getDimensions()
    local chat_h = H - INPUT_H - 1
    local text_w = W - PAD * 2

    -- ── measure content height ────────────────────────────────────────────
    love.graphics.setFont(font)
    local lh = font:getHeight() * font:getLineHeight()
    local content_h = PAD

    for _, m in ipairs(messages) do
        local text = msg_prefix(m.role) .. m.content
        local _, lines = font:getWrap(text, text_w)
        content_h = content_h + #lines * lh + LINE_GAP
    end
    if is_waiting then content_h = content_h + lh + LINE_GAP end
    content_h = content_h + PAD

    -- clamp scroll
    local max_scroll = math.max(0, content_h - chat_h)
    if scroll_y == math.huge then
        scroll_y = max_scroll
    else
        scroll_y = math.min(scroll_y, max_scroll)
        scroll_y = math.max(scroll_y, 0)
    end

    -- ── message area ──────────────────────────────────────────────────────
    set_color(C.bg)
    love.graphics.rectangle("fill", 0, 0, W, chat_h)

    love.graphics.setScissor(0, 0, W, chat_h)
    love.graphics.push()
    love.graphics.translate(0, PAD - scroll_y)

    local y = 0
    for _, m in ipairs(messages) do
        set_color(msg_color(m.role))
        local text = msg_prefix(m.role) .. m.content
        local _, lines = font:getWrap(text, text_w)
        love.graphics.printf(text, PAD, y, text_w, "left")
        y = y + #lines * lh + LINE_GAP
    end

    if is_waiting then
        local dots = ("."):rep(math.floor(love.timer.getTime() * 2.5) % 4)
        set_color(C.ai)
        love.graphics.print("AI:   thinking" .. dots, PAD, y)
    end

    love.graphics.pop()
    love.graphics.setScissor()

    -- ── separator ─────────────────────────────────────────────────────────
    set_color(C.border)
    love.graphics.rectangle("fill", 0, chat_h, W, 1)

    -- ── input bar ─────────────────────────────────────────────────────────
    set_color(C.bg_input)
    love.graphics.rectangle("fill", 0, chat_h + 1, W, INPUT_H)

    -- input box
    local box_x = PAD
    local box_y = chat_h + 1 + math.floor((INPUT_H - 32) / 2)
    local box_w = W - PAD * 2 - 70

    set_color(C.border)
    love.graphics.rectangle("line", box_x, box_y, box_w, 32, 4)

    -- cursor blink
    local show_cursor = math.floor(love.timer.getTime() * CURSOR_HZ * 2) % 2 == 0
    local display = input_text .. (show_cursor and "|" or "")

    love.graphics.setScissor(box_x + 6, box_y, box_w - 10, 32)
    set_color(is_waiting and C.dim or C.input)
    love.graphics.print(display, box_x + 8, box_y + 8)
    love.graphics.setScissor()

    -- send hint
    set_color(C.dim)
    love.graphics.setFont(font_sm)
    love.graphics.print("Enter", W - PAD - 56, box_y + 10)
    love.graphics.setFont(font)

    -- scroll hint
    if max_scroll > 0 then
        set_color(C.dim)
        love.graphics.setFont(font_sm)
        love.graphics.print("scroll: wheel", PAD, chat_h + 1 + INPUT_H - 18)
        love.graphics.setFont(font)
    end
end

-- ── input handling ────────────────────────────────────────────────────────────

function chat.keypressed(key)
    if key == "return" or key == "kpenter" then
        chat.submit()
    elseif key == "backspace" then
        if #input_text > 0 then
            local byte = utf8.offset(input_text, -1)
            if byte then input_text = input_text:sub(1, byte - 1) end
        end
    elseif key == "up" then
        scroll_y = scroll_y - 60
    elseif key == "down" then
        scroll_y = scroll_y + 60
    end
end

function chat.textinput(t)
    if not is_waiting then input_text = input_text .. t end
end

function chat.wheelmoved(x, y)
    scroll_y = scroll_y - y * 50
end

function chat.submit()
    local text = input_text:match("^%s*(.-)%s*$")
    if text == "" or is_waiting then return end

    chat.addMessage("user", text)
    input_text = ""
    is_waiting = true

    -- Build API messages (exclude system-display entries)
    local api = {}
    if cfg.system_prompt and cfg.system_prompt ~= "" then
        api[#api + 1] = { role = "system", content = cfg.system_prompt }
    end
    for _, m in ipairs(messages) do
        if m.role == "user" or m.role == "assistant" then
            api[#api + 1] = { role = m.role, content = m.content }
        end
    end

    client.sendChat(api)
end

return chat
