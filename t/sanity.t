use Test::Nginx::Socket 'no_plan';

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
    lua_socket_log_errors off;
    lua_need_request_body on;
_EOC_

our $LocationConfig = <<'_EOC_';
    location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza"
            local waf = coraza.create_waf()
            if waf then
                ngx.say("done")
            end
            
        }
    }
_EOC_

add_block_preprocessor(sub {
    my ($block) = @_;

    if (!defined $block->request) {
        $block->set_value("request", "GET /t");
    }
});

no_shuffle();
no_long_string();
no_root_location();
run_tests();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            if waf then
                ngx.say("done")
            end
        }
    }
--- error_code: 200
--- response_body_like eval
"done"
--- error_log eval
["Success to creat new waf"]

=== TEST 2: test to release waf pointer
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            coraza.free_waf(waf)
        }
    }
--- error_code: 200
--- error_log eval
["Success to creat new waf", "Success to free new waf"]

=== TEST 3: test rules_add_file
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local ok, msg = coraza.rules_add_file(waf, "non-exist")
            ngx.say(msg)
        }
    }
--- error_code: 200
--- response_body_like eval
"failed to readfile: open non-exist: no such file or directory"

=== TEST 4: test rules_add with sec ssss
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local ok, msg = coraza.rules_add(waf, "sec ssss")
            ngx.say(msg)
        }
    }
--- error_code: 200
--- response_body_like eval
"unknown directive \"sec\""

=== TEST 5: test rules_add with SecRule REQUEST_HEADERS:User-Agent "Mozilla" "phase:1, id:3,drop,status:452,log,msg:'Blocked User-Agent'"
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local ok, msg = coraza.rules_add(waf, [[SecRule REQUEST_HEADERS:User-Agent "Mozilla" "phase:1, id:3,drop,status:452,log,msg:'Blocked User-Agent'"]])
            ngx.say(msg)
        }
    }
--- error_code: 200
--- error_log eval
["Success to load rule with"]

=== TEST 6: test new_transaction
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local ok, msg = coraza.new_transaction(waf)
        }
    }
--- error_code: 200
--- error_log eval
["Success to creat new transaction"]

=== TEST 7: test new_transaction with nil waf pointer
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local ok, msg = coraza.new_transaction()
        }
    }
--- error_code: 200
--- error_log eval
["Failed to creat new transaction"]

=== TEST 8: test process_connection
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(tran, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
        }
    }
--- error_code: 200
--- error_log eval
["success to invoke coraza_process_connection with"]

=== TEST 9: test process_connection with error
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(nil, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
        }
    }
--- error_code: 200
--- error_log eval
["failed to invoke coraza_process_connection with"]

=== TEST 10: test process_uri
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(tran, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
            coraza.process_uri(tran, "GET", "/index.php?a=1", "http/1.1")
            coraza.process_uri(tran, "aa", "/index.php?a=1", "http/1.1")
            coraza.process_uri(nil, "aa", "/index.php?a=1", "http/1.1")
        }
    }
--- error_code: 200
--- error_log eval
["success to invoke coraza_process_uri with", "failed to invoke coraza_process_uri with"]

=== TEST 11: test add_request_header
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(tran, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
            coraza.process_uri(tran, "GET", "/index.php?a=1", "http/1.1")
            coraza.add_request_header(tran, "key", "value")
        }
    }
--- error_code: 200
--- error_log eval
["success to invoke coraza_add_request_header with key:value"]

=== TEST 12: test add_request_header with error
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(tran, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
            coraza.process_uri(tran, "GET", "/index.php?a=1", "http/1.1")
            coraza.add_request_header(nil, "key", "value")
        }
    }
--- error_code: 200
--- error_log eval
["failed to invoke coraza_add_request_header with key:value"]

=== TEST 12: test add_get_args 
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(tran, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
            coraza.process_uri(tran, "GET", "/index.php?a=1", "http/1.1")
            coraza.add_request_header(tran, "key", "value")
            coraza.add_get_args(tran, "key", "value")
        }
    }
--- error_code: 200
--- error_log eval
["success to invoke coraza_add_get_args with key:value"]

=== TEST 13: test add_get_args with error
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(tran, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
            coraza.process_uri(tran, "GET", "/index.php?a=1", "http/1.1")
            coraza.add_request_header(tran, "key", "value")
            coraza.add_get_args(nil, "key", "value")
        }
    }
--- error_code: 200
--- error_log eval
["failed to invoke coraza_add_get_args with key:value"]

=== TEST 13: test process_request_headers
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            coraza.process_connection(tran, ngx.var.remote_addr,  ngx.var.remote_port,
            ngx.var.server_addr, ngx.var.server_port)
            coraza.process_uri(tran, "GET", "/index.php?a=1", "http/1.1")
            coraza.add_request_header(tran, "key", "value")
            coraza.process_request_headers(tran)
        }
    }
--- error_code: 200
--- error_log eval
["success to invoke coraza_process_request_headers"]
