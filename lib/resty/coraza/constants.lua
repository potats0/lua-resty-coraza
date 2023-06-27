local t = {}


t.MODE_OFF = "off"
t.MODE_BLOCK = "block"
t.MODE_MONITOR = "monitor"


t.NGX_HTTP_HEADER_PREFIX = "http_"

t.BLOCK_CONTENT_TYPE = "application/json"
t.BLOCK_CONTENT_FORMAT = [[{"code": %d, "message": "This connection was blocked by Coroza!"}]]

return t
