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

local ffi = require "ffi"
local log = require "resty.coraza.log"

local nlog = ngx.log

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

function _M.free_waf(waf)
    -- extern int coraza_free_waf(coraza_waf_t t);
    coraza.coraza_free_waf(waf)
    nlog(debug_fmt("Success to free new waf"))
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
    local ok, msg = pcall(coraza.coraza_new_transaction, waf, nil)
    if ok then
        ngx.ctx.request_id = ngx.var.request_id
        nlog(debug_fmt("Success to creat new transaction"))
        return msg
    else
        nlog(debug_fmt("Failed to creat new transaction, msg: %s", msg))
    end
end

function _M.process_connection(transaction, sourceAddress, clientPort, serverHost, serverPort)
    -- extern int coraza_process_connection(coraza_transaction_t t, char* sourceAddress, int clientPort,
    -- char* serverHost, int serverPort);
    local ok, msg = pcall(coraza.coraza_process_connection, transaction, cast_to_c_char(sourceAddress),
            tonumber(clientPort), cast_to_c_char(serverHost), tonumber(serverPort))
    if ok then
        nlog(debug_fmt("success to invoke coraza_process_connection with " ..
            "sourceAddress:%s clientPort:%s serverHost:%s serverPort:%s",
            sourceAddress, clientPort, serverHost, serverPort))
    else
        nlog(err_fmt("failed to invoke coraza_process_connection with " ..
            "sourceAddress:%s clientPort:%s serverHost:%s serverPort:%s msg: %s",
            sourceAddress, clientPort, serverHost, serverPort, msg))
    end
end

function _M.process_uri(transaction, uri, method, proto)
    -- This function won't add GET arguments, they must be added with AddArgument
    -- extern int coraza_process_uri(coraza_transaction_t t, char* uri, char* method, char* proto);
    local ok, msg = pcall(coraza.coraza_process_uri, transaction, cast_to_c_char(uri),
            cast_to_c_char(method), cast_to_c_char(proto))
    if ok then
        nlog(debug_fmt("success to invoke coraza_process_uri with %s %s %s",
                        method, uri, proto))
    else
        nlog(err_fmt("failed to invoke coraza_process_uri with %s %s %s. msg: %s",
                      method, uri, proto, msg))
    end
end

