local skynet = require "skynet"

skynet.start(function ()
    skynet.error("[Main] minimal bootstrap reached")
    skynet.exit()
end)