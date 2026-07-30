with open('godot_renderer.cpp', 'r') as f:
    content = f.read()

content = content.replace('current_node = child;', 'current_nodes[owner] = child;')
content = content.replace('current_node = found;', 'current_nodes[owner] = found;')
content = content.replace('current_node = new_node;', 'current_nodes[owner] = new_node;')
content = content.replace('current_node = instance;', 'current_nodes[owner] = instance;')
content = content.replace('current_node = to_delete->get_parent();', 'current_nodes[owner] = to_delete->get_parent();')

with open('godot_renderer.cpp', 'w') as f:
    f.write(content)
