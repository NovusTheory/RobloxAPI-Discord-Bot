local net = require("@lune/net")
local serde = require("@lune/serde")

return {
    new = function(host: string, apiKey: string?)
        return {
            addDocumentsReplace = function(index: string, documents: any, primaryKey: string)
                local requestConfig = {
                    url = `{host}/indexes/{index}/documents?primaryKey={primaryKey}`,
                    method = "POST",
                    headers = {
                        ["Content-Type"] = "application/json"
                    },
                    body = serde.encode("json", documents)
                }
                if apiKey then
                    requestConfig.headers["Authorization"] = `Bearer {apiKey}`
                end
                net.request(requestConfig)
            end,
            updateSearchableAttributes = function(index: string, attributes: {string})
                local requestConfig = {
                    url = `{host}/indexes/{index}/settings/searchable-attributes`,
                    method = "PUT",
                    headers = {
                        ["Content-Type"] = "application/json"
                    },
                    body = serde.encode("json", attributes)
                }
                if apiKey then
                    requestConfig.headers["Authorization"] = `Bearer {apiKey}`
                end
                net.request(requestConfig)
            end,
            search = function(index: string, query: string, limit: number)
                local requestConfig = {
                    url = `{host}/indexes/{index}/search`,
                    method = "POST",
                    headers = {
                        ["Content-Type"] = "application/json"
                    },
                    body = serde.encode("json", {
                        q = query,
                        limit = limit
                    })
                }
                if apiKey then
                    requestConfig.headers["Authorization"] = `Bearer {apiKey}`
                end
                local response = net.request(requestConfig)
                return serde.decode("json", response.body)
            end,
            getDocument = function(index: string, id: string)
                local requestConfig = {
                    url = `{host}/indexes/{index}/documents/{id}`,
                    method = "GET",
                    headers = {
                        ["Content-Type"] = "application/json"
                    }
                }
                if apiKey then
                    requestConfig.headers["Authorization"] = `Bearer {apiKey}`
                end
                local response = net.request(requestConfig)
                return serde.decode("json", response.body)
            end
        }
    end
}