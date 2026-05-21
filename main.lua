local VERSION_ID = "0.1.0"

local client = require("llm.client")
local server = require("llm.server")
local chat   = require("ui.chat")
local cfg    = require("config").llm

-- States: "starting" → "connecting" → "ready" / "error"
local state        = "starting"
local error_msg    = ""
local conn_timer   = 0
local CONN_TIMEOUT = 30
local health_tick  = 0
local HEALTH_EVERY = 1.0

local font_title, font_body, font_hint

-- ── helpers ──────────────────────────────────────────────────────────────────

local function set_state_error(msg)
    state     = "error"
    error_msg = msg
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────

function love.load()
    font_title = love.graphics.newFont(22)
    font_body  = love.graphics.newFont(15)
    font_hint  = love.graphics.newFont(12)

    client.init()
    chat.init()

    local ok, err = server.launch()
    if not ok then
        -- If launch failed but server might already be running, still try to connect.
        print("[server] " .. (err or "launch failed") .. " – will attempt connection anyway")
    end

    state = "connecting"
end

function love.update(dt)
    -- Always drain the response channel
    client.update()

    -- Check worker thread health
    local thread_err = client.getError()
    if thread_err and state ~= "error" then
        set_state_error("Worker thread crashed:\n" .. thread_err)
        return
    end

    if state == "connecting" then
        conn_timer  = conn_timer  + dt
        health_tick = health_tick + dt

        if conn_timer >= CONN_TIMEOUT then
            set_state_error(
                ("Timed out after %ds waiting for llama-server.\n\n"
                 .. "Make sure llama-server.exe and %s are\n"
                 .. "in the same folder as the game exe."):format(CONN_TIMEOUT, cfg.model_file)
            )
            return
        end

        if health_tick >= HEALTH_EVERY then
            health_tick = 0
            client.checkHealth()
        end

        local ok = client.pollHealth()
        if ok == true then
            state = "ready"
        end

    elseif state == "ready" then
        chat.update(dt)

        local resp = client.pollResponse()
        if resp then
            if resp.error then
                chat.addMessage("system", "Error: " .. resp.error)
            else
                chat.addMessage("assistant", resp.content)
            end
            chat.setWaiting(false)
        end
    end
end

-- ── drawing ───────────────────────────────────────────────────────────────────

local function draw_connecting()
    local W, H = love.graphics.getDimensions()
    local t    = love.timer.getTime()
    local dots = ("."):rep(math.floor(t * 2) % 4)

    love.graphics.setFont(font_title)
    love.graphics.setColor(0.8, 0.8, 0.85)
    love.graphics.printf("Starting llama-server" .. dots, 0, H/2 - 36, W, "center")

    love.graphics.setFont(font_body)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf(
        ("%.0f / %ds"):format(conn_timer, CONN_TIMEOUT),
        0, H/2 + 4, W, "center"
    )
    love.graphics.printf(
        "Ensure llama-server.exe and " .. cfg.model_file .. "\nare next to the game exe.",
        20, H/2 + 34, W - 40, "center"
    )
end

local function draw_error()
    local W, H = love.graphics.getDimensions()
    love.graphics.setFont(font_title)
    love.graphics.setColor(0.95, 0.35, 0.35)
    love.graphics.printf("Error", 0, H/2 - 56, W, "center")

    love.graphics.setFont(font_body)
    love.graphics.setColor(0.85, 0.85, 0.85)
    love.graphics.printf(error_msg, 30, H/2 - 10, W - 60, "center")

    love.graphics.setFont(font_hint)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Press Escape to quit.", 0, H/2 + 90, W, "center")
end

function love.draw()
    love.graphics.clear(0.10, 0.10, 0.12)

    if state == "starting" or state == "connecting" then
        draw_connecting()
    elseif state == "ready" then
        chat.draw()
    elseif state == "error" then
        draw_error()
    end
end

-- ── input ─────────────────────────────────────────────────────────────────────

function love.keypressed(key)
    if key == "escape" then love.event.quit(); return end
    if state == "ready" then chat.keypressed(key) end
end

function love.textinput(t)
    if state == "ready" then chat.textinput(t) end
end

function love.wheelmoved(x, y)
    if state == "ready" then chat.wheelmoved(x, y) end
end

function love.quit()
    client.shutdown()
    server.stop()
end
