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

function _M.clear_header_as_body_modified()
    ngx.header.content_length = nil
    -- in case of upstream content is compressed content
    ngx.header.content_encoding = nil

    -- clear cache identifier
    ngx.header.last_modified = nil
    ngx.header.etag = nil
end

function _M.build_and_process_body(transaction)
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    if type(chunk) == "string" and chunk ~= "" then
        -- TODO: 为了性能，客户端响应的二进制内容很有可能是下载或者加密等，
        -- 目前不支持检测二进制响应
        coraza.append_response_body(transaction, chunk)
    end

    if eof then
        coraza.process_response_body(transaction)
    end
end

-- process http req headers
function _M.build_and_process_header(transaction)
    local h = ngx.resp.get_headers(0, true)
    for k, v in pairs(h) do
        if type(v) == "table" then
            nlog(warn_fmt("http response headers potentially has HPP!"))
            for _, value in ipairs(v) do
                coraza.add_response_header(transaction, k, value)
            end
        else
            coraza.add_response_header(transaction, k, v)
        end
    end

    local http_version = ngx.req.http_version()
    if http_version == nil then
        http_version = 1.1
    end

    http_version = fmt("HTTP/%.1f", http_version)
    coraza.process_response_headers(transaction, ngx.status, http_version)
end

return _M
