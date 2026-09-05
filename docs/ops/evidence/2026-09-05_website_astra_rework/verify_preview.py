"""Serve the review directory locally, inspect browser behavior, then shut down."""
import hashlib
import http.server
import json
import re
import threading
from functools import partial
from pathlib import Path
from urllib.parse import unquote, urlsplit

from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright

OUT=Path(__file__).resolve().parent
ROOT=Path('C:/QM/deploy/qm-ops-refresh/tools/site-build/astra-rework')
SRC=Path('C:/QM/deploy/qm-ops-refresh/Website')


class Pretty(http.server.SimpleHTTPRequestHandler):
    def translate_path(self,path):
        target=Path(super().translate_path(path))
        if target.suffix=='' and (not target.exists() or target.is_dir()):
            html=target.with_suffix('.html')
            if html.is_file():return str(html)
        return str(target)
    def log_message(self,*args):pass


def static_checks():
    missing=[];bad_fragments=[];exposure=[];metadata=[];numbers=[]
    forbidden=re.compile(r'(?i)(?:[CD]:[\\/]|/QM/|T_Live|\bT(?:[1-9]|1[0-2])\b|\bmagic\b|\bRISK_|\bqm_|\bQM5_\d+|\.mq5\b|\.ex5\b)')
    # Browser asset code necessarily has numbers; prose is checked separately.
    for p in ROOT.rglob('*'):
        if p.is_file() and p.suffix in ('.html','.js','.json','.css'):
            text=p.read_text(encoding='utf-8-sig')
            matches=list(forbidden.finditer(text))
            if matches:exposure.append({'file':str(p.relative_to(ROOT)),'hits':[m.group() for m in matches[:8]]})
        if p.suffix!='.html':continue
        soup=BeautifulSoup(p.read_text(encoding='utf-8'),'html.parser')
        if not soup.title or not soup.find('meta',attrs={'name':'description'}) or len(soup.find_all('h1'))!=1:metadata.append(str(p.relative_to(ROOT)))
        for el in soup.select('[href],[src]'):
            raw=el.get('href') or el.get('src') or '';url=urlsplit(raw)
            if url.scheme or url.netloc:continue
            path=unquote(url.path)
            dest=ROOT/path.lstrip('/') if path.startswith('/') else p.parent/path
            if path=='/':dest=ROOT/'index.html'
            if not path:dest=p
            if not dest.exists() and not dest.suffix:dest=dest.with_suffix('.html')
            if not dest.exists():missing.append({'page':str(p.relative_to(ROOT)),'url':raw})
            elif url.fragment and dest.suffix=='.html':
                target=soup if dest==p else BeautifulSoup(dest.read_text(encoding='utf-8'),'html.parser')
                if not target.find(id=url.fragment):bad_fragments.append({'page':str(p.relative_to(ROOT)),'url':raw})
        if p.parent==ROOT:
            for t in soup.select('main'):
                # Retain a reviewable inventory instead of equating gate IDs,
                # dates, legal section numbers and measured values.
                for line in t.get_text(' ',strip=True).split('. '):
                    if re.search(r'\d',line):numbers.append({'page':p.name,'text':line[:600]})
    original=json.loads((OUT/'source_manifest.json').read_text())
    now={str(p.relative_to(SRC)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in SRC.rglob('*') if p.is_file()}
    return {'html_count':len(list(ROOT.rglob('*.html'))),'missing_links':missing,'bad_fragments':bad_fragments,'exposure':exposure,'metadata_errors':metadata,'numeric_prose_inventory':numbers,'source_website_unchanged':original==now}


def browser_checks():
    server=http.server.ThreadingHTTPServer(('127.0.0.1',8771),partial(Pretty,directory=str(ROOT)))
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    results=[];errors=[]
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe',headless=True)
            context=browser.new_context(viewport={'width':1400,'height':1050},device_scale_factor=1,reduced_motion='reduce')
            context.route('**/*',lambda route: route.continue_() if urlsplit(route.request.url).hostname in ('127.0.0.1',None) else route.abort())
            tab=context.new_page();tab.on('pageerror',lambda e:errors.append(str(e)))
            for width in (1400,800):
                tab.set_viewport_size({'width':width,'height':1050})
                for name in ('index','pipeline','strategies','strategies/_template','performance'):
                    url='http://127.0.0.1:8771/'+('' if name=='index' else name)
                    response=tab.goto(url,wait_until='networkidle')
                    if name=='strategies':tab.locator('.archive-card').first.wait_for()
                    if name in ('index','performance'):tab.locator('[data-live-chart] svg').wait_for()
                    dest=OUT/(name.replace('/','_')+'_'+str(width)+'.png');tab.screenshot(path=str(dest),full_page=True)
                    layout=tab.evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth,title:document.title,h1:document.querySelector("h1").innerText})')
                    results.append({'page':name,'viewport':width,'status':response.status,'render':dest.name,**layout})
            tab.set_viewport_size({'width':390,'height':844});tab.goto('http://127.0.0.1:8771/strategies',wait_until='networkidle');tab.locator('.archive-card').first.wait_for()
            tab.get_by_label('Find a strategy or market').fill('EURUSD')
            assert tab.locator('.archive-card').count()>0
            assert all('EURUSD' in c.inner_text() for c in tab.locator('.archive-card').all())
            tab.get_by_label('Find a strategy or market').fill('zzzz-no-record-expected')
            assert tab.locator('.archive-card').count()==0
            assert 'No records' in tab.locator('#archive-list').inner_text()
            tab.get_by_label('Find a strategy or market').fill('')
            tab.get_by_label('Recorded outcome').select_option('fail')
            assert all(c.locator('.result--fail').count()>0 for c in tab.locator('.archive-card').all())
            tab.get_by_label('Open navigation').focus();tab.keyboard.press('Enter')
            assert tab.locator('.nav__burger').get_attribute('aria-expanded')=='true'
            tab.keyboard.press('Escape');assert tab.locator('.nav__burger').get_attribute('aria-expanded')=='false'
            tab.get_by_label('Recorded outcome').select_option('all')
            tab.screenshot(path=str(OUT/'strategies_mobile_390.png'),full_page=True)
            mobile=tab.evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth})')
            results.append({'page':'strategies','viewport':390,**mobile,'filter_empty_market_tests':True,'keyboard_menu_escape':True})
            # Data failures are visible; an unavailable series never draws a fake curve.
            tab.route('**/public-data/live-performance.json',lambda r:r.abort())
            tab.goto('http://127.0.0.1:8771/performance',wait_until='networkidle')
            assert 'unavailable' in tab.locator('[data-live-chart]').inner_text()
            assert tab.locator('[data-live-chart] svg').count()==0
            results.append({'page':'performance','data_unavailable_state':True})
            context.close();browser.close()
    finally:server.shutdown();server.server_close()
    return {'renders':results,'javascript_errors':errors,'server_stopped':True}


if __name__=='__main__':
    static=static_checks();(OUT/'static_verification.json').write_text(json.dumps(static,indent=2)+'\n')
    print('static',json.dumps({k:v for k,v in static.items() if k!='numeric_prose_inventory'}))
    browser=browser_checks();(OUT/'browser_verification.json').write_text(json.dumps(browser,indent=2)+'\n');print('browser',json.dumps(browser))
