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

local NIL = {} -- 这两个是调试用的
function dump(o)
    local t = {}
    local _t = {}
    local _n = {}
    local space, deep = string.rep(' ', 2), 0
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
                deep = deep + 2
                table.insert(t, '{')

                for k, v in pairs(o) do
                    if v == _G then
                        table.insert(t, string.format('\r\n%s%s\t=%s ;', string.rep(space, deep - 1), k, "_G"))
                    elseif v ~= package.loaded then
                        if tonumber(k) then
                            k = string.format('[%s]', k)
                        else
                            k = string.format('[\"%s\"]', k)
                        end
                        table.insert(t, string.format('\r\n%s%s\t= ', string.rep(space, deep - 1), k))
                        if v == NIL then
                            table.insert(t, string.format('%s ;', "nil"))
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
                table.insert(t, string.format('\r\n%s}', string.rep(space, deep - 1)))
                deep = deep - 2
            end
        else
            table.insert(t, tostring(o))
        end
        table.insert(t, " ;")
        return t
    end

    t = _ToString(o, '')
    return table.concat(t)
end

function string:split(delimiter)
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

local function nbt2string(nbt)
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
    if err then
        return bak
    else
        return nbt:toString(2)
    end
end
local function setnbt(nbt, path, value)
    local nbt_list = {nbt}
    if path then
        path = path:gsub("^!", ""):gsub("%.", "/"):gsub("^%/", ""):split("/")
        for d, k in ipairs(path) do
            table.insert(nbt_list, nbt_list[#nbt_list]:getTag(k))
        end
    end
    if value then
        if value == NIL then
            nbt_list[#nbt_list - 1]:removeTag(path[#path])
            for d = #nbt_list - 2, 1, -1 do
                nbt_list[d] = nbt_list[d]:setTag(path[d], nbt_list[d + 1])
                -- log(dump({d, k, nbt_list, path}))
            end
        else
            -- log(dump({d, value, nbt_list, path}))
            nbt_list[#nbt_list - 1]:setTag(path[#path],
                NBT.parseSNBT(string.format("{\"value\":}", value)):getTag("value"))
            for d = #nbt_list - 1, 1, -1 do
                nbt_list[d] = nbt_list[d]:setTag(path[d], nbt_list[d + 1])
                -- log(dump({d, k, nbt_list, path}))
            end
        end
        return nbt_list[1]
    else
        return nbt_list[#nbt_list]
    end
end

local funs = {
    show = function(thing, res)
        if thing then
            return nbt2string(setnbt(thing:getNbt(), res.Path))
        else
            return "NULL"
        end
    end,
    list = function(thing, res)
        if thing then
            local nbt = setnbt(thing:getNbt(), res.Path)
            if nbt:getType() == NBT.Compound then
                return data.toJson(nbt:getKeys(), 2)
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
        return thing:setNbt(setnbt(thing:getNbt(), res.Path, res.Value))
    end,
    del = function(thing, res)
        return thing:setNbt(setnbt(thing:getNbt(), res.Path, NIL))
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
nbt_c:optional("Value", ParamType.RawText)

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
        if results.Path and results.Path:find("^!") then
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
