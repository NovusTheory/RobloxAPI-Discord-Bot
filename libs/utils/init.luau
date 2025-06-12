return {
    sanitizeName = function(name)
        local sanitizations = {
            {
                "%s",
                "_"
            },
            {
                "\"",
                ""
            },
            {
                "%(",
                ""
            },
            {
                "%)",
                ""
            },
            {
                "/",
                "-"
            }
        }
        local sanitizedName = name
        for i,sanitization in sanitizations do
            sanitizedName = string.gsub(sanitizedName, sanitization[1], sanitization[2])
        end
        return sanitizedName
    end
}