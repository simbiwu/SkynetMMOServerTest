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
    skynet.error("[Main] minimal bootstrap reached")
    skynet.uniqueservice("protocol/protoloader")
    skynet.error("[Main] protocol ready")

    local storage_mgr = skynet.uniqueservice("storage/storage_mgr")
    skynet.call(storage_mgr, "lua", "start", {
         pool = getenv_int("storage_pool", 2),
    })
    skynet.error("[Main] storage ready")

    skynet.exit()
end)