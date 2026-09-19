local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local schema = require "protocol.schema"

skynet.start(function()
    local c2s = sprotoparser.parse(schema.c2s)
    local s2c = sprotoparser.parse(schema.s2c)

    sprotoloader.save(c2s, 1)
    sprotoloader.save(s2c, 2)

    skynet.error("[ProtocolLoader] schemas ready slots=1/2")

    -- 不退出。sprotoloader Slot 依赖持有编译结果的 Service 继续存活。
end)