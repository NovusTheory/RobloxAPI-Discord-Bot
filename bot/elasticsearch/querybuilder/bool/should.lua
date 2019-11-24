local should = {}
should.__index = should

function should:Add(obj)
    self.unserialized[#self.unserialized + 1] = obj
end

function should:Serialize()
    local serializedShould = {}
    for _,unserialized in pairs(self.unserialized) do
        local index, serializedObj = unserialized:Serialize()
        if #self.unserialized > 0 then
            local serialized = {}
            serialized[index] = serializedObj
            serializedShould[#serializedShould + 1] = serialized
        else
            serializedShould[index] = serializedObj
        end
    end
    return "should", serializedShould
end

function should:new()
    local shouldObj = {
        unserialized = {}
    }
    setmetatable(shouldObj, should)
    return shouldObj
end

return should