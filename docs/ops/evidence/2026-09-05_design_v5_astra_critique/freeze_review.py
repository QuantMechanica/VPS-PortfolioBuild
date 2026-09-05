"""Freeze evidence and generate an UNAPPLIED CEO refinement proposal."""
from pathlib import Path
import datetime as dt
import difflib
import hashlib
import json
import re
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent
SITE = Path('C:/QM/deploy/qm-ops-refresh/tools/site-build/homepage-v4')

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def diff(a, b, name):
    return ''.join(difflib.unified_diff(a.splitlines(True), b.splitlines(True), fromfile='a/'+name, tofile='b/'+name))

for filename in ('style.css', 'index.html'):
    assert sha(ROOT/'baseline'/filename) == sha(SITE/filename), f'CEO file changed: {filename}; regenerate proposal against it before review'
assert sha(ROOT/'qm-funnel.js') == sha(SITE/'scripts/qm-funnel.js')
assert (ROOT/'qm-funnel.js').stat().st_size < 45000
assert sha(ROOT/'funnel-stats.json') == sha(SITE/'public-data/funnel-stats.json')

old_css = (ROOT/'baseline/style.css').read_text(encoding='utf-8')
new_css = old_css + '''

/* PROPOSAL ONLY — Astra v5 co-design. CEO decides which hunks to merge. */
/* Align the hero to the record grid and let content determine its height. */
.hero--canvas{min-height:0;padding-block:96px 104px}
.hero--canvas .hero__inner{max-width:var(--wide);display:grid;grid-template-columns:repeat(12,minmax(0,1fr));gap:24px}
.hero--canvas :is(.hero__eyebrow,.hero__title,.hero__cta){grid-column:1/-1;margin:0}
.hero--canvas .hero__title{font-weight:500;letter-spacing:-.02em;line-height:1.08}
.hero--canvas .hero__lead{grid-column:1/9;max-width:60ch;margin:0}
.hero--canvas .hero__source{grid-column:1/-1;margin:0;color:var(--ink-3);font:400 13px/1.55 var(--font-mono)}
/* Six related observations compose one deliberate 3 x 2 instrument. */
@media(min-width:960px){.figure-grid{grid-template-columns:repeat(3,minmax(0,1fr))}}
/* Keep archive names expressive, with quiet, aligned evidence metadata. */
.archive-list .archive-card{padding-block:24px;gap:32px;align-items:start}
.archive-list .archive-card__name{font-size:24px;font-weight:500;line-height:1.2}
.archive-list .archive-card__markets{font-family:var(--font-mono);font-size:13px;line-height:1.7;color:var(--ink-2)}
.archive-list .archive-card__dates{font-family:var(--font-mono);font-size:13px;color:var(--ink-3)}
.archive-list .record-link{align-self:start;margin-top:4px}
.archive-list .archive-card:focus-within{background:var(--paper-alt)}
.archive-toolbar[role="search"]{position:sticky;top:var(--nav-h);z-index:20;background:var(--paper);padding-block:16px;border-bottom:1px solid var(--line)}
/* Full-width instrument rail, no shadows or decorative accent rails. */
.mechanic-row__chart.chart--frame{border-radius:0;border-color:var(--frame)}
.instrument-caption{padding:12px 16px;border-top:1px solid var(--line);font:400 13px/1.55 var(--font-mono);color:var(--ink-2);background:var(--paper-2)}
@media(max-width:800px){
  .hero--canvas{padding-block:64px 72px}
  .hero--canvas .hero__lead{grid-column:1/-1}
  .archive-list .archive-card{gap:20px}
  .archive-toolbar[role="search"]{position:static}
}
'''

old_html = (ROOT/'baseline/index.html').read_text(encoding='utf-8')
new_html = old_html.replace(
    'The archive is the centre — every named strategy, every test and every result is there to inspect.',
    'Explore the named strategy families, their markets, and recorded test outcomes in the archive.')
anchor = '<a class="btn btn--secondary" href="/pipeline">Understand the tests</a>\n</div>'
assert anchor in new_html
new_html = new_html.replace(anchor, anchor + '\n<p class="hero__source">Background: illustrative price action. Observed performance is shown below.</p>', 1)
new_html = new_html.replace('Sequential test gates every strategy passes, from Q00 through Q17.',
                            'Research and operational checkpoints, from Q00 through Q17.')
new_html = new_html.replace('Every strategy enters on the left and is sieved at eighteen gates. Only a few reach the right. The widths follow the real counts from the latest census.',
                            'An idea moves through validation, requalification, and portfolio checks. The funnel illustrates selection; the gate register shows the actual census counts.')
