// Review-only browser verification. Owns only its spawned headless Chrome process.
const {spawn} = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const net = require('net');
const assert = require('assert/strict');
const out = __dirname;
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function freePort() {
  const server = net.createServer();
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const p = server.address().port; await new Promise(r => server.close(r)); return p;
}
async function run(width) {
  const port = await freePort();
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'qm-funnel-review-'));
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--remote-debugging-port='+port,
    '--user-data-dir='+profile, 'about:blank'
  ], {stdio:'ignore', windowsHide:true});
  let ws;
  try {
    let target;
    for (let i=0; i<50 && !target; i++) {
      await sleep(200);
      try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(x=>x.type==='page'); } catch (_) {}
    }
    assert(target, 'Own CDP target is available');
    ws = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise(r=>ws.onopen=r);
    let id=0; const pending=new Map(), errors=[], warnings=[];
    ws.onmessage = msg => {
      const j=JSON.parse(msg.data);
      if(j.id && pending.has(j.id)) {const p=pending.get(j.id); pending.delete(j.id); j.error?p.reject(Error(JSON.stringify(j.error))):p.resolve(j.result);}
      else if(j.method==='Runtime.exceptionThrown') errors.push(j.params.exceptionDetails);
      else if(j.method==='Runtime.consoleAPICalled' && ['error','warning'].includes(j.params.type))
        (j.params.type==='error'?errors:warnings).push(j.params.args.map(a=>a.value||a.description));
      else if(j.method==='Log.entryAdded' && j.params.entry.level==='error') errors.push(j.params.entry);
    };
    const send=(method,params={})=>new Promise((resolve,reject)=>{let i=++id;pending.set(i,{resolve,reject});ws.send(JSON.stringify({id:i,method,params}));});
    const ev=async expression=>{
      const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
      if(r.exceptionDetails) throw Error(JSON.stringify(r.exceptionDetails)); return r.result.value;
    };
    const shot=async(name,clip)=>{
      const r=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:!!clip,...(clip?{clip}: {})});
      fs.writeFileSync(path.join(out,name+'.png'),Buffer.from(r.data,'base64'));
    };
    const waitFor=async expression=>{for(let i=0;i<80;i++){if(await ev(expression))return;await sleep(150);}throw Error('Condition timed out: '+expression);};
    await send('Runtime.enable'); await send('Page.enable'); await send('Log.enable');
    await send('Emulation.setDeviceMetricsOverride',{width,height:1050,deviceScaleFactor:1,mobile:false});
    await send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
    await send('Page.navigate',{url:'http://127.0.0.1:8772/'});
    await waitFor('!!document.querySelector("#gate-funnel")?._qmFunnel');
    await ev('document.fonts.ready.then(()=>true)');
    await ev('document.querySelector("#gate-funnel").closest("section").scrollIntoView()');
    await sleep(800);
    const state=await ev(`(()=>{let el=document.querySelector('#gate-funnel'),f=el._qmFunnel,c=f.canvas,r=c.getBoundingClientRect();return {
      reducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches, paused:f.paused, visible:f.visible,
      canvas:[c.width,c.height], css:[r.width,r.height], rect:{x:r.x,y:r.y,width:r.width,height:r.height}, scrollY,
      pageWidth:document.documentElement.scrollWidth, viewport:innerWidth, tableHidden:el.querySelector('table').classList.contains('visually-hidden'),
      table: [...el.querySelectorAll('tbody tr')].map(tr=>[...tr.cells].map(td=>td.textContent)),
      description:c.getAttribute('aria-label'), registerItems:el.querySelectorAll('.qm-funnel__register li').length,
      fonts:{display:document.fonts.check('600 32px Fraunces'),sans:document.fonts.check('400 17px "IBM Plex Sans"'),mono:document.fonts.check('400 13px "IBM Plex Mono"')},
      styleFonts:{h1:getComputedStyle(document.querySelector('h1')).fontFamily,body:getComputedStyle(document.body).fontFamily},
      hasPrivateText:/[CDG]:[\\/]|terminal64|T_Live|\\bQM5_|agent_task:|(?:localhost|127\\.0\\.0\\.1):/i.test(document.querySelector('main').innerText)
    }})()`);
    assert(state.reducedMotion && !state.paused && state.visible);
    assert(state.tableHidden && state.table.length===18 && state.registerItems===18);
    assert(state.pageWidth<=width, 'No page overflow'); assert(!state.hasPrivateText);
    const ax=await send('Accessibility.getFullAXTree');
    const accessibleTable=ax.nodes.some(n=>n.role?.value==='table' && n.name?.value.startsWith('Distinct strategies with'));
    assert(accessibleTable, 'Clipped native census table remains in the accessibility tree');
    const source=JSON.parse(fs.readFileSync(path.join(out,'funnel-stats.json'),'utf8'));
    assert.deepEqual(state.table.map(r=>[r[0],Number(r[3].replaceAll(',',''))]),source.gates.map(g=>[g.id,g.strategies_cleared]));
    const clip={x:state.rect.x,y:state.rect.y+state.scrollY,width:state.rect.width,height:state.rect.height,scale:1};
    await shot(`funnel_${width}_t1`,clip); await sleep(2000); await shot(`funnel_${width}_t2`,clip);
    await shot(`funnel_context_${width}`);
    await send('Page.bringToFront');
    await ev('document.querySelector(".funnel__control").focus()');
    await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',text:'\r',windowsVirtualKeyCode:13});
    await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13});
    await sleep(200); await shot(`paused_${width}_t1`,clip); await sleep(650); await shot(`paused_${width}_t2`,clip);
    const pause=await ev('({paused:document.querySelector("#gate-funnel")._qmFunnel.paused,stored:localStorage.getItem("qm-funnel-paused"),label:document.querySelector(".funnel__control").textContent})');
    assert(pause.paused && pause.stored==='1' && pause.label==='Play funnel', JSON.stringify(pause));
    await send('Page.reload'); await waitFor('!!document.querySelector("#gate-funnel")?._qmFunnel');
    assert(await ev('document.querySelector("#gate-funnel")._qmFunnel.paused'), 'Pause persists across reload');
    await ev('document.querySelector("#gate-funnel").scrollIntoView();document.querySelector(".funnel__control").click()');
    await sleep(300);
    await ev('scrollTo(0,0)'); await sleep(400);
    const offscreen=await ev('({visible:document.querySelector("#gate-funnel")._qmFunnel.visible,raf:document.querySelector("#gate-funnel")._qmFunnel.raf})');
    assert(!offscreen.visible && offscreen.raf===0, 'Offscreen animation suspended');
    await send('Emulation.setDeviceMetricsOverride',{width,height:1050,deviceScaleFactor:2,mobile:false});
    await ev('document.querySelector("#gate-funnel").scrollIntoView()'); await sleep(500);
    const dpr=await ev('(()=>{let f=document.querySelector("#gate-funnel")._qmFunnel;return {dpr:f.dpr,width:f.canvas.width,css:f.canvas.getBoundingClientRect().width,visible:f.visible,t:f.t}})()');
    assert(dpr.dpr===2 && Math.abs(dpr.width-dpr.css*2)<2 && dpr.visible);
    await send('Emulation.setDeviceMetricsOverride',{width:390,height:1050,deviceScaleFactor:1,mobile:false}); await sleep(400);
    const narrow=await ev(`(()=>{let el=document.querySelector('#gate-funnel'),f=el._qmFunnel;
      let r={page:document.documentElement.scrollWidth,viewport:innerWidth,inner:f.viewport.scrollWidth,outer:f.viewport.clientWidth};
      el.style.display='none';r.pageWithoutFunnel=document.documentElement.scrollWidth;el.style.display='';
      r.overwide=[...document.querySelectorAll('main *')].filter(x=>x.getBoundingClientRect().right>innerWidth+1).slice(0,18).map(x=>({tag:x.tagName,id:x.id,cls:x.className,right:x.getBoundingClientRect().right,whiteSpace:getComputedStyle(x).whiteSpace}));return r})()`);
    assert(narrow.inner>=700 && narrow.outer<700 && narrow.page===narrow.pageWithoutFunnel, '390px funnel scroll is contained: '+JSON.stringify(narrow));
    await send('Emulation.setDeviceMetricsOverride',{width,height:1050,deviceScaleFactor:1,mobile:false});
    await ev('document.querySelector(".qm-funnel__register").open=true;document.querySelector(".qm-funnel__register").scrollIntoView()'); await sleep(300);
    await shot(`register_${width}`);
    await ev('document.querySelector(".mechanics").scrollIntoView()'); await sleep(350);
    await shot(`mechanics_${width}`);
    // Mount replacement must remove old observers/controls and refresh accessible counts.
    const remount=await ev(`(async()=>{let el=document.querySelector('#gate-funnel'),d=await(await fetch(el.dataset.src)).json();let old=el._qmFunnel;
      QMFunnel.mount(el,d);let current=el._qmFunnel;let invalidRejected=false;try{QMFunnel.mount(el,{...d,gates:d.gates.slice(1)})}catch(e){invalidRejected=true}
      return {oldDestroyed:old.dead,instances:el.querySelectorAll('.qm-funnel__instrument').length,controls:el.querySelectorAll('.funnel__control').length,invalidRejected,previousPreserved:el._qmFunnel===current};})()`);
    assert(remount.oldDestroyed && remount.instances===1 && remount.controls===1 && remount.invalidRejected && remount.previousPreserved);
    assert.equal(errors.length,0,'No page console, runtime, or log errors');
    return {width,state,accessibleTable,pause,keyboardPause:true,pauseReload:true,offscreen,dpr,narrow,remount,errors,warnings,ownChromePid:chrome.pid,profile};
  } finally { if(ws)ws.close(); chrome.kill(); }
}
(async()=>{
  const result={checked_utc:new Date().toISOString(),browser:'Headless Google Chrome',results:[]};
  for(const width of [1400,800]) result.results.push(await run(width));
  fs.writeFileSync(path.join(out,'browser_verification.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result,null,2));
})().catch(e=>{console.error(e.stack);process.exitCode=1;});
