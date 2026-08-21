#!/usr/bin/env python3
import urllib.request
import json
import urllib.parse
import os
import sys
import re
import subprocess
import uuid

def sanitize_filename(name):
    clean = re.sub(r'[^a-zA-Z0-9 -]', '', name).strip()
    return re.sub(r'\s+', '_', clean).lower()

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 download_blenderkit.py <ASSET_UUID>")
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
        asset_name = asset_info.get("name", "blenderkit_skybox")
        safe_name = sanitize_filename(asset_name)
        
        print(f"[*] Found Asset: '{asset_name}'")
        
        files = asset_info.get('files', [])
        if not files:
            print("[-] Error: No files available for this asset.")
            sys.exit(1)
            
        download_url = None
        for f in files:
            if f.get("fileType") == "resolution_4K":
                download_url = f.get("downloadUrl")
                break
        
        if not download_url:
            for f in files:
                if f.get("fileType") == "resolution_2K":
                    download_url = f.get("downloadUrl")
                    break
                    
        if not download_url:
            download_url = files[0].get("downloadUrl")
            
        if not download_url:
            print("[-] Error: Could not resolve a download URL.")
            sys.exit(1)
            
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
            
        # Save in the sky folder
        os.makedirs("sky", exist_ok=True)
        exr_filename = os.path.join("sky", f"{safe_name}.exr")
        hdr_filename = os.path.join("sky", f"{safe_name}.hdr")
        
        print(f"[*] Downloading {exr_filename} from AWS S3...")
        req3 = urllib.request.Request(file_path, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req3) as s3_resp:
            with open(exr_filename, 'wb') as out_file:
                out_file.write(s3_resp.read())
                
        print(f"[+] Successfully downloaded {exr_filename}.")
        print(f"[*] Converting {exr_filename} to {hdr_filename} using ImageMagick...")
        
        cmd = ["magick", exr_filename, hdr_filename]
        try:
            subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except FileNotFoundError:
            cmd = ["convert", exr_filename, hdr_filename]
            subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
        if os.path.exists(hdr_filename):
            print(f"[+] Conversion successful. Deleting original {exr_filename}...")
            os.remove(exr_filename)
            print(f"[+] Done! Your skybox '{hdr_filename}' is ready to use in Godot.")
        else:
            print("[-] Error: Conversion failed. The .hdr file was not created.")
            
    except Exception as e:
        print(f"[-] An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
