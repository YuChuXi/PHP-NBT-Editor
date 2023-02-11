ll.registerPlugin("PNE", "PHP-NBT-Editor", {0, 0, 2})
logger.setFile(os.date("logs/nbt/%m-%d.log"))

local help = [[
    nbt help
    nbt show @s "/"
    nbt show @e "."
    nbt set @e "xxx.xxx.xxx" "xxx" <- snbt
               "xxx/xxx/xxx"
    nbt show xx xx xx "!xxx/xxx/xxx" <- blockentity
    nbt show "xxx/xxx/xxx" <- item
    这东西很危险，用之前先备份！！！
]]

-- #>
local NIL = {}

function dump(o) -- 这个是调试用的
    local t = {}
    local _t = {}
    local _n = {}
    local deepin = 4
    local space, deep = ' ', 0
    local function _ToString(o, _k)
        if type(o) == ('number') then
            table.insert(t, o)
        elseif type(o) == ('string') then
            table.insert(t, string.format('%q', o))
        elseif type(o) == ('table') then
            local mt = getmetatable(o)
            if mt and mt.__tostring then
                table.insert(t, tostring(o))
            else
                deep = deep + deepin
                table.insert(t, '{')
                for k, v in pairs(o) do
                    if v == _G then
                        table.insert(t, string.format('\n%s%s\t= %s;', string.rep(space, deep), k, "_G"))
                    elseif v ~= package.loaded then
                        if tonumber(k) then
                            k = string.format('[%s]', k)
                        else
                            k = string.format('[\"%s\"]', k)
                        end
                        table.insert(t, string.format('\n%s%s\t= ', string.rep(space, deep), k))
                        if v == NIL then
                            table.insert(t, string.format('%s;', "nil"))
                        elseif type(v) == ('table') then
                            if _t[tostring(v)] == nil then
                                _t[tostring(v)] = v
                                local _k = _k .. k
                                _t[tostring(v)] = _k
                                _ToString(v, _k)
                            else
                                table.insert(t, tostring(_t[tostring(v)]))
                                table.insert(t, ';')
                            end
                        else
                            _ToString(v, _k)
                        end
                    end
                end
                deep = deep - deepin
                table.insert(t, string.format('\n%s}', string.rep(space, deep)))
            end
        else
            table.insert(t, tostring(o))
        end
        table.insert(t, ";")
        return t
    end
    t = _ToString(o, '')
    return table.concat(t)
end

function string:split(delimiter) -- 拆分字符串
    local input = tostring(self)
    delimiter = tostring(delimiter)
    if delimiter == "" or self == "" then
        return {}
    end
    local pos, arr = 0, {}
    for st, sp in function()
        return string.find(input, delimiter, pos, true)
    end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

local function nbt2string(nbt) -- 标签转snbt，列表转json
    --[[
    local t = nbt:getType()
    if t == NBT.Compound then
        return nbt:toJson(2)
    elseif t == NBT.List then
        return data.toJson(nbt:toArray(), 2)
    else
        return tostring(nbt:get())
    end
    --]]
    local err, bak = pcall(function()
        return nbt:toSNBT(2)
    end)
    -- log(err,"",bak)
    if err then
        return bak
    else
        return nbt:toString(2)
    end
end

