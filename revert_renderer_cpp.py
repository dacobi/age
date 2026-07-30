import re
import sys

def revert_cpp(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    funcs_to_revert = [
        r'(bool GodotRenderer::selectNode[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)',
        r'(bool GodotRenderer::searchNode[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)',
        r'(bool GodotRenderer::createNode[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)',
        r'(bool GodotRenderer::loadNode[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)',
        r'(bool GodotRenderer::attachScript[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)',
        r'(void GodotRenderer::setProperty[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)',
        r'(Variant GodotRenderer::getProperty[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)'
    ]
    
    for pattern in funcs_to_revert:
        content = re.sub(pattern, r'\1\2', content)
        
    # Also revert setCamera
    content = re.sub(r'(bool GodotRenderer::setCamera[^{]*\{[^}]*?Node\* current_node = )target_node \? \(Node\*\)target_node : (getCurrentNode\(owner\);)', r'\1\2', content)

    with open(filepath, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    revert_cpp(sys.argv[1])