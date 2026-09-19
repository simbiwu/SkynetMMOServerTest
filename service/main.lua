local skynet = require "skynet"

skynet.start(function ()
    skynet.error("[Main] minimal bootstrap reached")
    skynet.uniqueservice("protocol/protoloader")
    skynet.error("[Main] protocol ready")

    skynet.exit()
end)