import re

with open('godot_renderer.cpp', 'r') as f:
    lines = f.readlines()

new_lines = []
methods = [
    'selectNode(', 'searchNode(', 'getNodeType(', 'getName(', 'getChildCount(',
    'renameNode(', 'setCamera(', 'getPos(', 'setPos(', 'setVisible(', 'getScale(',
    'setScale(', 'move(', 'moveAndCollide(', 'getOverlappingAreas(', 'createNode(',
    'loadNode(', 'deleteNode(', 'attachScript(', 'setProperty(', 'getProperty(', 'watchSignal('
]

i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    if any(line.startswith('bool GodotRenderer::' + m) or 
           line.startswith('void GodotRenderer::' + m) or
           line.startswith('std::string GodotRenderer::' + m) or
           line.startswith('int GodotRenderer::' + m) or
           line.startswith('Variant GodotRenderer::' + m) or
           line.startswith('std::vector<std::string> GodotRenderer::' + m) for m in methods):
        new_lines.append('    Node* current_node = getCurrentNode(owner);\n')
    i += 1

with open('godot_renderer.cpp', 'w') as f:
    f.writelines(new_lines)

