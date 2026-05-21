-- Love2D worker thread: handles all blocking HTTP I/O with llama-server.
-- Communicates with the main thread via named channels:
--   "llm_req"  (main → worker)
--   "llm_res"  (worker → main)
--
-- Message shapes:
--   request:  { type="health" }
--             { type="chat", messages={...}, id=N, temperature=T, max_tokens=M }
--             { type="quit" }
--   response: { type="health", ok=true/false, error="..." }
--             { type="chat",   id=N, content="...", error="..." }

print("[worker] starting, loading libraries...")
local http  = require("socket.http")
local ltn12 = require("ltn12")
local json  = require("lib.json")
print("[worker] libraries loaded")

local req_ch = love.thread.getChannel("llm_req")
local res_ch = love.thread.getChannel("llm_res")

local BASE_URL = "http://127.0.0.1:8080"  -- overridden by message.port

local function do_get(path)
    local body = {}
    local ok, code = http.request({
        url    = BASE_URL .. path,
        method = "GET",
        sink   = ltn12.sink.table(body),
    })
    if not ok then return nil, tostring(code) end
    if code ~= 200 then return nil, "HTTP " .. code end
    return table.concat(body)
end

local function do_post(path, payload)
    local body = {}
    local ok, code = http.request({
        url     = BASE_URL .. path,
        method  = "POST",
        headers = {
            ["Content-Type"]   = "application/json",
            ["Content-Length"] = tostring(#payload),
        },
        source = ltn12.source.string(payload),
        sink   = ltn12.sink.table(body),
    })
    if not ok then return nil, tostring(code) end
    if code ~= 200 then return nil, "HTTP " .. code .. ": " .. table.concat(body) end
    return table.concat(body)
end

-- Main loop
while true do
    local msg = req_ch:demand()

    if msg.port then
        BASE_URL = "http://127.0.0.1:" .. msg.port
    end

    if msg.type == "quit" then
        break

    elseif msg.type == "health" then
        print("[worker] health check -> " .. BASE_URL .. "/health")
        local raw, err = do_get("/health")
        if raw then
            print("[worker] health OK: " .. raw)
            res_ch:push({ type = "health", ok = true })
        else
            print("[worker] health FAIL: " .. tostring(err))
            res_ch:push({ type = "health", ok = false, error = err })
        end

    elseif msg.type == "chat" then
        local payload = json.encode({
            model       = "local",
            messages    = msg.messages,
            stream      = false,
            temperature = msg.temperature or 0.7,
            max_tokens  = msg.max_tokens  or 512,
        })
        local raw, err = do_post("/v1/chat/completions", payload)
        if raw then
            local ok, decoded = pcall(json.decode, raw)
            if ok and decoded and decoded.choices and decoded.choices[1] then
                res_ch:push({
                    type    = "chat",
                    id      = msg.id,
                    content = decoded.choices[1].message.content,
                })
            else
                res_ch:push({ type = "chat", id = msg.id, error = "bad response: " .. raw:sub(1, 120) })
            end
        else
            res_ch:push({ type = "chat", id = msg.id, error = err or "request failed" })
        end
    end
end
