-- Compact pure-Lua JSON encoder / decoder
local json = {}

-- ── ENCODER ────────────────────────────────────────────────────────────────

local escape_map = {
    ['"']  = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n',
    ['\r'] = '\\r', ['\t'] = '\\t',  ['\b'] = '\\b', ['\f'] = '\\f',
}

local function enc_string(s)
    return '"' .. s:gsub('[\\"/%c]', function(c)
        return escape_map[c] or ('\\u%04x'):format(c:byte())
    end) .. '"'
end

local function enc(v, seen)
    local t = type(v)
    if v == nil then
        return 'null'
    elseif t == 'boolean' then
        return v and 'true' or 'false'
    elseif t == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then return 'null' end
        return tostring(v)
    elseif t == 'string' then
        return enc_string(v)
    elseif t == 'table' then
        assert(not seen[v], 'circular reference')
        seen[v] = true
        local out
        -- treat as array only when it has a dense integer sequence from 1
        local n = #v
        local is_arr = n > 0
        if is_arr then
            for i = 1, n do if v[i] == nil then is_arr = false; break end end
        end
        if is_arr then
            local parts = {}
            for i = 1, n do parts[i] = enc(v[i], seen) end
            out = '[' .. table.concat(parts, ',') .. ']'
        else
            local parts = {}
            for k, val in pairs(v) do
                local ks = type(k) == 'number' and tostring(k) or k
                assert(type(ks) == 'string', 'object keys must be strings')
                parts[#parts + 1] = enc_string(ks) .. ':' .. enc(val, seen)
            end
            out = '{' .. table.concat(parts, ',') .. '}'
        end
        seen[v] = nil
        return out
    else
        error('cannot encode ' .. t)
    end
end

function json.encode(v) return enc(v, {}) end

-- ── DECODER ────────────────────────────────────────────────────────────────

function json.decode(src)
    local pos = 1

    local function err(msg)
        error(msg .. ' (pos ' .. pos .. ' near "' .. src:sub(pos, pos + 20) .. '")')
    end

    local function skip()
        local p = src:find('[^ \t\r\n]', pos)
        pos = p or (#src + 1)
    end

    local function eat(c)
        if src:sub(pos, pos) ~= c then err('expected ' .. c) end
        pos = pos + 1
    end

    local read_value

    local function read_string()
        eat('"')
        local parts = {}
        while pos <= #src do
            local c = src:sub(pos, pos)
            if c == '"' then pos = pos + 1; return table.concat(parts) end
            if c ~= '\\' then parts[#parts + 1] = c; pos = pos + 1
            else
                pos = pos + 1
                local e = src:sub(pos, pos); pos = pos + 1
                if     e == 'n' then parts[#parts+1] = '\n'
                elseif e == 'r' then parts[#parts+1] = '\r'
                elseif e == 't' then parts[#parts+1] = '\t'
                elseif e == 'b' then parts[#parts+1] = '\b'
                elseif e == 'f' then parts[#parts+1] = '\f'
                elseif e == 'u' then
                    local h = src:sub(pos, pos + 3); pos = pos + 4
                    local cp = tonumber(h, 16) or 0
                    if cp < 0x80 then
                        parts[#parts+1] = string.char(cp)
                    elseif cp < 0x800 then
                        parts[#parts+1] = string.char(0xC0 + math.floor(cp/64), 0x80 + cp%64)
                    else
                        parts[#parts+1] = string.char(
                            0xE0 + math.floor(cp/4096),
                            0x80 + math.floor((cp%4096)/64),
                            0x80 + cp%64)
                    end
                else parts[#parts+1] = e end
            end
        end
        err('unterminated string')
    end

    local function read_array()
        eat('['); skip()
        local arr = {}
        if src:sub(pos, pos) == ']' then pos = pos + 1; return arr end
        repeat
            skip(); arr[#arr + 1] = read_value(); skip()
            local c = src:sub(pos, pos)
            if c == ',' then pos = pos + 1
            elseif c == ']' then pos = pos + 1; return arr
            else err("expected ',' or ']'") end
        until false
    end

    local function read_object()
        eat('{'); skip()
        local obj = {}
        if src:sub(pos, pos) == '}' then pos = pos + 1; return obj end
        repeat
            skip(); local k = read_string(); skip()
            eat(':'); skip()
            obj[k] = read_value(); skip()
            local c = src:sub(pos, pos)
            if c == ',' then pos = pos + 1
            elseif c == '}' then pos = pos + 1; return obj
            else err("expected ',' or '}'") end
        until false
    end

    read_value = function()
        skip()
        local c = src:sub(pos, pos)
        if c == '"' then return read_string()
        elseif c == '[' then return read_array()
        elseif c == '{' then return read_object()
        elseif c == 't' then pos = pos + 4; return true
        elseif c == 'f' then pos = pos + 5; return false
        elseif c == 'n' then pos = pos + 4; return nil
        else
            local n = src:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
            if n then pos = pos + #n; return tonumber(n) end
            err("unexpected '" .. c .. "'")
        end
    end

    return read_value()
end

return json
