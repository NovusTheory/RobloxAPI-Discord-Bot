local query = require("./query")
local functions = require("./functions")
local functionScore = {}
functionScore.__index = functionScore

function functionScore:Serialize()
    local _, serializedQueryObj = self.query:Serialize()
    local _, serializedFunctionsObj = self.functions:Serialize()
    return "function_score", {
        boost = self.boost,
        boost_mode = self.boost_mode,
        query = serializedQueryObj,
        -- JSON stringify to table
        functions = (serializedFunctionsObj.filter ~= nil) and {
            serializedFunctionsObj
        } or nil
    }
end

function functionScore:new()
    local functionScoreObj = {
        boost = nil,
        boost_mode = nil,
        query = query:new(),
        functions = functions:new()
    }
    setmetatable(functionScoreObj, functionScore)
    return functionScoreObj
end

return functionScore