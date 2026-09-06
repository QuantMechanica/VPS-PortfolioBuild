from pathlib import Path
from playwright.sync_api import sync_playwright
OUT=Path('C:/QM/repo/docs/ops/evidence/2026-09-06_website_round2_astra_critique')
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe',headless=True)
 for state in ('before','after'):
  page=browser.new_page(viewport={'width':375,'height':960})
  if state=='before':
   page.route('**/archive.css',lambda r:r.fulfill(body=(OUT/'source_before/archive.css').read_bytes(),content_type='text/css'))
  page.goto('http://127.0.0.1:8772/strategies/index.html',wait_until='load');page.wait_for_function("document.querySelector('#mx-count').textContent.includes('showing first 200')");page.evaluate('document.fonts.ready')
  page.locator('.mx-stats').screenshot(path=str(OUT/f'crop_{state}_stats.png'))
  page.locator('.mx-legend-glyphs').screenshot(path=str(OUT/f'crop_{state}_legend.png'))
  page.goto('http://127.0.0.1:8772/strategies/avoid-monday-index-long-1e38ac.html',wait_until='load');page.evaluate('document.fonts.ready')
  page.locator('.gate-step--none').first.screenshot(path=str(OUT/f'crop_{state}_future_gate.png'));page.close()
 browser.close()
print('Six browser crops captured; before crops replay the retained original stylesheet.')
