---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by mac.
--- DateTime: 2023/6/14 09:50
---
local ffi = require "ffi"
local log = require "resty.coraza.log"

local nlog = ngx.log
local ngx_var = ngx.var
local ngx_ctx = ngx.ctx

local err_fmt = log.err_fmt
local debug_fmt = log.debug_fmt

local cast_to_c_char = function(str)
    return ffi.cast("char *", str)
end

-- Contains the target OS name: "Windows", "Linux", "OSX", "BSD", "POSIX" or "Other".
local os_name = ffi.os
if os_name ~= "OSX" and os_name ~= "Linux" then
    nlog(log.err_fmt("Now, the lua_resty_coraza supports Linux or MacOs"))
    nlog(log.err_fmt("%s unsupported platform, exiting! %s\n----", os_name, debug.traceback()))
else 
    nlog(log.debug_fmt("platform %s , loading libcoraza...", os_name))
end

local prefixed_shared_lib = "/usr/local/lib/libcoraza"
local shared_lib_name = os_name == "Linux" and ".so" or ".dylib"
local ok, coraza = pcall(ffi.load, prefixed_shared_lib..shared_lib_name)
if ok ~= true then
    nlog(log.err_fmt("failed to load libcoraza %s , exiting! %s\n----",
    prefixed_shared_lib..shared_lib_name, debug.traceback()))
    return
end
nlog(log.debug_fmt("loading libcoraza with %s successfully", prefixed_shared_lib..shared_lib_name))

ffi.cdef [[
typedef struct coraza_intervention_t
{
	char *action;
	char *log;
    char *url;
    int status;
    int pause;
    int disruptive;
} coraza_intervention_t;

typedef uint64_t coraza_waf_t;
typedef uint64_t coraza_transaction_t;


typedef void (*coraza_log_cb) (const void *);
void send_log_to_cb(coraza_log_cb cb, const char *msg);

/*not used api/ not implement api*/
extern int coraza_update_status_code(coraza_transaction_t t, int code);
extern int coraza_rules_count(coraza_waf_t w);
extern int coraza_rules_merge(coraza_waf_t w1, coraza_waf_t w2, char** er);
extern void coraza_set_log_cb(coraza_waf_t waf, coraza_log_cb cb);


/*initialize phrase/ init_worker_by_lua*/
extern coraza_waf_t coraza_new_waf();
extern int coraza_rules_add_file(coraza_waf_t w, char* file, char** er);
extern int coraza_rules_add(coraza_waf_t w, char* directives, char** er);

/*http request phrase*/
extern coraza_transaction_t coraza_new_transaction(coraza_waf_t waf, void* logCb);
extern coraza_transaction_t coraza_new_transaction_with_id(coraza_waf_t waf, char* id, void* logCb);
extern int coraza_process_connection(coraza_transaction_t t, char* sourceAddress, int clientPort, char* serverHost, int serverPort);
extern int coraza_process_uri(coraza_transaction_t t, char* uri, char* method, char* proto);
extern int coraza_add_get_args(coraza_transaction_t t, char* name, char* value);
extern int coraza_add_request_header(coraza_transaction_t t, char* name, int name_len, char* value, int value_len);
extern int coraza_process_request_headers(coraza_transaction_t t);
extern int coraza_append_request_body(coraza_transaction_t t, unsigned char* data, int length);
extern int coraza_request_body_from_file(coraza_transaction_t t, char* file);
extern int coraza_process_request_body(coraza_transaction_t t);

/*http response phrase*/
extern int coraza_add_response_header(coraza_transaction_t t, char* name, int name_len, char* value, int value_len);
extern int coraza_process_response_headers(coraza_transaction_t t, int status, char* proto);
extern int coraza_append_response_body(coraza_transaction_t t, unsigned char* data, int length);
extern int coraza_process_response_body(coraza_transaction_t t);

/* end */
extern int coraza_process_logging(coraza_transaction_t t);
extern int coraza_free_transaction(coraza_transaction_t t);
extern int coraza_free_intervention(coraza_intervention_t* it);
extern int coraza_free_waf(coraza_waf_t t);
extern coraza_intervention_t* coraza_intervention(coraza_transaction_t tx);
extern char* coraza_get_matched_logmsg(coraza_transaction_t t);
extern int coraza_free_matched_logmsg(char* t);
]]