local function setnbt(nbt, path, value) -- 设置nbt，获取路径
    local nbt_list = {nbt} -- 每层的nbt
    if path then
        path = path:gsub("^!", ""):gsub("%.", "/"):gsub("^%/", ""):gsub("%/$", ""):split("/") -- 路径转列表
        for d, k in ipairs(path) do -- 逐层提取nbt
            if k:find("^!") then -- 数字索引模式
                k = tonumber(k:sub(2, -1))
            end
            -- log(dump(nbt_list, nbt_list[#nbt_list]:getTag(k)))
            table.insert(nbt_list, nbt_list[#nbt_list]:getTag(k))
        end
    end
    if value then
        if value == NIL then
            nbt_list[#nbt_list - 1]:removeTag(path[#path])
            for d = #nbt_list - 2, 1, -1 do -- 逐层塞回去
                nbt_list[d] = nbt_list[d]:setTag(path[d], nbt_list[d + 1])
                -- log(dump({d, k, nbt_list, path}))
            end
        else
            -- log(dump({d, value, nbt_list, path}))
            nbt_list[#nbt_list - 1]:setTag(path[#path],
                NBT.parseSNBT(string.format("{\"value\":%s}", value)):getTag("value"))
            for d = #nbt_list - 1, 1, -1 do -- 逐层塞回去
                nbt_list[d] = nbt_list[d]:setTag(path[d], nbt_list[d + 1])
                -- log(dump({d, k, nbt_list, path}))
            end
        end
        return nbt_list[1]
    else
        return nbt_list[#nbt_list]
    end
end

local function nbt2world(thing, nbt, res) -- 应用至世界
    log("backup:to: ", nbt:toSNBT())
    return thing:setNbt(nbt)
    --[[
    if res.Block and (not res.Path:find("^!")) and false then
        log(res.Block.x, " ", res.Block.y, " ", res.Block.z, " ", res.Block.dimid)
        return mc.setBlock(res.Block, nbt)
    else
        return thing:setNbt(nbt)
    end
    --]]
end

local funs = { -- 枚举每个操作
    show = function(thing, res)
        if thing then
            local nbt = setnbt(thing:getNbt(), res.Path)
            log("backup:show: ", nbt:toSNBT())
            return nbt2string(nbt)
        else
            return "NULL"
        end
    end,
    list = function(thing, res)
        if thing then
            local nbt = setnbt(thing:getNbt(), res.Path)
            if nbt:getType() == NBT.Compound then
                return table.concat(nbt:getKeys(), "  ")
            elseif nbt:getType() == NBT.List() then
                return nbt2string(nbt)
            else
                return "不是一个NBT标签或NBT列表"
            end
        else
            return "NULL"
        end
    end,
    set = function(thing, res)
        if thing then
            local nbt = thing:getNbt()
            log("backup:set: ", nbt:toSNBT())
            nbt = setnbt(nbt, res.Path, res.Value)
            return nbt2world(thing, nbt, res)
        else
            return "NULL"
        end
    end,
    del = function(thing, res)
        if thing then
            local nbt = thing:getNbt()
            log("backup:del: ", nbt:toSNBT())
            nbt = setnbt(nbt, res.Path, NIL)
            return nbt2world(thing, nbt, res)
        else
            return "NULL"
        end
    end
}

local nbt_c = mc.newCommand("nbt", "NBT编辑器", PermType.GameMasters)
nbt_c:setEnum("ActionList", {"show", "list", "set", "del", "help"})
nbt_c:mandatory("Action", ParamType.Enum, "ActionList", 1)
-- item
nbt_c:mandatory("Block", ParamType.BlockPos)
nbt_c:mandatory("Entity", ParamType.Actor)
nbt_c:mandatory("Player", ParamType.Player)

nbt_c:mandatory("Path", ParamType.String)
nbt_c:optional("Value", ParamType.String)

-- help
nbt_c:overload({"Action"})
-- item
nbt_c:overload({"Action", "Path", "Value"})
-- block
nbt_c:overload({"Action", "Block", "Path", "Value"})
-- entity
nbt_c:overload({"Action", "Entity", "Path", "Value"})
-- player
nbt_c:overload({"Action", "Player", "Path", "Value"})

nbt_c:setCallback(function(cmd, origin, output, results)
    if results.Action == "help" then
        output:success(help)
    elseif results.Block then -- Block
        local block = mc.getBlock(results.Block)
        if results.Path and results.Path:find("^!") then -- 方块实体模式
            block = block:getBlockEntity()
        end
        output:success(tostring(funs[results.Action](block, results)))
    elseif results.Entity and #results.Entity > 0 then -- Entity
        if #results.Entity > 1 then
            output:error("目标数量太多")
            return
        end
        output:success(tostring(funs[results.Action](results.Entity[1], results)))
        results.Entity[1]:refreshItems()
    elseif results.Player and #results.Player > 0 then -- Player
        if #results.Player > 1 then
            output:error("目标数量太多")
            return
        end
        output:success(tostring(funs[results.Action](results.Player[1], results)))
        results.Player[1]:refreshItems()
    else
        output:success(tostring(funs[results.Action](origin.player:getHand(), results)))
        origin.player:refreshItems()
    end
end)

nbt_c:setup()
