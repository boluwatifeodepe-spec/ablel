from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import yt_dlp

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

from pydantic import BaseModel

class ExtractRequest(BaseModel):
    url: str

@app.get("/ping")
def ping():
    return {"status": "alive"}

@app.post("/api/extract")
def extract_post(req: ExtractRequest):
    return download(req.url)

@app.get("/api/extract")
def extract_get(url: str):
    return download(url)

@app.get("/download")
def download(url: str):
    try:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "format": "best",
            "http_headers": {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept-Language": "en-US,en;q=0.9"
            },
            "socket_timeout": 30,
            "retries": 3,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            formats = []
            for f in info.get("formats", []):
                if f.get("url") and f.get("ext") != "none":
                    formats.append({
                        "format_id": f.get("format_id"),
                        "ext": f.get("ext"),
                        "quality": f.get("format_note", "unknown"),
                        "url": f.get("url"),
                        "filesize": f.get("filesize"),
                        "width": f.get("width"),
                        "height": f.get("height")
                    })
            return {
                "success": True,
                "title": info.get("title"),
                "thumbnail": info.get("thumbnail"),
                "duration": info.get("duration"),
                "author": info.get("uploader"),
                "platform": info.get("extractor"),
                "url": info.get("url"),
                "formats": formats
            }
    except Exception as e:
        return {"success": False, "error": str(e)}

