local log = require "resty.coraza.log"
local request = require "resty.coraza.request"
local coraza = require "resty.coraza.coraza"
local consts = require "resty.coraza.constants"

local nlog = ngx.log
local fmt = string.format

local debug_fmt = log.debug_fmt
local err_fmt = log.err_fmt
local warn_fmt = log.warn_fmt

local _M = {
    _VERSION = '1.0.2'
}

function _M.create_waf()
    return coraza.new_waf()  
end

function _M.free_waf(waf)
    return coraza.free_waf(waf)
end

function _M.rules_add_file(waf, file)
    return coraza.rules_add_file(waf, file)
end

function _M.rules_add(waf, directives)
    return coraza.rules_add(waf, directives)
end

function _M.do_access_filter()
    local transaction = ngx.ctx.transaction

    coraza.process_connection(transaction, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)

    -- process uri
    coraza.process_uri(transaction, ngx.var.request_uri, ngx.req.get_method(), ngx.var.server_protocol)

    -- process http get args.The coraza_process_uri function recommends using AddGetRequestArgument to add get args
    request.build_and_process_get_args(transaction)

    -- process http req headers
    request.build_and_process_header(transaction)

    -- process http req body if has
    request.build_and_process_body(transaction)

    ngx.ctx.action, ngx.ctx.status_code = coraza.intervention(transaction)

end

function _M.do_create_transaction(waf)
    -- each connection will be created a transaction
    ngx.ctx.transaction = coraza.new_transaction(waf)
end

function _M.do_free_transaction()
    local transaction = ngx.ctx.transaction
    if transaction ~= nil then
        nlog(debug_fmt("transaction %s is freed by coraza_free_transaction", ngx.ctx.request_id))
        ngx.ctx.transaction = nil
        coraza.free_transaction(transaction)
    end
end

function _M.do_handle()
    -- transaction is interrupted by policy, be free firstly.
    -- If request has disrupted by coraza, the transaction is freed and set to nil.
    -- Response which was disrupted doesn't make sense.
    if ngx.ctx.action ~= nil and ngx.ctx.transaction ~= nil then
        nlog(warn_fmt([[Transaction %s request: "%s" is interrupted by policy. Action is %s]], ngx.ctx.request_id, ngx.var.request, ngx.ctx.action))
        if ngx.ctx.action == "drop" or ngx.ctx.action == "deny" then
            ngx.ctx.is_disrupted = true
            return ngx.ctx.status_code, fmt(consts.BLOCK_CONTENT_FORMAT, ngx.ctx.status_code)
        end
    end
end

function _M.do_interrupt()
    -- transaction is interrupted by policy, be free firstly.
    -- If request has disrupted by coraza, the transaction is freed and set to nil.
    -- Response which was disrupted doesn't make sense.
    if ngx.ctx.is_disrupted == true and ngx.get_phase() == "header_filter" then
        nlog(debug_fmt("Transaction %s has been disrupted at request phrase. ignore", 
        ngx.ctx.request_id))
        return
    end
    local status_code, block_msg = _M.do_handle()
    if status_code ~= nil then
        ngx.status = ngx.ctx.status_code
        local ok, msg = pcall(ngx.say, block_msg)
        if ok == false then
            nlog(err_fmt(msg))
        end
        return ngx.exit(ngx.status)
    end
end

function _M.do_header_filter()
    if ngx.ctx.is_disrupted == true then
        -- If request was interrupted by coraza at access_by_lua phrase, the ngx.ctx.transaction will be set nil.
        -- We can bypass the check.
        nlog(debug_fmt("Transaction %s has been disrupted at request phrase. ignore", 
        ngx.ctx.request_id))
        return
    end
    local h = ngx.resp.get_headers(0, true)
    for k, v in pairs(h) do
        coraza.add_response_header(ngx.ctx.transaction, k, v)
    end
    -- copy from https://github.com/SpiderLabs/ModSecurity-nginx/blob/d59e4ad121df702751940fd66bcc0b3ecb51a079/src/ngx_http_modsecurity_header_filter.c#L527
    coraza.process_response_headers(ngx.ctx.transaction, ngx.status, "HTTP 1.1")

    ngx.ctx.action, ngx.ctx.status_code = coraza.intervention(ngx.ctx.transaction)
end

function _M.do_body_filter()
    -- TODO
end

function _M.do_log()
    coraza.process_logging(ngx.ctx.transaction)
end

return _M
