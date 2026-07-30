import re

with open('godot_renderer.h', 'r') as f:
    content = f.read()

content = content.replace('Node* current_node = nullptr;', 'std::unordered_map<void*, Node*> current_nodes;\n    std::vector<ObjectID> signal_bridges;')
content = content.replace('Node* getCurrentNode() const { return current_node; }', 'Node* getCurrentNode(void* owner) const { \n        auto it = current_nodes.find(owner);\n        return it != current_nodes.end() ? it->second : nullptr; \n    }')
content = content.replace('void setCurrentNode(Node* n) { current_node = n; }', 'void setCurrentNode(Node* n, void* owner) { current_nodes[owner] = n; }')

methods_to_patch = [
    ('void selectRoot();', 'void selectRoot(void* owner);'),
    ('bool selectNode(const std::string& name);', 'bool selectNode(const std::string& name, void* owner);'),
    ('bool searchNode(const std::string& name);', 'bool searchNode(const std::string& name, void* owner);'),
    ('std::string getNodeType();', 'std::string getNodeType(void* owner);'),
    ('std::string getName();', 'std::string getName(void* owner);'),
    ('void renameNode(const std::string& new_name);', 'void renameNode(const std::string& new_name, void* owner);'),
    ('int getChildCount();', 'int getChildCount(void* owner);'),
    ('bool setCamera();', 'bool setCamera(void* owner);'),
    ('bool getPos(float& x, float& y, float& z);', 'bool getPos(float& x, float& y, float& z, void* owner);'),
    ('void setPos(float x, float y, float z);', 'void setPos(float x, float y, float z, void* owner);'),
    ('void setVisible(bool visible);', 'void setVisible(bool visible, void* owner);'),
    ('bool getScale(float& x, float& y, float& z);', 'bool getScale(float& x, float& y, float& z, void* owner);'),
    ('void setScale(float x, float y, float z);', 'void setScale(float x, float y, float z, void* owner);'),
    ('void move(float x, float y, float z);', 'void move(float x, float y, float z, void* owner);'),
    ('bool moveAndCollide(float x, float y, float z);', 'bool moveAndCollide(float x, float y, float z, void* owner);'),
    ('std::vector<std::string> getOverlappingAreas();', 'std::vector<std::string> getOverlappingAreas(void* owner);'),
    ('bool createNode(const std::string& name);', 'bool createNode(const std::string& name, void* owner);'),
    ('bool loadNode(const std::string& path, float x = 0, float y = 0, float z = 0, bool use_pos = false);', 'bool loadNode(const std::string& path, void* owner, float x = 0, float y = 0, float z = 0, bool use_pos = false);'),
    ('void deleteNode();', 'void deleteNode(void* owner);'),
    ('bool attachScript(const std::string& path);', 'bool attachScript(const std::string& path, void* owner);'),
    ('void setProperty(const std::string& name, const class Variant& value);', 'void setProperty(const std::string& name, const class Variant& value, void* owner);'),
    ('class Variant getProperty(const std::string& name);', 'class Variant getProperty(const std::string& name, void* owner);')
]

for old, new in methods_to_patch:
    # also handle parameter rename 'new_name' to 'name' which was in the cpp file
    if 'renameNode(const std::string& name);' in content:
        content = content.replace('void renameNode(const std::string& name);', 'void renameNode(const std::string& name, void* owner);')
    content = content.replace(old, new)

# add clearSignalWatchers and includes
content = content.replace('class SubViewport;', '#include <unordered_map>\n#include "core/object/object_id.h"\n\nclass SubViewport;')
content = content.replace('bool watchSignal(const std::string& signal_name, const std::string& callback_file, void* owner);', 'bool watchSignal(const std::string& signal_name, const std::string& callback_file, void* owner);\n    void clearSignalWatchers();')

with open('godot_renderer.h', 'w') as f:
    f.write(content)
