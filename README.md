1 . ffi 调用 C动态库中函数时，如果函数时有类似 char** （char的指针的指针）类型的的参数时，lua 代码中，按如下方式申明变量，并分配好内存空间：

local initValue = "这是初始值"
local inLen = string.len(initValue)
local inStr  = ffi.new("char[?]", inLen + 2, initValue)
local inPtr  = ffi.new("char*[1]", inStr);
-- 这里的 inPtr 就可以传入 C 函数中了，对应是参数类型应是 char**, 如果有C函数中对此参数有变更，
-- 则可以在lua中获取到返回值

2. 如何集成到openresty里？

因为cgo的多线程会死锁 https://www.v2ex.com/t/568117
所以必须在init_worker阶段加载cgo代码 必须这样配置

```
    init_worker_by_lua_block{
            local coraza = require "resty.coraza"
            coraza.do_init()
            coraza.rules_add([[SecRule REQUEST_HEADERS:User-Agent "Mozilla" "phase:1, id:3,drop,status:452,log,msg:'Blocked User-Agent'"]])
    }
```
其他一切正常
```
    location /t {
        access_by_lua_block {
            local coraza = require "resty.coraza"
            coraza.do_access_filter()
        }

        header_filter_by_lua_block{
            local coraza = require "resty.coraza"
            coraza.do_header_filter()
        }

        log_by_lua_block{
            local coraza = require "resty.coraza"
            coraza.do_free()
        }
```

3. 因为在调用go的时候，go并没有转换`char *`到go中string，只是单纯做了类型转换。也就是说，在调用期间一定要保证lua字符串不会被free，不然go中很有可能产生UAF漏洞。但是好在lua vm会自动管理内存，这点不必担心

4. 编译好的动态共享库，macos放到`/usr/local/lib/libcoraza.dylib` linux同样也在`/usr/local/lib/libcoraza.so`