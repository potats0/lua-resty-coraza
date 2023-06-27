use Test::Nginx::Socket 'no_plan';

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
    lua_socket_log_errors off;
    lua_code_cache on;
    lua_need_request_body on;
    init_worker_by_lua_block{
            local coraza = require "resty.coraza"
            coraza.do_init()
   }
_EOC_

our $LocationConfig = <<'_EOC_';
    location /t {
            access_by_lua_block {
            local coraza = require "resty.coraza"
            coraza.do_access_filter()
        }

        content_by_lua_block {
            ngx.say("passed")
        }

        header_filter_by_lua_block{
            local coraza = require "resty.coraza"
            coraza.do_header_filter()
        }

        log_by_lua_block{
            local coraza = require "resty.coraza"
            coraza.do_free()
        }
    }
_EOC_

# master_on();
# workers(4);
run_tests();

__DATA__

=== TEST 1: integration test blocked
--- http_config eval: $::HttpConfig
--- config eval: $::LocationConfig
--- request
POST /t/shell.php
aaaaaaaaa=aaaaaa
--- error_code: 200
--- response_body_like eval
"passed"