local _M = {
    _VERSION = '1.0.0'
}
-- global variable to store error value
local err_Str = "error"
local err_in_Ptr = ffi.new("char[?]", #err_Str + 2, err_Str)
local err_Ptr = ffi.new("char*[1]", err_in_Ptr);

function _M.new_waf()
    -- extern coraza_waf_t coraza_new_waf();
    local waf = coraza.coraza_new_waf()
    nlog(debug_fmt("Success to creat new waf"))
    return waf
end

function _M.rules_add_file(waf, conf_file)
    -- extern int coraza_rules_add_file(coraza_waf_t w, char* file, char** er);
    local code = coraza.coraza_rules_add_file(waf, cast_to_c_char(conf_file), err_Ptr)
    if code == 0 then
        local err_log = ffi.string(err_Ptr[0])
        nlog(err_fmt(err_log))
        return false, err_log
    else
        nlog(debug_fmt("Success to load rule file with %s", conf_file))
    end
end

function _M.rules_add(waf, rule)
    -- extern int coraza_rules_add(coraza_waf_t w, char* directives, char** er);
    local code = coraza.coraza_rules_add(waf, cast_to_c_char(rule), err_Ptr)
    if code == 0 then
        local err_log = ffi.string(err_Ptr[0])
        nlog(err_fmt(err_log))
        return false, err_log
    else
        nlog(debug_fmt("Success to load rule with %s", rule))
    end
end

function _M.new_transaction(waf)
    -- a transaction represent a http request and reponse.It should free when
    -- end of process.If there is a memory leak issue, you should focus on
    -- checking whether the transaction objects are correctly released or not.
    -- In end of process, or intervention.
    -- extern coraza_transaction_t coraza_new_transaction(coraza_waf_t waf, void* logCb);
    local res = coraza.coraza_new_transaction(waf, nil)
    ngx_ctx.request_id = ngx_var.request_id
    nlog(debug_fmt("Success to creat new transaction id %s", ngx_ctx.request_id))
    return res
end

function _M.process_connection(transaction, sourceAddress, clientPort, serverHost, serverPort)
    -- extern int coraza_process_connection(coraza_transaction_t t, char* sourceAddress, int clientPort,
    -- char* serverHost, int serverPort);
    local res = coraza.coraza_process_connection(transaction, cast_to_c_char(sourceAddress),
            tonumber(clientPort), cast_to_c_char(serverHost), tonumber(serverPort))
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_process_connection with " ..
                "sourceAddress:%s clientPort:%s serverHost:%s serverPort:%s",
                ngx_ctx.request_id, sourceAddress, clientPort, serverHost, serverPort))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_process_connection with " ..
                "sourceAddress:%s clientPort:%s serverHost:%s serverPort:%s",
                ngx_ctx.request_id, sourceAddress, clientPort, serverHost, serverPort))
    end
end

function _M.process_uri(transaction, uri, method, proto)
    -- This function won't add GET arguments, they must be added with AddArgument
    -- extern int coraza_process_uri(coraza_transaction_t t, char* uri, char* method, char* proto);
    local res = coraza.coraza_process_uri(transaction, cast_to_c_char(uri),
            cast_to_c_char(method), cast_to_c_char(proto))
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_process_uri with %s %s %s",
                ngx_ctx.request_id, ngx_ctx.request_id, method, uri, proto))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_process_uri with %s %s %s",
                ngx_ctx.request_id, method, uri, proto))
    end
end

function _M.add_request_header(transaction, header_name, header_value)
    -- extern int coraza_add_request_header(coraza_transaction_t t, char* name, int name_len,
    --                                      char* value, int value_len);
    local res = coraza.coraza_add_request_header(transaction, cast_to_c_char(header_name), #header_name,
            cast_to_c_char(header_value), #header_value)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_add_request_header with %s:%s",
                ngx_ctx.request_id, header_name, header_value))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_add_request_header with %s:%s",
                ngx_ctx.request_id, header_name, header_value))
    end
end

function _M.add_get_args(transaction, header_name, header_value)
    -- extern int coraza_add_get_args(coraza_transaction_t t, char* name, char* value);
    local res = coraza.coraza_add_get_args(transaction, cast_to_c_char(header_name),
            cast_to_c_char(header_value))
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_add_get_args with %s:%s",
                ngx_ctx.request_id, header_name, header_value))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_add_get_args with %s:%s",
                ngx_ctx.request_id, header_name, header_value))
    end
end

function _M.process_request_headers(transaction)
    -- extern int coraza_process_request_headers(coraza_transaction_t t);
    local res = coraza.coraza_process_request_headers(transaction)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_process_request_headers",
                ngx_ctx.request_id))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_process_request_headers",
                ngx_ctx.request_id))
    end
