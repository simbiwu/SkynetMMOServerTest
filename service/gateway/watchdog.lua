-- 仓库路径：service/gateway/watchdog.lua
-- Watchdog 拥有未登录连接表和 Login 状态机。官方 Gate 负责 Socket 生命周期、
-- TCP Frame 拆包和登录后的 Packet Redirect；玩家数据由 PlayerAgent 持有。
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local frame = require "protocol.frame"

local CMD = {}       -- Main 等 Service 通过 "lua" Protocol 调用的管理命令。
local SOCKET = {}    -- Gate 通过 command="socket" 转发的连接事件处理函数。

local gate                  -- 官方 Gate Service Address。
local player_mgr            -- PlayerMgr Address，用于查找/创建 PlayerAgent。
local auth_service          -- 开发期 Auth Service Address。
local host                  -- 用 Slot 1 C2S Schema 创建的 Sproto RPC Host。
local connections = {}      -- key=fd，value=当前逻辑 Connection Table。
local next_connection_id = 0 -- 单调递增的进程内连接代际；不发送给 Client。

-- 为新连接分配逻辑代际。函数只修改 Watchdog 本地整数，不 yield。
local function new_connection_id()
    next_connection_id = next_connection_id + 1
    return next_connection_id
end

-- 检查 yield 前保存的 Connection Table 是否仍是 fd 当前绑定对象。
-- Table Identity 同时防止“旧连接关闭、fd 被新连接复用”的 ABA 问题。
local function alive(fd, connection)
    return connections[fd] == connection
end

-- 延迟 10 个 Skynet Tick（默认约 0.1 秒）再 Kick，让已经写入的拒绝
-- Response 有机会进入发送路径。
-- timeout Callback 是新的 coroutine；执行时必须重新按 fd + connection_id
-- 查询当前代际，不能捕获旧 Connection 后直接操作。
local function close_later(fd, connection_id)
    skynet.timeout(10, function()
        local connection = connections[fd]
        if connection and connection.id == connection_id then
            skynet.call(gate, "lua", "kick", fd)
        end
    end)
end

-- Gate 建立 TCP 连接后发送的 open 事件。
-- fd：Socket Descriptor；addr：对端地址文本。当前函数会 call Gate.accept，
-- 因而可能 yield；Connection 已在 yield 前写入表，Close 事件可以安全处理。
function SOCKET.open(fd, addr)
    local connection = {
        id = new_connection_id(), -- 逻辑代际，区别同一个整数 fd 的前后两次连接。
        fd = fd,                  -- Gate/Socket Runtime 使用的当前 Descriptor。
        addr = addr,              -- 对端地址文本，仅用于日志和诊断。
        state = "CONNECTED",      -- CONNECTED/AUTHING/PLAYING/CLOSING。
        agent = nil,              -- Login 创建并绑定的 PlayerAgent Address。
    }
    connections[fd] = connection

    skynet.error("[Watchdog] open fd=", fd,
        " conn=", connection.id, " addr=", addr)

    -- Gate 接受 Socket 后默认尚未读取 Client 数据；accept/openclient 后才开始。
    skynet.call(gate, "lua", "accept", fd)
end

-- 统一处理 Gate 的 close/error 事件。先删除连接表中的 Owner 记录，再用 send
-- 通知 Agent；Watchdog 不等待 Agent 的下线清理完成。
local function on_close(fd)
    local connection = connections[fd]
    if not connection then
        return
    end

    connections[fd] = nil
    if connection.agent then
        skynet.send(connection.agent, "lua", "client_closed",
            fd, connection.id)
    end

    skynet.error("[Watchdog] close fd=", fd,
        " conn=", connection.id)
end

-- 正常断开事件。
function SOCKET.close(fd)
    on_close(fd)
end

-- 异常断开事件；msg 是 Gate 提供的 Socket Error 文本。
function SOCKET.error(fd, msg)
    skynet.error("[Watchdog] socket error fd=", fd, " msg=", msg)
    on_close(fd)
end

-- Gate 发送缓冲区积压告警；size 单位由 Gate 定义为 KB。
-- 当前只记录日志，生产实现还应接入 Metric、限流和慢连接处置。
function SOCKET.warning(fd, size)
    skynet.error("[Watchdog] send buffer warning fd=", fd,
        " size_kb=", size)
end

-- 仓库路径：service/gateway/watchdog.lua
-- Watchdog 拥有未登录连接表和 Login 状态机。官方 Gate 负责 Socket 生命周期、
-- TCP Frame 拆包和登录后的 Packet Redirect；玩家数据由 PlayerAgent 持有。
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local frame = require "protocol.frame"

