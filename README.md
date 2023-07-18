# lua-resty-coraza
[![Tests](https://github.com/potats0/lua-resty-coraza/actions/workflows/CI.yml/badge.svg)](https://github.com/potats0/lua-resty-coraza/actions/workflows/CI.yml)

## Name

Lua implementation of the [libcoraza](https://github.com/corazawaf/libcoraza) for modsecurity Web Application Firewall.


## dependence

### 1. libcoraza-nginx
1. clone the repository
`git clone https://github.com/potats0/coraza.git`

2. Build the source && Installation
```
cd coraza
./build.sh
./configure
make
sudo make install
```
`libcoraza.so` will be installed at `/usr/local/lib`

### 2. Coreruleset
coreruleset is an opensource waf rules.
1. clone the repository
`git clone https://github.com/coreruleset/coreruleset`

### 3. lua-resty-coraza
```bash
opm get potats0/lua-resty-coraza
```


## Synopsis

```lua

init_worker_by_lua_block{
    coraza = require "resty.coraza"
    waf = coraza.create_waf()
    -- add rule from file
    coraza.rules_add_file(waf, "%s/t/coraza.conf")

    -- your corerule set, add rule from directive
    coraza.rules_add(waf, "Include %s/t/coreruleset/crs-setup.conf.example")
    coraza.rules_add(waf, "Include %s/t/coreruleset/rules/*.conf")
}

location /t {
    access_by_lua_block {
        coraza.do_create_transaction(waf)
        coraza.do_access_filter()
        coraza.do_interrupt()
    }

    content_by_lua_block {
        ngx.say("passed")
    }

    header_filter_by_lua_block{
        coraza.do_header_filter()
        coraza.do_interrupt()
    }
    
    body_filter_by_lua_block{
        coraza.do_body_filter()
    }

    log_by_lua_block{
        coraza.do_log()
        coraza.do_free_transaction()
    }
}
```

if you need more log for debug, please turn on the debug on nginx.

```
error_log logs/error.log debug;
```

the matched rules log will be logged at `ngx.ctx.coraza_msg` by `coraza.do_log()`

# TODO:
1. block response when detected the event