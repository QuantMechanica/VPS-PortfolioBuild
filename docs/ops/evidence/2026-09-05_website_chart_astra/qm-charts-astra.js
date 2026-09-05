/* QuantMechanica / Astra concept. Independent canvas renderer. No market bars embedded. */
(function (global) {
  'use strict';
  const P = { paper: '#ffffff', ink: '#26323d', muted: '#84909b', grid: '#edf0f2',
    up: '#168775', down: '#cc625d', blue: '#557eae', amber: '#b38c4c', band: '#92a5b7' };
  const profiles = {
    EURUSD: { start: 1.0834, sigma: .001067, range: .001051, gap: .000014, decimals: 5 },
    XAUUSD: { start: 2370, sigma: .009018, range: .011916, gap: .00031, decimals: 2 },
    US100: { start: 19450, sigma: .014907, range: .018464, gap: .00052, decimals: 1 }
  };
  function random(seed) {
    let h = 2166136261;
    for (const ch of String(seed)) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
    return () => { h += 0x6D2B79F5; let t = Math.imul(h ^ h >>> 15, 1 | h);
      t ^= t + Math.imul(t ^ t >>> 7, 61 | t); return ((t ^ t >>> 14) >>> 0) / 4294967296; };
  }
  function generate(options) {
    const key = options.instrument || 'EURUSD', p = profiles[key] || profiles.EURUSD;
    const r = random(options.seed || key), normal = () => Math.sqrt(-2 * Math.log(Math.max(1e-9, r()))) * Math.cos(2 * Math.PI * r());
    const daily = options.tf !== 'H1', count = options.bars || 60, data = [];
    let previous = p.start, logVol = -.18, trend = 0;
    let date = new Date(daily ? '2026-04-06T00:00:00Z' : '2026-06-15T00:00:00Z');
    for (let i = 0; i < count; i++) {
      logVol = Math.max(-.85, Math.min(.75, .88 * logVol + .18 * normal()));
      if (i % 11 === 0) trend = .13 * normal();
      const hour = date.getUTCHours(), session = daily ? 1 : (hour >= 7 && hour < 17 ? 1.35 : .66);
      const vol = Math.exp(logVol) * session;
      let drift = trend;
      if (key === 'XAUUSD') drift = i < 19 ? (p.start - previous) / (p.start * p.sigma) * .25 : i < 32 ? -.23 : .27;
      const open = previous * Math.exp((daily ? p.gap * normal() * (r() < .08 ? 4 : 1) : 0));
      const close = open * Math.exp(p.sigma * vol * (.72 * normal() + drift));
      const extension = p.range * open * vol;
      let high = Math.max(open, close) + extension * (.045 + .36 * r() ** 1.6);
      let low = Math.min(open, close) - extension * (.045 + .36 * r() ** 1.6);
      if (key === 'XAUUSD' && i === 27) low -= extension * .65;
      const volume = Math.round(450 + 1600 * session * (high - low) / (p.start * p.range) * Math.exp(.24 * normal()));
      data.push({ time: date.toISOString(), open, high, low, close, volume }); previous = close;
      date = new Date(+date + (daily ? 86400000 : 3600000));
      while (date.getUTCDay() === 0 || date.getUTCDay() === 6) date = new Date(+date + 86400000);
    }
    return data;
  }
  function ema(data, period) {
    let value = data[0].close;
    return data.map(b => value += (b.close - value) * 2 / (period + 1));
  }
  function bands(data) {
    return data.map((_, i) => { if (i < 19) return null;
      const v = data.slice(i - 19, i + 1).map(b => b.close), mean = v.reduce((a,b) => a+b) / 20;
      const sd = Math.sqrt(v.reduce((a,b) => a + (b-mean) ** 2, 0) / 20);
      return [mean - 2 * sd, mean + 2 * sd]; });
  }
  function mount(target, options, painter, description) {
    const host = typeof target === 'string' ? document.querySelector(target) : target;
    if (!host) throw new Error('Chart target missing');
    const canvas = host.tagName === 'CANVAS' ? host : host.appendChild(document.createElement('canvas'));
    canvas.style.cssText = 'display:block;width:100%;height:' + (options.height || 300) + 'px;touch-action:pan-y';
    canvas.setAttribute('role', 'img'); canvas.setAttribute('aria-label', description);
    let pointer = null;
    function draw() {
      const w = canvas.getBoundingClientRect().width, h = options.height || 300;
      if (w < 100) return;
      const dpr = global.devicePixelRatio || 1;
      canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
      const c = canvas.getContext('2d'); c.setTransform(dpr, 0, 0, dpr, 0, 0);
      c.fillStyle = P.paper; c.fillRect(0, 0, w, h); c.lineWidth = 1;
      painter(c, w, h, pointer);
    }
    function move(e) { pointer = e.clientX - canvas.getBoundingClientRect().left; draw(); }
    function leave() { pointer = null; draw(); }
    canvas.addEventListener('pointermove', move); canvas.addEventListener('pointerleave', leave);
    const ro = new ResizeObserver(draw); ro.observe(canvas); draw();
    return { canvas, redraw: draw, destroy() { ro.disconnect(); canvas.removeEventListener('pointermove', move); canvas.removeEventListener('pointerleave', leave); } };
  }
  function label(c, text, x, y, color = P.muted, size = 10, align = 'left', weight = 400) {
    c.font = `${weight} ${size}px Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
    c.textAlign = align; c.fillStyle = color; c.fillText(text, x, y);
  }
  function line(c, points, color, width = 1) {
    c.beginPath(); let started = false;
    points.forEach(p => { if (!p) { started = false; return; } if (!started) { c.moveTo(...p); started = true; } else c.lineTo(...p); });
    c.strokeStyle = color; c.lineWidth = width; c.stroke(); c.lineWidth = 1;
  }
  function niceStep(span) { const power = 10 ** Math.floor(Math.log10(span / 4)), v = span / 4 / power;
    return (v < 1.5 ? 1 : v < 3 ? 2 : v < 7 ? 5 : 10) * power; }
  function candles(target, options = {}) {
    const data = generate(options), key = options.instrument || 'EURUSD', p = profiles[key] || profiles.EURUSD;
    const fast = ema(data, 20), slow = ema(data, 50), bb = bands(data), overlays = options.overlays || ['ema20', 'ema50'];
    const title = {EURUSD:'EUR/USD', XAUUSD:'XAU/USD', US100:'US 100'}[key] || key;
    const fmt = x => x.toFixed(p.decimals);
    const view = mount(target, options, (c, w, h, pointer) => {
      const left = 10, right = w - 61, top = 67, bottom = h - 66, volumeBase = h - 27;
      const step = (right - left) / (data.length + 1), x = i => left + (i + .6) * step;
      const extremes = data.flatMap(b => [b.low, b.high]);
      if (overlays.includes('bb')) bb.filter(Boolean).forEach(b => extremes.push(...b));
      const min = Math.min(...extremes), max = Math.max(...extremes), pad = (max-min) * .09;
      const y = price => bottom - (price - min + pad) / (max-min + 2*pad) * (bottom-top);
      const selected = pointer === null ? data.length-1 : Math.max(0, Math.min(data.length-1, Math.round((pointer-left)/step-.6)));
      const bar = data[selected], tint = bar.close >= bar.open ? P.up : P.down;
      label(c, title + '  ·  ' + (options.tf === 'H1' ? '1h' : '1D'), 12, 20, P.ink, 11, 'left', 600);
      label(c, 'OHLC', right+51, 20, P.muted, 9, 'right');
      label(c, `O ${fmt(bar.open)}   H ${fmt(bar.high)}   L ${fmt(bar.low)}   C ${fmt(bar.close)}`, 12, 36, tint, w < 340 ? 8 : 9);
      let legendX = 12;
      for (const [id, text, color] of [['ema20','EMA 20',P.blue],['ema50','EMA 50',P.amber],['bb','BB 20 · 2',P.band]]) {
        if (overlays.includes(id)) { label(c, text, legendX, 53, color, 9); legendX += 63; }
      }
      c.save(); c.beginPath(); c.rect(left, top-7, right-left, volumeBase-top+7); c.clip();
      if (options.tf === 'H1') {
        for (const session of options.sessions || [{label:'London',from:7,to:16,color:'rgba(85,126,174,.055)'},{label:'NY',from:12,to:21,color:'rgba(179,140,76,.05)'}]) {
          data.forEach((b,i) => { const hour = new Date(b.time).getUTCHours();
            if (hour >= session.from && hour < session.to) { c.fillStyle = session.color; c.fillRect(x(i)-step/2,top,step,bottom-top);
              if (hour === session.from && x(i) < right-32) label(c, session.short || session.label, x(i), top+(session.from >= 12 ? 22 : 11), P.muted, 8); }
          });
        }
      } else if (key === 'XAUUSD') {
        [[0,18,'Accum.',P.up],[19,33,'Manip.',P.amber],[34,data.length-1,'Distrib.',P.blue]].forEach(([a,b,t,color]) => {
          c.globalAlpha = .045; c.fillStyle = color; c.fillRect(x(a)-step/2,top,(b-a+1)*step,bottom-top); c.globalAlpha = 1;
          label(c,t,(x(a)+x(b))/2,top+11,color,8,'center');
        });
      }
      const tick = niceStep(max-min+2*pad), last = data[data.length-1];
      for (let price = Math.ceil((min-pad)/tick)*tick; price <= max+pad; price += tick) line(c,[[left,y(price)],[right,y(price)]],P.grid);
      for (let i = 0; i < data.length; i += options.tf === 'H1' ? 24 : 20) line(c,[[x(i),top],[x(i),volumeBase]],P.grid);
      if (overlays.includes('bb')) {
        const valid = bb.map((b,i) => b && [x(i),y(b[0]),y(b[1])]).filter(Boolean);
        c.fillStyle = 'rgba(146,165,183,.06)'; c.beginPath();
        valid.forEach((b,i) => i ? c.lineTo(b[0],b[1]) : c.moveTo(b[0],b[1]));
        [...valid].reverse().forEach(b => c.lineTo(b[0],b[2])); c.closePath(); c.fill();
        for (const side of [0,1]) line(c,bb.map((b,i) => b && [x(i),y(b[side])]),P.band,.8);
      }
      const maxVolume = Math.max(...data.map(b => b.volume));
      data.forEach((b,i) => {
        const color = b.close >= b.open ? P.up : P.down, width = Math.max(1,step*.68);
        c.globalAlpha = .24; c.fillStyle = color; const vh = b.volume/maxVolume*29;
        c.fillRect(x(i)-width/2,volumeBase-vh,width,vh); c.globalAlpha = 1;
        line(c,[[x(i),y(b.high)],[x(i),y(b.low)]],color,.9);
        c.fillStyle = color; c.fillRect(x(i)-width/2,Math.min(y(b.open),y(b.close)),width,Math.max(1,Math.abs(y(b.close)-y(b.open))));
      });
      if (overlays.includes('ema20')) line(c,fast.map((v,i)=>[x(i),y(v)]),P.blue,1.1);
      if (overlays.includes('ema50')) line(c,slow.map((v,i)=>[x(i),y(v)]),P.amber,1.1);
      function marker(start,end,high,text) {
        let i = start; for (let j = start+1; j <= Math.min(end,data.length-1); j++) if (high ? data[j].high > data[i].high : data[j].low < data[i].low) i = j;
        const at = y(high ? data[i].high : data[i].low), sign = high ? -1 : 1;
        line(c,[[x(i),at+sign*3],[x(i),at+sign*10]],P.ink);
        label(c,text,x(i),at+sign*13+(high?0:7),P.ink,8,'center');
      }
      if (key === 'XAUUSD') marker(19,33,false,'Sweep');
      if (key === 'US100') { marker(8,36,true,'SH'); marker(30,data.length-1,false,'SL'); }
      c.setLineDash([3,3]); line(c,[[left,y(last.close)],[right,y(last.close)]],last.close>=last.open?P.up:P.down,.65);
      if (pointer !== null) line(c,[[x(selected),top],[x(selected),volumeBase]],P.muted);
      c.setLineDash([]); c.restore();
      line(c,[[right,top-7],[right,volumeBase+3]],P.grid); line(c,[[left,volumeBase+3],[right,volumeBase+3]],P.grid);
      for (let price = Math.ceil((min-pad)/tick)*tick; price <= max+pad; price += tick) if (Math.abs(y(price)-y(last.close))>13) label(c,fmt(price),right+6,y(price)+3,P.muted,9);
      c.fillStyle = last.close>=last.open?P.up:P.down; c.fillRect(right,y(last.close)-9,60,18);
      label(c,fmt(last.close),right+5,y(last.close)+3,'#fff',9);
      for (let i = 0; i < data.length; i += options.tf === 'H1' ? 24 : 20) {
        const d = new Date(data[i].time); label(c,d.toLocaleDateString('en-GB',{day:'2-digit',month:'short',timeZone:'UTC'}),Math.max(25,x(i)),h-8,P.muted,9);
      }
      label(c,pointer === null ? 'VOL' : data[selected].time.slice(0,16).replace('T',' ')+' · V '+bar.volume,12,volumeBase-30,P.muted,8);
    }, title + ' illustrative synthetic ' + (options.tf || 'D1') + ' candles with indicator overlays and volume.');
    return {...view, bars: data};
  }
  function equity(target, options = {}) {
    const series = options.series || (options.data && options.data.series);
    if (!Array.isArray(series) || series.length < 2) throw new Error('Equity requires the supplied dated index series');
    let peak = -Infinity; const peaks = series.map(b => peak = Math.max(peak,b[1]));
    const dd = series.map((b,i) => (b[1]/peaks[i]-1)*100);
    const view = mount(target, {...options,height:options.height || 300}, (c,w,h,pointer) => {
      const left = 14, right = w-62, top = 40, bottom = h-51, low = Math.min(0,...series.map(b=>b[1]));
      const high = Math.max(...peaks)*1.07, x = i => left+i/(series.length-1)*(right-left), y = n => bottom-(n-low)/(high-low)*(bottom-top);
      label(c,'COMBINED BACKTEST  ·  INDEX 100',left,19,P.muted,w<500?9:10,'left',500);
      const tagIndex = pointer===null ? series.length-1 : Math.max(0,Math.min(series.length-1,Math.round((pointer-left)/(right-left)*(series.length-1))));
      for (let value = 500; value <= high; value += 500) { line(c,[[left,y(value)],[right,y(value)]],P.grid);
        if (Math.abs(y(value)-y(series[tagIndex][1]))>13) label(c,value.toLocaleString('en-US'),right+8,y(value)+3,P.muted,9); }
      c.fillStyle = 'rgba(22,135,117,.035)'; c.beginPath(); c.moveTo(left,bottom);
      series.forEach((b,i) => c.lineTo(x(i),y(b[1]))); c.lineTo(right,bottom);c.closePath();c.fill();
      c.fillStyle = 'rgba(204,98,93,.16)'; c.beginPath(); peaks.forEach((v,i)=>i?c.lineTo(x(i),y(v)):c.moveTo(x(i),y(v)));
      for(let i=series.length-1;i>=0;i--) c.lineTo(x(i),y(series[i][1]));c.closePath();c.fill();
      line(c,series.map((b,i)=>[x(i),y(b[1])]),P.up,1.6);
      const end = series.length-1, selected = pointer===null ? end : Math.max(0,Math.min(end,Math.round((pointer-left)/(right-left)*end)));
      c.fillStyle = P.up;c.beginPath();c.arc(x(selected),y(series[selected][1]),2.7,0,Math.PI*2);c.fill();
      if(pointer!==null) { c.setLineDash([3,3]);line(c,[[x(selected),top],[x(selected),bottom]],P.muted);c.setLineDash([]); }
      label(c,series[selected][1].toLocaleString('en-US',{maximumFractionDigits:2}),right+6,y(series[selected][1])+3,P.up,10);
      let lastYear = '';
      series.forEach((b,i)=>{const year=b[0].slice(0,4);if(year!==lastYear && (+year%2===1 || w>700)) {label(c,year,Math.max(27,x(i)),h-13,P.muted,9);lastYear=year;}});
      label(c,'Drawdown from prior peak',left,h-31,P.down,9);
      label(c,pointer===null ? '2017–2025' : series[selected][0]+'  ·  DD '+dd[selected].toFixed(2)+'%',right,h-31,P.muted,9,'right');
    }, 'Combined historical backtest index from 2017 to 2025, with drawdown shading. Not live returns.');
    return {...view, series};
  }
  global.QMChartsAstra = Object.freeze({version:'1.0.0',candles,equity});
})(window);
