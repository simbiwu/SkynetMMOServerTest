local skynet = require "skynet"

local CMD = {}

local STATE_LOADING = "LOADING"
local STATE_LOADED = "LOADED"
local STATE_ONLINE = "ONLINE"
local STATE_CLOSING = "CLOSING"

local state = STATE_LOADING
local player
local storage_mgr
local player_mgr
local client_fd
local client_connection_id

local function login_info()
    return
    {
        player_id = player.player_id,
        name = player.name,
        level = player.level,
        gold = player.gold,
    }
end

function CMD.load(conf)
    assert(state == STATE_LOADING, "player agent already loaded")

    storage_mgr = assert(conf.storage_mgr)
    player_mgr = assert(conf.player_mgr)

    local ok, result = skynet.call(storage_mgr, "lua", "load_player", conf.playerid) 
    if not ok then
        return false, result
    end

    player = result
    state = STATE_LOADED
    skynet.error("[PlayerAgent] loaded player=", player.player_id)
    return true
end

function CMD.bind_client(conf)
    if state == STATE_ONLINE then
        return false, "ALREADY_ONLINE"
    end
    if state ~= STATE_LOADED then
        return false, "INVALID_AGENT_STATE"
    end

    client_fd = assert(conf.fd)
    client_connection_id = assert(conf.connection_id)
    state = STATE_ONLINE

    return true, login_info()
end

-- 处理 Watchdog 发来的连接关闭通知。
-- 参数必须同时匹配 fd 与 connection_id，才能作用于当前连接。
-- remove 使用 skynet.call，会 yield；发起前先提交 CLOSING 并清空绑定，
-- 防止等待期间继续接受旧连接操作。
function CMD.client_closed(fd, connection_id)
    -- fd 会被 OS 复用；fd 与逻辑 connection_id 同时匹配，才能关闭当前绑定。
    if fd ~= client_fd or connection_id ~= client_connection_id then
        return false
    end

    state = STATE_CLOSING
    client_fd = nil
    client_connection_id = nil

    -- player_id 在 yield 前复制到局部值；player 仍由 Agent 持有。
    local player_id = player.player_id
    skynet.call(player_mgr, "lua", "remove", player_id, skynet.self())

    -- call 恢复后当前 Agent 已不在 PlayerMgr 路由中，可以安全注销 Service。
    skynet.error("[PlayerAgent] offline player=", player_id)
    skynet.exit()
end

-- 清理“创建成功但 Socket 已断开、尚未完成 Bind”的 Agent。
-- Watchdog 只用 send 通知，所以调用方不等待返回；本函数内部 remove 会 yield。
function CMD.abort_if_unbound()
    if state == STATE_ONLINE then
        return false
    end

    state = STATE_CLOSING
    local player_id = player and player.player_id
    if player_id then
        skynet.call(player_mgr, "lua", "remove", player_id, skynet.self())
    end
    skynet.exit()
end

-- PlayerMgr 在 Load 失败时用 send 请求退出。当前没有持久状态需要提交。
function CMD.shutdown()
    skynet.exit()
end

skynet.register_protocol(
{
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function(msg, sz)
        return skynet.tostring(msg, sz)
    end,
    dispatch = function(fd, source, payload)
        skynet.ignoreret()
        if fd ~= client_fd then
            skynet.error("[PlayerAgent] stale client packet fd=", fd)
            return
        end
        skynet.error("[PlayerAgent] post-login packet is not implemented size=", #payload)
    end,
})

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local fn = assert(CMD[command],"unknown player agent command: " .. tostring(command))
        local result = {fn(...)}
        if session ~= 0 then
            skynet.retpack(table.unpack(result))
        end
    end)
end)