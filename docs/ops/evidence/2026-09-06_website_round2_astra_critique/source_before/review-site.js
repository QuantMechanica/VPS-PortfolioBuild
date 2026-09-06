/* Public review copy: progressive enhancement of local, governed data. */
(() => {
  'use strict';
  const node = (tag, cls, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  };
  const nav = document.querySelector('.nav');
  const menu = document.getElementById('mobile-menu');
  const toggle = document.querySelector('.nav__burger');
  if (menu && toggle) {
    menu.inert = true;
    const close = () => { nav.classList.remove('is-open'); menu.inert = true; toggle.setAttribute('aria-expanded','false'); };
    toggle.addEventListener('click', () => {
      const open = toggle.getAttribute('aria-expanded') !== 'true';
      nav.classList.toggle('is-open', open); menu.inert = !open;
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
    });
    document.addEventListener('keydown', e => { if (e.key === 'Escape' && nav.classList.contains('is-open')) { close(); toggle.focus(); } });
    menu.querySelectorAll('a').forEach(a => a.addEventListener('click', close));
  }
  document.querySelectorAll('.nav__links a').forEach(a => {
    if (a.pathname === location.pathname || (a.pathname === '/strategies' && location.pathname.startsWith('/strategies/'))) a.setAttribute('aria-current','page');
  });

  async function json(url) {
    const response = await fetch(url, {cache:'no-store'});
    if (!response.ok) throw Error('Data unavailable');
    return response.json();
  }

  const list = document.getElementById('archive-list');
  if (list) {
    const search = document.getElementById('archive-search');
    const filter = document.getElementById('archive-filter');
    const count = document.getElementById('archive-count');
    const more = document.getElementById('archive-more');
    json('/public-data/strategy-archive-v3.json').then(data => {
      if (data.schema_version !== 3 || !Array.isArray(data.items)) throw Error('Contract unavailable');
      const items = data.items.slice().sort((a,b) => a.display_name.localeCompare(b.display_name) || a.public_id.localeCompare(b.public_id));
      let limit = 24;
      function render() {
        const term = search.value.trim().toLowerCase();
        const matches = items.filter(i => {
          const haystack = [i.display_name, i.family, i.summary, ...i.markets.map(m => m.symbol_public)].join(' ').toLowerCase();
          return haystack.includes(term) && (filter.value === 'all' || i.gate_journey.some(g => g.verdict.toLowerCase() === filter.value));
        });
        list.replaceChildren();
        matches.slice(0,limit).forEach(i => {
          const card = node('article','archive-card');
          const content = node('div','stack');
          content.append(node('p','eyebrow',i.family));
          const title = node('h2','h3');
          const link = node('a','',i.display_name); link.href = '/strategies/'+encodeURIComponent(i.slug); title.append(link);
          content.append(title,node('p','',i.summary));
          content.append(node('p','caption',i.markets.map(m => m.symbol_public+' · '+(m.timeframe==='UNKNOWN'?'Timeframe not recorded':m.timeframe)).join(' / ') || 'No market recorded'));
          const journey = node('div','record-journey');
          i.gate_journey.forEach(g => journey.append(node('span','result result--'+g.verdict.toLowerCase(),g.gate+' '+g.verdict)));
          content.append(journey);
          const action = node('a','btn btn--secondary','Read the evidence →'); action.href = link.href;
          card.append(content,action);list.append(card);
        });
        if (!matches.length) list.append(node('p','panel','No records match this search. Try a different name or market.'));
        count.textContent = matches.length.toLocaleString()+' card revisions · '+Math.min(limit,matches.length).toLocaleString()+' shown · alphabetical order';
        more.hidden = matches.length <= limit;
      }
      search.addEventListener('input', () => { limit = 24; render(); });
      filter.addEventListener('change', () => { limit = 24; render(); });
      more.addEventListener('click', () => { limit += 24; render(); });
      document.getElementById('archive-stamp').textContent = 'Archive snapshot: '+new Date(data.generated_at).toISOString().slice(0,10)+'. A card revision is not a count of distinct live strategies.';
      render();
    }).catch(() => { count.textContent = 'The archive is temporarily unavailable. Please try again later.'; more.hidden = true; });
  }

  const chart = document.querySelector('[data-live-chart]');
  if (chart) json('/public-data/live-performance.json').then(data => {
    if (data.schema_version !== 1 || !Array.isArray(data.series) || data.series.length < 2) throw Error('Series unavailable');
    document.querySelector('[data-live-net]').textContent = new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(data.totals.net_pnl);
    document.querySelector('[data-live-closes]').textContent = data.totals.closes.toLocaleString();
    document.querySelector('[data-live-caption]').textContent = 'Observed close days: '+data.epoch+' to '+data.series.at(-1)[0]+'. Snapshot '+new Date(data.generated_at).toISOString().slice(0,10)+'. Closed-P&L index on USD 100,000 reference capital; excludes floating P&L.';
    document.querySelector('[data-live-basis]').textContent = data.basis;
    const ns = 'http://www.w3.org/2000/svg';
    function svg(tag, attrs, text) { const n=document.createElementNS(ns,tag); Object.entries(attrs).forEach(([k,v])=>n.setAttribute(k,v)); if(text!==undefined)n.textContent=text;return n; }
    const values=data.series.map(r=>r[3]); if(values.some(v=>!Number.isFinite(v)))throw Error('Invalid series');
    const low=Math.min(...values,100)-.12, high=Math.max(...values,100)+.12;
    const x=i=>20+i/(values.length-1)*810, y=v=>280-(v-low)/(high-low)*250;
    const canvas=svg('svg',{viewBox:'0 0 920 330',role:'img','aria-label':'Observed closed-position P and L index, ending at '+values.at(-1).toFixed(3)});
    for(let i=0;i<5;i++){const value=low+(high-low)*i/4;canvas.append(svg('line',{x1:20,x2:830,y1:y(value),y2:y(value),stroke:'#e7e9eb'}),svg('text',{x:848,y:y(value)+5,fill:'#555', 'font-size':14},value.toFixed(2)));}
    canvas.append(svg('line',{x1:20,x2:830,y1:y(100),y2:y(100),stroke:'#989ea5','stroke-dasharray':'5 5'}));
    canvas.append(svg('path',{d:values.map((v,i)=>(i?'L':'M')+x(i)+','+y(v)).join(' '),fill:'none',stroke:'#08754c','stroke-width':2.5,'stroke-linejoin':'round'}));
    canvas.append(svg('text',{x:20,y:315,fill:'#555','font-size':14},data.series[0][0]),svg('text',{x:830,y:315,fill:'#555','font-size':14,'text-anchor':'end'},data.series.at(-1)[0]));
    chart.replaceChildren(canvas);
  }).catch(() => { chart.replaceChildren(node('p','','The observed series is temporarily unavailable. The external DARWIN record is linked above.')); });

  // Existing illustrative light charts retain explicit synthetic captions.
  if (window.QMCharts) {
    const options=[['w-eurusd',{instrument:'EURUSD',tf:'H1',seed:'home-eur',bars:60,overlays:['ema20','ema50']}],['w-xauusd',{instrument:'XAUUSD',tf:'D1',seed:'home-xau-po3c',bars:56,overlays:['ema20']}],['w-us100',{instrument:'US100',tf:'D1',seed:'home-us100',bars:64,overlays:['ema20','ema50','bb']}]];
    options.forEach(([id,options]) => { const el=document.getElementById(id);if(el)QMCharts.candles(el,{...options,theme:'light'}); });
  }
})();
