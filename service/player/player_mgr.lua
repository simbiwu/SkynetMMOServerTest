-- 仓库路径：service/player/player_mgr.lua
-- PlayerMgr 是 PlayerAgent 的生命周期与路由 Owner。它只保存
-- player_id -> Agent Address，不持有玩家业务数据，也不转发登录后的高频 Packet。
local skynet = require "skynet"
local queue = require "skynet.queue"

-- Service 间 Lua Protocol 的命令表；接口已在上一节协作表中固定。
local CMD = {}
local players = {}       -- key=player_id，value=当前有效 PlayerAgent Address。
local login_locks = {}   -- 固定 64 个分片 Queue，串行化同分片的创建流程。
local storage_mgr        -- StorageMgr Address，由 Main 在 CMD.init 中注入。

for index = 1, 64 do
    login_locks[index] = queue()-- body
end

-- 返回指定玩家使用的 Queue Closure。Hash 冲突只会让不同玩家创建阶段互相
-- 等待，不会混淆玩家状态；函数本身不 yield。
local function player_lock(player_id)
    return login_locks[(player_id % #login_locks) + 1]
end

-- 注入下游依赖。Main 只调用一次；返回 true 作为启动确认。
function CMD.init(conf)
    storage_mgr = conf.storage_mgr
    return true
end

-- 查找或创建指定玩家的唯一 Agent。
-- 返回：existing,false；或 new_agent,true；加载失败为 nil,false,error_code。
-- Queue 保护范围包含查表、newservice、Agent.load 和发布路由。内部两个调用
-- 都可能 yield；Queue 保证同一分片的第二个 Login 不会越过当前临界区。
function CMD.login(player_id)
    local existing = players[player_id]
    if existing then
        return existing, false
    end

    local agent = skynet.newservice("player/player_agent")
    local ok, err = skynet.call(agent, "lua", "load",  {
            player_id = player_id,
            storage_mgr = storage_mgr,
            player_mgr = skynet.self(),
        })

        if not ok then
            -- 发送退出通知即可；调用方当前只需得到 Load Error，不等待 Agent 销毁。
            skynet.send(agent, "lua", "shutdown")
            return nil, false, err
        end

        -- 所有可能失败的初始化完成后再发布路由。
        players[player_id] = agent
        return agent, true
end

-- 删除 Agent 路由。必须同时比较 player_id 和 Agent Address；旧 Agent 的迟到
-- remove 不能删除同一玩家后来建立的新 Agent。函数不 yield。
function CMD.remove(player_id, agent)
    if players[player_id] ~= agent then
        return false
    end
    players[player_id] = nil
    return true
end

-- 查询当前 Agent Address；找不到时返回 nil。函数不 yield。
function CMD.get(player_id)
    return players[player_id]
end

skynet.start(function()
    -- session/source/command 分别是 RPC ID、发送方 Address 和 CMD Key。
    -- session 非 0 的 call 必须 retpack；send 只执行 Handler，不发 Response。
    skynet.dispatch("lua", function(session, source, command, ...)
        local fn = assert(CMD[command],
            "unknown player manager command: " .. tostring(command))
        local result = { fn(...) }
        if session ~= 0 then
            skynet.retpack(table.unpack(result))
        end
    end)
end)