function _M.add_request_header(transaction, header_name, header_value)
    -- extern int coraza_add_request_header(coraza_transaction_t t, char* name, int name_len,
    --                                      char* value, int value_len);
    local ok, msg = pcall(coraza.coraza_add_request_header, transaction, 
    cast_to_c_char(header_name), #header_name, cast_to_c_char(header_value), #header_value)
    if ok then
        nlog(debug_fmt("success to invoke coraza_add_request_header with %s:%s",
                        header_name, header_value))
    else
        nlog(err_fmt("failed to invoke coraza_add_request_header with %s:%s. msg: %s",
                    header_name, header_value, msg))
    end
end

function _M.add_get_args(transaction, header_name, header_value)
    -- extern int coraza_add_get_args(coraza_transaction_t t, char* name, char* value);
    local ok, msg  = pcall(coraza.coraza_add_get_args, transaction, 
    cast_to_c_char(header_name), cast_to_c_char(header_value))
    if ok then
        nlog(debug_fmt("success to invoke coraza_add_get_args with %s:%s", 
                        header_name, header_value))
    else
        nlog(err_fmt("failed to invoke coraza_add_get_args with %s:%s. msg: %s",
                      header_name, header_value, msg))
    end
end

function _M.process_request_headers(transaction)
    -- extern int coraza_process_request_headers(coraza_transaction_t t);
    local ok, msg = pcall(coraza.coraza_process_request_headers, transaction)
    if ok then
        nlog(debug_fmt("success to invoke coraza_process_request_headers"))
    else
        nlog(err_fmt("failed to invoke coraza_process_request_headers. msg: %s", msg))
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
        if status_code == 0 then
            status_code = 403
        end
        nlog(debug_fmt("disrupted with status %s action %s", status_code, action))
        return action, status_code
    else
        nlog(debug_fmt("Failed to disrupt, action is nil"))
        return nil, nil
    end

end

function _M.free_transaction(transaction)
    -- extern int coraza_free_transaction(coraza_transaction_t t);
    local ok, msg = coraza.coraza_free_transaction(transaction)
    if ok then
        nlog(debug_fmt("success to invoke coraza_free_transaction"))
    else
        nlog(err_fmt("failed to invoke coraza_free_transaction. msg: %s", msg))
    end
end

function _M.append_request_body(transaction, body)
    -- extern int coraza_append_request_body(coraza_transaction_t t, unsigned char* data, int length);
    local ok, msg = pcall(coraza.coraza_append_request_body, transaction, 
                         cast_to_c_char(body), #body)
    if ok then
        nlog(debug_fmt("success to invoke coraza_append_request_body with %s", body))
    else
        nlog(err_fmt("failed to invoke coraza_append_request_body with %s. msg: %s", body, msg))
    end
end

function _M.request_body_from_file(transaction, file_path)
    -- extern int coraza_request_body_from_file(coraza_transaction_t t, char* file);
    -- return 0 if success, otherwish return 1
    local ok, msg = pcall(coraza.coraza_request_body_from_file,
                          transaction, cast_to_c_char(file_path))
    if ok then
        nlog(debug_fmt("success to invoke coraza_request_body_from_file with %s", file_path))
    else
        nlog(err_fmt("failed to invoke coraza_request_body_from_file with %s. msg: %s", file_path, msg))
    end
end

function _M.process_request_body(transaction)
    -- extern int coraza_process_request_body(coraza_transaction_t t);
    local ok, msg = pcall(coraza.coraza_process_request_body, transaction)
    if ok then
        nlog(debug_fmt("success to invoke coraza_process_request_body"))
    else
        nlog(err_fmt("failed to invoke coraza_process_request_body. msg: %s", msg))
    end
end

-- for processing response
function _M.process_response_headers(transaction, status_code, proto)
    -- extern int coraza_process_response_headers(coraza_transaction_t t, int status, char* proto);
    local ok, msg = pcall(coraza.coraza_process_response_headers,transaction, 
                         tonumber(status_code), cast_to_c_char(proto))
    if ok then
        nlog(debug_fmt("success to invoke coraza_process_response_headers with %s %s",
                        status_code, proto))
    else
        nlog(err_fmt("failed to invoke coraza_process_response_headers with %s %s, msg: %s",
                      status_code, proto, msg))
    end
end

function _M.add_response_header(transaction, header_name, header_value)
    -- extern int coraza_add_response_header(coraza_transaction_t t, char* name,
    --                                       int name_len, char* value, int value_len);
    local ok, msg = pcall(coraza.coraza_add_response_header, transaction, cast_to_c_char(header_name), #header_name, cast_to_c_char(header_value), #header_value)
    if ok then
        nlog(debug_fmt("success to invoke coraza_add_response_header with %s:%s",
                        header_name, header_value))
    else
        nlog(err_fmt("failed to invoke coraza_add_response_header with %s:%s. msg: %s",
                     header_name, header_value, msg))
    end
end

function _M.append_response_body(transaction, body)
    local ok, msg = pcall(coraza.coraza_append_response_body, transaction, 
                          cast_to_c_char(body), #body)
    if ok then
        nlog(debug_fmt("success to invoke coraza_append_response_body with %s", body))
    else
        nlog(err_fmt("failed to invoke coraza_append_response_body with %s, msg: %s", body, msg))
    end
end

function _M.process_response_body(transaction)
    local ok, msg = pcall(coraza.coraza_process_response_body,transaction)
    if ok then
        nlog(debug_fmt("success to invoke coraza_process_response_body"))
    else
        nlog(err_fmt("failed to invoke coraza_process_response_body. msg: %s", msg))
    end
end

function _M.process_logging(transaction)
    local ok, msg = pcall(coraza.coraza_process_logging, transaction)
    if ok then
        nlog(debug_fmt("success to invoke coraza_process_logging"))
    else 
        nlog(debug_fmt("failed to invoke coraza_process_logging. msg: %s", msg))
    end
end

return _M