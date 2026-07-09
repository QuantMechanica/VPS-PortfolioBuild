import sys
import json
import time
import urllib.request
from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api.proxies import GenericProxyConfig

def get_proxies():
    urls = [
        "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt",
        "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt",
        "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt",
        "https://raw.githubusercontent.com/zloi-user/hideip.me/main/http.txt",
        "https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=6000&country=all&ssl=all&anonymity=all"
    ]
    proxies = []
    source_stats = []
    for url in urls:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                content = response.read().decode('utf-8', errors='ignore')
                lines = [line.strip() for line in content.splitlines() if line.strip()]
                proxies.extend(lines)
                source_stats.append({
                    "url": url,
                    "status": 200,
                    "count": len(lines)
                })
                print(f"Loaded {len(lines)} proxies from {url}")
        except Exception as e:
            source_stats.append({
                "url": url,
                "status": "error",
                "error": str(e)
            })
            print(f"Error loading from {url}: {e}")
    
    # deduplicate
    unique_proxies = sorted(list(set(proxies)))
    return unique_proxies, source_stats

def fetch_with_proxies(video_id, proxies, max_attempts=100):
    attempts = []
    success = None
    
    print(f"Starting transcript fetch for video {video_id} with {len(proxies)} unique proxies.")
    
    # Try direct first (no proxy)
    t0 = time.time()
    try:
        print("Trying direct fetch (no proxy)...")
        api = YouTubeTranscriptApi()
        fetched = api.fetch(video_id, languages=["en"])
        rows = fetched.to_raw_data()
        elapsed = time.time() - t0
        success = {
            "proxy": None,
            "ok": True,
            "elapsed": round(elapsed, 2),
            "rows": len(rows)
        }
        print(f"Direct fetch succeeded: {len(rows)} rows")
        return rows, success, attempts
    except Exception as e:
        elapsed = time.time() - t0
        attempts.append({
            "proxy": None,
            "ok": False,
            "elapsed": round(elapsed, 2),
            "error_type": type(e).__name__,
            "error": str(e)
        })
        print(f"Direct fetch failed: {e}")

    for idx, proxy in enumerate(proxies[:max_attempts]):
        proxy_url = f"http://{proxy}" if not proxy.startswith("http") else proxy
        t0 = time.time()
        try:
            print(f"[{idx+1}/{max_attempts}] Trying proxy {proxy_url}...")
            config = GenericProxyConfig(http_url=proxy_url, https_url=proxy_url)
            api = YouTubeTranscriptApi(proxy_config=config)
            fetched = api.fetch(video_id, languages=["en"])
            rows = fetched.to_raw_data()
            elapsed = time.time() - t0
            success = {
                "proxy": proxy_url,
                "ok": True,
                "elapsed": round(elapsed, 2),
                "rows": len(rows),
            }
            print(f"SUCCESS with {proxy_url} in {elapsed:.2f}s: {len(rows)} rows")
            return rows, success, attempts
        except Exception as e:
            elapsed = time.time() - t0
            attempts.append({
                "proxy": proxy_url,
                "ok": False,
                "elapsed": round(elapsed, 2),
                "error_type": type(e).__name__,
                "error": str(e)
            })
            print(f"Failed with {proxy_url}: {type(e).__name__}")
            if len(attempts) >= max_attempts:
                break
                
    return None, None, attempts

def main():
    if len(sys.argv) < 2:
        print("Usage: python fetch_transcript.py <video_id> [output_dir] [attempts_file]")
        sys.exit(1)
        
    video_id = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "."
    attempts_file = sys.argv[3] if len(sys.argv) > 3 else None
    
    proxies, stats = get_proxies()
    rows, success, attempts = fetch_with_proxies(video_id, proxies, max_attempts=150)
    
    # Save attempts if requested
    if attempts_file:
        attempt_data = {
            "source_stats": stats,
            "candidate_count": len(proxies),
            "attempted": len(attempts),
            "success": success,
            "sample_attempts": attempts[:100]  # limit size
        }
        with open(attempts_file, "w", encoding="utf-8") as f:
            json.dump(attempt_data, f, indent=2)
            
    if rows:
        import os
        os.makedirs(out_dir, exist_ok=True)
        
        # Write clean transcript
        clean_path = os.path.join(out_dir, f"transcript_{video_id}.txt")
        with open(clean_path, "w", encoding="utf-8") as f:
            for row in rows:
                text = (row.get("text") or "").strip()
                if text:
                    f.write(text + "\n")
                    
        # Write timestamped transcript
        ts_path = os.path.join(out_dir, f"transcript_{video_id}_timestamped.txt")
        with open(ts_path, "w", encoding="utf-8") as f:
            for row in rows:
                start = row.get("start", 0)
                h = int(start // 3600)
                m = int((start % 3600) // 60)
                s = int(start % 60)
                ts = f"[{h:02d}:{m:02d}:{s:02d}]"
                text = (row.get("text") or "").strip()
                if text:
                    f.write(f"{ts} {text}\n")
                    
        # Write raw json
        json_path = os.path.join(out_dir, f"transcript_{video_id}.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=2)
            
        print(f"Saved transcript files to {out_dir}")
        sys.exit(0)
    else:
        print("Failed to fetch transcript from all proxy attempts.")
        sys.exit(1)

if __name__ == "__main__":
    main()
