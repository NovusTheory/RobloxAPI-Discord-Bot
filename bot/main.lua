local json = require("json")
local fs = require("fs")
local uv = require("uv")
local env = require("./env")
local consts = require("../consts")
local elasticsearch = require("./elasticsearch")
local esClient = elasticsearch.Client(env.ELASTICSEARCH_ENDPOINT)
local discordia = require("discordia")
discordia.extensions()
local client = discordia.Client()
local elasticQueryBuilder = require("./elasticsearch/querybuilder")
local QueryBuilder = elasticQueryBuilder.QueryBuilder
local FunctionScore = elasticQueryBuilder.FunctionScore
local Bool = elasticQueryBuilder.Bool
local MultiMatch = elasticQueryBuilder.MultiMatch
local Fuzzy = elasticQueryBuilder.Fuzzy
local Nested = elasticQueryBuilder.Nested
local Exists = elasticQueryBuilder.Exists
local Match = elasticQueryBuilder.Match
local Suggestion = elasticQueryBuilder.Suggestion
local Suggest = elasticQueryBuilder.Suggest
local Term = elasticQueryBuilder.Term

local function tohex(char)
	return string.format('%%%02X', string.byte(char))
end

local function urlencode(obj)
	return string.gsub(tostring(obj), '%W', tohex)
end

local function getClassOrMemberSearchQuery(searchQuery, boostClassSearch)
    local body = "{}\n"

    -- Generate class query
    do
        local queryBuilder = QueryBuilder:new()
        local query = queryBuilder.query

        local bool = Bool:new()
        query:Add(bool)

        local functionScore = FunctionScore:new()
        functionScore.boost = boostClassSearch and 10 or 0
        functionScore.boost_mode = "multiply"
        bool.must:Add(functionScore)

        local multiMatch = MultiMatch:new()
        multiMatch.query = searchQuery
        multiMatch.fields = {
            "Name^3",
            "Superclass"
        }
        multiMatch.fuzziness = "AUTO"
        functionScore.query:Add(multiMatch)

        -- Add class query to body json
        body = body .. queryBuilder:Serialize() .. "\n"
    end

    -- Generate member query
    do
        local queryBuilder = QueryBuilder:new()
        local query = queryBuilder.query

        local nested = Nested:new()
        nested.path = "Members"
        nested.inner_hits.highlight:AddField("Members.Name", setmetatable({},{__jsontype="object"}))
        query:Add(nested)

        local functionScore = FunctionScore:new()
        functionScore.boost = boostClassSearch and 0 or 10
        functionScore.boost_mode = "multiply"
        nested.query:Add(functionScore)

        local functionScoreFunctions = functionScore.functions
        functionScoreFunctions.weight = 5
        local boolFilter = Bool:new()
        local match = Match:new()
        match:Add("Members.Tags", "Deprecated")
        boolFilter.must_not:Add(match)
        functionScoreFunctions:AddFilter(boolFilter)

        local functionScoreBool = Bool:new()
        functionScore.query:Add(functionScoreBool)

        local fuzzy = Fuzzy:new()
        fuzzy:Add("Members.Name", searchQuery, "AUTO")
        functionScoreBool.must:Add(fuzzy)

        local exists = Exists:new()
        exists.field = "Members.InheritedFrom"
        functionScoreBool.must_not:Add(exists)

        -- Add member query
        body = body .. "{}\n" .. queryBuilder:Serialize() .. "\n"
    end

    -- TEMPORARY: Exact match member query (until fuzziness problems are sorted)
    do
        local queryBuilder = QueryBuilder:new()
        local query = queryBuilder.query

        local nested = Nested:new()
        nested.path = "Members"
        nested.inner_hits.highlight:AddField("Members.Name", setmetatable({},{__jsontype="object"}))
        query:Add(nested)

        local functionScore = FunctionScore:new()
        functionScore.boost = boostClassSearch and 0 or 10
        functionScore.boost_mode = "multiply"
        nested.query:Add(functionScore)

        local functionScoreFunctions = functionScore.functions
        functionScoreFunctions.weight = 5
        local boolFilter = Bool:new()
        local match = Match:new()
        match:Add("Members.Tags", "Deprecated")
        boolFilter.must_not:Add(match)
        functionScoreFunctions:AddFilter(boolFilter)

        local functionScoreBool = Bool:new()
        functionScore.query:Add(functionScoreBool)

        local match = Match:new()
        match:Add("Members.Name", searchQuery)
        functionScoreBool.must:Add(match)

        local exists = Exists:new()
        exists.field = "Members.InheritedFrom"
        functionScoreBool.must_not:Add(exists)

        -- Add exact match member query
        body = body .. "{}\n" .. queryBuilder:Serialize() .. "\n"
    end

    -- Generate suggest query
    do
        local suggest = Suggest:new()
        suggest.text = searchQuery
        
        local classSuggestion = Suggestion:new("class_suggestion")
        local classSuggestionTerm = Term:new()
        classSuggestionTerm.field = "Name"
        classSuggestionTerm.suggest_mode = "always"
        classSuggestion:Add(classSuggestionTerm)
        suggest:AddSuggestion(classSuggestion)

        local memberSuggestion = Suggestion:new("member_suggestion")
        local memberSuggestionTerm = Term:new()
        memberSuggestionTerm.field = "Members.Name"
        memberSuggestionTerm.suggest_mode = "always"
        memberSuggestion:Add(memberSuggestionTerm)
        suggest:AddSuggestion(memberSuggestion)

        local index, suggestTable = suggest:Serialize()
        local serializedSuggest = {}
        serializedSuggest[index] = suggestTable

        -- Add suggest query
        body = body .. "{}\n" .. json.stringify(serializedSuggest) .. "\n"
    end

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

