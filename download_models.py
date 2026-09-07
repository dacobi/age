#!/usr/bin/env python3
import urllib.request
import json
import os
import sys
import re
import subprocess
import uuid
import argparse

def sanitize_filename(name):
    clean = re.sub(r'[^a-zA-Z0-9 -]', '', name).strip()
    return re.sub(r'\s+', '_', clean).lower()

def main():
    parser = argparse.ArgumentParser(description="Download and optionally convert BlenderKit 3D models.")
    parser.add_argument("asset_uuid", help="The Asset UUID from BlenderKit")
    parser.add_argument("-d", "--download-only", action="store_true", 
                        help="Only download the .blend asset. Do not convert to GLB or unpack textures.")
    
    args = parser.parse_args()
    asset_id = args.asset_uuid.strip()
    
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
        asset_name = asset_info.get("name", "blenderkit_model")
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
            
        mod_dir = os.path.join("models", safe_name)
        os.makedirs(mod_dir, exist_ok=True)
        blend_filename = os.path.join(mod_dir, f"{safe_name}.blend")
        
        print(f"[*] Downloading {blend_filename} from AWS S3...")
        req3 = urllib.request.Request(file_path, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req3) as s3_resp:
            with open(blend_filename, 'wb') as out_file:
                out_file.write(s3_resp.read())
                
        print(f"[+] Successfully downloaded {blend_filename}.")
        
        if args.download_only:
            print("[+] Download-only mode active. Skipping conversion.")
            print(f"[+] Asset is ready at: {blend_filename}")
            sys.exit(0)
            
        # Conversion mode
        glb_filename = os.path.join(mod_dir, f"{safe_name}.glb")
        
        print("[*] Unpacking textures and exporting to GLB using Blender...")
        
        unpack_script = os.path.join(mod_dir, "unpack.py")
        with open(unpack_script, "w") as f:
            # We can now safely save the mainfile since we are going to delete it anyway
            f.write(f"""import bpy
bpy.ops.file.unpack_all(method='USE_LOCAL')
bpy.ops.wm.save_mainfile()
bpy.ops.export_scene.gltf(
    filepath='{glb_filename}',
    export_format='GLB',
    export_apply=True,
    export_animations=True
)
""")
            
        result = subprocess.run(["blender", "-b", blend_filename, "-P", unpack_script], capture_output=True, text=True)
        
        # Clean up unpack script
        if os.path.exists(unpack_script):
            os.remove(unpack_script)
            
        if result.returncode != 0:
            print(f"[-] Blender failed to unpack and export:\n{result.stderr}")
            sys.exit(1)
            
        # Delete original asset
        if os.path.exists(blend_filename):
            os.remove(blend_filename)
        if os.path.exists(blend_filename + "1"): # Blender backup files
            os.remove(blend_filename + "1")
            
        print(f"[+] Successfully converted to GLB and removed original .blend file.")
        print(f"[+] Godot-ready model at: {glb_filename}")
        
    except Exception as e:
        print(f"[-] An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
