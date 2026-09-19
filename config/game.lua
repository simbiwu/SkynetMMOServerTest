-- 所有相对路径都以 Skynet Process 的 Current Working Directory 为起点。
-- scripts/linux/run_server.sh 会先切回仓库根目录，再启动 ELF。
root = "./"
skynet_root = root .. "third_party/skynet/"

-- snlua Loader 用 luaservice 查找一个 Service 的 Lua 入口文件。
-- 项目目录放前面，因此 "main" 会先命中 ./service/main.lua；
-- 项目没有的 "bootstrap" 会继续命中官方 service/bootstrap.lua。
luaservice = root .. "service/?.lua;"
    .. skynet_root .. "service/?.lua"

-- 每个 snlua Service 创建自己的 Lua State 后，都由这个官方 Loader
-- 根据 Service Name 搜索并执行对应的入口文件。
lualoader = skynet_root .. "lualib/loader.lua"

-- 普通 Lua Module 的搜索路径，例如 require "skynet"。
lua_path = root .. "lualib/?.lua;"
    .. root .. "lualib/?/init.lua;"
    .. skynet_root .. "lualib/?.lua;"
    .. skynet_root .. "lualib/?/init.lua"

-- Lua require 加载的 Native Module，例如 require "skynet.core"。
lua_cpath = skynet_root .. "luaclib/?.so"

-- Skynet C Service Module 的搜索路径。snlua 属于这一类。
cpath = skynet_root .. "cservice/?.so"

-- 创建 8 个业务 Worker Thread。Monitor、Timer、Socket Thread 不计入此数。
thread = 8

-- 本课使用单节点模式，不启用旧 Harbor 多节点组件。
harbor = 0

-- C Runtime 的第一个 Service：加载 snlua.so，并把 "bootstrap" 作为参数。
bootstrap = "snlua bootstrap"

-- 官方 bootstrap.lua 读取 start，再创建项目的 Main Service。
start = "main"

-- 后续章节使用的业务配置。当前最小 Main 尚未读取这些字段。
gate_host = "127.0.0.1"
gate_port = 8888
max_client = 1024
debug_console_port = 8000
storage_pool = 2