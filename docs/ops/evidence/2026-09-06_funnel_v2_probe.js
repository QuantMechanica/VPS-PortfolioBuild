// Local-only browser verification; requires a disposable headless Chrome on 9347.
const fs = require('node:fs');
const base = 'C:/QM/repo/docs/ops/evidence/2026-09-06_funnel_v2';
const pause = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const targets = await (await fetch('http://127.0.0.1:9347/json')).json();
  const ws = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let seq = 0; const pending = new Map(), errors = [];
  ws.onmessage = e => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) {
      const p = pending.get(m.id); pending.delete(m.id);
      m.error ? p.reject(m.error) : p.resolve(m.result);
    }
    if (m.method === 'Runtime.exceptionThrown') errors.push(m.params.exceptionDetails);
  };
  const call = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++seq; pending.set(id, {resolve, reject}); ws.send(JSON.stringify({id, method, params}));
  });
  const evaluate = async expression => {
    const r = await call('Runtime.evaluate', {expression, returnByValue: true, awaitPromise: true});
    if (r.exceptionDetails) throw Error(JSON.stringify(r.exceptionDetails));
    return r.result.value;
  };
  await call('Page.enable'); await call('Runtime.enable');
  await call('Page.bringToFront');
  await call('Emulation.setDeviceMetricsOverride', {width: 1440, height: 1100, deviceScaleFactor: 1, mobile: false});
  await call('Page.navigate', {url: 'http://127.0.0.1:8772/'});
  for (let i = 0; i < 60; i++) {
    if (await evaluate("!!document.getElementById('gate-funnel')?._qmFunnel")) break;
    await pause(150);
  }
  await evaluate("document.fonts.ready.then(()=>true)");
  await evaluate(`(()=>{const f=document.getElementById('gate-funnel')._qmFunnel;
    document.documentElement.style.scrollBehavior='auto';
    f.canvas.scrollIntoView({block:'center',behavior:'instant'});
    f.paused=true; f.t=0; f.control(); f.sync(); f.draw(); return true;})()`);
  await pause(200);
  const screenshot = async name => {
    const clip = await evaluate(`(()=>{const r=document.getElementById('gate-funnel').closest('section').getBoundingClientRect();
      return {x:Math.max(0,r.x+scrollX-12), y:Math.max(0,r.y+scrollY-12),
        width:Math.min(innerWidth,r.width+24), height:r.height+24, scale:1};})()`);
    const r = await call('Page.captureScreenshot', {format:'png', captureBeyondViewport:true, clip});
    fs.writeFileSync(base + '_' + name + '.png', Buffer.from(r.data, 'base64'));
  };
  const facts = await evaluate(`(()=>{const f=document.getElementById('gate-funnel')._qmFunnel;
    const pixels=f.ctx.getImageData(0,0,f.canvas.width,f.canvas.height).data;
    let visible=0; for(let i=3;i<pixels.length;i+=4) if(pixels[i])visible++;
    return {gates:f.model.data.gates.length, phases:f.model.data.phases.length,
      counts:[...f.register.querySelectorAll('li b')].map(n=>n.textContent),
      expected:f.model.data.gates.map(g=>Number(g.strategies_cleared).toLocaleString('en-US')),
      accent:f.colors.accent, siteAccent:getComputedStyle(f.el).getPropertyValue('--accent').trim(),
      halfAtMidpoint:f.half((f.left+f.neck)/2), linearMidpoint:(f.rim+f.tube)/2,
      restVisiblePixels:visible, restTime:f.t, text:f.el.innerText,
      pausedButton:f.button.textContent, pausedRaf:f.raf};})()`);
  if (facts.gates !== 18 || facts.phases !== 3 || JSON.stringify(facts.counts) !== JSON.stringify(facts.expected)) throw Error('Census mismatch');
  if (facts.restVisiblePixels < 3000 || facts.halfAtMidpoint >= facts.linearMidpoint) throw Error('Missing or straight profile');
  if (facts.accent !== facts.siteAccent) throw Error('Accent mismatch');
  if (/QM5_\d|[A-Z]:[\\/]|T_Live|AutoTrading|qm_\w+|\bmagic\b|[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}/i.test(facts.text)) throw Error('Private token in funnel');
  await screenshot('rest');
  await call('Emulation.setDeviceMetricsOverride', {width:1440,height:1100,deviceScaleFactor:1,mobile:false});
  await evaluate("window.scrollTo({top:0,behavior:'instant'})");
  await pause(100);
  await evaluate("document.getElementById('gate-funnel')._qmFunnel.canvas.scrollIntoView({block:'center',behavior:'instant'})");
  await pause(150);
  await evaluate("document.querySelector('#gate-funnel .funnel__control').click()");
  await pause(1250);
  facts.animationTime = await evaluate("document.getElementById('gate-funnel')._qmFunnel.t");
  if (facts.animationTime <= .3) throw Error('Animation did not advance: ' + JSON.stringify(await evaluate("(()=>{const f=document.getElementById('gate-funnel')._qmFunnel;return {visible:f.visible,hidden:document.hidden,paused:f.paused,reduced:f.media.matches,raf:f.raf,t:f.t}})()")));
  await screenshot('animation');
  await call('Emulation.setEmulatedMedia', {features:[{name:'prefers-reduced-motion',value:'reduce'}]});
  await pause(150);
  const reducedTime = await evaluate("document.getElementById('gate-funnel')._qmFunnel.t");
  await pause(300);
  facts.reduced = await evaluate(`(()=>{const f=document.getElementById('gate-funnel')._qmFunnel; return {time:f.t,raf:f.raf,button:f.button.textContent};})()`);
  if (facts.reduced.time !== reducedTime || facts.reduced.raf !== 0) throw Error('Reduced motion still animates');
  await call('Emulation.setDeviceMetricsOverride', {width:390,height:844,deviceScaleFactor:1,mobile:false});
  await pause(200);
  facts.mobile = await evaluate(`(()=>{const f=document.getElementById('gate-funnel')._qmFunnel;return {
    pageWidth:document.documentElement.scrollWidth,viewport:innerWidth,
    canvasWidth:f.w,gateRows:f.register.querySelectorAll('li').length};})()`);
  if (facts.mobile.pageWidth > facts.mobile.viewport || facts.mobile.gateRows !== 18) throw Error('Mobile overflow or lost gates');
  facts.runtimeErrors = errors;
  if (errors.length) throw Error('Browser runtime errors');
  delete facts.text;
  fs.writeFileSync(base + '_verification.json', JSON.stringify(facts,null,2)+'\n');
  console.log(JSON.stringify(facts,null,2));
  await call('Browser.close');
})().catch(e => {console.error(e); process.exitCode=1; process.exit();});
