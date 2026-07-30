import re

with open('godot_renderer.cpp', 'r') as f:
    content = f.read()

# Add owner parameter to method definitions
content = re.sub(r'void GodotRenderer::selectRoot\(\)', r'void GodotRenderer::selectRoot(void* owner)', content)
content = re.sub(r'bool GodotRenderer::selectNode\(const std::string& name\)', r'bool GodotRenderer::selectNode(const std::string& name, void* owner)', content)
content = re.sub(r'bool GodotRenderer::searchNode\(const std::string& name\)', r'bool GodotRenderer::searchNode(const std::string& name, void* owner)', content)
content = re.sub(r'std::string GodotRenderer::getNodeType\(\)', r'std::string GodotRenderer::getNodeType(void* owner)', content)
content = re.sub(r'std::string GodotRenderer::getName\(\)', r'std::string GodotRenderer::getName(void* owner)', content)
content = re.sub(r'int GodotRenderer::getChildCount\(\)', r'int GodotRenderer::getChildCount(void* owner)', content)
content = re.sub(r'void GodotRenderer::renameNode\(const std::string& name\)', r'void GodotRenderer::renameNode(const std::string& name, void* owner)', content)
content = re.sub(r'bool GodotRenderer::setCamera\(\)', r'bool GodotRenderer::setCamera(void* owner)', content)
content = re.sub(r'bool GodotRenderer::getPos\(float& x, float& y, float& z\)', r'bool GodotRenderer::getPos(float& x, float& y, float& z, void* owner)', content)
content = re.sub(r'void GodotRenderer::setPos\(float x, float y, float z\)', r'void GodotRenderer::setPos(float x, float y, float z, void* owner)', content)
content = re.sub(r'void GodotRenderer::setVisible\(bool visible\)', r'void GodotRenderer::setVisible(bool visible, void* owner)', content)
content = re.sub(r'bool GodotRenderer::getScale\(float& x, float& y, float& z\)', r'bool GodotRenderer::getScale(float& x, float& y, float& z, void* owner)', content)
content = re.sub(r'void GodotRenderer::setScale\(float x, float y, float z\)', r'void GodotRenderer::setScale(float x, float y, float z, void* owner)', content)
content = re.sub(r'void GodotRenderer::move\(float x, float y, float z\)', r'void GodotRenderer::move(float x, float y, float z, void* owner)', content)
content = re.sub(r'bool GodotRenderer::moveAndCollide\(float x, float y, float z\)', r'bool GodotRenderer::moveAndCollide(float x, float y, float z, void* owner)', content)
content = re.sub(r'std::vector<std::string> GodotRenderer::getOverlappingAreas\(\)', r'std::vector<std::string> GodotRenderer::getOverlappingAreas(void* owner)', content)
content = re.sub(r'bool GodotRenderer::createNode\(const std::string& name\)', r'bool GodotRenderer::createNode(const std::string& name, void* owner)', content)
content = re.sub(r'bool GodotRenderer::loadNode\(const std::string& path, float x, float y, float z, bool use_pos\)', r'bool GodotRenderer::loadNode(const std::string& path, void* owner, float x, float y, float z, bool use_pos)', content)
content = re.sub(r'void GodotRenderer::deleteNode\(\)', r'void GodotRenderer::deleteNode(void* owner)', content)
content = re.sub(r'bool GodotRenderer::attachScript\(const std::string& path\)', r'bool GodotRenderer::attachScript(const std::string& path, void* owner)', content)
content = re.sub(r'void GodotRenderer::setProperty\(const std::string& name, const Variant& value\)', r'void GodotRenderer::setProperty(const std::string& name, const Variant& value, void* owner)', content)
content = re.sub(r'Variant GodotRenderer::getProperty\(const std::string& name\)', r'Variant GodotRenderer::getProperty(const std::string& name, void* owner)', content)

# Special cases for assignment
content = re.sub(r'current_node = scene_instance;', r'current_nodes[owner] = scene_instance;', content)
content = re.sub(r'current_node = child;', r'current_nodes[owner] = child;', content)
content = re.sub(r'current_node = found;', r'current_nodes[owner] = found;', content)
content = re.sub(r'current_node = new_node;', r'current_nodes[owner] = new_node;', content)
content = re.sub(r'current_node = instance;', r'current_nodes[owner] = instance;', content)
content = re.sub(r'current_node = to_delete->get_parent\(\);', r'current_nodes[owner] = to_delete->get_parent();', content)
content = re.sub(r'if \(!current_node\) current_node = scene_instance;', r'if (!getCurrentNode(owner)) current_nodes[owner] = scene_instance;', content)


# Add Node* current_node = getCurrentNode(owner); to the beginning of each modified method if needed
methods_to_patch = [
    r'bool GodotRenderer::selectNode(const std::string& name, void* owner) {',
    r'bool GodotRenderer::searchNode(const std::string& name, void* owner) {',
    r'std::string GodotRenderer::getNodeType(void* owner) {',
    r'std::string GodotRenderer::getName(void* owner) {',
    r'int GodotRenderer::getChildCount(void* owner) {',
    r'void GodotRenderer::renameNode(const std::string& name, void* owner) {',
    r'bool GodotRenderer::setCamera(void* owner) {',
    r'bool GodotRenderer::getPos(float& x, float& y, float& z, void* owner) {',
    r'void GodotRenderer::setPos(float x, float y, float z, void* owner) {',
    r'void GodotRenderer::setVisible(bool visible, void* owner) {',
    r'bool GodotRenderer::getScale(float& x, float& y, float& z, void* owner) {',
    r'void GodotRenderer::setScale(float x, float y, float z, void* owner) {',
    r'void GodotRenderer::move(float x, float y, float z, void* owner) {',
    r'bool GodotRenderer::moveAndCollide(float x, float y, float z, void* owner) {',
    r'std::vector<std::string> GodotRenderer::getOverlappingAreas(void* owner) {',
    r'bool GodotRenderer::createNode(const std::string& name, void* owner) {',
    r'bool GodotRenderer::loadNode(const std::string& path, void* owner, float x, float y, float z, bool use_pos) {',
    r'void GodotRenderer::deleteNode(void* owner) {',
    r'bool GodotRenderer::attachScript(const std::string& path, void* owner) {',
    r'void GodotRenderer::setProperty(const std::string& name, const Variant& value, void* owner) {',
    r'Variant GodotRenderer::getProperty(const std::string& name, void* owner) {',
    r'bool GodotRenderer::watchSignal(const std::string& signal_name, const std::string& callback_file, void* owner) {'
]

for method in methods_to_patch:
    escaped_method = re.escape(method)
    content = re.sub(escaped_method, method + '\n    Node* current_node = getCurrentNode(owner);', content)

# Now fix the watchSignal bridge adding logic
watch_signal_bridge = """    current_node->add_child(bridge);
    signal_bridges.push_back(bridge_obj->get_instance_id());"""

content = re.sub(r'    current_node->add_child\(bridge\);(?![\s\S]*signal_bridges\.push_back)', watch_signal_bridge, content)

clear_signal_watchers = """
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
content += clear_signal_watchers

with open('godot_renderer.cpp', 'w') as f:
    f.write(content)
