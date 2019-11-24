local bool = {}
bool.__index = bool

function bool:Must()
    
end

function bool:new()
    local boolObj = {
        must = 
    }
    setmetatable(boolObj, bool)
    return boolObj
end

return bool