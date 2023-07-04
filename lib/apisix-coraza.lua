--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local core = require("apisix.core")
local core_log = core.log
local coraza = require "resty.coraza"



local schema = {
    type = "object",
    properties = {
        Mode = {
            description = "waf running at block mode or monitor mode",
            type = "string"
        },
        Rules = {
            type = "array",
            items = {
                type = "string",
                minLength = 1,
                maxLength = 4096,
            },
            uniqueItems = true
        },
    },
    required = {"Mode"},
}


local plugin_name = "apisix-coraza"

local _M = {
    version = 0.1,
    priority = 12,
    name = plugin_name,
    schema = schema,
}

function _M.check_schema(conf)
    core.log.info("check coraza schema")
    if conf.Rules ~= nil then
        for i, rule in ipairs(conf.Rules) do
            coraza.rules_add(rule)
        end
    end
    return core.schema.check(schema, conf)
end

function _M.init()
    -- call this function when plugin is loaded
    core_log.info("coraza init")
    coraza.do_init()
end

function _M.access(conf, ctx)
    core.log.info("plugin access phase, conf: ", core.json.delay_encode(conf))
    -- each connection will be created a transaction
    coraza.do_access_filter()
    return coraza.do_handle()
end

function _M.header_filter(conf, ctx)
    core.log.info("plugin access phase, conf: ", core.json.delay_encode(conf))
    -- each connection will be created a transaction
    coraza.do_header_filter()
    ngx.status, _ = coraza.do_handle()
    core.response.clear_header_as_body_modified()
end

function _M.destroy()
    core.log.info("coraza destroy")
end


function _M.log(conf, ctx)
    coraza.do_log()
    coraza.do_free()
end

return _M