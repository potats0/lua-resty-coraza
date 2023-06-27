use Test::Nginx::Socket 'no_plan';

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
    lua_socket_log_errors off;
    lua_code_cache on;
    lua_need_request_body on;
    init_worker_by_lua_block{
            local coraza = require "resty.coraza"
            coraza.do_init()
            coraza.rules_add([[SecRule REQUEST_HEADERS:User-Agent "Mozilla" "phase:1, id:3,drop,status:452,log,msg:'Blocked User-Agent'"]])
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
--- more_headers
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.44
--- request
POST /t/shell.php
aaaaaaaaa=aaaaaa
--- error_code: 452
--- response_body_like eval
'{"code": 452, "message": "This connection was blocked by Coroza!"}'