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
            local request = require "resty.coraza.request"
            if request then
                ngx.say("done")
            end
        }
    }
--- error_code: 200
--- response_body_like eval
"done"

=== TEST 2: build_and_process_header
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local request = require "resty.coraza.request"
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            request.build_and_process_header(tran)
            ngx.say("done")
        }
    }

--- more_headers
aaa: bbbb
cc:dd
cc:ee
--- error_code: 200
--- response_body_like eval
"done"
--- error_log eval
[
    "success to invoke coraza_add_request_header with aaa:bbbb",
    "potentially has HPP",
    "coraza_add_request_header with cc:dd",
    "coraza_add_request_header with cc:ee"
]

=== TEST 3: build_and_process_body with simple body
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local request = require "resty.coraza.request"
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            request.build_and_process_body(tran)
            ngx.say("done")
        }
    }
--- request
POST /t
aaa=bbb
--- error_code: 200
--- response_body_like eval
"done"
--- error_log eval
[
    "success to invoke coraza_append_request_body with aaa=bbb", 
    "success to invoke coraza_process_request_body"
]

=== TEST 4: build_and_process_body with Json body
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local request = require "resty.coraza.request"
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            request.build_and_process_body(tran)
            ngx.say("done")
        }
    }

--- more_headers
content-type: application/json
--- request
POST /t
[{
	"msg": "Blocked User-Agent",
	"data": "User-Agent:Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.44",
}]
--- error_code: 200
--- response_body_like eval
"done"
--- error_log eval
[
    "Blocked User-Agent", 
    "User-Agent:Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7",
    "success to invoke coraza_process_request_body"
]

=== TEST 5: build_and_process_body with multipart-formdata
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local request = require "resty.coraza.request"
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            request.build_and_process_body(tran)
            ngx.say("done")
        }
    }

--- more_headers
Content-Type: multipart/form-data; boundary=boundary1234567890
--- request
POST /t/upload
--boundary1234567890
Content-Disposition: form-data; name="username"

John Doe
--boundary1234567890
Content-Disposition: form-data; name="profile_pic"; filename="pic.jpg"
Content-Type: image/jpeg

[Binary data goes here]
--boundary1234567890
Content-Disposition: form-data; name="email"

john.doe@example.com
--boundary1234567890--
--- error_code: 200
--- response_body_like eval
"done"
--- error_log eval
[
    "success to invoke coraza_append_request_body with --boundary1234567890",
    "--boundary1234567890",
    "success to invoke coraza_process_request_body"
]

=== TEST 6: build_and_process_body with none body
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local request = require "resty.coraza.request"
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            request.build_and_process_body(tran)
            ngx.say("done")
        }
    }

--- request
POST /t/upload
--- error_code: 200
--- response_body_like eval
"done"
--- error_log eval
[
    "success to invoke coraza_process_request_body"
]

=== TEST 7: build_and_process_get_args
--- http_config eval: $::HttpConfig
--- config     
location /t {
        content_by_lua_block {
            local request = require "resty.coraza.request"
            local coraza = require "resty.coraza.coraza"
            local waf = coraza.new_waf()
            local tran = coraza.new_transaction(waf)
            request.build_and_process_get_args(tran)
            ngx.say("done")
        }
    }

--- request
POST /t/upload?aaa=bbb&ccc=ddd&eee=fff&eee=ggg
--- error_code: 200
--- response_body_like eval
"done"
--- error_log eval
[
    "success to invoke coraza_add_get_args with aaa:bbb",
    "http get args potentially has HPP!",
    "with eee:fff",
    "with eee:ggg",
    "with ccc:ddd"
]

