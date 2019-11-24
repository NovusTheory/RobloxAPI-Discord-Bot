local highlight = {}
highlight.__index = highlight

function highlight:AddField(name, value)
    self.fields[name] = value
end

function highlight:Serialize()
    return "highlight", {
        fields = self.fields
    }
end

function highlight:new()
    local highlightObj = {
        fields = {}
    }
    setmetatable(highlightObj, highlight)
    return highlightObj
end

return highlight