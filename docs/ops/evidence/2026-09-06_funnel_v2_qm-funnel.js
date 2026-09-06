/* QuantMechanica public gate instrument. No individual strategy histories are inferred. */
(function () {
  'use strict';
  var MONO = '"IBM Plex Mono", monospace';
  var KEY = 'qm-funnel-paused';
  var INTRO = 'An idea moves through validation, requalification, and portfolio checks. The funnel illustrates selection; the gate register shows the actual census counts.';
  var BASIS = 'Traces illustrate the process, not individual strategy histories. Their density through Q02–Q08 follows recorded clearances relative to strategies tested. From Q09 onward, subset retests are not a conversion chain: counts can rise. Zero means no recorded clearance. Funnel width is illustrative. Qualified pairs are a separate measure.';
  function fmt(v) { return Number(v).toLocaleString('en-US'); }
  function integer(v) { return Number.isSafeInteger(v) && v >= 0; }
  function node(tag, cls, content) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (content != null) n.textContent = content;
    return n;
  }
  function modelOf(d) {
    if (!d || d.schema !== 'qm.public-funnel-stats/v1' || !integer(d.strategies_tested) ||
        !integer(d.qualified_pairs_current) || !integer(d.qualified_pairs_target) ||
        d.gates_total !== 18 || !Array.isArray(d.gates) || d.gates.length !== 18 ||
        !Array.isArray(d.phases) || d.phases.length !== 3) throw Error('Invalid public census');
    var ids = new Set();
    d.gates.forEach(function (g, i) {
      if (g.id !== 'Q' + String(i).padStart(2, '0') || !integer(g.strategies_cleared) ||
          typeof g.label !== 'string' || !g.label || ids.has(g.id)) throw Error('Invalid gate census');
      ids.add(g.id);
    });
    var phaseIds = new Set();
    d.phases.forEach(function (p) {
      if (!p || typeof p.name !== 'string' || !Array.isArray(p.gates) || !p.gates.length) throw Error('Invalid phase');
      p.gates.forEach(function (id) {
        var g = d.gates.find(function (x) { return x.id === id; });
        if (!g || g.phase !== p.id || phaseIds.has(id)) throw Error('Invalid phase gates');
        phaseIds.add(id);
      });
    });
    if (phaseIds.size !== 18) throw Error('Incomplete phases');
    // A nonmonotone validation census cannot support even aggregate thinning.
    var last = d.strategies_tested, scaleValid = last > 0;
    d.gates.slice(2, 9).forEach(function (g) {
      if (g.strategies_cleared > last) scaleValid = false;
      last = g.strategies_cleared;
    });
    return { data: d, scaleValid: scaleValid };
  }
  function styles() {
    if (document.getElementById('qm-funnel-instrument-style')) return;
    var s = node('style'); s.id = 'qm-funnel-instrument-style';
    s.textContent = `
      #gate-funnel .visually-hidden{position:absolute!important;width:1px!important;height:1px!important;padding:0!important;margin:-1px!important;overflow:hidden!important;clip:rect(0,0,0,0)!important;white-space:nowrap!important;border:0!important}
      #gate-funnel .qm-funnel__instrument{margin-bottom:32px}
      #gate-funnel .qm-funnel__viewport{overflow-x:auto;overscroll-behavior-x:contain}
      #gate-funnel .qm-funnel__canvas{display:block;width:100%;min-width:700px;max-width:none;height:416px}
      #gate-funnel .qm-funnel__toolbar{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;border-top:1px solid var(--line,rgba(15,23,32,.12));padding-block:16px}
      #gate-funnel .funnel__control{appearance:none;border:1px solid var(--ink-3,#5f6b78);border-radius:3px;background:transparent;color:var(--ink,#0f1720);padding:8px 12px;font:500 13px ${MONO};min-height:40px;cursor:pointer}
      #gate-funnel .funnel__control:hover{background:var(--accent-soft,rgba(18,185,129,.1))}
      #gate-funnel .funnel__control:disabled{cursor:default}
      #gate-funnel :is(button,summary,.qm-funnel__viewport):focus-visible{outline:2px solid var(--accent,#12b981);outline-offset:4px}
      #gate-funnel .qm-funnel__summary{font:400 13px ${MONO};color:var(--ink-2,#3a4653);margin:0;line-height:1.6;font-variant-numeric:tabular-nums}
      #gate-funnel .qm-funnel__summary strong{color:var(--ink,#0f1720);font-weight:500}
      #gate-funnel .qm-funnel__basis{font:400 13px/1.6 'IBM Plex Sans',sans-serif;color:var(--ink-2,#3a4653);max-width:95ch;margin:0 0 24px}
      #gate-funnel .qm-funnel__register{border-block:1px solid var(--line,rgba(15,23,32,.12));margin-top:24px}
      #gate-funnel .qm-funnel__register summary{cursor:pointer;padding-block:16px;font:500 13px ${MONO};color:var(--ink,#0f1720)}
      #gate-funnel .qm-funnel__register ol{list-style:none;padding:0;margin:0 0 24px;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 32px}
      #gate-funnel .qm-funnel__register li{display:grid;grid-template-columns:3ch minmax(0,1fr) 6ch;gap:16px;padding-block:10px;border-top:1px solid var(--line,rgba(15,23,32,.12));font:400 15px/1.5 'IBM Plex Sans',sans-serif}
      #gate-funnel .qm-funnel__register :is(code,b){font:400 13px/1.7 ${MONO};font-variant-numeric:tabular-nums}
      #gate-funnel .qm-funnel__register b{text-align:right}
      @media(max-width:900px){#gate-funnel .qm-funnel__register ol{grid-template-columns:1fr}}
      @media(max-width:600px){#gate-funnel .qm-funnel__summary{font-size:12px}}
    `;
    document.head.appendChild(s);
  }
  function description(m) {
    return 'QuantMechanica selection process, three phases and eighteen gates. ' +
      fmt(m.data.strategies_tested) + ' distinct strategies tested; ' +
      m.data.gates.map(function (g) { return g.id + ' ' + g.label + ': ' + fmt(g.strategies_cleared) + ' recorded clearances'; }).join('; ') +
      '. Counts from Q09 onward refer to subsets and are not sequential conversion rates. ' +
      fmt(m.data.qualified_pairs_current) + ' qualified strategy-and-market pairs, separate from gate counts, against a target of ' + fmt(m.data.qualified_pairs_target) +
      '. Shape and moving traces are an aggregate process illustration.';
  }
  function Funnel(el, m) {
    this.el = el; this.model = m; this.t = 0; this.last = 0; this.raf = 0;
    this.visible = true; this.dead = false; this.paused = false;
    this.media = window.matchMedia('(prefers-reduced-motion: reduce)');
    try { this.paused = localStorage.getItem(KEY) === '1'; } catch (_) {}
    this.root = node('div', 'qm-funnel__instrument');
    this.viewport = node('div', 'qm-funnel__viewport');
    this.viewport.tabIndex = 0;
    this.viewport.setAttribute('role', 'region');
    this.viewport.setAttribute('aria-label', 'Gate instrument. Scroll horizontally on small screens; full gate register follows.');
    this.canvas = node('canvas', 'qm-funnel__canvas');
    this.canvas.setAttribute('role', 'img');
    this.canvas.setAttribute('aria-label', description(m));
    this.viewport.appendChild(this.canvas); this.root.appendChild(this.viewport);
    this.toolbar = node('div', 'qm-funnel__toolbar');
    this.button = node('button', 'funnel__control'); this.button.type = 'button';
    this.button.setAttribute('aria-controls', 'qm-funnel-view'); this.canvas.id = 'qm-funnel-view';
    this.toolbar.appendChild(this.button);
    var summary = node('p', 'qm-funnel__summary');
    summary.appendChild(node('strong', '', fmt(m.data.strategies_tested)));
    summary.appendChild(document.createTextNode(' tested · '));
    summary.appendChild(node('strong', '', fmt(m.data.gates[8].strategies_cleared)));
    summary.appendChild(document.createTextNode(' cleared Q08 | '));
    summary.appendChild(node('strong', '', fmt(m.data.qualified_pairs_current) + ' / ' + fmt(m.data.qualified_pairs_target)));
    summary.appendChild(document.createTextNode(' qualified pairs / target'));
    this.toolbar.appendChild(summary); this.root.appendChild(this.toolbar);
    this.root.appendChild(node('p', 'qm-funnel__basis', m.scaleValid ? BASIS :
      'The validation counts do not form a decreasing series, so moving traces are illustrative only. Exact clearances are printed at each gate; widths do not encode counts. Qualified pairs are a separate measure.'));
    this.register = node('details', 'qm-funnel__register');
    this.register.appendChild(node('summary', '', 'Read all eighteen gate names and counts'));
    var list = node('ol');
    m.data.gates.forEach(function (g) {
      var li = node('li');
      li.appendChild(node('code', '', g.id)); li.appendChild(node('span', '', g.label));
      li.appendChild(node('b', '', fmt(g.strategies_cleared))); list.appendChild(li);
    });
    this.register.appendChild(list); this.root.appendChild(this.register);
    el.insertBefore(this.root, el.firstChild);
    this.ctx = this.canvas.getContext('2d');
    if (!this.ctx) { this.root.remove(); throw Error('Canvas unavailable'); }
    this.table = el.querySelector('table.funnel__table');
    if (!this.table) { this.table = node('table', 'funnel__table'); el.appendChild(this.table); }
    // Replace fallback cells from the same fetched snapshot; do not leave stale accessible data.
    this.oldTable = this.table.innerHTML; this.tableWasHidden = this.table.classList.contains('visually-hidden');
    this.table.replaceChildren(node('caption', '', 'Distinct strategies with at least one passing market-and-timeframe test at each gate.'));
    var head = node('thead'), row = node('tr');
    ['Gate', 'Name', 'Phase', 'Strategies cleared'].forEach(function (x) { var th = node('th', '', x); th.scope = 'col'; row.appendChild(th); });
    head.appendChild(row); this.table.appendChild(head);
    var body = node('tbody');
    m.data.gates.forEach(function (g) {
      var tr = node('tr'), p = m.data.phases.find(function (x) { return x.id === g.phase; });
      [g.id, g.label, p.name, fmt(g.strategies_cleared)].forEach(function (x) { tr.appendChild(node('td', '', x)); });
      body.appendChild(tr);
    });
    this.table.appendChild(body); this.table.classList.add('visually-hidden');
    // A wrapper contains a table's intrinsic minimum width even at narrow viewports.
    this.tableWrap = node('div', 'visually-hidden');
    this.table.before(this.tableWrap); this.tableWrap.appendChild(this.table);
    var section = el.closest('section');
    this.intro = section && section.querySelector('.section__intro');
    this.note = section && section.querySelector('.funnel__note');
    this.oldIntro = this.intro && this.intro.textContent; this.oldNote = this.note && this.note.textContent;
    if (this.intro) this.intro.textContent = INTRO;
    if (this.note) this.note.textContent = 'Census: ' + String(m.data.snapshot_utc || 'date not supplied') + '. Gate counts record distinct strategies; qualification counts strategy-and-market pairs.';
    var self = this;
    this.toggle = function () {
      self.paused = !self.paused;
      try { localStorage.setItem(KEY, self.paused ? '1' : '0'); } catch (_) {}
      self.control(); self.sync();
    };
    this.button.addEventListener('click', this.toggle);
    this.change = function () { self.control(); self.sync(); };
    this.resize = function () { self.fit(); };
    document.addEventListener('visibilitychange', this.change);
    window.addEventListener('resize', this.resize);
    if (this.media.addEventListener) this.media.addEventListener('change', this.change);
    if (window.ResizeObserver) { this.ro = new ResizeObserver(this.resize); this.ro.observe(this.viewport); }
    if (window.IntersectionObserver) {
      this.io = new IntersectionObserver(function (entries) { self.visible = entries[0].isIntersecting; self.sync(); }, { threshold: 0.01 });
      this.io.observe(this.canvas);
    }
    this.control(); this.fit(); this.sync();
    // Late font arrival redraws labels even when paused or offscreen.
    if (document.fonts) document.fonts.ready.then(function () { if (!self.dead) self.draw(); });
  }
  Funnel.prototype.control = function () {
    if (this.media.matches) {
      this.button.textContent = 'Motion reduced';
      this.button.setAttribute('aria-label', 'Funnel animation stopped by your reduced-motion preference');
      this.button.disabled = true;
      return;
    }
    this.button.disabled = false;
    this.button.textContent = this.paused ? 'Play funnel' : 'Pause funnel';
    this.button.setAttribute('aria-label', this.paused ? 'Play funnel animation' : 'Pause funnel animation');
  };
  Funnel.prototype.fit = function () {
    if (this.dead) return;
    this.w = Math.max(700, Math.round(this.viewport.clientWidth)); this.h = 416;
    this.dpr = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
    this.canvas.width = Math.round(this.w * this.dpr); this.canvas.height = Math.round(this.h * this.dpr);
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    this.left = 26; this.right = this.w - 20; this.neck = this.w * 0.85;
    this.cy = 208; this.rim = 125; this.tube = 16;
    this.step = (this.right - this.left - 38) / 18;
    this.xs = this.model.data.gates.map(function (_, i) { return this.left + 26 + (i + 0.5) * this.step; }, this);
    var css = getComputedStyle(this.el);
    this.colors = { ink: css.getPropertyValue('--ink').trim() || '#0f1720',
      label: css.getPropertyValue('--ink-3').trim() || '#5f6b78',
      accent: css.getPropertyValue('--accent').trim() || '#12b981',
      wash: 'rgba(95,107,120,.09)' };
    this.draw();
  };
  Funnel.prototype.half = function (x) {
    var t = Math.max(0, Math.min(1, (x - this.left) / (this.neck - this.left)));
    return this.tube + (this.rim - this.tube) * (1 - t) * (1 - t);
  };
  // The quadratic radius is expressed as an exact cubic Bezier: a concave
  // glass-funnel wall with a horizontal tangent where it joins the outlet.
  // The same profile positions every sieve and trace, keeping them contained.
  Funnel.prototype.wall = function (side, reverse) {
    var c = this.ctx, span = this.neck - this.left, delta = this.rim - this.tube;
    var x1 = this.left + span / 3, x2 = this.left + span * 2 / 3;
    var y1 = this.cy + side * (this.rim - delta * 2 / 3), y2 = this.cy + side * this.tube;
    if (reverse) c.bezierCurveTo(x2, y2, x1, y1, this.left, this.cy + side * this.rim);
    else c.bezierCurveTo(x1, y1, x2, y2, this.neck, y2);
  };
  Funnel.prototype.outline = function () {
    var c = this.ctx;
    c.beginPath(); c.moveTo(this.left, this.cy - this.rim);
    this.wall(-1, false); c.lineTo(this.right, this.cy - this.tube);
    c.lineTo(this.right, this.cy + this.tube); c.lineTo(this.neck, this.cy + this.tube);
    this.wall(1, true); c.closePath();
  };
  Funnel.prototype.draw = function () {
    var c = this.ctx, self = this, col = this.colors;
    if (!col || this.dead) return;
    c.clearRect(0, 0, this.w, this.h); c.lineCap = 'butt'; c.lineJoin = 'miter';
    c.textAlign = 'center'; c.textBaseline = 'alphabetic';
    this.model.data.phases.forEach(function (p, i) {
      var first = self.model.data.gates.findIndex(function (g) { return g.id === p.gates[0]; });
      var end = first + p.gates.length - 1, x0 = self.xs[first] - self.step / 2, x1 = self.xs[end] + self.step / 2;
      c.fillStyle = col.label; c.font = '11px ' + MONO;
      c.fillText(p.gates[0] + '–' + p.gates[p.gates.length - 1], (x0 + x1) / 2, 14);
      c.font = '500 12px ' + MONO; c.fillStyle = col.ink;
      c.fillText(i === 2 ? 'PORTFOLIO / OPS' : p.name.toUpperCase(), (x0 + x1) / 2, 34);
      c.globalAlpha = 0.22; c.strokeStyle = col.ink; c.lineWidth = 1;
      c.beginPath(); c.moveTo(x0 + 3, 48); c.lineTo(x1 - 3, 48); c.stroke(); c.globalAlpha = 1;
    });
    this.outline(); c.fillStyle = col.wash; c.globalAlpha = 0.45; c.fill(); c.globalAlpha = 1;
    // Open mouth and short parallel outlet; only the curved walls are stroked.
    c.strokeStyle = col.ink; c.lineWidth = 1.4; c.globalAlpha = 0.72;
    c.beginPath(); c.moveTo(this.left, this.cy - this.rim); this.wall(-1, false); c.lineTo(this.right, this.cy - this.tube);
    c.moveTo(this.left, this.cy + this.rim); this.wall(1, false); c.lineTo(this.right, this.cy + this.tube); c.stroke();
    c.globalAlpha = 1;
    this.xs.forEach(function (x, i) {
      var h = self.half(x), y0 = self.cy - h + 3, y1 = self.cy + h - 3;
      c.strokeStyle = col.ink; c.lineWidth = 0.7; c.globalAlpha = i < 9 ? 0.35 : 0.22;
      c.beginPath(); c.moveTo(x - 2, y0); c.lineTo(x - 2, y1); c.moveTo(x + 2, y0); c.lineTo(x + 2, y1); c.stroke();
      c.lineWidth = 0.7; c.beginPath();
      for (var y = y0 + 4; y < y1; y += 6) { c.moveTo(x - 3, y); c.lineTo(x + 3, y - 2); }
      c.stroke(); c.globalAlpha = 0.15;
      c.beginPath(); c.moveTo(x, self.cy + h + 6); c.lineTo(x, 356); c.stroke(); c.globalAlpha = 1;
      c.font = '500 13px ' + MONO; c.fillStyle = col.ink; c.fillText(self.model.data.gates[i].id, x, 375);
      c.font = '13px ' + MONO; c.fillStyle = col.label;
      c.fillText(fmt(self.model.data.gates[i].strategies_cleared), x, self.w < 900 && i % 2 ? 406 : 394);
    });
    // A fixed stratified population makes the density reproducible, with no random bursts.
    // Only Q02–Q08 use measured cumulative ratios. Later traces are a process illustration.
    var total = 220, length = this.right - this.left + 42;
    c.save(); this.outline(); c.clip();
    for (var i = 0; i < total; i++) {
      var quantile = (i + 0.5) / total, stop = this.right + 24;
      if (this.model.scaleValid) {
        for (var gate = 2; gate <= 8; gate++) {
          if (quantile > this.model.data.gates[gate].strategies_cleared / this.model.data.strategies_tested) { stop = this.xs[gate]; break; }
        }
      } else if (quantile > 0.025) stop = this.xs[2 + i % 7];
      var phase = (i * 0.61803398875 + this.t * 0.055) % 1;
      var x = this.left - 12 + phase * length;
      var lane = ((i * 0.754877666) % 1 - 0.5) * 1.7;
      var y = this.cy + lane * (this.half(Math.max(this.left, x)) - 6);
      var alpha = 0.8, tail = 3;
      if (x > stop) {
        var age = (x - stop) / 35;
        if (age >= 1) continue;
        x = stop - age * 3; y += age * 20; alpha *= 1 - age; tail = 2;
        c.strokeStyle = col.ink;
      } else c.strokeStyle = col.accent;
      c.globalAlpha = alpha * 0.45; c.lineWidth = 0.8;
      c.beginPath(); c.moveTo(x - tail, y - lane * 0.7); c.lineTo(x, y); c.stroke();
      c.globalAlpha = alpha; c.fillStyle = c.strokeStyle;
      c.beginPath(); c.arc(x, y, 1.5, 0, Math.PI * 2); c.fill();
    }
    c.restore(); c.globalAlpha = 1;
    // Sparse outlet movement is illustrative; no assertion of Q17 clearance is made.
  };
  Funnel.prototype.sync = function () {
    if (this.raf) cancelAnimationFrame(this.raf);
    this.raf = 0; this.last = 0;
    if (this.media.matches) { this.draw(); return; }
    if (this.dead || this.paused || !this.visible || document.hidden) return;
    var self = this;
    function tick(now) {
      if (self.dead || self.paused || !self.visible || document.hidden) { self.raf = 0; return; }
      var currentDpr = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
      if (currentDpr !== self.dpr) self.fit();
      if (self.last) self.t += Math.min((now - self.last) / 1000, 0.08);
      self.last = now; self.draw(); self.raf = requestAnimationFrame(tick);
    }
    this.raf = requestAnimationFrame(tick);
  };
  Funnel.prototype.destroy = function () {
    this.dead = true; if (this.raf) cancelAnimationFrame(this.raf);
    if (this.ro) this.ro.disconnect(); if (this.io) this.io.disconnect();
    document.removeEventListener('visibilitychange', this.change); window.removeEventListener('resize', this.resize);
    if (this.media.removeEventListener) this.media.removeEventListener('change', this.change);
    this.button.removeEventListener('click', this.toggle); this.root.remove();
    this.tableWrap.replaceWith(this.table); this.table.innerHTML = this.oldTable;
    if (!this.tableWasHidden) this.table.classList.remove('visually-hidden');
    if (this.intro) this.intro.textContent = this.oldIntro;
    if (this.note) this.note.textContent = this.oldNote;
  };
  function mount(el, data) {
    var m = modelOf(data); styles();
    if (el._qmFunnel) el._qmFunnel.destroy();
    el._qmFunnel = new Funnel(el, m); return el._qmFunnel;
  }
  function fillRecordsGrid(d) {
    var vals = { strategies_tested: d.strategies_tested, backtests_completed: d.backtests_completed,
      optimization_census_cells_measured: d.optimization_census_cells_measured, gates_total: d.gates_total,
      qualified_pairs_current: d.qualified_pairs_current, qualified_pairs_target: d.qualified_pairs_target,
      q08_strategies_cleared: d.gates[8].strategies_cleared, live_closed_positions: d.live && d.live.closed_positions };
    Object.keys(vals).forEach(function (k) {
      if (integer(vals[k])) document.querySelectorAll('[data-stat="' + k + '"]').forEach(function (n) { n.textContent = fmt(vals[k]); });
    });
  }
  function autoInit() {
    var el = document.getElementById('gate-funnel'); if (!el) return;
    fetch(el.getAttribute('data-src') || '/public-data/funnel-stats.json', { cache: 'no-cache' })
      .then(function (r) { if (!r.ok) throw Error('Census unavailable'); return r.json(); })
      .then(function (d) { mount(el, d); fillRecordsGrid(d); })
      .catch(function () { console.warn('QMFunnel: using the static census table.'); });
  }
  window.QMFunnel = { mount: mount };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', autoInit); else autoInit();
})();
