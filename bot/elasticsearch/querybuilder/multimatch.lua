local multiMatch = {}
multiMatch.__index = multiMatch

function multiMatch:Serialize()
    return "multi_match", {
        query = self.query,
        fields = self.fields,
        fuzziness = self.fuzziness
    }
end

function multiMatch:new()
    local multiMatchObj = {
        query = nil,
        fields = {},
        fuzziness = nil
    }
    setmetatable(multiMatchObj, multiMatch)
    return multiMatchObj
end

return multiMatch