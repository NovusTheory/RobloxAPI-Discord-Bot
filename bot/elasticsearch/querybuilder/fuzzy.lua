local fuzzy = {}
fuzzy.__index = fuzzy

function fuzzy:Add(name, value, fuzziness)
    self.fields[name] = {
        value = value,
        fuzziness = fuzziness
    }
end

function fuzzy:Serialize()
    return "fuzzy", self.fields
end

function fuzzy:new()
    local fuzzyObj = {
        fields = {}
    }
    setmetatable(fuzzyObj, fuzzy)
    return fuzzyObj
end

return fuzzy