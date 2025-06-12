local fs = require("@lune/fs")
local serde = require("@lune/serde")

local envFile = fs.readFile(".env")
local env = serde.decode("yaml", envFile)

return env
