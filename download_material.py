#!/usr/bin/env python3
import urllib.request
import json
import os
import sys
import re
import subprocess
import uuid
import shutil

def sanitize_filename(name):
    clean = re.sub(r'[^a-zA-Z0-9 -]', '', name).strip()
    return re.sub(r'\s+', '_', clean).lower()

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 download_material.py <ASSET_UUID>")
        sys.exit(1)
        
    asset_id = sys.argv[1].strip()
    print(f"[*] Searching BlenderKit for Asset ID: {asset_id}")
    
    search_url = f"https://www.blenderkit.com/api/v1/search/?query=asset_base_id:{asset_id}"
    req = urllib.request.Request(search_url, headers={'User-Agent': 'Mozilla/5.0'})
    
    try:
        response = urllib.request.urlopen(req).read()
        data = json.loads(response)
        
        if not data.get('results'):
            print("[-] Error: Asset not found.")
            sys.exit(1)
            
        asset_info = data['results'][0]
        asset_name = asset_info.get("name", "blenderkit_material")
        safe_name = sanitize_filename(asset_name)
        
        print(f"[*] Found Asset: '{asset_name}'")
        
        files = asset_info.get('files', [])
        blend_file = next((f for f in files if f.get("fileType") == "blend"), None)
        if not blend_file:
            print("[-] Error: No blend file available for this asset.")
            sys.exit(1)
            
        download_url = blend_file.get("downloadUrl")
        
        print("[*] Requesting S3 download signature...")
        fake_uuid = str(uuid.uuid4())
        sign_url = f"{download_url}?scene_uuid={fake_uuid}"
        
        req2 = urllib.request.Request(sign_url, headers={'User-Agent': 'Mozilla/5.0'})
        dl_response = urllib.request.urlopen(req2)
        dl_data = json.loads(dl_response.read())
        
        file_path = dl_data.get('filePath')
        if not file_path:
            print("[-] Error: S3 filePath not returned by API.")
            sys.exit(1)
            
        # Create a temp dir
        mat_dir = os.path.join("materials", safe_name)
        os.makedirs(mat_dir, exist_ok=True)
        blend_filename = os.path.join(mat_dir, f"{safe_name}.blend")
        
        print(f"[*] Downloading {blend_filename} from AWS S3...")
        req3 = urllib.request.Request(file_path, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req3) as s3_resp:
            with open(blend_filename, 'wb') as out_file:
                out_file.write(s3_resp.read())
                
        print(f"[+] Successfully downloaded {blend_filename}.")
        print("[*] Unpacking textures using Blender...")
        
        unpack_script = os.path.join(mat_dir, "unpack.py")
        with open(unpack_script, "w") as f:
            f.write("import bpy\nbpy.ops.file.unpack_all(method='USE_LOCAL')\n")
            
        subprocess.run(["blender", "-b", blend_filename, "-P", unpack_script], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Check unpacked textures
        textures_dir = os.path.join(mat_dir, "textures")
        if not os.path.exists(textures_dir):
            print("[-] Error: No textures unpacked.")
            sys.exit(1)
            
        albedo = None
        normal = None
        roughness = None
        
        for f in os.listdir(textures_dir):
            fname = f.lower()
            if "color" in fname or "albedo" in fname or "diffuse" in fname:
                albedo = f
            elif "normal" in fname or "nor" in fname:
                normal = f
            elif "rough" in fname or "gloss" in fname:
                roughness = f
                
        # Generate .tres material
        tres_content = f'[gd_resource type="StandardMaterial3D" load_steps=4 format=3]\n\n'
        
        step = 1
        if albedo:
            tres_content += f'[ext_resource type="Texture2D" path="res://materials/{safe_name}/textures/{albedo}" id="{step}"]\n'
            step += 1
        if normal:
            tres_content += f'[ext_resource type="Texture2D" path="res://materials/{safe_name}/textures/{normal}" id="{step}"]\n'
            step += 1
        if roughness:
            tres_content += f'[ext_resource type="Texture2D" path="res://materials/{safe_name}/textures/{roughness}" id="{step}"]\n'
            step += 1
            
        tres_content += '\n[resource]\n'
        
        curr_id = 1
        if albedo:
            tres_content += f'albedo_texture = ExtResource("{curr_id}")\n'
            curr_id += 1
        if normal:
            tres_content += f'normal_enabled = true\nnormal_texture = ExtResource("{curr_id}")\n'
            curr_id += 1
        if roughness:
            tres_content += f'roughness_texture = ExtResource("{curr_id}")\n'
            curr_id += 1
            
        tres_content += 'uv1_scale = Vector3(20, 20, 20)\n'
        
        tres_path = os.path.join(mat_dir, f"{safe_name}.tres")
        with open(tres_path, "w") as f:
            f.write(tres_content)
            
        print(f"[+] Successfully generated Godot material: {tres_path}")
        
    except Exception as e:
        print(f"[-] An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
