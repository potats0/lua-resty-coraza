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
            local coraza = require "resty.coraza.response"
            if coraza then
                ngx.say("done")
            end
        }
    }
--- error_code: 200
--- response_body_like eval
"done"

=== TEST 2: clear_header_as_body_modified
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.response"
            coraza.clear_header_as_body_modified()
            ngx.say("done")
        }
    }
--- error_code: 200
--- response_body_like eval
"done"

=== TEST 3: build_and_process_body
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            ngx.ctx.tran = tran
            ngx.say("aaaaaaaaaaaaaaaaaaaa")
            ngx.say("bbbbbbbbbbbbbbbbbbbb")
        }

        body_filter_by_lua_block {
            local response = require "resty.coraza.response"
            response.build_and_process_body(ngx.ctx.tran)
        }
    }
--- error_code: 200
--- error_log eval
["success to invoke coraza_append_response_body with aaaaaaaaaaaaaaaaaaaa",
"success to invoke coraza_append_response_body with bbbbbbbbbbbbbbbbbbbb",
"success to invoke coraza_process_response_body"]

=== TEST 4: build_and_process_header
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            ngx.ctx.tran = tran
            ngx.header.aa="bb"
            ngx.header.cc={"dd", "ee"}
        }

        body_filter_by_lua_block {
            local response = require "resty.coraza.response"
            response.build_and_process_header(ngx.ctx.tran)
        }
    }
--- error_code: 200
--- response_headers
aa:bb
cc:dd, ee
--- error_log eval
["success to invoke coraza_add_response_header with aa:bb",
"with cc:dd", "with cc:ee"]

=== TEST 5: build_and_process_header with http 0.9
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            ngx.ctx.tran = tran
            ngx.header.aa="bb"
            ngx.header.cc={"dd", "ee"}
        }

        body_filter_by_lua_block {
            local response = require "resty.coraza.response"
            response.build_and_process_header(ngx.ctx.tran)
        }
    }

--- request
GET /t  HTTP/1.0
--- error_code: 200
--- response_headers
aa:bb
cc:dd, ee
--- error_log eval
["coraza_process_response_headers with 200 HTTP/1.0"]