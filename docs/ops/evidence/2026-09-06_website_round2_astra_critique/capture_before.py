from pathlib import Path
from playwright.sync_api import sync_playwright
import json
OUT=Path('C:/QM/repo/docs/ops/evidence/2026-09-06_website_round2_astra_critique')
PAGES={'home':'/','archive':'/strategies/index.html','detail':'/strategies/avoid-monday-index-long-1e38ac.html'}
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe',headless=True)
 for name,url in PAGES.items():
  for width in (1440,375):
   page=browser.new_page(viewport={'width':width,'height':960},device_scale_factor=1)
   page.goto('http://127.0.0.1:8772'+url,wait_until='networkidle',timeout=30000)
   page.screenshot(path=str(OUT/f'before_{name}_{width}.png'))
   if name=='archive':
    page.locator('.mx-scroll').scroll_into_view_if_needed();page.screenshot(path=str(OUT/f'before_matrix_{width}.png'))
   if name=='detail':
    page.locator('.gate-step').first.scroll_into_view_if_needed();page.screenshot(path=str(OUT/f'before_ledger_{width}.png'))
   print(name,width,page.title(),flush=True)
   page.close()
 browser.close()
