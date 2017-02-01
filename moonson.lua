--
-- moonson
--
-- Copyright (c) 2016-2017, Florian Keßeler
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local parse_value

local function throw(str, idx, err)
  error("JSON error in '" .. str:gsub('[\r\n]', '\\n', 2):gsub('[\r\n].*$', '...') .. "':" .. tostring(idx) .. ': ' .. err, 2)
end


local escape_characters = {
  ['"' ] = '"',
  ['\\'] = '\\',
  ['/' ] = '/',
  ['b' ] = '\b',
  ['f' ] = '\f',
  ['n' ] = '\n',
  ['r' ] = '\r',
  ['t' ] = '\t',
}


local function convert_escape_sequence(esc)
  local r = escape_characters[esc]
  if not r then
    return nil, "\\" .. esc
  end
  return r
end


local function convert_unicode_codepoint(ucp)
  if ucp <= 0x7F then
    return string.char(ucp)
  elseif ucp <= 0x7FF then
    return string.char(
      0xC0 + math.floor(ucp / 0x40),      -- 0xC0 | (ucp >> 6)
      0x80 + ucp % 0x40                   -- 0x80 | (ucp & 0x3F)
    )
  elseif ucp <= 0xFFFF then
    local floor = math.floor
    return string.char(
      0xE0 + floor(ucp / 0x1000),         -- 0xE0 | (ucp >> 12)
      0x80 + floor(ucp / 0x40) % 0x40,    -- 0x80 | ((ucp >> 6) & 0x3F)
      0x80 + ucp % 0x40                   -- 0x80 | (ucp & 0x3F)
    )
  elseif ucp <= 0x10FFFF then
    local floor = math.floor
    return string.char(
      0xF0 + floor(ucp / 0x40000),        -- 0xF0 | (ucp >> 18)
      0x80 + floor(ucp / 0x1000) % 0x40,  -- 0x80 | ((ucp >> 12) & 0x3F)
      0x80 + floor(ucp / 0x40) % 0x40,    -- 0x80 | ((ucp >> 6) & 0x3F)
      0x80 + ucp % 0x40                   -- 0x80 | (ucp & 0x3F)
    )
  else
    return nil, string.format("U+%X", ucp)
  end
end


local function convert_unicode(esc)
  local ucp = tonumber(esc, 16)
  if ucp >= 0xD800 and ucp <= 0xDFFF then
    return nil, string.format("U+%s", esc)
  end

  return convert_unicode_codepoint(ucp)
end


local function convert_unicode_surrogate(esc_a, esc_b)
  return convert_unicode_codepoint(
    (tonumber(esc_a, 16) - 0x800) * 1024 + 
    (tonumber(esc_b, 16) - 0xC00) +
    0x10000)
end


