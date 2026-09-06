// Headless Chrome CDP probe: load a page, wait, evaluate JS, take two screenshots N ms apart, report console errors.
const { spawn } = require('child_process');
const fs = require('fs');
const url = process.argv[2] || 'http://127.0.0.1:8772/';
const out = process.argv[3] || 'probe';
const port = 9333;
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--window-size=1400,3400', '--remote-debugging-port=' + port, '--user-data-dir=' + process.env.TEMP + '/cdp-probe-profile', 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
(async () => {
  let wsUrl = null;
  for (let i = 0; i < 40 && !wsUrl; i++) { await sleep(250); try { const r = await fetch('http://127.0.0.1:' + port + '/json/list'); const j = await r.json(); const t = j.find(x => x.type === 'page'); if (t) wsUrl = t.webSocketDebuggerUrl; } catch (e) {} }
  if (!wsUrl) { console.log('no cdp target'); chrome.kill(); process.exit(2); }
  const ws = new WebSocket(wsUrl); let id = 0; const pending = new Map(); const logs = [];
  ws.onmessage = (m) => { const j = JSON.parse(m.data); if (j.id && pending.has(j.id)) { pending.get(j.id)(j); pending.delete(j.id); } else if (j.method === 'Runtime.consoleAPICalled') { logs.push(j.params.type + ': ' + (j.params.args || []).map(a => a.value || a.description || '').join(' ')); } else if (j.method === 'Runtime.exceptionThrown') { logs.push('EXCEPTION: ' + (j.params.exceptionDetails.exception && j.params.exceptionDetails.exception.description || j.params.exceptionDetails.text)); } };
  const send = (method, params) => new Promise(res => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params: params || {} })); });
  await new Promise(r => ws.onopen = r);
  await send('Runtime.enable'); await send('Page.enable'); await send('Log.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1400, height: 3400, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url }); await sleep(2500);
  const ev = async (expr) => { const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }); return r.result && r.result.result ? r.result.result.value : r; };
  const probe = await ev(`(function(){ var f=document.querySelector('#gate-funnel'); var fc=f&&f.querySelector('canvas'); var hb=document.getElementById('hero-bg'); return JSON.stringify({ reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches, visibility: document.visibilityState, funnelCanvas: !!fc, funnelSize: fc?[fc.width,fc.height,fc.getBoundingClientRect().top|0]:null, heroCanvas: !!hb, heroSize: hb?[hb.width,hb.height]:null, QMFunnel: typeof window.QMFunnel, QMCharts: typeof window.QMCharts, tableHidden: !!(f&&f.querySelector('table.visually-hidden, .visually-hidden table')) }); })()`);
  console.log('probe', probe);
  const shot = async (name) => { const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true }); fs.writeFileSync(out + '_' + name + '.png', Buffer.from(r.result.data, 'base64')); };
  await shot('t1'); await sleep(2000); await shot('t2');
  console.log('console:', logs.slice(0, 12).join(' | ') || 'none');
  ws.close(); chrome.kill(); process.exit(0);
})().catch(e => { console.log('probe error', e && e.message); chrome.kill(); process.exit(1); });
