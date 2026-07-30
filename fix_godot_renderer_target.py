import re
import sys

def modify_header(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    methods = [
        r'std::string getNodeType\(void\* owner\);',
        r'std::string getName\(void\* owner\);',
        r'int getChildCount\(void\* owner\);',
        r'void renameNode\(const std::string& name, void\* owner\);',
        r'bool getPos\(float& x, float& y, float& z, void\* owner\);',
        r'void setPos\(float x, float y, float z, void\* owner\);',
        r'void setVisible\(bool visible, void\* owner\);',
        r'bool getScale\(float& x, float& y, float& z, void\* owner\);',
        r'void setScale\(float x, float y, float z, void\* owner\);',
        r'void move\(float x, float y, float z, void\* owner\);',
        r'bool moveAndCollide\(float x, float y, float z, void\* owner\);',
        r'std::vector<std::string> getOverlappingAreas\(void\* owner\);',
        r'void deleteNode\(void\* owner\);'
    ]
    
    for m in methods:
        repl = m.replace(r'void\* owner\)', r'void* owner, void* target_node = nullptr)').replace('\\', '')
        content = re.sub(m, repl, content)

    # Add getNodePointer
    if 'void* getNodePointer' not in content:
        content = content.replace('bool searchNode(const std::string& name, void* owner);',
                                  'bool searchNode(const std::string& name, void* owner);\n    void* getNodePointer(const std::string& name, void* owner);')

    with open(filepath, 'w') as f:
        f.write(content)

def modify_cpp(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    methods = [
        r'std::string GodotRenderer::getNodeType\(void\* owner\)',
        r'std::string GodotRenderer::getName\(void\* owner\)',
        r'int GodotRenderer::getChildCount\(void\* owner\)',
        r'void GodotRenderer::renameNode\(const std::string& name, void\* owner\)',
        r'bool GodotRenderer::getPos\(float& x, float& y, float& z, void\* owner\)',
        r'void GodotRenderer::setPos\(float x, float y, float z, void\* owner\)',
        r'void GodotRenderer::setVisible\(bool visible, void\* owner\)',
        r'bool GodotRenderer::getScale\(float& x, float& y, float& z, void\* owner\)',
        r'void GodotRenderer::setScale\(float x, float y, float z, void\* owner\)',
        r'void GodotRenderer::move\(float x, float y, float z, void\* owner\)',
        r'bool GodotRenderer::moveAndCollide\(float x, float y, float z, void\* owner\)',
        r'std::vector<std::string> GodotRenderer::getOverlappingAreas\(void\* owner\)',
        r'void GodotRenderer::deleteNode\(void\* owner\)'
    ]
    
    for m in methods:
        repl = m.replace(r'void\* owner\)', r'void* owner, void* target_node)').replace('\\', '')
        content = re.sub(m, repl, content)

    # Replace Node* node = getCurrentNode(owner); with the target_node check
    content = re.sub(r'Node\* (current_node|node) = getCurrentNode\(owner\);', r'Node* \1 = target_node ? (Node*)target_node : getCurrentNode(owner);', content)
    
    # Add getNodePointer implementation
    if 'void* GodotRenderer::getNodePointer' not in content:
        impl = """
void* GodotRenderer::getNodePointer(const std::string& name, void* owner) {
    Node* current_node = getCurrentNode(owner);
    if (!current_node) return nullptr;
    return _searchNodeRecursive(current_node, name);
}
"""
        content += impl

    with open(filepath, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    if sys.argv[1] == 'header':
        modify_header(sys.argv[2])
    else:
        modify_cpp(sys.argv[2])