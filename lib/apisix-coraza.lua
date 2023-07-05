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
        mode = {
            description = "waf running at block mode or monitor mode.",
            type = "string"
        },
        rules = {
            description = "self waf rules.",
            type = "array"
        },
    },
    required = {"mode"},
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
    local ok, err = core.schema.check(schema, conf)
    if not ok then
        return false, err
    end
    if conf.rules ~= nil then
        for i, rule in ipairs(conf.rules) do
            local ok, msg = coraza.rules_add(rule)
            if not ok then
                return false, rule.."\t"..msg
            end
        end
    end
    return true
end

function _M.init()
    -- call this function when plugin is loaded
    core_log.info("coraza init")
    _M.waf = coraza.create_waf()
end

function _M.access(conf, ctx)
    core.log.info("plugin access phase, conf: ", core.json.delay_encode(conf))
    -- each connection will be created a transaction
    coraza.do_create_transaction(_M.waf)
    coraza.do_access_filter()
    return coraza.do_handle()
end

function _M.header_filter(conf, ctx)
    core.log.info("plugin access phase, conf: ", core.json.delay_encode(conf))
    coraza.do_header_filter()
    ngx.status, _ = coraza.do_handle()
    core.response.clear_header_as_body_modified()
end

function _M.destroy()
    core.log.info("coraza destroy")
    coraza.free_waf(_M.waf)
end


function _M.log(conf, ctx)
    coraza.do_log()
    coraza.do_free_transaction()
end

return _M