local CMD = {}       -- Main 等 Service 通过 "lua" Protocol 调用的管理命令。
local SOCKET = {}    -- Gate 通过 command="socket" 转发的连接事件处理函数。

local gate                  -- 官方 Gate Service Address。
local player_mgr            -- PlayerMgr Address，用于查找/创建 PlayerAgent。
local auth_service          -- 开发期 Auth Service Address。
local host                  -- 用 Slot 1 C2S Schema 创建的 Sproto RPC Host。
local connections = {}      -- key=fd，value=当前逻辑 Connection Table。
local next_connection_id = 0 -- 单调递增的进程内连接代际；不发送给 Client。

-- 为新连接分配逻辑代际。函数只修改 Watchdog 本地整数，不 yield。
local function new_connection_id()
    next_connection_id = next_connection_id + 1
    return next_connection_id
end

-- 检查 yield 前保存的 Connection Table 是否仍是 fd 当前绑定对象。
-- Table Identity 同时防止“旧连接关闭、fd 被新连接复用”的 ABA 问题。
local function alive(fd, connection)
    return connections[fd] == connection
end

-- 延迟 10 个 Skynet Tick（默认约 0.1 秒）再 Kick，让已经写入的拒绝
-- Response 有机会进入发送路径。
-- timeout Callback 是新的 coroutine；执行时必须重新按 fd + connection_id
-- 查询当前代际，不能捕获旧 Connection 后直接操作。
local function close_later(fd, connection_id)
    skynet.timeout(10, function()
        local connection = connections[fd]
        if connection and connection.id == connection_id then
            skynet.call(gate, "lua", "kick", fd)
        end
    end)
end

-- Gate 建立 TCP 连接后发送的 open 事件。
-- fd：Socket Descriptor；addr：对端地址文本。当前函数会 call Gate.accept，
-- 因而可能 yield；Connection 已在 yield 前写入表，Close 事件可以安全处理。
function SOCKET.open(fd, addr)
    local connection = {
        id = new_connection_id(), -- 逻辑代际，区别同一个整数 fd 的前后两次连接。
        fd = fd,                  -- Gate/Socket Runtime 使用的当前 Descriptor。
        addr = addr,              -- 对端地址文本，仅用于日志和诊断。
        state = "CONNECTED",      -- CONNECTED/AUTHING/PLAYING/CLOSING。
        agent = nil,              -- Login 创建并绑定的 PlayerAgent Address。
    }
    connections[fd] = connection

    skynet.error("[Watchdog] open fd=", fd,
        " conn=", connection.id, " addr=", addr)

    -- Gate 接受 Socket 后默认尚未读取 Client 数据；accept/openclient 后才开始。
    skynet.call(gate, "lua", "accept", fd)
end

-- 统一处理 Gate 的 close/error 事件。先删除连接表中的 Owner 记录，再用 send
-- 通知 Agent；Watchdog 不等待 Agent 的下线清理完成。
local function on_close(fd)
    local connection = connections[fd]
    if not connection then
        return
    end

    connections[fd] = nil
    if connection.agent then
        skynet.send(connection.agent, "lua", "client_closed",
            fd, connection.id)
    end

    skynet.error("[Watchdog] close fd=", fd,
        " conn=", connection.id)
end

-- 正常断开事件。
function SOCKET.close(fd)
    on_close(fd)
end

-- 异常断开事件；msg 是 Gate 提供的 Socket Error 文本。
function SOCKET.error(fd, msg)
    skynet.error("[Watchdog] socket error fd=", fd, " msg=", msg)
    on_close(fd)
end

-- Gate 发送缓冲区积压告警；size 单位由 Gate 定义为 KB。
-- 当前只记录日志，生产实现还应接入 Metric、限流和慢连接处置。
function SOCKET.warning(fd, size)
    skynet.error("[Watchdog] send buffer warning fd=", fd,
        " size_kb=", size)
end