new_html = new_html.replace('Each figure is the number of distinct strategies that cleared that gate, and the balls illustrate the measured pass ratios. Requalification gates (Q09 onward) score per market-and-timeframe subsets, so their counts are not a strict subset of the earlier validation chain — a later gate can show a higher count than an earlier one.',
                            'Gate counts record distinct strategies with at least one passing market-and-timeframe test. From Q09 onward, subset retests are not a conversion chain; counts can rise. Zero means no recorded clearance. Qualified strategy-and-market pairs are a separate measure. Shape and traces illustrate the process.')
for canvas, label in [('w-eurusd','EURUSD · illustrative price action'),('w-us100','US 100 · illustrative price action'),('w-xauusd','XAUUSD · illustrative price action')]:
    anchor = f'<div class="mechanic-row__chart chart chart--frame"><canvas id="{canvas}" style="width:100%;height:300px"></canvas></div>'
    assert anchor in new_html
    new_html = new_html.replace(anchor, anchor.replace('</canvas></div>',f'</canvas><p class="instrument-caption">{label} · price axis at right</p></div>'))

(ROOT/'refinements_unapplied.diff').write_text(diff(old_css,new_css,'style.css')+diff(old_html,new_html,'index.html'),encoding='utf-8',newline='\n')
(ROOT/'qm-funnel.diff').write_text(diff((ROOT/'baseline/qm-funnel.js').read_text(encoding='utf-8'),(ROOT/'qm-funnel.js').read_text(encoding='utf-8'),'scripts/qm-funnel.js'),encoding='utf-8',newline='\n')

def changed(a,b,box=None):
    with Image.open(a) as aa, Image.open(b) as bb:
        x,y=aa.convert('RGB'),bb.convert('RGB')
        assert x.size==y.size
        if box: x,y=x.crop(box),y.crop(box)
        delta=ImageChops.difference(x,y)
        count=sum(1 for p in delta.getdata() if max(p)>12)
        return {'size':x.size,'threshold_channel_delta':12,'changed_pixels':count,'fraction':count/(x.width*x.height)}

motion={}
for width in (1400,800):
    motion[str(width)]=changed(ROOT/f'funnel_{width}_t1.png',ROOT/f'funnel_{width}_t2.png')
    motion[str(width)]['paused']=changed(ROOT/f'paused_{width}_t1.png',ROOT/f'paused_{width}_t2.png')
    assert motion[str(width)]['changed_pixels']>250, 'Visible content motion required'
    assert motion[str(width)]['paused']['changed_pixels']==0, 'Pause must freeze every funnel pixel'
ceo=(ROOT/'ceo_probe.txt').read_text(encoding='utf-16' if (ROOT/'ceo_probe.txt').read_bytes().startswith(b'\xff\xfe') else 'utf-8-sig')
probe=json.loads(re.search(r'probe (\{[^\n]+\})',ceo).group(1))
cx,cy,top=probe['funnelSize']
motion['supplied_ceo_probe']={**changed(ROOT/'ceo_probe_t1.png',ROOT/'ceo_probe_t2.png',(142,top,142+cx,top+cy)), 'reported_reduced_motion':probe['reducedMotion'],'funnel_band':[142,top,142+cx,top+cy]}
assert motion['supplied_ceo_probe']['changed_pixels']>250
assert 'console: none' in ceo
browser=json.loads((ROOT/'browser_verification.json').read_text())
assert len(browser['results'])==2
assert all(r['state']['reducedMotion'] and r['keyboardPause'] and r['accessibleTable'] and not r['errors'] and not r['warnings'] for r in browser['results'])

def luminance(h):
    rgb=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    rgb=[c/12.92 if c<=0.04045 else ((c+0.055)/1.055)**2.4 for c in rgb]
    return sum(c*w for c,w in zip(rgb,(.2126,.7152,.0722)))
contrasts={h:round((luminance('#f4f6f8')+.05)/(luminance(h)+.05),3) for h in ['#6b7785','#5f6b78','#b7791f','#8a5a10','#2954d4']}
record={
    'verified_utc':dt.datetime.now(dt.UTC).isoformat(), 'status':'PASS',
    'motion':motion,'contrast_on_paper':contrasts,'js_bytes':(ROOT/'qm-funnel.js').stat().st_size,
    'boundary':{'css_unchanged':True,'html_unchanged':True,'public_census_unchanged':True,'deploy_repo_commit':False,'deployed':False},
    'hashes':{str(p.relative_to(ROOT)):sha(p) for p in [ROOT/'baseline/style.css',ROOT/'baseline/index.html',ROOT/'baseline/qm-funnel.js',ROOT/'qm-funnel.js',ROOT/'funnel-stats.json',ROOT/'refinements_unapplied.diff',ROOT/'qm-funnel.diff']}
}
(ROOT/'verification.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record,indent=2))
