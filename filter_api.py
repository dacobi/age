import json

def process_dict(d):
    keys_to_delete = []
    for k, v in d.items():
        if isinstance(v, dict):
            process_dict(v)
        elif isinstance(v, list):
            for item in v:
                if isinstance(item, dict):
                    process_dict(item)
        elif k == "meta" and v == "required":
            keys_to_delete.append(k)
        elif k == "meta" and v == "char32":
            d[k] = "char32_t"
    for k in keys_to_delete:
        del d[k]

with open("extension_api.json", "r") as f:
    data = json.load(f)

# Also strip Fmod classes while we're at it
data["classes"] = [c for c in data.get("classes", []) if not c["name"].startswith("Fmod")]

process_dict(data)

with open("godot-cpp/gdextension/extension_api.json", "w") as f:
    json.dump(data, f, indent=4)
