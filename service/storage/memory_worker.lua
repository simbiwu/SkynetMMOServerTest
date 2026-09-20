local skynet = require "skynet"
local CMD = {}
local players = {}

local function clone_player(p)
    if not p then
        return nil
    end

     return {
        player_id = p.player_id,
        name = p.name,
        level = p.level,
        gold = p.gold,
    }
end

function CMD.start(conf, worker_index)
    local seed =
    {
        [10001] = {
            player_id = 10001,
            name = "Knight10001",
            level = 10,
            gold = 10000,
        },
        [10002] = {
            player_id = 10002,
            name = "Mage10002",
            level = 8,
            gold = 8000,
        },
    }

    for player_id, player in pairs(seed) do
         if (player_id % conf.pool) + 1 == worker_index then
            players[player_id] = clone_player(player)
        end
    end

    skynet.error("[MemoryWorker] started index=", worker_index)
    return true
end

function CMD.load_player(palyer_id)
    local player = players[palyer_id]
    if not player then
        return false, "PLAYER_NOT_FOUND"
    end

    return true, clone_player(player)
end

function CMD.save_player(player)
    players[player.player_id] = clone_player(player)
    return true
end

skynet.start(function ()
    skynet.dispatch("lua", function(session, source, command, ...)
        local fn = assert(CMD[command], "unknown memory command: " .. tostring(command))
        local result = {fn(...)}
        if session ~= 0 then
            skynet.retpack(table.unpack(result))
        end
    end)

    
end)