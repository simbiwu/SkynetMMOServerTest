-- 当前 Lua Client 与 Server 读取同一份 Sproto Schema 源定义。
-- [[...]] 是 Lua Long String Literal，不是注释；--[[...]] 才是 Lua Block Comment。
-- Long String 内部按 Sproto Grammar 解析，行注释使用 #，不能使用 Lua 的 --。
local M = {}

M.c2s = [[
# Sproto Package Header：type 标识协议，session 关联 Request 与 Response。
.package {
    type 0 : integer
    session 1 : integer
}

# 第一阶段的 Client -> Server 登录协议，协议 ID 为 1。
login 1 {
    request {
        player_id 0 : integer
        token 1 : string
    }
    response {
        code 0 : integer
        message 1 : string
        player_id 2 : integer
        name 3 : string
        level 4 : integer
        gold 5 : integer
    }
}
]]

-- 第一阶段没有 Server Push，但仍建立独立 S2C Schema，后续 AOI、Chat、
-- Kick 等 Push 直接增加在这里，不改变 Client host/attach 方向。
M.s2c = [[
# S2C 使用独立 Package，后续 Server Push 都在这个 Schema 中定义。
.package {
    type 0 : integer
    session 1 : integer
}
]]

return M