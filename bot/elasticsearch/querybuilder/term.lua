local term = {}
term.__index = term

function term:Serialize()
    return "term", {
        field = self.field,
        suggest_mode = self.suggest_mode
    }
end

function term:new()
    local termObj = {
        field = nil,
        suggest_mode = nil
    }
    setmetatable(termObj, term)
    return termObj
end

return term