-- 处理未登录连接的一帧完整 Sproto Payload。
-- 参数 msg 已由 Gate 去掉 2-byte Length Prefix。
-- 本函数依次 call Auth、PlayerMgr、PlayerAgent 和 Gate，每次都会 yield；
-- 每个恢复点都必须用 alive 检查 fd 当前仍绑定同一个 Connection Table。
function SOCKET.data(fd, msg)
    local connection = connections[fd]
    if not connection or connection.state ~= "CONNECTED" then
        return
    end

    -- pcall 隔离畸形 Payload 的 Decoder Error。dispatch_ok 表示解码是否成功；
    -- protocol_type/name 应为 "REQUEST"/"login"；args 是 Login Request Table；
    -- response 是绑定本次 Sproto session 的 Encoder Closure。
    local dispatch_ok, protocol_type, name, args, response = pcall(function()
        return host:dispatch(msg)
    end)
    if not dispatch_ok or protocol_type ~= "REQUEST" or name ~= "login" then
        skynet.error("[Watchdog] first packet must be login fd=", fd)
        connection.state = "CLOSING"
        close_later(fd, connection.id)
        return
    end

    -- 必须在第一个 yield 前改变状态。否则处理 Auth 时，第二个 Packet 可能
    -- 进入另一个 data coroutine，再次开始 Login。
    connection.state = "AUTHING"

    local player_id = math.tointeger(args.player_id) -- 拒绝非整数 ID。
    local token = args.token                         -- 第一课开发 Token String。
    local auth_ok = player_id
        and skynet.call(auth_service, "lua", "verify", player_id, token)

    -- skynet.call 期间 Socket 可能已经关闭，恢复后不能继续使用旧 connection。
    if not alive(fd, connection) then
        return
    end

    if not auth_ok then
        if response then
            frame.write(fd, response {
                code = 1,
                message = "AUTH_FAILED",
            })
        end
        connection.state = "CLOSING"
        close_later(fd, connection.id)
        return
    end

    -- PlayerMgr 返回 Agent Address、是否本次创建，以及可选 Load Error。
    local agent, is_new, load_error = skynet.call(
        player_mgr, "lua", "login", player_id)

    if not alive(fd, connection) then
        if is_new and agent then
            skynet.send(agent, "lua", "abort_if_unbound")
        end
        return
    end

    if not agent then
        if response then
            frame.write(fd, response {
                code = 2,
                message = load_error or "LOAD_PLAYER_FAILED",
            })
        end
        connection.state = "CLOSING"
        close_later(fd, connection.id)
        return
    end

    -- 先记录 Agent，保证 bind call 等待期间发生 Close 时能通知它清理。
    connection.agent = agent
    -- bind_ok 表示 Agent 是否接受连接；成功时 player_info 是 Login Snapshot，
    -- 失败时第二个返回值是 Error Code String。
    local bind_ok, player_info = skynet.call(agent, "lua", "bind_client", {
        fd = fd,
        connection_id = connection.id,
    })

    if not alive(fd, connection) then
        return
    end

    if not bind_ok then
        connection.agent = nil
        if response then
            frame.write(fd, response {
                code = 3,
                message = player_info or "BIND_FAILED",
            })
        end
        connection.state = "CLOSING"
        close_later(fd, connection.id)
        return
    end

    -- future Client Packet 不再绕行 Watchdog，而是由 Gate 直接 redirect 到 Agent。
    skynet.call(gate, "lua", "forward", fd, 0, agent)
    if not alive(fd, connection) then
        return
    end
    connection.state = "PLAYING"

    if response then
        -- response(...) 只编码 Sproto Payload；frame.write 再增加 TCP Length。
        frame.write(fd, response {
            code = 0,
            message = "OK",
            player_id = player_info.player_id,
            name = player_info.name,
            level = player_info.level,
            gold = player_info.gold,
        })
    end

    skynet.error("[Watchdog] login success player=", player_id,
        " fd=", fd, " agent=", skynet.address(agent))
end

-- 由 Main 调用一次，注入依赖并创建官方 Gate。
-- conf 包含监听地址、端口、连接上限及 PlayerMgr/Auth Address。
-- 返回 Gate.open 的 address,port；newservice 与 call 都会 yield。
function CMD.start(conf)
    player_mgr = assert(conf.player_mgr)
    auth_service = assert(conf.auth_service)

    gate = skynet.newservice("gate")
    return skynet.call(gate, "lua", "open", {
        address = conf.address,
        port = conf.port,
        maxclient = conf.maxclient,
        nodelay = true,
        watchdog = skynet.self(),
    })
end


skynet.start(function()
    -- ProtocolLoader 必须已经保存 Slot 1；Host 用于解码 Client Request。
    host = sprotoloader.load(1):host "package"

    --  Gate 事件与普通管理命令共用 "lua" Dispatcher：
    --   command="socket" 时，subcommand 是 open/data/close/error/warning；
    --   其他 command 通过 CMD 分发，subcommand 实际是该命令的第一个参数。
    skynet.dispatch("lua", function(session, source, command, subcommand, ...)
        if command == "socket" then
            local fn = assert(SOCKET[subcommand],
                "unknown socket event: " .. tostring(subcommand))
            fn(...)
            return
        end

        local fn = assert(CMD[command],
            "unknown watchdog command: " .. tostring(command))
        local result = { fn(subcommand, ...) }
        if session ~= 0 then
            skynet.retpack(table.unpack(result))
        end
    end)
end)