local typedefs = require "kong.db.schema.typedefs"

local schema = {
  name = "jwt-crafter",
  fields = {
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { expires_in = { type = "number", default = 8 * 60 * 60 } }
        }
      }
    }
  }
}

return schema