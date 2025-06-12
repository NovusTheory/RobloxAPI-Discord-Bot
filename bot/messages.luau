local serde = require("@lune/serde")
local fs = require("@lune/fs")
local utils = require("@self/../libs/utils")

local ROBLOX_CREATOR_HUB_DOMAIN = "https://create.roblox.com"

local BACK_TYPE_MAP = {
    Property = "properties",
    Function = "functions",
    Event = "events"
}

local MEMBER_GROUP_LOCALE_MAP = {
    properties = "Properties",
    functions = "Functions",
    events = "Events",
}

local function addBotCredits(finalComponents)
    table.insert(finalComponents, {
        type = 14,
        divider = false,
        spacing = 1
    })
    table.insert(finalComponents, {
        type = 10,
        content = "-# Made by [NovusTheory](https://github.com/NovusTheory) • [Source Code](https://github.com/NovusTheory/RobloxAPI-Discord-Bot)"
    })
end

return {
    createClassOrMemberMessage = function(record)
        local docsLink = `{ROBLOX_CREATOR_HUB_DOMAIN}/docs/reference/engine/classes/{record.OwningClass and `{record.OwningClass}#{record.Name}` or record.Name}`
        local backType = BACK_TYPE_MAP[record.Type]
        
        local finalComponents = {
            {
                type = 10,
                content = `# [{record.Name}]({docsLink})`
            }
        }

        if record.Tags and #record.Tags > 0 then
            local tags = "### "
            for _,tag in record.Tags do
                tags = tags .. `\`{tag}\` `
            end
            table.insert(finalComponents, {
                type = 10,
                content = tags
            })
            table.insert(finalComponents, {
                type = 14,
                divider = false,
                spacing = 1
            })
        end

        if record.Documentation and record.Documentation.Description then
            local description = record.Documentation.Description
            local hasOverflow = false
            if #description > 3500 then
                description = string.sub(description, 1, 3500)
                description ..= `...`
                hasOverflow = true
            end
            table.insert(finalComponents, {
                type = 10,
                content = description
            })
            if hasOverflow then
                table.insert(finalComponents, {
                    type = 10,
                    content = `[Read more]({docsLink})`
                })
            end
        end

        local memberButtonComponents = {}
        if not backType then
            if record.Properties and #record.Properties > 0 then
                table.insert(memberButtonComponents, {
                    type = 2,
                    style = 2,
                    label = "Properties",
                    custom_id = `0|{record.Id}|properties`
                })
            end
            if record.Functions and #record.Functions > 0 then
                table.insert(memberButtonComponents, {
                    type = 2,
                    style = 2,
                    label = "Functions",
                    custom_id = `0|{record.Id}|functions`
                })
            end
            if record.Events and #record.Events > 0 then
                table.insert(memberButtonComponents, {
                    type = 2,
                    style = 2,
                    label = "Events",
                    custom_id = `0|{record.Id}|events`
                })
            end
        else
            table.insert(memberButtonComponents, {
                type = 2,
                style = 2,
                label = "Go Back",
                custom_id = `0|{record.OwningId}|{backType}`
            })
        end
        table.insert(memberButtonComponents, {
            type = 2,
            style = 4,
            label = "Delete Message",
            custom_id = `2`
        })
        
        -- Documentation credits
        table.insert(finalComponents, {
            type = 10,
            content = "-# Documentation provided by [roblox/creator-docs](https://github.com/Roblox/creator-docs)"
        })
        
        table.insert(finalComponents, {
            type = 14,
            divider = true,
            spacing = 2
        })
        table.insert(finalComponents, {
            type = 1,
            components = memberButtonComponents
        })

        addBotCredits(finalComponents)
        return {
            flags = 32768,
            components = {
                {
                    type = 17,
                    components = finalComponents
                }
            }
        }
    end,
    createIntrospectionMessage = function(record, memberGroup, offset, limit)
        local offset = offset and tonumber(offset) or 1
        local docsLink = `{ROBLOX_CREATOR_HUB_DOMAIN}/docs/reference/engine/classes/{record.Name}`
        
        local finalComponents = {}

        table.insert(finalComponents, {
            type = 10,
            content = `# [{record.Name}]({docsLink}) {MEMBER_GROUP_LOCALE_MAP[memberGroup]}`
        })
        table.insert(finalComponents, {
            type = 14,
            divider = false,
            spacing = 1
        })

        if memberGroup == "properties" then
            if record.Properties and #record.Properties > 0 then
                local lastIndex = 1
                for i = offset,math.min(#record.Properties, offset + limit) do
                    lastIndex = i
                    local member = record.Properties[i]

                    table.insert(finalComponents, {
                        type = 9,
                        components = {
                            {
                                type = 10,
                                content = `### {member.Name}`
                            }
                        },
                        accessory = {
                            type = 2,
                            label = "View",
                            style = 2,
                            custom_id = `1|{member.Id}`
                        }
                    })
                    if member.Documentation and member.Documentation.Summary and #member.Documentation.Summary > 0 then
                        table.insert(finalComponents, {
                            type = 10,
                            content = member.Documentation.Summary
                        })
                    end
                    if i ~= #record.Properties then
                        table.insert(finalComponents, {
                            type = 14,
                            divider = false,
                            spacing = 1
                        })
                    end
                end
                table.insert(finalComponents, {
                    type = 14,
                    divider = true,
                    spacing = 2
                })
                local actionButtons = {
                    {
                        type = 2,
                        label = "Go Back",
                        style = 2,
                        custom_id = `1|{record.Id}`
                    }
                }
                if lastIndex - limit ~= 1 then
                    table.insert(actionButtons, {
                        type = 2,
                        label = "Previous Page",
                        style = 2,
                        custom_id = `0|{record.Id}|properties|{offset - (limit + 1)}`
                    })
                end
                if lastIndex ~= #record.Properties then
                    table.insert(actionButtons, {
                        type = 2,
                        label = "Next Page",
                        style = 2,
                        custom_id = `0|{record.Id}|properties|{lastIndex + 1}`
                    })
                end
                table.insert(actionButtons, {
                    type = 2,
                    style = 4,
                    label = "Delete Message",
                    custom_id = `2`
                })
                table.insert(finalComponents, {
                    type = 1,
                    components = actionButtons
                }) 
            end
            
            addBotCredits(finalComponents)
            return {
                components = {
                    {
                        type = 17,
                        components = finalComponents
                    }
                }
            }
        elseif memberGroup == "functions" then
            if record.Functions and #record.Functions > 0 then
                local lastIndex = 1
                for i = offset,math.min(#record.Functions, offset + limit) do
                    lastIndex = i
                    local member = record.Functions[i]

                    table.insert(finalComponents, {
                        type = 9,
                        components = {
                            {
                                type = 10,
                                content = `### {member.Name}`
                            }
                        },
                        accessory = {
                            type = 2,
                            label = "View",
                            style = 2,
                            custom_id = `1|{member.Id}`
                        }
                    })
                    if member.Documentation and member.Documentation.Summary and #member.Documentation.Summary > 0 then
                        table.insert(finalComponents, {
                            type = 10,
                            content = member.Documentation.Summary
                        })
                    end
                    if i ~= #record.Functions then
                        table.insert(finalComponents, {
                            type = 14,
                            divider = false,
                            spacing = 1
                        })
                    end
                end
                table.insert(finalComponents, {
                    type = 14,
                    divider = true,
                    spacing = 2
                })
                local actionButtons = {
                    {
                        type = 2,
                        label = "Go Back",
                        style = 2,
                        custom_id = `1|{record.Id}`
                    }
                }
                if lastIndex - limit ~= 1 then
                    table.insert(actionButtons, {
                        type = 2,
                        label = "Previous Page",
                        style = 2,
                        custom_id = `0|{record.Id}|functions|{offset - (limit + 1)}`
                    })
                end
                if lastIndex ~= #record.Functions then
                    table.insert(actionButtons, {
                        type = 2,
                        label = "Next Page",
                        style = 2,
                        custom_id = `0|{record.Id}|functions|{lastIndex + 1}`
                    })
                end
                table.insert(actionButtons, {
                    type = 2,
                    style = 4,
                    label = "Delete Message",
                    custom_id = `2`
                })
                table.insert(finalComponents, {
                    type = 1,
                    components = actionButtons
                })
            end

            addBotCredits(finalComponents)
            return {
                components = {
                    {
                        type = 17,
                        components = finalComponents
                    }
                }
            }
        elseif memberGroup == "events" then
            if record.Events and #record.Events > 0 then
                local lastIndex = 1
                for i = offset,math.min(#record.Events, offset + limit) do
                    lastIndex = i
                    local member = record.Events[i]

                    table.insert(finalComponents, {
                        type = 9,
                        components = {
                            {
                                type = 10,
                                content = `### {member.Name}`
                            }
                        },
                        accessory = {
                            type = 2,
                            label = "View",
                            style = 2,
                            custom_id = `1|{member.Id}`
                        }
                    })
                    if member.Documentation and member.Documentation.Summary and #member.Documentation.Summary > 0 then
                        table.insert(finalComponents, {
                            type = 10,
                            content = member.Documentation.Summary
                        })
                    end
                    if i ~= #record.Events then
                        table.insert(finalComponents, {
                            type = 14,
                            divider = false,
                            spacing = 1
                        })
                    end
                end
                table.insert(finalComponents, {
                    type = 14,
                    divider = true,
                    spacing = 2
                })
                local actionButtons = {
                    {
                        type = 2,
                        label = "Go Back",
                        style = 2,
                        custom_id = `1|{record.Id}`
                    }
                }
                if lastIndex - limit ~= 1 then
                    table.insert(actionButtons, {
                        type = 2,
                        label = "Previous Page",
                        style = 2,
                        custom_id = `0|{record.Id}|events|{offset - (limit + 1)}`
                    })
                end
                if lastIndex ~= #record.Events then
                    table.insert(actionButtons, {
                        type = 2,
                        label = "Next Page",
                        style = 2,
                        custom_id = `0|{record.Id}|events|{lastIndex + 1}`
                    })
                end
                table.insert(actionButtons, {
                    type = 2,
                    style = 4,
                    label = "Delete Message",
                    custom_id = `2`
                })
                table.insert(finalComponents, {
                    type = 1,
                    components = actionButtons
                }) 
            end
        end

        addBotCredits(finalComponents)
        return {
            components = {
                {
                    type = 17,
                    components = finalComponents
                }
            }
        }
    end
}