end

function _M.intervention(transaction)
    -- extern coraza_intervention_t* coraza_intervention(coraza_transaction_t tx);
    local intervention = coraza.coraza_intervention(transaction)
    if intervention ~= nil then
        local action = ffi.string(intervention.action)
        local status_code = tonumber(intervention.status)
        --free intervention to avoid memory leak
        coraza.coraza_free_intervention(intervention)
        nlog(debug_fmt("Transaction %s disrupted with status %s action %s",
                ngx_ctx.request_id, status_code, action))
        return action, status_code
    else
        nlog(debug_fmt("Failed to disrupt transaction %s", ngx_ctx.request_id))
        return nil, nil
    end

end

function _M.free_transaction(transaction)
    -- extern int coraza_free_transaction(coraza_transaction_t t);
    local res = coraza.coraza_free_transaction(transaction)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_free_transaction",
                ngx_ctx.request_id))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_free_transaction",
                ngx_ctx.request_id))
    end
end

function _M.append_request_body(transaction, body)
    -- extern int coraza_append_request_body(coraza_transaction_t t, unsigned char* data, int length);
    local res = coraza.coraza_append_request_body(transaction, cast_to_c_char(body), #body)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_append_request_body with %s",
                ngx_ctx.request_id, body))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_append_request_body with %s",
                ngx_ctx.request_id, body))
    end
end

function _M.request_body_from_file(transaction, file_path)
    -- extern int coraza_request_body_from_file(coraza_transaction_t t, char* file);
    -- return 0 if success, otherwish return 1
    local res = coraza.coraza_request_body_from_file(transaction, cast_to_c_char(file_path))
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_request_body_from_file with %s",
                ngx_ctx.request_id, file_path))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_request_body_from_file with %s",
                ngx_ctx.request_id, file_path))
    end
end

function _M.process_request_body(transaction)
    -- extern int coraza_process_request_body(coraza_transaction_t t);
    local res = coraza.coraza_process_request_body(transaction)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_process_request_body",
                ngx_ctx.request_id))
    else
        nlog(debug_fmt("Transaction %s uccess to invoke coraza_process_request_body",
                ngx_ctx.request_id))
    end
end

-- for processing response

function _M.process_response_headers(transaction, status_code, proto)
    -- extern int coraza_process_response_headers(coraza_transaction_t t, int status, char* proto);
    local res = coraza.coraza_process_response_headers(transaction, tonumber(status_code), cast_to_c_char(proto))
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_process_response_headers with %s %s",
                ngx_ctx.request_id, status_code, proto))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_process_response_headers with %s %s",
                ngx_ctx.request_id, status_code, proto))
    end
end

function _M.add_response_header(transaction, header_name, header_value)
    -- extern int coraza_add_response_header(coraza_transaction_t t, char* name,
    --                                       int name_len, char* value, int value_len);
    local res = coraza.coraza_add_response_header(transaction, cast_to_c_char(header_name), #header_name,
            cast_to_c_char(header_value), #header_value)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_add_response_header with %s:%s",
                ngx_ctx.request_id, header_name, header_value))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_add_response_header with %s:%s",
                ngx_ctx.request_id, header_name, header_value))
    end
end

function _M.append_response_body(transaction, body)
    local res = coraza.coraza_append_response_body(transaction, cast_to_c_char(body), #body)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_append_response_body with %s",
                ngx_ctx.request_id, body))
    else
        nlog(debug_fmt("Transaction %s success to invoke coraza_append_response_body with %s",
                ngx_ctx.request_id, body))
    end
end

function _M.process_response_body(transaction)
    local res = coraza.coraza_process_response_body(transaction)
    if res == 1 then
        nlog(err_fmt("Transaction %s failed to invoke coraza_process_response_body",
                ngx_ctx.request_id))
    else
        nlog(debug_fmt("Transaction %s uccess to invoke coraza_process_response_body",
                ngx_ctx.request_id))
    end
end

function _M.get_matched_logmsg(transaction)
    local c_str = coraza.coraza_get_matched_logmsg(transaction)
    nlog(debug_fmt("Transaction %s uccess to invoke coraza_get_matched_logmsg",
    ngx_ctx.request_id))
    local res = ffi.string(c_str)
    coraza.coraza_free_matched_logmsg(c_str)
    return res
end

function _M.process_logging(transaction)
    coraza.coraza_process_logging(transaction)
    nlog(debug_fmt("Transaction %s uccess to invoke coraza_process_logging",
                ngx_ctx.request_id))
end

return _M