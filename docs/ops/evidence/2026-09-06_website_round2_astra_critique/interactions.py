from pathlib import Path
from playwright.sync_api import sync_playwright
import json
OUT=Path('C:/QM/repo/docs/ops/evidence/2026-09-06_website_round2_astra_critique')
results=[]
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe',headless=True)
 for width in (1440,375):
  page=browser.new_page(viewport={'width':width,'height':960});page.goto('http://127.0.0.1:8772/strategies/index.html',wait_until='load');page.wait_for_function("document.querySelector('#mx-count').textContent.includes('showing first 200')")
  r={'width':width,'initial_rows':page.locator('#mx-body tr:not([hidden])').count()}
  page.locator('#mx-more').click();r['after_more_rows']=page.locator('#mx-body tr:not([hidden])').count()
  search=page.locator('#mx-search');search.fill('zzzzNoSuchStrategy');page.wait_for_function("!document.querySelector('#mx-empty').hidden")
  r['empty_visible']=page.locator('#mx-empty').is_visible();r['empty_rows']=page.locator('#mx-body tr:not([hidden])').count()
  page.screenshot(path=str(OUT/f'after_empty_{width}.png'))
  search.fill('');page.wait_for_function("document.querySelector('#mx-count').textContent.includes('showing first 200')")
  header=page.locator('th[data-col]').first;header.focus();header.press('Enter');r['sort']=header.get_attribute('aria-sort');r['focus']=header.evaluate('(e)=>({outline:getComputedStyle(e).outlineStyle,width:getComputedStyle(e).outlineWidth})')
  scroll=page.locator('.mx-scroll');scroll.scroll_into_view_if_needed();scroll.evaluate('(e)=>{e.scrollLeft=700;e.scrollTop=300}')
  r['sticky']=page.evaluate('''()=>{let box=document.querySelector('.mx-scroll').getBoundingClientRect();let first=document.querySelector('#mx-body tr:not([hidden]) .mx-name').getBoundingClientRect();let head=document.querySelector('.mx-h-name').getBoundingClientRect();return {scrollLeft:document.querySelector('.mx-scroll').scrollLeft,boxLeft:box.left,firstLeft:first.left,headerLeft:head.left,pageOverflow:document.documentElement.scrollWidth-innerWidth}}''')
  page.screenshot(path=str(OUT/f'after_sticky_{width}.png'))
  if width==375:
   page.locator('.nav__burger').click();r['menu_open']=page.locator('.nav__burger').get_attribute('aria-expanded');page.keyboard.press('Escape');r['menu_closed_label']=page.locator('.nav__burger').get_attribute('aria-label');r['menu_inert']=page.locator('#mobile-menu').evaluate('(e)=>e.inert')
  results.append(r);page.close()
 # Simulated network errors are confined to this isolated browser context.
 page=browser.new_page(viewport={'width':375,'height':960},reduced_motion='reduce');page.goto('http://127.0.0.1:8772/',wait_until='load');page.wait_for_selector('button[aria-label="Funnel animation stopped by your reduced-motion preference"]',timeout=15000)
 results.append({'reduced_motion':True,'funnel_paused':page.locator('button[aria-label="Funnel animation stopped by your reduced-motion preference"]').count()==1,'hero_visible':page.locator('#hero-bg').is_visible()});page.close()
 page=browser.new_page();page.route('**/public-data/live-performance.json',lambda route:route.abort());page.goto('http://127.0.0.1:8772/',wait_until='load');page.wait_for_function("document.querySelector('[data-live-chart]').textContent.includes('temporarily unavailable')")
 results.append({'network_error_message':page.locator('[data-live-chart]').inner_text()});page.close();browser.close()
(OUT/'interaction_checks.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
