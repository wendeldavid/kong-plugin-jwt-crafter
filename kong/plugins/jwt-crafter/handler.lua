local singletons = require "kong.singletons"
-- local responses = require "kong.tools.responses"
local groups = require "kong.plugins.acl.groups"

local table_insert = table.insert
local table_concat = table.concat

local cjson = require "cjson"

local asn_sequence = require "kong.plugins.jwt-crafter.asn_sequence"
local jwt_parser = require "kong.plugins.jwt-crafter.jwt_parser"

local plugin = {
  PRIORITY = 900, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1",
}

local function fetch_acls(consumer_id)
  kong.log("fetch acls")

  -- local results, err = singletons.dao.acls:find_all {consumer_id = consumer_id}
  local authenticated_groups = kong.client.get_credentials()
  kong.log(cjson.encode(authenticated_groups))

  local results, err = kong.db.consumers:select_by_username("senior.com.br")
  if err then
    return nil, err
  end

  return results
end

local function load_credential(consumer_id)
  -- Only HS256 is now supported, probably easy to add more if needed
  local rows, err = singletons.dao.jwt_secrets:find_all {algorithm = "HS256"}
  if err then
    return nil, err
  end
  return rows[1]
end

local function craft_jwt()

  local data = {
    sub = "1234567890",
    name = "John Doe",
    iat = 1516239022
  }
  local key = "keyzera"
  local alg = "HS256"
  local header = {
    typ = "JWT"
  }
  local  jwt = jwt_parser.encode(data, key, alg, header)

  kong.log("decoded jwt: "..jwt)
  return jwt
end

-- Executed for every request upon it's reception from a client and before it is being proxied to the upstream service.
function plugin:access(plugin_conf)
  kong.log("jwt-crafter:access")
  -- kong.log(cjson.encode())

  local consumer = kong.client.load_consumer("senior.com.br", true)

  if consumer then
    local consumer_id = consumer.id

    local acls, err = fetch_acls(consumer_id)

    local jwt = craft_jwt("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")

    kong.service.request.add_header("X-JWT-ASSERTION", cjson.encode(jwt))

  else
    kong.response.exit(403, "Cannot identify the consumer, add an authentication plugin to generate JWT token")
  end

end

return plugin

-- OLD PLUGIN

  -- local acls, err = fetch_acls(consumer_id)

  -- if err then
  --   return  kong.response.exit(500, err)
  -- end
  -- if not acls then acls = {} end

  -- -- Prepare header
  -- local str_acls = {}
  -- for _, v in ipairs(acls) do
  --   table_insert(str_acls, v.group)
  -- end

  -- -- Fetch JWT secret for signing
  -- local credential, err = load_credential(consumer_id)

  -- if err then
  --   return  kong.response.exit(500, err)
  -- end
  -- if not credential then
  --   return  kong.response.exit(500, "Consumer has no JWT credential, cannot craft token")
  -- end

  -- -- Hooray, create the token finally
  -- local jwt_token = jwt:sign(
  --   credential.secret,
  --   {
  --     header = {
  --       typ = "JWT",
  --       alg = "HS256" -- load_credential only loads HS256 for now
  --     },
  --     payload = {
  --       sub = ngx.ctx.authenticated_consumer.id,
  --       nam = ngx.ctx.authenticated_credential.username or ngx.ctx.authenticated_credential.id,
  --       iss = credential.key,
  --       rol = str_acls,
  --       exp = ngx.time() + config.expires_in
  --     }
  --   }