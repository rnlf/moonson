--
-- moonson
--
-- Copyright (c) 2016-2017, Florian Keßeler
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

package.path = "../?.lua"
local json = require "moonson"

local console = {
}
console.reset = "\27[0m"
console.red = function(text) return "\27[31;1m" .. text .. console.reset end
console.green = function(text) return "\27[32;1m" .. text .. console.reset end
console.bright = function(text) return "\27[1m" .. text .. console.reset end

local test = {
  r = 0,
  p = 0,
  f = 0,
  maxTestNameLen = 0,
  groups = {}
}

test.group = function(name)
  local grp = {
    tests = {},
    name = name,
    case = function(self, name, func)
      self.tests[#self.tests+1] = {
        name = name,
        func = func
      }

      test.maxTestNameLen = math.max(test.maxTestNameLen, #name)

      return self
    end,
    run = function(self)
      print("Running group '" .. self.name .. "'...")
      local r, p, f = 0, 0, 0
      for i, t in ipairs(self.tests) do
        io.write(" * Running test '" .. t.name .. "'")
        for i = 1, test.maxTestNameLen - #t.name + 3 do
          io.write('.')
        end
        io.flush()
        local ok, res = pcall(t.func)
        io.write((ok and console.green("pass") or (console.red("fail: ") .. res)) .. "\n")
        io.flush()
        r = r + 1
        p = p + (ok and 1 or 0)
        f = f + (ok and 0 or 1)
      end
      print("Finished group '" .. self.name .. "': " .. console.bright(r) .. " run, " .. console.green(p) .. " passed, " .. console.red(f) .. " failed\n")
      test.r = test.r + r
      test.p = test.p + p
      test.f = test.f + f
    end
  }

  test.groups[#test.groups+1] = grp

  return grp
end


test.assert_error = function(func, ...)
  local err = pcall(func, ...)
  assert(not err)
end


test.run = function()
  for i, g in ipairs(test.groups) do
    g:run()
  end

  print("\n===============================================================================")
  print("All tests run: " .. console.bright(test.r) .. " tests, " .. console.green(test.p) .. " passed, " .. console.red(test.f) .. " failed\n")
end

local tables = {
  deep_equal = function(a, b)
    local visited = {}
    local function recurse(a, b)
      if type(a) ~= type(b) then return false end
      if type(a) ~= "table" then return a == b end
      if visited[a] then return visited[a] == b end

      visited[a] = b

      for k, v in pairs(a) do
        if not recurse(v, b[k]) then
          visited[a] = nil
          return false
        end
      end

      for k, v in pairs(b) do
        if not recurse(v, a[k]) then
          visited[a] = nil
          return false
        end
      end

      visited[a] = nil

      return true
    end

    return recurse(a, b)
  end
}



local fail_cases = {
  "fail10.json", "fail11.json", "fail12.json",
  "fail13.json", "fail14.json", "fail15.json", "fail16.json", "fail17.json",
  "fail19.json", "fail1.json", "fail20.json", "fail21.json", "fail22.json",
  "fail23.json", "fail24.json", "fail25.json", "fail26.json", "fail27.json",
  "fail28.json", "fail29.json", "fail2.json", "fail30.json", "fail31.json",
  "fail32.json", "fail33.json", "fail3.json", "fail4.json", "fail5.json",
  "fail6.json", "fail7.json", "fail8.json", "fail9.json"
}

local pass_cases = {["pass1.json"] = {
    [1] = "JSON Test Pattern pass1",
    [2] = {["object with 1 member"]= {"array with 1 element"}},
    [3] = {},
    [4] = {},
    [5] = -42,
    [6] = true,
    [7] = false,
    [8] = nil,
    [9] = {
        integer = 1234567890,
        real = -9876.543210,
        e = 0.123456789e-12,
        E = 1.234567890E+34,
        [""]=  23456789012E66,
        zero= 0,
        one = 1,
        space = " ",
        quote = "\"",
        backslash = "\\",
        controls = "\b\f\n\r\t",
        slash = "/ & /",
        alpha = "abcdefghijklmnopqrstuvwyz",
        ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWYZ",
        digit = "0123456789",
        ["0123456789"] = "digit",
        special = "`1~!@#$%^&*()_+-={':[,]}|;.</>?",
        hex = "\xC4\xA3\xE4\x95\xA7\xE8\xA6\xAB\xEC\xB7\xAF\xEA\xAF\x8D\xEE\xBD\x8A",
        ["true"] = true,
        ["false"] = false,
        null = nil,
        array = {  },
        object = {  },
        address =  "50 St. James Street",
        url = "http://www.JSON.org/",
        comment = "// /* <!-- --",
        ["# -- --> */"] = " ",
        [" s p a c e d "] = {1, 2, 3, 4, 5, 6, 7},
        compact = {1,2,3,4,5,6,7},
        jsontext = "{\"object with 1 member\":[\"array with 1 element\"]}",
        quotes = "&#34; \" %22 0x22 034 &#x22;",
        ["/\\\"\xEC\xAB\xBE\xEB\xAA\xBE\xEA\xAE\x98\xEF\xB3\x9E\xEB\xB3\x9A\xEE\xBD\x8A\b\f\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?"] = "A key can be any string"
      },
      [10] = 0.5 ,[11] = 98.6 , [12] = 99.44 , [13] = 1066, [14] = 1e1, [15] = 0.1e1, [16] = 1e-1, [17] = 1e00, [18] = 2e+00, [19] = 2e-00 , [20] = "rosebud"
  },
  ["pass2.json"] = {{{{{{{{{{{{{{{{{{{"Not too deep"}}}}}}}}}}}}}}}}}}},
  ["pass3.json"] = {
    ["JSON Test Pattern pass3"]= {
        ["The outermost value"] = "must be an object or array.",
        ["In this test"]= "It is an object."
    }
  }
}

local grp = test.group("json")

grp

:case("simple tests - objects", function()
  assert(tables.deep_equal(json.decode('{}'), {}))
end)

:case("simple tests - objects with one entry", function()
  assert(tables.deep_equal(json.decode('{"foo": "bar"}'), {foo='bar'}))
end)

:case("simple tests - objects with two entries", function()
  assert(tables.deep_equal(json.decode('{"foo": "bar", "bar": "foo"}'), {foo='bar', bar='foo'}))
end)

:case("simple tests - arrays", function()
  assert(tables.deep_equal(json.decode('[]'), {}))
end)

:case("simple tests - arrays with one entry", function()
  assert(tables.deep_equal(json.decode('[ "foo" ]'), {'foo'}))
end)

:case("simple tests - arrays with two entries", function()
  assert(tables.deep_equal(json.decode('["foo", "bar"]'), {'foo', 'bar'}))
end)

:case("simple tests - strings", function()
  assert(tables.deep_equal(json.decode('["foo"]'), {"foo"}))
end)

:case("simple tests - strings with basic escape sequences", function()
  assert(tables.deep_equal(json.decode('["\\r\\n\\t\\b\\"\\f\\/\\\\"]'), {"\r\n\t\b\"\f/\\"}))
end)

:case("simple tests - strings with unicode escape sequences U+0000 - U+007F", function()
  assert(tables.deep_equal(json.decode('["\\u0046"]'), {"F"}))
end)

:case("simple tests - strings with unicode escape sequences U+0080 - U+07FF", function()
  assert(tables.deep_equal(json.decode('["\\u00A2"]'), {"\xC2\xA2"}))
end)

:case("simple tests - strings with unicode escape sequences U+0800 - U+FFFF", function()
  assert(tables.deep_equal(json.decode('["\\ubcda"]'), {"\xEB\xB3\x9A"}))
end)

:case("simple tests - strings with unicode escape sequences U+10000 - U+10FFFF (using surrogates)", function()
  assert(tables.deep_equal(json.decode('["\\uD800\\uDF48"]'), {"\xF0\x90\x8D\x88"}))
end)


:case("simple tests - numbers", function()
  assert(tables.deep_equal(json.decode('[10]'), {10}))
  assert(tables.deep_equal(json.decode('[10.0]'), {10}))
  assert(tables.deep_equal(json.decode('[10.0e1]'), {100}))
  assert(tables.deep_equal(json.decode('[10.0e+1]'), {100}))
  assert(tables.deep_equal(json.decode('[10.0e-1]'), {1}))
  assert(tables.deep_equal(json.decode('[10.0E1]'), {100}))
  assert(tables.deep_equal(json.decode('[10.0E+1]'), {100}))
  assert(tables.deep_equal(json.decode('[10.0E-1]'), {1}))
  assert(tables.deep_equal(json.decode('[10e1]'), {100}))
  assert(tables.deep_equal(json.decode('[10e+1]'), {100}))
  assert(tables.deep_equal(json.decode('[10e-1]'), {1}))
  assert(tables.deep_equal(json.decode('[10E1]'), {100}))
  assert(tables.deep_equal(json.decode('[10E+1]'), {100}))
  assert(tables.deep_equal(json.decode('[10.0E-1]'), {1}))
  assert(tables.deep_equal(json.decode('[-10]'), {-10}))
  assert(tables.deep_equal(json.decode('[-10.0]'), {-10}))
  assert(tables.deep_equal(json.decode('[-10.0e1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10.0e+1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10.0e-1]'), {-1}))
  assert(tables.deep_equal(json.decode('[-10.0E1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10.0E+1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10.0E-1]'), {-1}))
  assert(tables.deep_equal(json.decode('[-10e1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10e+1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10e-1]'), {-1}))
  assert(tables.deep_equal(json.decode('[-10E1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10E+1]'), {-100}))
  assert(tables.deep_equal(json.decode('[-10.0E-1]'), {-1}))
end)

:case("simple tests - literals", function()
  assert(tables.deep_equal(json.decode('[true]'), {true}))
  assert(tables.deep_equal(json.decode('[false]'), {false}))
  assert(tables.deep_equal(json.decode('[null]'), {}))
end)

local test_case_dir = "testfiles/"
for i, f in ipairs(fail_cases) do
  grp:case("fail case - " .. f, function()
    test.assert_error(json.decode, io.open(test_case_dir .. f):read('*a'))
  end)
end

for k, v in pairs(pass_cases) do
  grp:case("pass cases - " .. k, function()
    local doc = json.decode(io.open(test_case_dir .. k):read('*a'))
    assert(tables.deep_equal(doc, v))
  end)
end

test.run()
