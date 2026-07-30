import re
import sys

def modify_main(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # The lines in main.cpp look like this:
    # case AppState::LuaCommand::GODOT_GET_NODE_TYPE: if (cmd.sync) cmd.sync->s_res = state->selected_godots[cmd.owner_thread]->getNodeType(cmd.owner_thread); break;
    # We want to change cmd.owner_thread); to cmd.owner_thread, cmd.target_node);
    
    methods = [
        "getNodeType",
        "getName",
        "getChildCount",
        "renameNode",
        "getPos",
        "setPos",
        "setVisible",
        "getScale",
        "setScale",
        "move",
        "moveAndCollide",
        "getOverlappingAreas",
        "deleteNode"
    ]
    
    for m in methods:
        pattern = r'(state->selected_godots\[cmd\.owner_thread\]->' + m + r'\([^;]*?cmd\.owner_thread)(\))'
        content = re.sub(pattern, r'\1, cmd.target_node\2', content)

    # We also need to add GODOT_GET_NODE_POINTER handling in the switch
    # case AppState::LuaCommand::GODOT_GET_NODE_POINTER: if (cmd.sync) cmd.sync->ptr_res = state->selected_godots[cmd.owner_thread]->getNodePointer(cmd.syntax, cmd.owner_thread); break;
    if 'GODOT_GET_NODE_POINTER:' not in content:
        content = content.replace('case AppState::LuaCommand::GODOT_SELECT_ROOT:', 
                                  'case AppState::LuaCommand::GODOT_GET_NODE_POINTER: if (cmd.sync) cmd.sync->ptr_res = state->selected_godots[cmd.owner_thread]->getNodePointer(cmd.syntax, cmd.owner_thread); break;\n                        case AppState::LuaCommand::GODOT_SELECT_ROOT:')

    with open(filepath, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    modify_main(sys.argv[1])