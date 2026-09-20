local skynet = require "skynet"

local CMD = {}

function CMD.verify(player_id, token)
    if not math.tointeger(player_id) then
        return false
    end

    return token == "dev"..tostring(player_id)
end

skynet.start(function ()
    skynet.dispatch("lua", function(session, source, command, ...)
        local fn = assert(CMD[command],
            "unknown auth command: " .. tostring(command))
        local result = { fn(...) }
        if session ~= 0 then
            skynet.retpack(table.unpack(result))
        end
    end)
end)