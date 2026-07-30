import re

with open('godot_renderer.cpp', 'r') as f:
    content = f.read()

# Replace assignments directly and inject getCurrentNode calls
replacements = [
    (r'void GodotRenderer::selectRoot\(\)', r'void GodotRenderer::selectRoot(void* owner)'),
    (r'bool GodotRenderer::selectNode\(const std::string& name\)', r'bool GodotRenderer::selectNode(const std::string& name, void* owner)'),
    (r'bool GodotRenderer::searchNode\(const std::string& name\)', r'bool GodotRenderer::searchNode(const std::string& name, void* owner)'),
    (r'std::string GodotRenderer::getNodeType\(\)', r'std::string GodotRenderer::getNodeType(void* owner)'),
    (r'std::string GodotRenderer::getName\(\)', r'std::string GodotRenderer::getName(void* owner)'),
    (r'int GodotRenderer::getChildCount\(\)', r'int GodotRenderer::getChildCount(void* owner)'),
    (r'void GodotRenderer::renameNode\(const std::string& name\)', r'void GodotRenderer::renameNode(const std::string& name, void* owner)'),
    (r'bool GodotRenderer::setCamera\(\)', r'bool GodotRenderer::setCamera(void* owner)'),
    (r'bool GodotRenderer::getPos\(float& x, float& y, float& z\)', r'bool GodotRenderer::getPos(float& x, float& y, float& z, void* owner)'),
    (r'void GodotRenderer::setPos\(float x, float y, float z\)', r'void GodotRenderer::setPos(float x, float y, float z, void* owner)'),
    (r'void GodotRenderer::setVisible\(bool visible\)', r'void GodotRenderer::setVisible(bool visible, void* owner)'),
    (r'bool GodotRenderer::getScale\(float& x, float& y, float& z\)', r'bool GodotRenderer::getScale(float& x, float& y, float& z, void* owner)'),
    (r'void GodotRenderer::setScale\(float x, float y, float z\)', r'void GodotRenderer::setScale(float x, float y, float z, void* owner)'),
    (r'void GodotRenderer::move\(float x, float y, float z\)', r'void GodotRenderer::move(float x, float y, float z, void* owner)'),
    (r'bool GodotRenderer::moveAndCollide\(float x, float y, float z\)', r'bool GodotRenderer::moveAndCollide(float x, float y, float z, void* owner)'),
    (r'std::vector<std::string> GodotRenderer::getOverlappingAreas\(\)', r'std::vector<std::string> GodotRenderer::getOverlappingAreas(void* owner)'),
    (r'bool GodotRenderer::createNode\(const std::string& name\)', r'bool GodotRenderer::createNode(const std::string& name, void* owner)'),
    (r'bool GodotRenderer::loadNode\(const std::string& path, float x, float y, float z, bool use_pos\)', r'bool GodotRenderer::loadNode(const std::string& path, void* owner, float x, float y, float z, bool use_pos)'),
    (r'void GodotRenderer::deleteNode\(\)', r'void GodotRenderer::deleteNode(void* owner)'),
    (r'bool GodotRenderer::attachScript\(const std::string& path\)', r'bool GodotRenderer::attachScript(const std::string& path, void* owner)'),
    (r'void GodotRenderer::setProperty\(const std::string& name, const Variant& value\)', r'void GodotRenderer::setProperty(const std::string& name, const Variant& value, void* owner)'),
    (r'Variant GodotRenderer::getProperty\(const std::string& name\)', r'Variant GodotRenderer::getProperty(const std::string& name, void* owner)')
]

for old, new in replacements:
    content = re.sub(old, new, content)

# Handle selectRoot body
content = re.sub(r'void GodotRenderer::selectRoot\(void\* owner\) \{\n\s*current_node = scene_instance;\n\}', r'void GodotRenderer::selectRoot(void* owner) {\n    current_nodes[owner] = scene_instance;\n}', content)

# Apply current_node local injection, but skipping selectRoot and init
methods_to_inject = [
    r'bool GodotRenderer::selectNode\(const std::string& name, void\* owner\) \{',
    r'bool GodotRenderer::searchNode\(const std::string& name, void\* owner\) \{',
    r'std::string GodotRenderer::getNodeType\(void\* owner\) \{',
    r'std::string GodotRenderer::getName\(void\* owner\) \{',
    r'int GodotRenderer::getChildCount\(void\* owner\) \{',
    r'void GodotRenderer::renameNode\(const std::string& name, void\* owner\) \{',
    r'bool GodotRenderer::setCamera\(void\* owner\) \{',
    r'bool GodotRenderer::getPos\(float& x, float& y, float& z, void\* owner\) \{',
    r'void GodotRenderer::setPos\(float x, float y, float z, void\* owner\) \{',
    r'void GodotRenderer::setVisible\(bool visible, void\* owner\) \{',
    r'bool GodotRenderer::getScale\(float& x, float& y, float& z, void\* owner\) \{',
    r'void GodotRenderer::setScale\(float x, float y, float z, void\* owner\) \{',
    r'void GodotRenderer::move\(float x, float y, float z, void\* owner\) \{',
    r'bool GodotRenderer::moveAndCollide\(float x, float y, float z, void\* owner\) \{',
    r'std::vector<std::string> GodotRenderer::getOverlappingAreas\(void\* owner\) \{',
    r'bool GodotRenderer::createNode\(const std::string& name, void\* owner\) \{',
    r'bool GodotRenderer::loadNode\(const std::string& path, void\* owner, float x, float y, float z, bool use_pos\) \{',
    r'void GodotRenderer::deleteNode\(void\* owner\) \{',
    r'bool GodotRenderer::attachScript\(const std::string& path, void\* owner\) \{',
    r'void GodotRenderer::setProperty\(const std::string& name, const Variant& value, void\* owner\) \{',
    r'Variant GodotRenderer::getProperty\(const std::string& name, void\* owner\) \{',
    r'bool GodotRenderer::watchSignal\(const std::string& signal_name, const std::string& callback_file, void\* owner\) \{'
]

for method_sig in methods_to_inject:
    # Use re.sub to inject after the method signature brace
    content = re.sub(method_sig, method_sig[:-2] + '{' + '\n    Node* current_node = getCurrentNode(owner);', content)


# Now fix all 'current_node = ' assignments to update current_nodes[owner] within the methods
# Only the specific reassignments we care about
content = content.replace('current_node = child;', 'current_nodes[owner] = child;')
content = content.replace('current_node = found;', 'current_nodes[owner] = found;')
content = content.replace('current_node = new_node;', 'current_nodes[owner] = new_node;')
content = content.replace('current_node = instance;', 'current_nodes[owner] = instance;')
content = content.replace('current_node = to_delete->get_parent();', 'current_nodes[owner] = to_delete->get_parent();')
content = content.replace('if (!current_node) current_node = scene_instance;', 'if (!getCurrentNode(owner)) current_nodes[owner] = scene_instance;')

# Remove current_node = scene_instance; from init
content = content.replace('current_node = scene_instance;', '')

# Watch signal ID tracking
content = content.replace('current_node->add_child(bridge);', 'current_node->add_child(bridge);\n    signal_bridges.push_back(bridge_obj->get_instance_id());')

# Clear signal watchers
content += """
void GodotRenderer::clearSignalWatchers() {
    for (ObjectID id : signal_bridges) {
        Object* obj = ObjectDB::get_instance(id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) {
                node->queue_free();
            }
        }
    }
    signal_bridges.clear();
}
"""

with open('godot_renderer.cpp', 'w') as f:
    f.write(content)
