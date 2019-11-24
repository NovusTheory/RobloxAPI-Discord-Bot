local functions = {}
functions.__index = functions

function functions:AddFilter(obj)
    self.unserializedFilters[#self.unserializedFilters + 1] = obj
end

function functions:Serialize()
    local serializedFilters = {}
    for _,unserialized in pairs(self.unserializedFilters) do
        local index, serializedObj = unserialized:Serialize()
        serializedFilters[index] = serializedObj
    end
    return "functions", {
        filter = (#serializedFilters > 0) and serializedFilters or nil,
        weight = self.weight
    }
end

function functions:new()
    local functionsObj = {
        weight = nil,
        unserializedFilters = {}
    }
    setmetatable(functionsObj, functions)
    return functionsObj
end

return functions