local coraza = require "resty.coraza.coraza"

local fmt = string.format

local ngx = ngx
local nlog = ngx.log
local ngx_req = ngx.req

local _M = {
    _VERSION = '1.0.0',
}


function _M.build_and_process_header(transaction)
    local headers, err = ngx_req.get_headers(0, true)
    if err then
        err = fmt("failed to call ngx_req.get_headers: %s", err)
        nlog(ngx.ERR, err)
    end
    for k, v in pairs(headers) do
        coraza.add_request_header(transaction, k, v)
    end
    coraza.process_request_headers(transaction)
end

function _M.build_and_process_body(transaction)
    local req_body = ngx_req.get_body_data()
    if not req_body then
        -- TODO: fix code
        local path = ngx_req.get_body_file()
        if not path then
            -- end process
            return
        end
        coraza.request_body_from_file(path)
    else
        local req_body_size = #req_body
        -- TODO req_body_size > req_body_size_opt
        coraza.append_request_body(transaction, req_body)
    end
    coraza.process_request_body(transaction)
end

function _M.build_and_process_get_args(transaction)
    -- process http get args if has
    local arg = ngx_req.get_uri_args()
    for k,v in pairs(arg) do
        coraza.add_get_args(transaction, k, v)
    end
end

return _M



