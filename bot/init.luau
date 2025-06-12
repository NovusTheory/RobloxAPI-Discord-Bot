local net = require("@lune/net")
local serde = require("@lune/serde")
local task = require("@lune/task")
local meilisearch = require("@self/../libs/meilisearch")
local messages = require("@self/messages")
local env = require("@self/env")

local meiliClient = meilisearch.new("http://127.0.0.1:7700", env.MEILISEARCH_KEY)

net.serve(env.LISTEN_PORT, {
    address = env.LISTEN_ADDRESS,
    handleRequest = function(request)
        local success, responseOrError = pcall(function()
            local body = request.body
            if not env.DEBUG or not request.query.debug then
                local timestamp = request.headers["x-signature-timestamp"]
                local signature = request.headers["x-signature-ed25519"]

                if not timestamp or not signature then
                    return {
                        status = 400,
                        body = "400 Bad Request"
                    }
                end

                local message = timestamp .. body
                -- This is a function from a custom built Lune executable
                if not serde.naclDetachedVerify(message, signature, env.DISCORD_PUBLIC_KEY) then
                    return {
                        status = 401,
                        body = "401 Unauthorized"
                    }
                end
            end
            
            local json = serde.decode("json", body)
            if json.type == 1 then
                -- Ping
                print("Discord requested ping")
                return {
                    status = 200,
                    headers = {
                        ["Content-Type"] = "application/json"
                    },
                    body = serde.encode("json", {
                        type = 1
                    })
                }
            elseif json.type == 4 then
                -- Autocomplete
                if json.user then
                    print(`User '{json.user.id}' executed autocomplete for '{json.data.name}'`)
                elseif json.member then
                    print(`User '{json.member.user.id}' executed autocomplete for '{json.data.name}' in '{json.guild_id}'`)
                end

                if json.data.name == "search" then
                    if #json.data.options == 1 then
                        local query = json.data.options[1].value
                        local results = meiliClient.search("api", query, 25)
                        local choices = {}
                        for i,record in results.hits do
                            choices[i] = {
                                name = `{record.Type}: {record.OwningClass and record.OwningClass .. "." or ""}{record.Name}`,
                                value = record.Id
                            }
                        end

                        return {
                            status = 200,
                            headers = {
                                ["Content-Type"] = "application/json"
                            },
                            body = serde.encode("json", {
                                type = 8,
                                data = {
                                    choices = choices
                                }
                            })
                        }
                    end
                end
            elseif json.type == 2 then
                -- Application Command
                if json.user then
                    print(`User '{json.user.id}' executed command '{json.data.name}'`)
                elseif json.member then
                    print(`User '{json.member.user.id}' executed command '{json.data.name}' in '{json.guild_id}'`)
                end

                if json.data.name == "search" then
                    if #json.data.options == 1 then
                        local documentId = json.data.options[1].value
                        local record = meiliClient.getDocument("api", documentId)

                        local message = messages.createClassOrMemberMessage(record)

                        return {
                            status = 200,
                            headers = {
                                ["Content-Type"] = "application/json"
                            },
                            body = serde.encode("json", {
                                type = 4,
                                data = message
                            })
                        }
                    end
                end
            elseif json.type == 3 then
                -- Component Interactions
                if json.user then
                    print(`User '{json.user.id}' executed component interaction '{json.data.custom_id}' on '{json.message.id}'`)
                elseif json.member then
                    print(`User '{json.member.user.id}' executed component interaction '{json.data.custom_id}' in '{json.guild_id}' on '{json.message.id}'`)
                end

                if json.data.component_type == 2 then
                    local actionMap = string.split(json.data.custom_id, "|")
                    if not (#actionMap > 0) then
                        return {
                            status = 400,
                            body = "400 Bad Request"
                        }
                    end

                    local action = actionMap[1]
                    -- Introspection Command
                    if action == "0" then
                        if #actionMap ~= 3 and #actionMap ~= 4 then
                            return {
                                status = 400,
                                body = "400 Bad Request"
                            }
                        end

                        local documentId = actionMap[2]
                        local introspection = actionMap[3]
                        local offset = actionMap[4]

                        local record = meiliClient.getDocument("api", documentId)
                        if record.OwningId then
                            -- Introspection is only valid for top level records. This should be a class
                            return {
                                status = 400,
                                body = "400 Bad Request"
                            }
                        end
                        local message = messages.createIntrospectionMessage(record, introspection, offset, 4)

                        return {
                            status = 200,
                            headers = {
                                ["Content-Type"] = "application/json"
                            },
                            body = serde.encode("json", {
                                type = 7,
                                data = message
                            })
                        }
                    elseif action == "1" then
                        -- Navigate Command
                        local documentId = actionMap[2]
                        local record = meiliClient.getDocument("api", documentId)

                        local message = messages.createClassOrMemberMessage(record)
                        
                        return {
                            status = 200,
                            headers = {
                                ["Content-Type"] = "application/json"
                            },
                            body = serde.encode("json", {
                                type = 7,
                                data = message
                            })
                        }
                    elseif action == "2" then
                        -- Delete Interaction Command
                        task.spawn(function()
                            net.request({
                                url = `https://discord.com/api/v10/webhooks/{env.DISCORD_CLIENT_ID}/{json.token}/messages/@original`,
                                method = "DELETE",
                                headers = {
                                    ["Content-Type"] = "application/json"
                                }
                            })
                        end)

                        return {
                            status = 200,
                            headers = {
                                ["Content-Type"] = "application/json"
                            },
                            body = serde.encode("json", {
                                type = 6
                            })
                        }
                    end
                end
            end

            return {
                status = 400,
                body = "400 Bad Request"
            }
        end)
        
        if success then
            return responseOrError
        else
            print(`ERR: {responseOrError}`)
            return {
                status = 500,
                body = "500 Internal Server Error"
            }
        end
    end
})