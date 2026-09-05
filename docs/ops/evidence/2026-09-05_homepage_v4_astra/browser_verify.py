from pathlib import Path
from playwright.sync_api import sync_playwright
from PIL import Image, ImageChops
import hashlib, json, statistics

ROOT = Path(__file__).parent
URL = 'http://127.0.0.1:8771/'
report = {'url': URL, 'viewports': [], 'errors': []}
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe', headless=True)
    context = browser.new_context(viewport={'width': 1400, 'height': 1000}, reduced_motion='no-preference', device_scale_factor=1)
    page = context.new_page()
    page.on('pageerror', lambda e: report['errors'].append(str(e)))
    page.on('console', lambda m: report['errors'].append(m.text) if m.type == 'error' else None)
    for width in [1400, 800, 390]:
        page.set_viewport_size({'width': width, 'height': 1000})
        page.goto(URL, wait_until='networkidle')
        page.locator('#gate-funnel[data-ready="true"]').wait_for()
        assert ' '.join(page.locator('h1').inner_text().split()) == 'The Quantitative Edge.'
        assert page.locator('.qf-grid li').count() == 18
        assert page.locator('table.visually-hidden tbody tr').count() == 18
        assert page.locator('.qm-mechanic canvas').count() == 3
        assert page.locator('link[rel="canonical"]').get_attribute('href') == 'https://quantmechanica.com/'
        assert page.locator('.contact-panel input[disabled]').count() == 1
        assert page.locator('.footer').count() == 1
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(ROOT / f'astra-{width}.png'), full_page=True)
        page.locator('#gate-funnel').scroll_into_view_if_needed()
        page.locator('#gate-funnel').screenshot(path=str(ROOT / f'funnel-{width}.png'))
        report['viewports'].append({'width': width, 'overflow': False, 'gate_rows': 18, 'mechanics_charts': 3})
    page.set_viewport_size({'width': 1400, 'height': 1000})
    page.locator('#gate-funnel').scroll_into_view_if_needed()
    page.wait_for_timeout(250)
    canvas = page.locator('.qf-stage')
    canvas.screenshot(path=str(ROOT / 'motion-a.png'))
    page.wait_for_timeout(2000)
    canvas.screenshot(path=str(ROOT / 'motion-b.png'))
    diff = ImageChops.difference(Image.open(ROOT/'motion-a.png').convert('RGB'), Image.open(ROOT/'motion-b.png').convert('RGB'))
    changed = sum(1 for pixel in diff.getdata() if pixel != (0, 0, 0))
    assert changed > 0
    report['normal_motion_changed_pixels_2s'] = changed
    intervals = page.evaluate('''() => new Promise(resolve => {const xs=[];let last;function f(t){if(last)xs.push(t-last);last=t;if(xs.length<120)requestAnimationFrame(f);else resolve(xs);}requestAnimationFrame(f);})''')
    report['host_frame_timing_ms'] = {'median': statistics.median(intervals), 'p95': sorted(intervals)[113], 'frames': len(intervals), 'scope': 'Headless review host, not a laptop performance certification'}
    button = page.locator('.qf-toggle')
    button.focus(); page.keyboard.press('Enter')
    assert button.inner_text() == 'Play'
    a=canvas.evaluate('(c)=>c.toDataURL()');page.wait_for_timeout(350);assert canvas.evaluate('(c)=>c.toDataURL()')==a
    page.reload(wait_until='networkidle');assert page.locator('.qf-toggle').inner_text()=='Play'
    report['keyboard_pause_persists_reload'] = True
    page.evaluate('localStorage.removeItem("qm-funnel-paused")')
    page.emulate_media(reduced_motion='reduce');page.reload(wait_until='networkidle')
    page.locator('#gate-funnel').scroll_into_view_if_needed();page.wait_for_timeout(250)
    a=page.locator('.qf-stage').evaluate('(c)=>c.toDataURL()');page.wait_for_timeout(700)
    assert page.locator('.qf-stage').evaluate('(c)=>c.toDataURL()')==a
    report['reduced_motion_funnel_static'] = True
    page.locator('.qm-hero').scroll_into_view_if_needed();page.wait_for_timeout(100)
    a=page.locator('#hero-bg').evaluate('(c)=>c.toDataURL()');page.wait_for_timeout(500)
    assert page.locator('#hero-bg').evaluate('(c)=>c.toDataURL()')==a
    report['reduced_motion_hero_static'] = True
    text=page.locator('body').inner_text()
    import re
    assert not re.search(r'[CDG]:[/\\]|terminal64|T_Live|QM5_\d|agent_task|magic_slot|RISK_FIXED',text,re.I)
    report['exposure_scan'] = 'PASS'
    assert not report['errors'], report['errors']
    browser.close()
(ROOT/'browser-verification.json').write_text(json.dumps(report, indent=2)+'\n',encoding='utf-8')
print(json.dumps(report, indent=2))
