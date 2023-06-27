local log = require "resty.coraza.log"
local request = require "resty.coraza.request"
local coraza = require "resty.coraza.coraza"
local consts = require "resty.coraza.constants"

local nlog = ngx.log
local ngx_var = ngx.var
local ngx_ctx = ngx.ctx
local ngx_req = ngx.req
local fmt = string.format

local debug_fmt = log.debug_fmt
local err_fmt = log.err_fmt
local warn_fmt = log.warn_fmt

local _M = {
    _VERSION = '1.0.0'
}

function _M.do_init()
    _M.waf = coraza.new_waf()
end

function _M.rules_add_file(file)
    coraza.rules_add_file(_M.waf, file)
end

function _M.rules_add(directives)
    coraza.rules_add(_M.waf, directives)
end

function _M.do_access_filter()
    -- each connection will be created a transaction
    local transaction = coraza.new_transaction(_M.waf)
    ngx_ctx.transaction = transaction

    coraza.process_connection(transaction, ngx_var.remote_addr,  ngx_var.remote_port,
            ngx_var.server_addr, ngx_var.server_port)

    -- process uri
    coraza.process_uri(transaction, ngx_var.request_uri, ngx_req.get_method(), ngx_var.server_protocol)

    -- process http get args.The coraza_process_uri function recommends using AddGetRequestArgument to add get args
    request.build_and_process_get_args(transaction)

    -- process http req headers
    request.build_and_process_header(transaction)

    -- process http req body if has
    request.build_and_process_body(transaction)

    ngx_ctx.action, ngx_ctx.status_code = coraza.intervention(transaction)
    _M.do_handle()
end

function _M.do_free()
    local transaction = ngx_ctx.transaction
    if transaction ~= nil then
        nlog(debug_fmt("transaction %s is freed by coraza_free_transaction", ngx_ctx.request_id))
        ngx_ctx.transaction = nil
        coraza.free_transaction(transaction)
    end
end

function _M.do_handle()
    -- transaction is interrupted by policy, be free firstly.
    -- If request has disrupted by coraza, the transaction is freed and set to nil.
    -- Response which was disrupted doesn't make sense.
    if ngx_ctx.action ~= nil and ngx_ctx.transaction ~= nil then
        nlog(warn_fmt([[Transaction %s request: "%s" is interrupted by policy. Action is %s]],
                ngx_ctx.request_id, ngx_var.request, ngx_ctx.action))
        if ngx_ctx.action == "drop" then
            ngx.status = ngx_ctx.status_code
            local ok, msg = pcall(ngx.say, fmt(consts.BLOCK_CONTENT_FORMAT, ngx_ctx.status_code))
            if ok == false then
                nlog(err_fmt(msg))
            end
            return ngx.exit(ngx.status)
            -- TODO: disrupted by more action
            --elseif ngx_ctx.action == "deny" then
            --    ngx.status = ngx_ctx.status_code
            --    -- NYI: cannot call this C function (yet)
            --    -- ngx.header.content_type = consts.BLOCK_CONTENT_TYPE
            --    ngx.say(fmt(consts.BLOCK_CONTENT_FORMAT, ngx_ctx.status_code))
            --    return ngx.exit(ngx.status)
        end
    end
end

function _M.do_header_filter()
    if ngx_ctx.action ~= nil then
        -- If request was interrupted by coraza at access_by_lua phrase, the ngx_ctx.transaction will be set nil.
        -- We can bypass the check.
        nlog(debug_fmt("Transaction %s has been disrupted at request phrase. ignore", ngx_ctx.request_id))
        return
    end
    local h = ngx.resp.get_headers(0, true)
    for k, v in pairs(h) do
        coraza.add_response_header(ngx_ctx.transaction, k, v)
    end
    -- copy from https://github.com/SpiderLabs/ModSecurity-nginx/blob/d59e4ad121df702751940fd66bcc0b3ecb51a079/src/ngx_http_modsecurity_header_filter.c#L527
    coraza.process_response_headers(ngx_ctx.transaction, ngx.status, "HTTP 1.1")

    -- TODO: add http response body to coraza.append_response_body. Openresty can't disrupt the body_filter phrase
    --local resp_body = string.sub(ngx.arg[1], 1, 1000)
    --ngx.ctx.buffered = (ngx.ctx.buffered or "") .. resp_body
    --if ngx.arg[2] then
    --    ngx.var.resp_body = ngx.ctx.buffered
    --end
    --
    --coraza.append_response_body(ngx_ctx.transaction, ngx.ctx.buffered)
    --coraza.process_response_body(ngx_ctx.transaction)

    ngx_ctx.action, ngx_ctx.status_code = coraza.intervention(ngx_ctx.transaction)
    _M.do_handle()
end

return _M
