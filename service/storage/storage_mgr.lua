local skynet = require "skynet"

local CMD = {}
local workers = {}

local function get_worker(player_id)
    assert(#workers > 0, "storage pool is not started")
    return workers[(player_id % #workers) + 1]
end

function CMD.start(conf)
    assert(conf.pool and conf.pool > 0, "storage pool must be > 0")

    for index = 1, conf.pool do
        local worker = skynet.newservice("storage/memory_worker")
        skynet.call(worker, "lua", "start", conf, index)
        workers[index] = worker
    end

    skynet.error("[StorageMgr] workers=", #workers)
    return true
end

function CMD.load_player(player_id)
    return skynet.call(get_worker(player_id), "lua", "load_player", player_id)
end

function CMD.save_player(player)
    return skynet.call(get_worker(player.player_id), "lua", "save_player", player)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local fn = assert(CMD[command],
            "unknown storage manager command: " .. tostring(command))
        local result = { fn(...) }
        if session ~= 0 then
            skynet.retpack(table.unpack(result))
        end
    end)
end)