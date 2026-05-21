-- Non-blocking interface between the main thread and llm/worker.lua.
-- Call client.update() every frame to drain the response channel.
local cfg    = require("config").llm
local client = {}

local worker
local req_ch, res_ch

local next_id      = 1
local health_state = nil   -- nil=unknown, true=ok, false=failed
local chat_queue   = {}    -- pending chat responses (table of {id, content, error})
local busy         = false -- one in-flight chat at a time

function client.init()
    print("[client] initialising worker thread")
    req_ch = love.thread.getChannel("llm_req")
    res_ch = love.thread.getChannel("llm_res")
    worker = love.thread.newThread("llm/worker.lua")
    worker:start()
    req_ch:push({ type = "noop", port = cfg.port })
    print("[client] worker started, port=" .. cfg.port)
end

-- Drain the response channel; call once per frame.
function client.update()
    while res_ch:getCount() > 0 do
        local msg = res_ch:pop()
        if msg then
            print("[client] received: type=" .. tostring(msg.type) .. " ok=" .. tostring(msg.ok) .. " error=" .. tostring(msg.error))
            if msg.type == "health" then
                health_state = msg.ok
            elseif msg.type == "chat" then
                busy = false
                chat_queue[#chat_queue + 1] = msg
            end
        end
    end
end

-- Request a health check. Result available via client.pollHealth().
function client.checkHealth()
    print("[client] sending health check")
    health_state = nil
    req_ch:push({ type = "health", port = cfg.port })
end

-- Returns true/false/nil (nil = no answer yet).
-- Consuming: clears the stored result after reading.
function client.pollHealth()
    local v = health_state
    if v ~= nil then health_state = nil end
    return v
end

-- Send a chat request. Returns false if another request is in flight.
-- messages = array of {role, content} following the OpenAI schema.
function client.sendChat(messages)
    if busy then return false end
    busy = true
    req_ch:push({
        type        = "chat",
        port        = cfg.port,
        id          = next_id,
        messages    = messages,
        temperature = cfg.temperature,
        max_tokens  = cfg.max_tokens,
    })
    next_id = next_id + 1
    return true
end

-- Returns the next completed chat response or nil.
-- Shape: { id=N, content="...", error="..." }
function client.pollResponse()
    return table.remove(chat_queue, 1)
end

-- Returns a thread error string if the worker crashed, else nil.
function client.getError()
    if worker and not worker:isRunning() then
        local err = worker:getError()
        if err then print("[client] worker thread error: " .. err) end
        return err
    end
end

function client.shutdown()
    if req_ch then req_ch:push({ type = "quit" }) end
end

return client
