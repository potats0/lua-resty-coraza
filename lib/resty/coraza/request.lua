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

local coraza = require "resty.coraza.coraza"
local log = require "resty.coraza.log"


local fmt = string.format
local warn_fmt = log.warn_fmt

local ngx = ngx
local nlog = ngx.log

local _M = {
    _VERSION = '1.0.0',
}


function _M.build_and_process_header(transaction)
    -- https://github.com/openresty/lua-nginx-module#ngxreqget_headers
    local headers, err = ngx.req.get_headers(0, true)
    if err then
        err = fmt("failed to call ngx.req.get_headers: %s", err)
        nlog(ngx.ERR, err)
    end
    for k, v in pairs(headers) do
        if type(v) == "table" then
            nlog(warn_fmt("http request headers potentially has HPP!"))
            for _, value in ipairs(v) do
                coraza.add_request_header(transaction, k, value)
            end
        else
            coraza.add_request_header(transaction, k, v)
        end
    end
    coraza.process_request_headers(transaction)
end

function _M.build_and_process_body(transaction)
    ngx.req.read_body()
    local req_body = ngx.req.get_body_data()
    if req_body then
        -- TODO: fix code to process multipart/formdata
        -- local path = ngx.req.get_body_file()
        -- coraza.request_body_from_file(path)
        local req_body_size = #req_body
        -- TODO req_body_size > req_body_size_opt
        coraza.append_request_body(transaction, req_body)
    end
    coraza.process_request_body(transaction)
end

function _M.build_and_process_get_args(transaction)
    -- process http get args if has
    local arg = ngx.req.get_uri_args()
    for k, v in pairs(arg) do
        if type(v) == "table" then
            nlog(warn_fmt("http get args potentially has HPP!"))
            for _, value in ipairs(v) do
                if type(value) == "string" then
                    -- 类似于 test.com?test 有key无value,value为boolean
                    coraza.add_get_args(transaction, k, value)
                end
            end
        elseif type(v) == "string" then
            -- 类似于 test.com?test 有key无value,value为boolean
            coraza.add_get_args(transaction, k, v)
        end
    end
end

return _M