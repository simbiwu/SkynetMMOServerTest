local skynet = require "skynet"

  -- 从 Skynet Environment 读取配置。
  -- 如果配置不存在或为空字符串，则返回调用方提供的默认值。
  local function getenv(name, default)
      local value = skynet.getenv(name)
      if value == nil or value == "" then
          return default
      end
      return value
  end

  -- skynet.getenv 返回的是字符串。
  -- 端口、Worker 数量等配置需要转成 Lua number 后才能参与计算。
  local function getenv_int(name, default)
      local value = getenv(name, tostring(default))
      return assert(
          tonumber(value),
          string.format("config %s must be an integer, actual=%s",
              name, tostring(value))
      )
  end

skynet.start(function ()
  skynet.error("========== Skynet MMO ARPG ==========")

    -- 先建立 Sproto Slot；后面的 Watchdog/PlayerAgent 才能 load(1/2)。
    skynet.uniqueservice("protocol/protoloader")

    -- StorageMgr 完成全部 Worker 初始化后，call 才返回。
    local storage_mgr = skynet.uniqueservice("storage/storage_mgr")
    skynet.call(storage_mgr, "lua", "start", {
        pool = getenv_int("storage_pool", 2),
    })

    -- PlayerMgr 只保存 Agent 路由，StorageMgr Address 通过 init 显式注入。
    local player_mgr = skynet.uniqueservice("player/player_mgr")
    skynet.call(player_mgr, "lua", "init", {
        storage_mgr = storage_mgr,
    })

    -- Auth 与 Watchdog 都是唯一 Service。Watchdog.start 收到所有依赖后才创建
    -- Gate 并监听端口，避免 Client 在下游尚未 Ready 时进入 Login。
    local auth_service = skynet.uniqueservice("auth/auth")
    local watchdog = skynet.uniqueservice("gateway/watchdog")
    local address, port = skynet.call(watchdog, "lua", "start", {
        address = getenv("gate_host", "127.0.0.1"),
        port = getenv_int("gate_port", 8888),
        maxclient = getenv_int("max_client", 1024),
        player_mgr = player_mgr,
        auth_service = auth_service,
    })

    -- 端口为 0 时禁用 Debug Console，供自动测试和非开发配置使用。
    local debug_port = getenv_int("debug_console_port", 8000)
    if debug_port > 0 then
        skynet.newservice("debug_console", debug_port)
    end

    skynet.error("[Main] gate listening at ", address, ":", port)
    skynet.error("[Main] startup complete")
    -- 所有长期 Service 已独立存活。Main 退出后不形成中央代理或额外跳转。
    skynet.exit()
end)