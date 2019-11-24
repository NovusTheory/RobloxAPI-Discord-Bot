local mustnot = {}
mustnot.__index = mustnot

function mustnot:Add(obj)
    self.unserialized[#self.unserialized + 1] = obj
end

function mustnot:Serialize()
    local serializedMust = {}
    for _,unserialized in pairs(self.unserialized) do
        local index, serializedObj = unserialized:Serialize()
        serializedMust[index] = serializedObj
    end
    return "must_not", serializedMust
end

function mustnot:new()
    local mustObj = {
        unserialized = {}
    }
    setmetatable(mustObj, mustnot)
    return mustObj
end

return mustnot