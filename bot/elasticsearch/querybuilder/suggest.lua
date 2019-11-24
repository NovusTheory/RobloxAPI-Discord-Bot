local suggest = {}
suggest.__index = suggest

function suggest:AddSuggestion(suggestion)
    self.unserialized[#self.unserialized + 1] = suggestion
end

function suggest:Serialize()
    local serializedSuggest = {
        text = self.text
    }
    for _,unserialized in pairs(self.unserialized) do
        local index, serializedObj = unserialized:Serialize()
        serializedSuggest[index] = serializedObj
    end
    return "suggest", serializedSuggest
end

function suggest:new()
    local suggestObj = {
        text = nil,
        unserialized = {}
    }
    setmetatable(suggestObj, suggest)
    return suggestObj
end

return suggest