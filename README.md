A small JSON decoder for Lua.


## Usage
Just require [moonson.lua](moonson.lua?raw=1) from your Lua script like

```lua
moonson = require "moonson"
```

Then just call moonson.decode with the string you want to decode.

```lua
json_object = moonson.decode(json_encoded_string)
```

## Comparison
moonson is pretty fast. In interpreted (vanilla) Lua, it is faster than rxi's [json.lua](https://github.com/rxi/json.lua). json.lua
is a bit faster in LuaJIT though.

## License
This library is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.
