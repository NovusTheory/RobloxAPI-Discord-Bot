local consts = require("../consts")
local env = require("./env")
local json = require("json")
local fs = require("fs")
local http = require("coro-http")
local request = http.request

-- Function Ref: http://lua-users.org/wiki/CopyTable
function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
        end
    else
        copy = orig
    end

    return copy
end

coroutine.wrap(function()
    -- Get the Roblox API dump
    local apiJson
    local res, body = request("GET", consts.ROBLOX_CDN_SETUP_URL .. "/versionQTStudio")
    if res.code == 200 then
        local hash = body
        local res, body = request("GET", consts.ROBLOX_CDN_SETUP_URL .. "/" .. hash .. "-API-Dump.json")
        if res.code == 200 then
            apiJson = json.parse(body)
        else
            print(res.code, body)
            error("Failed to get api dump from Roblox")
        end
    else
        print(res.code, body)
        error("Failed to get version has from Roblox")
    end

    if apiJson then
        -- Create a dictionary mapping each class name
        local classRef = {}
        for i,class in pairs(apiJson.Classes) do
            classRef[class.Name] = class
        end

        local function addParentMembers(class)
            local newClass = deepcopy(class)
            local currentClass = class
            while currentClass.Superclass ~= "<<<ROOT>>>" do
                parentClass = classRef[currentClass.Superclass]
                for i,member in pairs(parentClass.Members) do
                    local newMember = deepcopy(member)
                    newMember.InheritedFrom = parentClass.Name
                    newClass.Members[#newClass.Members + 1] = newMember
                end
                currentClass = parentClass
            end
            return newClass
        end

        -- Create a final class reference which adds inherited members to each class
        local classRefFinal = {}
        for i,class in pairs(apiJson.Classes) do
            newClass = addParentMembers(class)

            for i,member in pairs(newClass.Members) do
                -- Fix Members.Security mapping (Elasticsearch mapping issue)
                if type(member.Security) == "string" then
                    local security = member.Security
                    member.Security = {
                        Read = security,
                        Write = security
                    }
                end
            end

            classRefFinal[#classRefFinal+1] = newClass
        end

        -- Write the elasticsearch compatible index to file
        local fd = fs.openSync("rbxapi_elasticsearch.json", "w", 0664)
        local offset = 0
        for i,class in pairs(classRefFinal) do
            local index = { 
                index = { 
                    _index = "robloxapi", 
                    _id =  class.Name
                } 
            }
            local indexString = json.stringify(index) .. "\n"
            local classString = json.stringify(class) .. "\n"
            fs.writeSync(fd, offset, indexString)
            offset = offset + #indexString
            fs.writeSync(fd, offset, classString)
            offset = offset + #classString
        end
        fs.closeSync(fd)

        -- Update the elasticsearch mappings (fails if it's already mapped)
        local body = {
            settings = {
                analysis = {
                    analyzer=  {
                        autocomplete = {
                            tokenizer = "autocomplete",
                            filter = {
                                "lowercase"
                            }
                        },
                        autocomplete_search = {
                            tokenizer = "lowercase"
                        }
                    },
                    tokenizer = {
                        autocomplete = {
                            type = "edge_ngram",
                            min_gram = 2,
                            max_gram = 50,
                            token_chars = {
                                "letter"
                            }
                        }
                    }
                }
            },
            mappings = {
                properties =  {
                    Members = {
                        type = "nested",
                        properties = {
                            Name = {
                                type = "text",
                                analyzer = "autocomplete",
                                search_analyzer = "autocomplete_search"
                            }
                        }
                    },
                    Name = {
                        type = "text",
                        analyzer = "autocomplete",
                        search_analyzer = "autocomplete_search"
                    }
                }
            }
        }
        local res, body = request("PUT", env.ELASTICSEARCH_ENDPOINT .. "/robloxapi", {
            { "Content-Type", "application/json" },
        }, json.stringify(body))
        if res.code ~= 200 then
            local json = json.parse(body)
            if json.error.type == "resource_already_exists_exception" then
                print("Elasticsearch mapping already exists, ignoring")
            else
                print(res.code, body)
                error("Failed to update elasticsearch mappings")
            end
        end

        -- Upload the elasticsearch compatible index file to elasticsearch
        local body = fs.readFileSync("rbxapi_elasticsearch.json")
        local res, body = request("POST", env.ELASTICSEARCH_ENDPOINT .. "/robloxapi/_bulk", {
            { "Content-Type", "application/x-ndjson" },
        }, body)
        if res.code ~= 200 then
            print(res.code, body)
            error("Failed to update elasticsearch index")
        end
    end
end)()