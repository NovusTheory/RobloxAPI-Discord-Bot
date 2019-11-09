local json = require("json")
local http = require("coro-http")
local request = http.request

local ENDPOINT = nil
local client = {}

function client:msearch(index, body)
    local res, body = request("GET", ENDPOINT .. "/" .. index .. "/_msearch", {
        { "Content-Type", "application/x-ndjson" }
    }, body)

    if res.code == 200 then
        return json.parse(body)
    else
        error("Failed to perform msearch on elasticsearch")
    end
end

return function(endpoint)
    ENDPOINT = endpoint
    return client
end