import re

path = "/home/dacobi/src/age/src/luascripting.cpp"
with open(path, "r") as f:
    text = f.read()

# Replace sd->ptr_arg = lua_touserdata(L, X);
text = re.sub(r'sd->ptr_arg\s*=\s*lua_touserdata\(L,\s*(\d+)\);', r'sd->object_id_arg = (uint64_t)lua_tointeger(L, \1);', text)

# Replace lua_islightuserdata with lua_isinteger
text = re.sub(r'lua_islightuserdata\(L,\s*(\d+)\)', r'lua_isinteger(L, \1)', text)

# Replace target extraction in lua_godotSetProperty
text = re.sub(r'void\*\s*target\s*=\s*lua_isinteger\(L,\s*3\)\s*\?\s*lua_touserdata\(L,\s*3\)\s*:\s*nullptr;', r'uint64_t target = lua_isinteger(L, 3) ? (uint64_t)lua_tointeger(L, 3) : 0;', text)

# Also fix the manual target extraction that might have old lua_islightuserdata
text = re.sub(r'void\*\s*target\s*=\s*lua_islightuserdata\(L,\s*3\)\s*\?\s*lua_touserdata\(L,\s*3\)\s*:\s*nullptr;', r'uint64_t target = lua_isinteger(L, 3) ? (uint64_t)lua_tointeger(L, 3) : 0;', text)

# Fix sd->ptr_arg = target;
text = re.sub(r'sd->ptr_arg\s*=\s*target;', r'sd->object_id_arg = target;', text)

# Fix lua_godotGetProperty return lines
broken_ret = """        if (sd->object_id_res) {
            lua_pushinteger(L, sd->object_id_res);
        } else {
            lua_pushstring(L, sd->s_res.c_str());
        }"""
fixed_ret = """        if (sd->b_res) { 
            lua_pushnumber(L, sd->d_res);
        } else {
            lua_pushstring(L, sd->s_res.c_str());
        }"""
text = text.replace(broken_ret, fixed_ret)

with open(path, "w") as f:
    f.write(text)

print("Fixed luascripting.cpp!")
