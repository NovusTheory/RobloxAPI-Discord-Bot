local query = require('./query')
local json = require("json")
local queryBuilder = {}
queryBuilder.__index = queryBuilder

function queryBuilder:Serialize()
    local _, serializedQuery = self.query:Serialize()
    return json.stringify({
        query = serializedQuery
    })
end

function queryBuilder:new()
    local queryBuilderObj = {
        query = query:new()
    }
    setmetatable(queryBuilderObj, queryBuilder)
    return queryBuilderObj
end

return queryBuilder