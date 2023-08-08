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

local _M = {
    _VERSION = '1.0.0'
}

local fmt = string.format

local ERR = ngx.ERR
local WARN = ngx.WARN
local DEBUG = ngx.DEBUG

local function log(formatstring, ...)
    local str = "PID: "..ngx.worker.pid()..
                "\tphrase: "..ngx.get_phase()
    if ngx.ctx.request_id ~= nil then
        str = str.."\tTransaction: "..ngx.ctx.request_id
    end
    str = str.."\tlua-resty-coraza: "..formatstring
    return fmt(str, ...)
end

function _M.err_fmt(formatstring, ...)
    return ERR, log(formatstring, ...)
end

function _M.warn_fmt(formatstring, ...)
    return WARN, log(formatstring, ...)
end

function _M.debug_fmt(formatstring, ...)
    return DEBUG, log(formatstring, ...)
end

return _M