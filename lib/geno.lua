-- If you edit template.xml, reflect the change here
local nodesPerAF = 10

-- End of config

--[[ 
    Geno is a library for creating screens in a similar way 
    to how SM5's Def tables work.

    Source: https://github.com/ArcticFqx/nITGeno

    This library is dependant on LibActor to function propperly,
        see: https://github.com/ArcticFqx/LibActor
]]

local geno = { Def = {}, Actors = {} }

local log = nodesPerAF == 10
            and math.log10
            or  function(n) 
                    return math.log(n)/math.log(nodesPerAF) 
                end

local template = {}
local actorLookup = {}
local stack = {}

local ceil = math.ceil
local getn = table.getn
local lower = string.lower

local function GetDepth(t)
    return ceil(log(getn(t)))
end

function stack:Push(entry)
    self[getn(self) + 1] = entry
end

function stack:Pop()
    local t = self[getn(self)]
    self[getn(self)] = nil
    return t
end

function stack:Top()
    return self[getn(self)]
end

local function NewLayer(t)
    --print("----New ActorFrame layer----")
    stack:Push {
        template = t, -- current layer
        depth = GetDepth(t), -- depth of tree structure
        width = getn(t), -- width of layer
        cd = 1, -- current depth
        i = 0, -- current template index
        l = {}, -- current index of node
        a = {}
    }
end

-- This runs first
function geno.Cond(index)
    local s = stack:Top()
    s.l[s.cd] = index
    
    if s.width <= s.i then
        return false
    end
    return true
end

local types = {
    actorframe = "template.xml"
}

-- This runs second
function geno.File(index)
    local s = stack:Top()

    if s.cd < s.depth then
        s.cd = s.cd + 1
        --print("Depth:", s.cd-1, "->", s.cd)
        return types.actorframe
    end

    s.i = s.i + 1
    local template = s.template[s.i]

    local type = lower(template.Type)
    if types[type] then
        if type == "actorframe" then
            NewLayer(template)
            s.a[s.i] = stack:Top().a
        end
        return template.File or types[type]
    end

    return template.File
end

local function runCommand(func, target)
    if func then
        if type(func) == "string" then
            target:cmd(func)
        elseif type(func) == "function" then
            func(target)
        end
    end
end

-- This runs third
function geno.Init(self)
    local s = stack:Top()
    
    if s.cd < 1 then
        stack:Pop().a[0] = self
        s = stack:Top()
        --print("----End ActorFrame layer----")
    end
    local template = s.template[s.i]

    if s.cd == s.depth then
        --print("InitCommand", self, template.Name)
        if not s.a[s.i] then
            s.a[s.i] = self
        end
        actorLookup[self] = template
        runCommand(template.InitCommand, self)
    end

    if s.l[s.cd] >= nodesPerAF or s.width <= s.i then
        s.cd = s.cd - 1
        --print("Depth:", s.cd+1, "->", s.cd)
    end
end

-- These runs at the very end when everything has been built
function geno.InitCmd(self)
    geno.Actors[0] = self
    actorLookup[self] = template
    runCommand(template.InitCommand, self)
end

-- OnCommand Time
function geno.OnCmd(_, a)
    a = a or geno.Actors
    for k,v in ipairs(a) do
        if type(v) == "table" then
            geno.OnCmd(_, v)
        else
            runCommand(actorLookup[v].OnCommand, v)
        end
    end
    runCommand(actorLookup[a[0]].OnCommand, a[0])
end

-- Called from Root
function geno.Template(file)
    --print("Template:", file)
    template = lax.Require(file)
    NewLayer(template)
    stack:Top().a = geno.Actors
    return true
end

function geno.Def:__index(k)
    return function(t)
        t.Type = k
        return t
    end
end
setmetatable(geno.Def, geno.Def)

return geno