local function wrapDevHubUrlMarkdown(text, path)
    return "[" .. text .. "](" .. consts.ROBLOX_DEV_HUB_URL .. path .. ")"
end

client:on("messageCreate", function(message)
    local success, err = pcall(function()
        if message.author.bot then
            return
        end

        local fullArgs = message.content:split(" ")
        if fullArgs[1] == client.user.mentionString then
            if #fullArgs > 1 then
                local args = table.slice(fullArgs, 2)
                local query = args[1]:split("%.")

                -- Developer commands
                if message.author.id == client.owner.id then
                    if args[1] == "-update" then
                        if fs.existsSync(env.UPDATE_FILE) then
                            local message = message:reply("Updating...")
                            uv.spawn(env.UPDATE_FILE, {
                                env = nil,
                                detached = true
                            }, function(code)
                                -- It's expected this bot process will be restart if updating works. No need to check success here
                                if code > 0 then
                                    coroutine.wrap(message.setContent)(message, "**ERROR:** Failed to update")
                                end
                            end)
                        end

                        return
                    end
                end

                local searchResult = nil
                if #query == 1 then
                    searchResult = esClient:msearch("robloxapi", getClassOrMemberSearchQuery(query[1], true))
                elseif #query == 2 then
                    searchResult = esClient:msearch("robloxapi", getClassOrMemberSearchQuery(query[2], false))
                else
                    message:reply("Invalid search query provided")
                    return
                end

                local responseEmbed = {
                    color = 41727,
                    fields = {}
                }
                local responseEmbedHasResult = false
                local chosenResponse = nil

                for _,response in pairs(searchResult.responses) do
                    if response.hits.total.value > 0 then
                        if chosenResponse == nil then
                            chosenResponse = response
                        else
                            -- This response is likely more relevant to the user as it has a higher score
                            if response.hits.max_score > chosenResponse.hits.max_score then
                                chosenResponse = response
                            end
                        end
                    end
                end

                if chosenResponse ~= nil then
                    responseEmbedHasResult = true
                    
                    local document = chosenResponse.hits.hits[1]
                    local source = document._source
                    -- No inner hits which means this is a parent document (a class)
                    if document.inner_hits == nil then
                        responseEmbed.author = {
                            name = "Class " .. source.Name .. (source.Superclass == "<<<ROOT>>>" and "" or " : " .. source.Superclass),
                            url = consts.ROBLOX_DEV_HUB_URL .. "/api-reference/class/" .. urlencode(source.Name),
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
                            local propertiesShown = 0
                            for i,property in pairs(properties) do
                                local realMemberOwner = (property.InheritedFrom and property.InheritedFrom or source.Name)
                                local valueType = (property.ValueType.Category == "Class" and "class" or "type")

                                local appendedProperty = propertiesConcat .. wrapDevHubUrlMarkdown(property.ValueType.Name, "/api-reference/" .. urlencode(valueType) .. "/" .. urlencode(property.ValueType.Name)) .. " " .. wrapDevHubUrlMarkdown(property.Name, "/api-reference/property/" .. urlencode(realMemberOwner) .. "/" .. urlencode(property.Name))
                                if #propertiesConcat + #appendedProperty > 1024 then
                                    -- Discord does not permit field values to go over 1024 characters, we can't show more properties
                                    break
                                end
                                
                                propertiesConcat = appendedProperty
                                if i ~= #properties then
                                    propertiesConcat = propertiesConcat .. "\n"
                                end

                                propertiesShown = propertiesShown + 1

                                if i == 5 and i ~= #properties and i < #properties then
                                    break
                                end
                            end

                            responseEmbed.fields[#responseEmbed.fields + 1] = {
                                name = "Properties (" .. propertiesShown .. "/" .. #properties .. ")",
                                value = propertiesConcat
                            }
                        end

                        if #functions > 0 then
                            local functionsConcat = ""
                            local functionsShown = 0
                            for i,_function in pairs(functions) do
                                local realMemberOwner = (_function.InheritedFrom and _function.InheritedFrom or source.Name)
                                local valueType = (_function.ReturnType.Category == "Class" and "class" or "type")

                                local appendedFunction = functionsConcat .. wrapDevHubUrlMarkdown(_function.ReturnType.Name, "/api-reference/" .. urlencode(valueType) .. "/" .. urlencode(_function.ReturnType.Name)) .. " " .. wrapDevHubUrlMarkdown(_function.Name, "/api-reference/function/" .. urlencode(realMemberOwner) .. "/" .. urlencode(_function.Name)) .. "(" .. getParametersString(_function) .. ")"
                                if #functionsConcat + #appendedFunction > 1024 then
                                    -- Discord does not permit field values to go over 1024 characters, we can't show more properties
                                    break
                                end

                                functionsConcat = appendedFunction
                                if i ~= #functions then
                                    functionsConcat = functionsConcat .. "\n"
                                end

                                functionsShown = functionsShown + 1

                                if i == 5 and i ~= #functions and i < #functions then
                                    break
                                end
                            end

                            responseEmbed.fields[#responseEmbed.fields + 1] = {
                                name = "Functions (" .. functionsShown .. "/" .. #functions .. ")",
                                value = functionsConcat
                            }
                        end

                        if #events > 0 then
                            local eventsConcat = ""
                            local eventsShown = 0
                            for i,event in pairs(events) do                                
                                local realMemberOwner = (event.InheritedFrom and event.InheritedFrom or source.Name)

                                local appendedEvent = eventsConcat .. wrapDevHubUrlMarkdown("RBXScriptSignal", "/api-reference/type/RBXScriptSignal") .. " " .. wrapDevHubUrlMarkdown(event.Name, "/api-reference/event/" .. urlencode(realMemberOwner) .. "/" .. urlencode(event.Name)) .. "(" .. getParametersString(event) .. ")"
                                if #eventsConcat + #appendedEvent > 1024 then
                                    -- Discord does not permit field values to go over 1024 characters, we can't show more properties
                                    break
                                end

                                eventsConcat = appendedEvent
                                if i ~= #events then
                                    eventsConcat = eventsConcat .. "\n"
                                end

                                eventsShown = eventsShown + 1

                                if i == 5 and i ~= #functions and i < #functions then
                                    break
                                end
                            end

                            responseEmbed.fields[#responseEmbed.fields + 1] = {
                                name = "Events (" .. eventsShown .. "/" .. #events .. ")",
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
                            value = wrapDevHubUrlMarkdown(source.Name, "/api-reference/class/" .. urlencode(source.Name)),
                            inline = true
                        }

                        if memberSource.MemberType == "Property" then
                            responseEmbed.author.url = consts.ROBLOX_DEV_HUB_URL .. "/api-reference/property/" .. urlencode(source.Name) .. "/" .. urlencode(memberSource.Name)
                            local valueType = (memberSource.ValueType.Category == "Class" and "class" or "type")
                            responseEmbed.fields[#responseEmbed.fields + 1] = {
                                name = "Type",
                                value = wrapDevHubUrlMarkdown(memberSource.ValueType.Name, "/api-reference/" .. urlencode(valueType) .. "/" .. urlencode(memberSource.ValueType.Name)),
                                inline = true
                            }
                        elseif memberSource.MemberType == "Function" then
                            responseEmbed.author.url = consts.ROBLOX_DEV_HUB_URL .. "/api-reference/function/" .. urlencode(source.Name) .. "/" .. urlencode(memberSource.Name)
                            local valueType = (memberSource.ReturnType.Category == "Class" and "class" or "type")
                            responseEmbed.fields[#responseEmbed.fields + 1] = {
                                name = "Returns",
                                value = wrapDevHubUrlMarkdown(memberSource.ReturnType.Name, "/api-reference/" .. urlencode(valueType) .. "/" .. urlencode(memberSource.ReturnType.Name)),
                                inline = true
                            }

                            local parameters = getParametersString(memberSource)
                            responseEmbed.fields[#responseEmbed.fields + 1] = {
                                name = "Parameters",
                                value = parameters == "" and "None" or parameters,
                                inline = true
                            }
                        elseif memberSource.MemberType == "Event" then
                            responseEmbed.author.url = consts.ROBLOX_DEV_HUB_URL .. "/api-reference/event/" .. urlencode(source.Name) .. "/" .. urlencode(memberSource.Name)
                            local parameters = getParametersString(memberSource)
                            responseEmbed.fields[#responseEmbed.fields + 1] = {
                                name = "Parameters",
                                value = parameters == "" and "None" or parameters,
                                inline = true
                            }
                        end
                    end
                end

                if responseEmbedHasResult then
                    responseEmbed.footer = {
                        text = "Took " .. (searchResult.took / 1000) .. " seconds"
                    }
                    responseEmbed.timestamp = discordia.Date():toISO('T', 'Z')

                    message.channel:send({
                        embed = responseEmbed
                    })
                else
                    local totalSuggestions = 0
                    local suggestions = ""
                    -- Find the suggestion responses
                    for _,response in pairs(searchResult.responses) do
                        if response.suggest ~= nil then
                            for _,option in pairs(response.suggest.class_suggestion[1].options) do
                                if totalSuggestions == 5 then
                                    break
                                end

                                totalSuggestions = totalSuggestions + 1
                                suggestions = suggestions .. "**" .. option.text .. "**" .. "\n"
                            end

                            for _,option in pairs(response.suggest.member_suggestion[1].options) do
                                if totalSuggestions == 5 then
                                    break
                                end

                                totalSuggestions = totalSuggestions + 1
                                suggestions = suggestions .. "**" .. option.text .. "**" .. "\n"
                            end

                            break
                        end
                    end

                    if totalSuggestions > 0 then
                        message:reply("No results found, did you mean:\n" .. suggestions)
                    else
                        message:reply("No results found")
                    end
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
                                value = "NovusTheory",
                                inline = true
                            },
                            {
                                name = "GitHub",
                                value = "https://github.com/NovusTheory/RobloxAPI-Discord-Bot",
                                inline = true
                            },
                            { 
                                name = "Usage",
                                value = client.user.mentionString .. " <class|member|class.member>"
                            }
                        }
                    }
                })
            end
        end
    end)

    if not success then
        print(err)
        message:reply("An unexpected error occured, please try again later")
    end
end)

client:run("Bot " .. env.BOT_TOKEN)