local function parse_string(str, start)
  local result = ""
  start = start + 1

  while true do
    local e = str:find('[%c\\"]', start)
    if not e then
      throw(str, #str, "Input ended unexpectedly")
    end
    result = result .. str:sub(start, e-1)

    local c = str:sub(e,e)

    if c == '"' then
      return result, e+1
    elseif c == '\\' then
      if str:find('^\\u[Dd][89ABab]%x%x\\u[Dd][CDEFcdef]%x%x', e) then
        local res, err = convert_unicode_surrogate(str:sub(e+3, e+5), str:sub(e+9, e+11))
        if err then
          throw(str, e, "Invalid unicode codepoint " .. err)
        end
        result = result .. res
        start = e + 12
      elseif str:find('^\\u%x%x%x%x', e) then
        local res, err = convert_unicode(str:sub(e+2, e+5))
        if err then
          throw(str, e, "Invalid unicode codepoint " .. err)
        end
        result = result .. res
        start = e + 6
      else
        local res, err = convert_escape_sequence(str:sub(e+1, e+1))
        if err then
          throw(str, e, "Invalid escape sequence '" .. err .. "'")
        end
        result = result .. res
        start = e + 2
      end
    else
      throw(str, e, "Control character 0x" .. str:byte(e))
    end
  end

end


local function literal_parser(literal, value)
  return function(str, start)
    local s, e = str:find('^' .. literal, start)
    if not e then
      s, e = str:find('^%a+', start)
      throw(str, start, "Invalid literal '" .. str:sub(s, e) .. "'")
    end

    return value, e+1
  end
end


local function skip_ws(str, start)
  local first_non_ws = str:find('[^%s]', start)

  if not first_non_ws then
    throw(str, start, "Input ends unexpectedly")
  end

  return first_non_ws
end


local function parse_object(str, start)
  local object = {}

  start = skip_ws(str, start+1)
  if str:sub(start, start) == '}' then
    return object, start + 1
  end

  while true do
    local key, value
    key, start = parse_string(str, start)
    start = skip_ws(str, start)

    if str:sub(start, start) ~= ':' then
      throw(str, start, "Expected ':' instead of '" .. str:sub(start, start) .. "'")
    end

    start = skip_ws(str, start+1)
    value, start = parse_value(str, start)

    object[key] = value

    start = skip_ws(str, start)

    if str:sub(start, start) == '}' then
      return object, start + 1
    end
    
    if str:sub(start, start) ~= ',' then
      throw(str, start, "Expected '}' or ',' instead of '" .. str:sub(start, start) .. "'")
    end

    start = skip_ws(str, start + 1)
  end
end


local function parse_array(str, start)
  local array = {}

  start = skip_ws(str, start+1)
  if str:sub(start, start) == ']' then
    return array, start + 1
  end

  local idx = 1

  while true do
    array[idx], start = parse_value(str, start)
    idx = idx + 1

    start = skip_ws(str, start)

    if str:sub(start, start) == ']' then
      return array, start + 1
    end
    
    if str:sub(start, start) ~= ',' then
      throw(str, start, "Expected ']' or ',' instead of '" .. str:sub(start, start) .. "'")
    end

    start = skip_ws(str, start + 1)
  end
end


local function skip_int(str, start)
  if str:sub(start, start) == '0' then
    return start + 1
  end

  if not str:find('^%d', start) then
    throw(str, start, "Expected decimal digit [0-9] instead of '" .. str:sub(start, start) .. "'")
  end

  return str:find('[^%d]', start)
end


local function parse_number(str, start)
  local end_of_num = start

  if str:sub(start, start) == '-' then
    end_of_num = end_of_num + 1
  end

  end_of_num = skip_int(str, end_of_num)

  if not end_of_num then
    throw(str, #str, "Input ended unexpectedly")
  end

  if str:sub(end_of_num, end_of_num) == '.' then
    end_of_num = skip_int(str, end_of_num + 1)
  end

  local exp_s, exp_e = str:find('^[eE][+-]?%d+', end_of_num)

  if exp_e then
    end_of_num = exp_e + 1
  end

  return tonumber(str:sub(start, end_of_num-1)), end_of_num

end


local value_parsers = {
  ['"'] = parse_string,
  ['['] = parse_array,
  ['{'] = parse_object,
  ['t'] = literal_parser('true',  true),
  ['f'] = literal_parser('false', false),
  ['n'] = literal_parser('null',  nil),
  ['0'] = parse_number,
  ['1'] = parse_number,
  ['2'] = parse_number,
  ['3'] = parse_number,
  ['4'] = parse_number,
  ['5'] = parse_number,
  ['6'] = parse_number,
  ['7'] = parse_number,
  ['8'] = parse_number,
  ['9'] = parse_number,
  ['-'] = parse_number
}


parse_value = function(str, start)
  local p = value_parsers[str:sub(start, start)]

  if not p then
    throw(str, start, "Unexpected character '" .. str:sub(start, start) .. "'")
  end

  return p(str, start)
end


local function decode(str)
  local val, e = parse_value(str, skip_ws(str, 1))

  if not str:find('^%s*$', e) then
    throw(str, e, "Garbage in JSON input after root element")
  end

  if type(val) ~= 'table' then
    throw(str, 1, "Root element is not an object or an array")
  end

  return val
end


return {
  decode = decode
}
