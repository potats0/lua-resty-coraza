package = "lua-resty-coraza"
version = "1.0.1-0"
source = {
    url = "https://github.com/potats0/lua-resty-coraza",
    tag = "v1.0.1"
}

description = {
    summary = "Lua implementation of the libcoraza for modsecurity",
    homepage = "https://github.com/potats0/lua-resty-coraza",
    license = "Apache License 2.0",
    maintainer = "potats0 <bangzhiliang@gmail.com>"
}

build = {
   type = "builtin",
   modules = {
    ["resty.coraza"] = "lib/resty/coraza.lua",
    ["resty.coraza.coraza"] = "lib/resty/coraza/coraza.lua",
    ["resty.coraza.constants"] = "lib/resty/coraza/constants.lua",
    ["resty.coraza.log"] = "lib/resty/coraza/log.lua",
    ["resty.coraza.request"] = "lib/resty/coraza/request.lua",
    ["resty.coraza.response"] = "lib/resty/coraza/response.lua",
   },
}
