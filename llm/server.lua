-- Manages the llama-server.exe subprocess lifecycle.
-- Windows-only (ships alongside the fused game exe).
local cfg    = require("config").llm
local server = {}

local launched = false

local function base_dir()
    local source = love.filesystem.getSource()
    -- Fused exe: source is the .exe path → strip filename to get containing folder.
    -- Dev mode (love .): source is the game directory itself.
    if source:match("[/\\][^/\\]+%.exe$") or source:match("[/\\][^/\\]+%.love$") then
        return source:match("^(.*[/\\])") or "."
    end
    return source
end

function server.launch()
    local dir     = base_dir()
    local sep     = dir:sub(-1) == "\\" and "" or "\\"
    local runtime = dir .. sep .. (cfg.runtime_dir or "ollama")
    local srv     = runtime .. "\\llama-server.exe"
    local model   = dir .. sep .. cfg.model_file

    print("[server] base_dir  = " .. dir)
    print("[server] runtime   = " .. runtime)
    print("[server] server    = " .. srv)
    print("[server] model     = " .. model)

    local fs = io.open(srv, "rb")
    if not fs then
        print("[server] ERROR: llama-server.exe not found")
        return false, "llama-server.exe not found at:\n" .. srv
    end
    fs:close()
    print("[server] llama-server.exe found OK")

    local fm = io.open(model, "rb")
    if not fm then
        print("[server] ERROR: model file not found")
        return false, cfg.model_file .. " not found at:\n" .. model
    end
    fm:close()
    print("[server] model file found OK")

    local cmd = ('start /B "" "%s" --model "%s" --port %d --ctx-size %d > NUL 2>&1'):format(
        srv, model, cfg.port, cfg.context_size
    )
    print("[server] launch cmd: " .. cmd)
    os.execute(cmd)
    launched = true
    print("[server] process launched")
    return true
end

function server.stop()
    if launched then
        os.execute("taskkill /F /IM llama-server.exe >NUL 2>&1")
        launched = false
    end
end

return server
