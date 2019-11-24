local must = require("./must")
local mustnot = require("./mustnot")
local bool = {}
bool.__index = bool

function bool:Serialize()
    local _, serializedMustObj = self.must:Serialize()
    local _, serializedMustNotObj = self.must_not:Serialize()
    return "bool", {
        must = serializedMustObj,
        must_not = serializedMustNotObj
    }
end

function bool:new()
    local boolObj = {
        must = must:new(),
        must_not = mustnot:new()
    }
    setmetatable(boolObj, bool)
    return boolObj
end

return bool