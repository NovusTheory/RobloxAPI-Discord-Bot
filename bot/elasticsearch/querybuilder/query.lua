local query = {}
query.__index = query

function query:Add(obj)
    self.unserialized[#self.unserialized + 1] = obj
end

function query:Serialize()
    local serializedQuery = {}
    for _,unserialized in pairs(self.unserialized) do
        local index, serializedObj = unserialized:Serialize()
        serializedQuery[index] = serializedObj
    end
    return "query", serializedQuery
end

function query:new()
    local queryObj = {
        unserialized = {}
    }
    setmetatable(queryObj, query)
    return queryObj
end

return query