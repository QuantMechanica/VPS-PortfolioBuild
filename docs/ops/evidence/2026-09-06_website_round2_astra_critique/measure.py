from pathlib import Path
from playwright.sync_api import sync_playwright
import json,sys
OUT=Path('C:/QM/repo/docs/ops/evidence/2026-09-06_website_round2_astra_critique')
PAGES={'home':'/','archive':'/strategies/index.html','detail':'/strategies/avoid-monday-index-long-1e38ac.html'}
JS=r'''() => {
 const css=e=>getComputedStyle(e), rgba=s=>(s.match(/[\d.]+/g)||[]).map(Number);
 const blend=(a,b)=>[0,1,2].map(i=>a[i]*(a[3]??1)+b[i]*(1-(a[3]??1))).concat(1);
 const bg=e=>{let stack=[];for(let n=e;n;n=n.parentElement)stack.unshift(rgba(css(n).backgroundColor));return stack.reduce((b,a)=>a.length?blend(a,b):b,[255,255,255,1]);};
 const lum=c=>c.slice(0,3).map(x=>x/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4).reduce((a,v,i)=>a+v*[.2126,.7152,.0722][i],0);
 const ratio=(a,b)=>(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
 let failures=new Map(), measures=[], seen=0;
 for(const e of document.querySelectorAll('body *')){
  if(e.closest('[hidden],script,style,canvas,svg')||!e.getClientRects().length)continue;
  let text=[...e.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent).join('').trim();if(!text)continue;
  const s=css(e);if(s.visibility==='hidden'||s.display==='none')continue;
  const background=bg(e);let foreground=rgba(s.color);let opacity=1;for(let n=e;n;n=n.parentElement)opacity*=Number(css(n).opacity);foreground[3]=(foreground[3]??1)*opacity;
  const r=ratio(blend(foreground,background),background);const large=parseFloat(s.fontSize)>=24||(parseFloat(s.fontSize)>=18.66&&Number(s.fontWeight)>=700);const threshold=large?3:4.5;seen++;
  if(r<threshold){const key=e.tagName+'.'+e.className+'|'+s.color+'|'+background.join(',');if(!failures.has(key))failures.set(key,{selector:e.tagName+'.'+e.className,ratio:+r.toFixed(2),threshold,foreground:s.color,background,opacity,text:text.slice(0,75),count:0});failures.get(key).count++;}
 }
 for(const sel of ['h1','.hero__lead','.archive-intro__lead','.record-tagline','.howto dd','.section','.howto__row','.mx-table','.mx-scroll']){const e=document.querySelector(sel);if(!e)continue;const s=css(e);measures.push({selector:sel,font:s.fontFamily,size:s.fontSize,lineHeight:s.lineHeight,tracking:s.letterSpacing,maxWidth:s.maxWidth,width:e.getBoundingClientRect().width,padding:s.padding,margin:s.margin,numerals:s.fontVariantNumeric,scrollWidth:e.scrollWidth,clientWidth:e.clientWidth});}
 const inp=document.querySelector('input:not([disabled])');let placeholder=null;if(inp){const s=getComputedStyle(inp,'::placeholder');placeholder={color:s.color,background:bg(inp),ratio:ratio(rgba(s.color),bg(inp)),opacity:s.opacity};}
 return {width:innerWidth,documentWidth:document.documentElement.scrollWidth,contrastFailures:[...failures.values()],textNodesChecked:seen,measures,placeholder,loadedFonts:[...document.fonts].filter(f=>f.status==='loaded').map(f=>f.family),animations:document.getAnimations().map(a=>({name:a.animationName,state:a.playState})),sortHeaders:document.querySelectorAll('th[data-col][tabindex="0"]').length,visibleRows:document.querySelectorAll('tbody tr:not([hidden])').length};
}'''
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='C:/Program Files/Google/Chrome/Application/chrome.exe',headless=True)
 results=[]
 for name,url in PAGES.items():
  for width in (1440,375):
   page=browser.new_page(viewport={'width':width,'height':960});errors=[]
   page.on('pageerror',lambda e:errors.append(str(e)))
   page.goto('http://127.0.0.1:8772'+url,wait_until='load');page.evaluate('document.fonts.ready');
   if name=='archive': page.wait_for_function("document.querySelector('#mx-count').textContent.includes('showing first 200')")
   r=page.evaluate(JS);r.update(page=name,errors=errors);results.append(r);page.close()
 browser.close()
(OUT/(sys.argv[1]+'_metrics.json')).write_text(json.dumps(results,indent=2))
for r in results: print(r['page'],r['width'],'overflow',r['documentWidth']-r['width'],'contrast',[(f['selector'],f['ratio'],f['count']) for f in r['contrastFailures']],'fonts',r['loadedFonts'])
