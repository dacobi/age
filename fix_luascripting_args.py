import re
import sys

def modify_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We need to find `self->godotCmdFunc(GCMD_XYZ, ...);` and insert the pointer check before it.
    # The argument number N is the number of expected arguments + 1.
    
    # We will use regex to find the function definitions and insert the logic.
    
    funcs = {
        'lua_godotGetNodeType': 1,
        'lua_godotGetName': 1,
        'lua_godotGetChildCount': 1,
        'lua_godotRenameNode': 2,
        'lua_godotGetPos': 1,
        'lua_godotSetPos': 4,
        'lua_godotSetVisible': 2,
        'lua_godotGetScale': 1,
        'lua_godotSetScale': 4,
        'lua_godotMoveX': 2,
        'lua_godotMoveY': 2,
        'lua_godotMoveZ': 2,
        'lua_godotMoveAndCollide': 4,
        'lua_godotGetOverlappingAreas': 1,
        'lua_godotDeleteNode': 1,
        'lua_godotSetProperty': 3,
        'lua_godotGetProperty': 2
    }
    
    for func, arg_idx in funcs.items():
        pattern = r'(int LuaScripting::' + func + r'\(lua_State\* L\) \{.*?)(self->godotCmdFunc\()'
        
        def repl(m):
            injection = f"if (lua_islightuserdata(L, {arg_idx})) {{\n            sd->ptr_arg = lua_touserdata(L, {arg_idx});\n        }}\n        "
            return m.group(1) + injection + m.group(2)
            
        content = re.sub(pattern, repl, content, flags=re.DOTALL)
        
    # Special cases: GCMD_SET_PROPERTY has 3 godotCmdFunc calls
    # The regex above will only match the FIRST one because of DOTALL and non-greedy .*?
    # Let's run it multiple times for setProperty if needed, but actually setProperty has multiple calls inside.
    # Let's fix that.
    
    with open(filepath, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    modify_file(sys.argv[1])