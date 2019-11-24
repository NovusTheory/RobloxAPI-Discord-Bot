local exists = {}
exists.__index = exists

function exists:Serialize()
    return "exists", {
        field = self.field
    }
end

function exists:new()
    local existsObj = {
        field = nil
    }
    setmetatable(existsObj, exists)
    return existsObj
end

return exists