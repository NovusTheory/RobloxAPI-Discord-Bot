local json = require("json")
local env = require("./env")
local consts = require("../consts")
local elasticsearch = require("./elasticsearch")
local esClient = elasticsearch.Client(env.ELASTICSEARCH_ENDPOINT)
local discordia = require("discordia")
discordia.extensions()
local client = discordia.Client()

local function getClassOrMemberSearchQuery(query)
    local body = "{}\n"
    -- Add class query
    body = body .. json.stringify({
        query = {
            bool = {
                must = {
                    {
                        function_score = {
                            query = {
                                multi_match = {
                                    query = query,
                                    fields = {
                                        "Name^3",
                                        "Superclass"
                                    },
                                    fuzziness = "AUTO"
                                }
                            }
                        }
                    }
                }
           }
        }
    }) .. "\n"

    -- Add member query
    body = body .. "{}\n" .. json.stringify({
        query = {
            nested=  {
                path = "Members",
                query = {
                    function_score = {
                        query = {
                            bool = {
                                must = {
                                    fuzzy = {
                                        ["Members.Name"] = {
                                            value = query,
                                            fuzziness = "AUTO"
                                        }
                                    }
                                },
                                must_not = {
                                    exists = {
                                        field = "Members.InheritedFrom"
                                    }
                                }
                            }
                        },
                        functions = {
                            {
                                filter = {
                                    bool = {
                                        must_not = {
                                            {
                                                match = {
                                                    ["Members.Tags"] = "Deprecated"
                                                }
                                            }
                                        }
                                    }
                                },
                                weight = 5
                            }
                        }
                    }
                },
                inner_hits = { 
                    highlight = {
                        fields = {
                            ["Members.Name"] = setmetatable({},{__jsontype="object"})
                        }
                    }
                }
            }
        }
    }) .. "\n"

    -- TEMPORARY: Exact match member query (until fuzziness problems are sorted)
    body = body .. "{}\n" .. json.stringify({
        query = {
            nested=  {
                path = "Members",
                query = {
                    function_score = {
                        query = {
                            bool = {
                                must = {
                                    match = {
                                        ["Members.Name"] = query
                                    }
                                },
                                must_not = {
                                    exists = {
                                        field = "Members.InheritedFrom"
                                    }
                                }
                            }
                        },
                        functions = {
                            {
                                filter = {
                                    bool = {
                                        must_not = {
                                            {
                                                match = {
                                                    ["Members.Tags"] = "Deprecated"
                                                }
                                            }
                                        }
                                    }
                                },
                                weight = 5
                            }
                        }
                    }
                },
                inner_hits = { 
                    highlight = {
                        fields = {
                            ["Members.Name"] = setmetatable({},{__jsontype="object"})
                        }
                    }
                }
            }
        }
    }) .. "\n"

    -- Required newline at end
    body = body .. "\n"
    return body
end

local function getParametersString(object)
    local parametersConcat = ""
    for i,parameter in pairs(object.Parameters) do
        parametersConcat = parametersConcat .. parameter.Type.Name .. " " .. parameter.Name
        if i ~= #object.Parameters then
            parametersConcat = parametersConcat .. ", "
        end
    end

    return parametersConcat
end

