local match = {}
match.__index = match

function match:Add(name, value)
    self.fields[name] = value
end

function match:Serialize()
    return "match", self.fields
end

function match:new()
    local matchObj = {
        fields = {}
    }
    setmetatable(matchObj, match)
    return matchObj
end

return match