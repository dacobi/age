# Quick Python example to get the direct audio stream URL
import yt_dlp

ydl_opts = {'format': 'bestaudio'}
with yt_dlp.YoutubeDL(ydl_opts) as ydl:
    info = ydl.extract_info("https://www.youtube.com/watch?v=DsAVx0u9Cw4", download=False)
    audio_url = info['url']
    print(f"Direct Audio Stream URL: {audio_url}")
