local highlight = require("./highlight")
local innerHits = {}
innerHits.__index = innerHits

function innerHits:Serialize()
    local _, serializedHighlightObj = self.highlight:Serialize()
    return "inner_hits", {
        highlight = serializedHighlightObj
    }
end

function innerHits:new()
    local innerHitsObj = {
        highlight = highlight:new()
    }
    setmetatable(innerHitsObj, innerHits)
    return innerHitsObj
end

return innerHits