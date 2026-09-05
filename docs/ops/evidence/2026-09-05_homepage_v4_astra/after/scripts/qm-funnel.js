/* QuantMechanica filter instrument. Independent gate totals, never cohort pass rates. */
(() => {
  'use strict';
  const CSS = `.qm-filter{--q-ink:#0f1720;--q-steel:#2954d4;color:var(--q-ink);position:relative;width:100%}.qm-filter *{box-sizing:border-box}.qm-filter .qf-head{display:flex;align-items:center;justify-content:space-between;gap:16px;border-top:1px solid #b9c1cd;padding:18px 0}.qm-filter .qf-head p{margin:0;font:12px/1.5 'IBM Plex Mono',Consolas,monospace;letter-spacing:.08em;text-transform:uppercase}.qm-filter .qf-toggle{font:13px/1.4 'IBM Plex Mono',Consolas,monospace;background:transparent;color:#0f1720;border:1px solid #8995a5;border-radius:3px;padding:8px 14px;cursor:pointer;flex-shrink:0}.qm-filter .qf-toggle:focus-visible,.qm-filter summary:focus-visible{outline:2px solid #2954d4;outline-offset:4px}.qm-filter .qf-phases{display:grid;grid-template-columns:9fr 6fr 5fr;gap:12px}.qm-filter .qf-phase{border-top:2px solid #0f1720;padding-top:12px;display:grid;gap:4px}.qm-filter .qf-phase strong{font:500 clamp(12px,1.3vw,17px)/1.35 'IBM Plex Sans',system-ui,sans-serif}.qm-filter .qf-phase span{font:11px/1.5 'IBM Plex Mono',Consolas,monospace;color:#4b5869}.qm-filter .qf-stage{width:100%;height:330px;display:block}.qm-filter .qf-note{font:13px/1.6 'IBM Plex Sans',system-ui,sans-serif;color:#3a4653;max-width:78ch;margin:4px 0 18px}.qm-filter .qf-ledger{border-top:1px solid #b9c1cd;padding-top:14px}.qm-filter summary{cursor:pointer;font:14px/1.5 'IBM Plex Sans',system-ui,sans-serif;padding-bottom:12px}.qm-filter .qf-grid{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:0;list-style:none;margin:0;padding:0}.qm-filter .qf-grid li{border-top:1px solid #d3d9e1;padding:12px 8px 12px 0;display:grid;align-content:start;gap:5px}.qm-filter .qf-grid b{font:500 12px/1.4 'IBM Plex Mono',Consolas,monospace}.qm-filter .qf-grid span{font:12px/1.4 'IBM Plex Sans',system-ui,sans-serif;color:#3a4653}.qm-filter .qf-grid em{font:500 20px/1.3 'IBM Plex Mono',Consolas,monospace;font-style:normal}.qm-filter .visually-hidden{display:block!important;position:absolute!important;width:1px!important;height:1px!important;padding:0!important;margin:-1px!important;overflow:hidden!important;clip:rect(0,0,0,0)!important;white-space:nowrap!important;border:0!important}.qm-filter .qf-status{font:13px/1.6 system-ui,sans-serif}@media(max-width:600px){.qm-filter .qf-stage{height:260px}.qm-filter .qf-grid{grid-template-columns:repeat(3,minmax(0,1fr))}.qm-filter .qf-head p{font-size:10px}.qm-filter .qf-phases{gap:8px}.qm-filter .qf-note{font-size:12px}}`;
  const fmt = n => n.toLocaleString('en-US');
  const el = (tag, cls, text) => { const n=document.createElement(tag); if(cls)n.className=cls; if(text!==undefined)n.textContent=text; return n; };
  function valid(d) {
    return d && d.schema==='qm.public-funnel-stats/v1' && Number.isInteger(d.strategies_tested) && d.strategies_tested>0 &&
      d.gates_total===18 && Array.isArray(d.gates) && d.gates.length===18 && Array.isArray(d.phases) && d.phases.length===3 &&
      d.gates.every((g,i)=>g.id==='Q'+String(i).padStart(2,'0') && typeof g.label==='string' && Number.isInteger(g.strategies_cleared) && g.strategies_cleared>=0 && g.strategies_cleared<=d.strategies_tested);
  }
  function mount(host,d) {
    host.classList.add('qm-filter');
    host.replaceChildren();
    const head=el('div','qf-head');head.append(el('p','','Research filter / '+fmt(d.strategies_tested)+' strategies tested'));
    const button=el('button','qf-toggle','Pause');button.type='button';head.append(button);
    const phases=el('div','qf-phases');
    d.phases.forEach(p=>{const n=el('div','qf-phase');n.append(el('strong','',p.name),el('span','',p.gates[0]+'–'+p.gates.at(-1)));phases.append(n);});
    const canvas=el('canvas','qf-stage');canvas.setAttribute('role','img');
    const sentence=`A left-to-right filter with three phases and eighteen gates. ${fmt(d.strategies_tested)} distinct strategies tested. Gate totals are independent censuses, not one cohort or conditional pass rates. ${d.gates.map(g=>g.id+': '+fmt(g.strategies_cleared)+' cleared').join('; ')}. ${d.qualified_pairs_current} qualified market/timeframe pairs are a separate current count.`;
    canvas.setAttribute('aria-label',sentence);
    const note=el('p','qf-note','Each gate shows its recorded total. These are different cohorts, so the moving traces illustrate selection rather than a measured survival rate. An empty outlet reflects no recorded clearances at the final gates.');
    const details=el('details','qf-ledger');details.append(el('summary','','Read all 18 gate counts'));
    const grid=el('ol','qf-grid');
    d.gates.forEach(g=>{const li=el('li');li.append(el('b','',g.id),el('span','',g.label),el('em','',fmt(g.strategies_cleared)));grid.append(li);});details.append(grid);
    const table=el('table','visually-hidden');table.setAttribute('role','table');table.append(el('caption','','Recorded distinct strategies cleared at each gate; independent cohorts.'));
    const tr=el('tr');['Gate','Phase','Recorded clearances'].forEach(s=>{const th=el('th','',s);th.scope='col';tr.append(th);});const thd=el('thead');thd.append(tr);table.append(thd);
    const tbody=el('tbody');d.gates.forEach(g=>{const r=el('tr');r.append(el('td','',g.id+' '+g.label),el('td','',d.phases.find(p=>p.id===g.phase)?.name||g.phase),el('td','',String(g.strategies_cleared)));tbody.append(r);});table.append(tbody);
    host.append(head,phases,canvas,note,details,table);
    const ctx=canvas.getContext('2d');if(!ctx)return;
    const media=matchMedia('(prefers-reduced-motion: reduce)');
    // Astra defaults static; the v4 content-animation brief explicitly opts into calm motion.
    const calmAllowed=host.dataset.reducedMotion==='calm';
    let paused=false;try{paused=localStorage.getItem('qm-funnel-paused')==='true';}catch{}
    let visible=true,raf=0,last=0,clock=0,w=0,h=0,back=null;
    const running=()=>!paused && (!media.matches||calmAllowed) && visible && !document.hidden;
    const heightAt=t=>t<.79 ? 101-(101-15)*(t/.79) : 15;
    function geometry(){const left=w*.075,right=w*.95,span=right-left,cy=h*.51,scale=h/330;return {left,right,span,cy,scale};}
    function base(c) {
      const {left,right,span,cy,scale}=geometry(), neck=left+span*.79, top=101*scale, small=15*scale;
      c.clearRect(0,0,w,h);
      c.save();c.lineWidth=1;c.strokeStyle='#d8dfe8';c.setLineDash([3,6]);c.beginPath();c.moveTo(left-20,cy);c.lineTo(right+12,cy);c.stroke();c.setLineDash([]);
      c.fillStyle='rgba(41,84,212,.035)';c.beginPath();c.moveTo(left,cy-top);c.lineTo(neck,cy-small);c.lineTo(right,cy-small);c.lineTo(right,cy+small);c.lineTo(neck,cy+small);c.lineTo(left,cy+top);c.closePath();c.fill();
      c.strokeStyle='#566577';c.lineWidth=1.5;c.beginPath();c.moveTo(left,cy-top);c.lineTo(neck,cy-small);c.lineTo(right,cy-small);c.moveTo(left,cy+top);c.lineTo(neck,cy+small);c.lineTo(right,cy+small);c.stroke();
      c.beginPath();c.ellipse(left,cy,Math.max(8,w*.019),top,0,0,Math.PI*2);c.stroke();c.beginPath();c.ellipse(right,cy,4,small,0,0,Math.PI*2);c.stroke();
      d.gates.forEach((g,i)=>{
        const t=.065+i*.0525,x=left+span*t,hh=heightAt(t)*scale;
        c.strokeStyle=(i===9||i===15)?'#0f1720':'rgba(15,23,32,.27)';c.lineWidth=(i===9||i===15)?1.5:1;
        c.beginPath();c.moveTo(x,cy-hh);c.lineTo(x,cy+hh);c.stroke();
        c.strokeStyle='rgba(15,23,32,.15)';for(let y=cy-hh+7;y<cy+hh;y+=9){c.beginPath();c.moveTo(x-3,y-2);c.lineTo(x+3,y+2);c.stroke();}
        if(w>=600){c.fillStyle='#3a4653';c.font="11px 'IBM Plex Mono',Consolas,monospace";c.textAlign='center';c.fillText(g.id,x,h-40);c.fillStyle='#0f1720';c.fillText(fmt(g.strategies_cleared),x,h-21);}
      });
      c.textAlign='left';c.fillStyle='#3a4653';c.font="11px 'IBM Plex Mono',Consolas,monospace";c.fillText('OBSERVATIONS',Math.max(0,left-18),18);
      c.textAlign='right';c.fillText('RECORDED CLEARANCES',right,18);
      if(w<600){c.textAlign='center';c.fillText('18 GATES · COUNTS BELOW',w/2,h-10);}
      c.restore();
    }
    function resize(){const rect=canvas.getBoundingClientRect();w=rect.width;h=rect.height;if(!w||!h)return;const dpr=Math.min(devicePixelRatio||1,2);canvas.width=Math.round(w*dpr);canvas.height=Math.round(h*dpr);ctx.setTransform(dpr,0,0,dpr,0,0);back=document.createElement('canvas');back.width=canvas.width;back.height=canvas.height;const b=back.getContext('2d');b.setTransform(dpr,0,0,dpr,0,0);base(b);draw();}
    function draw(){if(!back)return;ctx.clearRect(0,0,w,h);ctx.drawImage(back,0,0,w,h);const {left,span,cy,scale}=geometry();ctx.lineCap='round';
      // Each station is an independent sample density, with a deterministic fractional token.
      // No transition divides one gate by its predecessor, and zero draws no trace.
      d.gates.forEach((g,i)=>{const density=g.strategies_cleared/d.strategies_tested*30;const n=Math.ceil(density);for(let j=0;j<n;j++){
        const fraction=Math.min(1,density-j);const phase=(clock*.13+(j*.618033+i*.173))%1;
        const t=.014+i*.0525+phase*.047,x=left+span*t;
        const lane=Math.sin((j+1)*127.1+(i+1)*31.7)*.79;
        const y=cy+lane*heightAt(t)*scale;const fade=Math.sin(Math.PI*phase);
        ctx.strokeStyle=`rgba(41,84,212,${(.25+.65*fade)*fraction})`;ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(x-3.8,y);ctx.lineTo(x,y);ctx.stroke();
      }});
    }
    function state(){button.textContent=paused?'Play':media.matches&&!calmAllowed?'Play motion':'Pause';button.setAttribute('aria-label',paused?'Play funnel animation':media.matches&&!calmAllowed?'Enable funnel motion':'Pause funnel animation');button.setAttribute('aria-pressed',String(paused));host.dataset.motion=running()?'running':paused?'paused':'static';}
    let explicitMotion=false;
    // Explicit Play may override the static preference; automatic reduced motion never does.
    const isRunning=()=>!paused && ((!media.matches||calmAllowed)||explicitMotion) && visible && !document.hidden;
    function frame(now){raf=0;if(!isRunning()){last=0;state();return;}if(last)clock+=Math.min((now-last)/1000,.05)*(media.matches?.45:1);last=now;draw();host.dataset.motion='running';raf=requestAnimationFrame(frame);}
    function sync(){if(raf)cancelAnimationFrame(raf);raf=0;last=0;state();draw();if(isRunning())raf=requestAnimationFrame(frame);}
    button.addEventListener('click',()=>{if(media.matches&&!calmAllowed&&!explicitMotion&&!paused){explicitMotion=true;}else paused=!paused;try{localStorage.setItem('qm-funnel-paused',String(paused));}catch{}sync();});
    media.addEventListener('change',()=>{explicitMotion=false;sync();});document.addEventListener('visibilitychange',sync);
    if('IntersectionObserver' in window)new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;sync();},{rootMargin:'80px'}).observe(host);
    if('ResizeObserver' in window)new ResizeObserver(resize).observe(canvas);else addEventListener('resize',resize);
    resize();sync();host.dataset.ready='true';
    return {canvas,data:d,redraw:resize,get motion(){return isRunning();}};
  }
  const style=el('style');style.textContent=CSS;document.head.append(style);
  window.QMFunnel={version:'3.0.0',mount,instances:[]};
  document.querySelectorAll('[data-qm-funnel],#gate-funnel').forEach(async host=>{
    try{const response=await fetch(host.dataset.src||'/public-data/funnel-stats.json',{cache:'no-store'});if(!response.ok)throw Error('Unavailable');const d=await response.json();if(!valid(d))throw Error('Invalid contract');const instance=mount(host,d);QMFunnel.instances.push(instance);document.dispatchEvent(new CustomEvent('qm:funnel-data',{detail:d}));}
    catch{host.replaceChildren(el('p','qf-status','Gate data is currently unavailable. Read the pipeline description for the research process.'));host.dataset.ready='error';}
  });
})();
