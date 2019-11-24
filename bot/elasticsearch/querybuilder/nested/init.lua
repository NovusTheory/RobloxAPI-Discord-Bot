local query = require("../query")
local innerHits = require("./innerhits")
local nested = {}
nested.__index = nested

function nested:Serialize()
    local _, serializedQueryObj = self.query:Serialize()
    local _, serializedInnerHitsObj = self.inner_hits:Serialize()
    return "nested", {
        path = self.path,
        query = serializedQueryObj,
        inner_hits = serializedInnerHitsObj
    }
end

function nested:new()
    local nestedObj = {
        path = nil,
        query = query:new(),
        inner_hits = innerHits:new()
    }
    setmetatable(nestedObj, nested)
    return nestedObj
end

return nested