local must = {}
must.__index = must

function must:Add(obj)
    self.unserialized[#self.unserialized + 1] = obj
end

function must:Serialize()
    local serializedMust = {}
    for _,unserialized in pairs(self.unserialized) do
        local index, serializedObj = unserialized:Serialize()
        if #self.unserialized > 0 then
            local serialized = {}
            serialized[index] = serializedObj
            serializedMust[#serializedMust + 1] = serialized
        else
            serializedMust[index] = serializedObj
        end
    end
    return "must", serializedMust
end

function must:new()
    local mustObj = {
        unserialized = {}
    }
    setmetatable(mustObj, must)
    return mustObj
end

return must