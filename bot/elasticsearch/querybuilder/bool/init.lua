local must = require("./must")
local mustnot = require("./mustnot")
local should = require("./should")
local bool = {}
bool.__index = bool

function bool:Serialize()
    local _, serializedMustObj = self.must:Serialize()
    local _, serializedMustNotObj = self.must_not:Serialize()
    local _, serializedShouldObj = self.should:Serialize()
    return "bool", {
        must = serializedMustObj,
        must_not = serializedMustNotObj,
        should = serializedShouldObj
    }
end

function bool:new()
    local boolObj = {
        must = must:new(),
        must_not = mustnot:new(),
        should = should:new()
    }
    setmetatable(boolObj, bool)
    return boolObj
end

return bool