client:on("messageCreate", function(message)
    local success = pcall(function()
        local fullArgs = message.content:split(" ")
        if fullArgs[1] == client.user.mentionString then
            if #fullArgs > 1 then
                local args = table.slice(fullArgs, 2)
                local query = args[1]:split("%.")

                if #query == 1 then
                    if query[1]:lower() == "help" then
                        message.channel:send({
                            embed = {
                                color = 41727,
                                author = {
                                    name = "Roblox API Help",
                                    icon_url = client.user.avatarURL
                                },
                                fields = {
                                    { 
                                        name = "Usage",
                                        value = client.user.mentionString .. " <class|member|class.member>"
                                    }
                                }
                            }
                        })
                        return
                    end
                end

                local searchResult = nil
                if #query == 1 then
                    searchResult = esClient:msearch("robloxapi", getClassOrMemberSearchQuery(query[1]))
                elseif #query == 2 then
                    searchResult = esClient:msearch("robloxapi", getClassOrMemberSearchQuery(query[2]))
                else
                    message:reply("Invalid search query provided")
                end

                local responseEmbed = {
                    color = 41727,
                    fields = {}
                }
                local responseEmbedHasResult = false
                
                -- We're looking to obtain a class or member
                for _,response in pairs(searchResult.responses) do
                    if response.hits.total.value > 0 then
                        if not responseEmbedHasResult then
                            responseEmbedHasResult = true
                            
                            local document = response.hits.hits[1]
                            local source = document._source
                            -- No inner hits which means this is a parent document (a class)
                            if document.inner_hits == nil then
                                responseEmbed.author = {
                                    name = "Class " .. source.Name .. (source.Superclass == "<<<ROOT>>>" and "" or " : " .. source.Superclass),
                                    icon_url = client.user.avatarURL
                                }
                                
                                if source.Tags ~= nil then
                                    local tagsConcat = ""
                                    for i,tag in pairs(source.Tags) do
                                        tagsConcat = tagsConcat .. tag
                                        if i ~= #source.Tags then
                                            tagsConcat = tagsConcat .. ", "
                                        end
                                    end

                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Tags",
                                        value = tagsConcat,
                                        inline = true
                                    }
                                else
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Tags",
                                        value = "None",
                                        inline = true
                                    }
                                end

                                if source.Security ~= nil then
                                    local value = "Read: " .. source.Security.Read .. "\nWrite: " .. source.Security.Write
                                    if source.Security.Read == source.Security.Write then
                                        value = source.Security.Read
                                    end

                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Security",
                                        value = value,
                                        inline = true
                                    }
                                else
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Security",
                                        value = "None",
                                        inline = true
                                    }
                                end

                                local properties = {}
                                local functions = {}
                                local events = {}
                                for _,member in pairs(source.Members) do
                                    if member.MemberType == "Property" then
                                        properties[#properties + 1] = member
                                    elseif member.MemberType == "Function" then
                                        functions[#functions + 1] = member
                                    elseif member.MemberType == "Event" then
                                        events[#events + 1] = member
                                    end
                                end

                                if #properties > 0 then
                                    local propertiesConcat = ""
                                    for i,property in pairs(properties) do
                                        propertiesConcat = propertiesConcat .. property.ValueType.Name .. " " .. property.Name
                                        if i ~= #properties then
                                            propertiesConcat = propertiesConcat .. "\n"
                                        end

                                        if i == 5 and i ~= #properties and i < #properties then
                                            propertiesConcat = propertiesConcat .. "..."
                                            break
                                        end
                                    end

                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Properties",
                                        value = propertiesConcat
                                    }
                                end

                                if #functions > 0 then
                                    local functionsConcat = ""
                                    for i,_function in pairs(functions) do
                                        functionsConcat = functionsConcat .. _function.ReturnType.Name .. " " .. _function.Name .. "(" .. getParametersString(_function) .. ")"
                                        if i ~= #functions then
                                            functionsConcat = functionsConcat .. "\n"
                                        end

                                        if i == 5 and i ~= #functions and i < #functions then
                                            functionsConcat = functionsConcat .. "..."
                                            break
                                        end
                                    end

                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Functions",
                                        value = functionsConcat
                                    }
                                end

                                if #events > 0 then
                                    local eventsConcat = ""
                                    for i,event in pairs(events) do
                                        eventsConcat = eventsConcat .. "RBXScriptSignal " .. event.Name .. "(" .. getParametersString(event) .. ")"
                                        if i ~= #events then
                                            eventsConcat = eventsConcat .. "\n"
                                        end

                                        if i == 5 and i ~= #functions and i < #functions then
                                            eventsConcat = eventsConcat .. "..."
                                            break
                                        end
                                    end

                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Events",
                                        value = eventsConcat
                                    }
                                end
                            else
                                local memberSource = document.inner_hits.Members.hits.hits[1]._source
                                responseEmbed.author = {
                                    name = memberSource.MemberType .. " " .. memberSource.Name,
                                    icon_url = client.user.avatarURL
                                }

                                if memberSource.Tags ~= nil then
                                    local tagsConcat = ""
                                    for i,tag in pairs(memberSource.Tags) do
                                        tagsConcat = tagsConcat .. tag
                                        if i ~= #memberSource.Tags then
                                            tagsConcat = tagsConcat .. ", "
                                        end
                                    end

                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Tags",
                                        value = tagsConcat,
                                        inline = true
                                    }
                                else
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Tags",
                                        value = "None",
                                        inline = true
                                    }
                                end

                                if memberSource.Security ~= nil then
                                    local value = "Read: " .. memberSource.Security.Read .. "\nWrite: " .. memberSource.Security.Write
                                    if memberSource.Security.Read == memberSource.Security.Write then
                                        value = memberSource.Security.Read
                                    end

                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Security",
                                        value = value,
                                        inline = true
                                    }
                                else
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Security",
                                        value = "None",
                                        inline = true
                                    }
                                end
                                
                                responseEmbed.fields[#responseEmbed.fields + 1] = {
                                    name = "Member Of",
                                    value = source.Name,
                                    inline = true
                                }

                                if memberSource.MemberType == "Property" then
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Type",
                                        value = memberSource.ValueType.Name,
                                        inline = true
                                    }
                                elseif memberSource.MemberType == "Function" then
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Returns",
                                        value = memberSource.ReturnType.Name,
                                        inline = true
                                    }

                                    local parameters = getParametersString(memberSource)
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Parameters",
                                        value = parameters == "" and "None" or parameters,
                                        inline = true
                                    }
                                elseif memberSource.MemberType == "Event" then
                                    local parameters = getParametersString(memberSource)
                                    responseEmbed.fields[#responseEmbed.fields + 1] = {
                                        name = "Parameters",
                                        value = parameters == "" and "None" or parameters,
                                        inline = true
                                    }
                                end
                            end
                        end
                    end
                end

                if responseEmbedHasResult then
                    message.channel:send({
                        embed = responseEmbed
                    })
                else
                    message:reply("No results found")
                end
            else
                message.channel:send({
                    embed = {
                        color = 41727,
                        description = "A Discord bot to reference and lookup the Roblox API",
                        author = {
                            name = "Roblox API",
                            icon_url = client.user.avatarURL
                        },
                        fields = {
                            { 
                                name = "Developer",
                                value = "NovusTheory"
                            }
                        }
                    }
                })
            end
        end
    end)

    if not success then
        message:reply("An unexpected error occured, please try again later")
    end
end)

client:run("Bot " .. env.BOT_TOKEN)