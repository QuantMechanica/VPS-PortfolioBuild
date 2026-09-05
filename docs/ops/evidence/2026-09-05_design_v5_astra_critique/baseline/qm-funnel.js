/*!
 * qm-funnel.js — QuantMechanica animated gate funnel
 * -------------------------------------------------------------------------
 * A left-to-right sieve funnel on a <canvas>. Strategies enter as balls on the
 * left (1 ball = 10 strategies; strategies_tested sets the spawn budget), stream
 * through 18 gate ports in three phase bands, and drop out at the real measured
 * pass ratios so only a trickle reaches the narrow spout on the right.
 *
 * The envelope is a smooth funnel built from cubic Bezier curves (wide rounded
 * mouth, gentle S-curve walls, rounded spout — no straight edges), an accent-to-
 * near-white gradient fill with a subtle inner shadow, phase pill chips over
 * softly tinted clipped regions, and rounded gate bars with a circular port
 * (dashed for pending gates). Balls carry radial shading + a faint trail;
 * dropped balls bounce and fade.
 *
 * Every figure is read from public-data/funnel-stats.json — nothing is invented.
 * Pass ratios:
 *   - Q00/Q01 (intake, build): pass-through (no per-symbol elimination here).
 *   - Q02..Q08: strict chain p(k) = cleared(k)/cleared(k-1); cleared(Q02) over
 *     strategies_tested.
 *   - Q09..Q17: cleared(k) over the previous NON-ZERO cleared count, clamped to
 *     1. A 0-count gate is "pending" and passes through (a literal 0 would wall
 *     the funnel and contradict the later non-zero gates and the live record).
 * The spout shows the real "qualified pairs today: N of M".
 *
 * Vanilla, no third-party library. HiDPI aware. ~60 fps, throttled to ~30 fps
 * when the tab is hidden; the loop fully pauses off-screen (IntersectionObserver)
 * and resumes when scrolled back in.
 *
 * ANIMATION IS CONTENT: the loop runs by DEFAULT, including under
 * prefers-reduced-motion — where it is calmer (~40% ball budget, 60% speed). A
 * visible Pause/Play control stops it; the choice is remembered in localStorage;
 * when paused, one static frame is drawn.
 *
 * Contract: on DOMContentLoaded, find #gate-funnel (a <div data-src="…json">),
 * fetch the JSON, hide the fallback <table> with .visually-hidden, insert a
 * <canvas> filling the div plus a Pause/Play button after it, and give the
 * canvas role="img" + a one-sentence aria-label. Exposes QMFunnel.mount(el,data).
 */
(function () {
  'use strict';

  /* 0. Small utilities */

  var REDUCED_MOTION =
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var FONT = '"Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif';
  var TAU = Math.PI * 2;

  function clamp(x, lo, hi) { return x < lo ? lo : x > hi ? hi : x; }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function smooth(x) { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); }   // smoothstep S-curve
  function dpr() { return Math.max(1, Math.min(window.devicePixelRatio || 1, 3)); }

  function fmt(n) {
    // thousands separators, e.g. 3097 -> "3,097"
    n = Math.round(+n || 0);
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }

  function cssVar(name, fallback) {
    try {
      var v = getComputedStyle(document.documentElement).getPropertyValue(name);
      v = (v || '').trim();
      return v || fallback;
    } catch (e) { return fallback; }
  }

  // Parse '#rgb' / '#rrggbb' / 'rgb()' / 'rgba()' to an [r,g,b] triple.
  function parseRGB(str, fb) {
    fb = fb || [10, 125, 79];
    if (!str) return fb.slice();
    str = String(str).trim();
    if (str.charAt(0) === '#') {
      var h = str.slice(1);
      if (h.length === 3) h = h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2);
      if (h.length >= 6) {
        return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
      }
      return fb.slice();
    }
    var m = str.match(/rgba?\(([^)]+)\)/);
    if (m) {
      var p = m[1].split(',');
      return [clamp(parseFloat(p[0]) || 0, 0, 255), clamp(parseFloat(p[1]) || 0, 0, 255), clamp(parseFloat(p[2]) || 0, 0, 255)];
    }
    return fb.slice();
  }
  function rgba(rgb, a) { return 'rgba(' + (rgb[0] | 0) + ',' + (rgb[1] | 0) + ',' + (rgb[2] | 0) + ',' + a + ')'; }
  function mix(rgb, t, k) { return [lerp(rgb[0], t[0], k), lerp(rgb[1], t[1], k), lerp(rgb[2], t[2], k)]; }
  var WHITE = [255, 255, 255], BLACK = [0, 0, 0];

  function roundRectPath(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function makeRng(seed) {
    var a = (seed >>> 0) || 0x9e3779b9;
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /* 1. Injected style block — .visually-hidden (fallback table) + the Pause/Play control. Injected once; only defines rules the site may not already carry. */

  var STYLE_INJECTED = false;
  function ensureStyles() {
    if (STYLE_INJECTED) return;
    STYLE_INJECTED = true;
    var el = document.createElement('style');
    el.id = 'qm-funnel-css';
    el.textContent =
      '.visually-hidden{position:absolute!important;width:1px;height:1px;' +
      'padding:0;margin:-1px;overflow:hidden;clip:rect(0 0 0 0);' +
      'clip-path:inset(50%);white-space:nowrap;border:0}' +
      '.funnel__control{display:inline-flex;align-items:center;gap:8px;margin:12px 0 0;' +
      'font:500 13px/1 ' + FONT + ';color:var(--c-accent,#0a7d4f);' +
      'background:var(--c-accent-soft,rgba(10,125,79,.10));border:1px solid rgba(10,125,79,.22);' +
      'border-radius:999px;padding:8px 16px;cursor:pointer;-webkit-appearance:none;appearance:none;' +
      'transition:background .15s ease,color .15s ease,border-color .15s ease}' +
      '.funnel__control:hover{background:var(--c-accent,#0a7d4f);color:#fff;border-color:var(--c-accent,#0a7d4f)}' +
      '.funnel__control:focus-visible{outline:3px solid var(--c-accent,#0a7d4f);outline-offset:3px}' +
      '.funnel__control::before{content:"";display:inline-block;box-sizing:border-box}' +
      '.funnel__control[aria-pressed="false"]::before{width:9px;height:11px;' +
      'border-left:3px solid currentColor;border-right:3px solid currentColor}' +
      '.funnel__control[aria-pressed="true"]::before{width:0;height:0;' +
      'border-top:6px solid transparent;border-bottom:6px solid transparent;' +
      'border-left:10px solid currentColor;border-right:0}';
    document.head.appendChild(el);
  }

  /* 2. Short, neutral gate names (derived from the already-public labels that appear verbatim on the pipeline page). Falls back to the JSON label if a gate id is not in this map. */

  var SHORT = {
    Q00: 'Intake', Q01: 'Build', Q02: 'Baseline', Q03: 'Param sweep',
    Q04: 'Walk-forward', Q05: 'Full history', Q06: 'Stress', Q07: 'Multi-seed',
    Q08: 'Statistics', Q09: 'Re-baseline', Q10: 'News + venue', Q11: 'Confirm',
    Q12: 'Filters', Q13: 'Re-optimize', Q14: 'Head-to-head', Q15: 'Portfolio',
    Q16: 'Ops ready', Q17: 'Live burn-in'
  };

  var PHASE_TITLE = {
    validation: 'Validation',
    requalification: 'Requalification',
    portfolio: 'Portfolio & operations'
  };

  // Short forms used when a phase band is too narrow for the full title
  // (e.g. the 3-gate portfolio band on a ~800px canvas), mirroring the SHORT
  // gate-name approach so titles never hard-clip mid-word.
  var PHASE_SHORT = {
    validation: 'Validation',
    requalification: 'Requal.',
    portfolio: 'Portfolio'
  };

  /* 3. Derive the funnel model (counts + pass probabilities) from the JSON */

  function buildModel(data) {
    var gatesIn = (data.gates || []).slice();
    var tested = Math.max(1, +data.strategies_tested || 0);

    // index gates in declared order
    var gates = gatesIn.map(function (g, i) {
      return {
        idx: i,
        id: g.id,
        label: g.label || g.id,
        short: SHORT[g.id] || (g.label || g.id),
        phase: g.phase,
        cleared: Math.max(0, +g.strategies_cleared || 0),
        pass: 1,          // per-gate pass probability (filled below)
        pending: false    // count == 0 -> pending / pass-through
      };
    });

    // pass probabilities
    var prevValid = tested;      // rolling denominator for the strict Q02..Q08 chain
    var prevNonZero = tested;    // rolling "previous non-zero count" for Q09+
    for (var i = 0; i < gates.length; i++) {
      var g = gates[i];
      var id = g.id;
      if (id === 'Q00' || id === 'Q01') {
        // intake / build — pass-through; census does not sieve per-strategy here
        g.pass = 1;
        g.pending = g.cleared === 0;
        if (g.cleared > 0) prevNonZero = g.cleared;
        continue;
      }
      if (id === 'Q02') {
        g.pass = clamp(g.cleared / tested, 0, 1);
        prevValid = g.cleared;
        prevNonZero = g.cleared || prevNonZero;
        continue;
      }
      if (id === 'Q03' || id === 'Q04' || id === 'Q05' ||
          id === 'Q06' || id === 'Q07' || id === 'Q08') {
        // strict validation chain
        g.pass = clamp(g.cleared / (prevValid || 1), 0, 1);
        prevValid = g.cleared || prevValid;
        prevNonZero = g.cleared || prevNonZero;
        continue;
      }
      // Q09..Q17: relative to previous non-zero count, never above 1.
      if (g.cleared === 0) {
        g.pending = true;
        g.pass = 1;               // pending gate -> pass-through (documented above)
      } else {
        g.pass = clamp(g.cleared / (prevNonZero || 1), 0, 1);
        prevNonZero = g.cleared;
      }
    }

    // phase bands in declared order, each spanning a contiguous gate range
    var bands = (data.phases || []).map(function (p) {
      var members = gates.filter(function (g) { return g.phase === p.id; });
      var lo = members.length ? members[0].idx : 0;
      var hi = members.length ? members[members.length - 1].idx : 0;
      return {
        id: p.id,
        name: PHASE_TITLE[p.id] || p.name || p.id,
        lo: lo, hi: hi,
        first: members.length ? members[0].id : '',
        last: members.length ? members[members.length - 1].id : ''
      };
    });

    return {
      tested: tested,
      baselineCleared: (gates[2] && gates[2].cleared) || 0, // Q02 cleared
      gatesTotal: gates.length,
      qualNow: +data.qualified_pairs_current || 0,
      qualTarget: +data.qualified_pairs_target || 0,
      closed: (data.live && +data.live.closed_positions) || 0,
      gates: gates,
      bands: bands
    };
  }

  function ariaSentence(m) {
    return 'Funnel of the research pipeline: ' + fmt(m.tested) +
      ' strategies tested; ' + fmt(m.baselineCleared) +
      ' cleared baseline screening, narrowing across ' + m.gatesTotal +
      ' gates to ' + m.qualNow + ' of ' + m.qualTarget +
      ' target pairs qualified today.';
  }

  /* 4. HiDPI canvas fit */

  function fitCanvas(canvas, cssH, cssW) {
    if (cssW == null) {
      var rect = canvas.getBoundingClientRect();
      cssW = Math.max(1, Math.round(rect.width || canvas.clientWidth || 320));
    }
    var ratio = dpr();
    canvas.width = Math.round(cssW * ratio);
    canvas.height = Math.round(cssH * ratio);
    var ctx = canvas.getContext('2d');
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    return { ctx: ctx, w: cssW, h: cssH };
  }

  /* 5. The funnel instance */

  function Funnel(canvas, model) {
    this.canvas = canvas;
    this.m = model;
    this.balls = [];
    this.rafId = null;
    this.lastFrame = 0;
    this.spawnAcc = 0;
    this.visible = true;         // in the viewport (IntersectionObserver)
    this.paused = false;         // user intent (Pause/Play), remembered in localStorage
    this.reduced = REDUCED_MOTION;
    this.btn = null;
    this.rng = makeRng(0x51cebabe);
    this.colors = null;
    this.layout = null;
    this._cssW = 0;      // last measured CSS width (updated only on resize)
    this._fit = null;    // cached { ctx, w, h } — refit only when the size changes
    this.readColors();
  }

  Funnel.prototype.readColors = function () {
    this.colors = {
      bg: cssVar('--c-bg', '#ffffff'),
      bgAlt: cssVar('--c-bg-alt', '#f5f5f7'),
      text: cssVar('--c-text', '#1d1d1f'),
      text2: cssVar('--c-text-2', '#6e6e73'),
      text3: cssVar('--c-text-3', '#86868b'),
      line: cssVar('--c-line', 'rgba(0,0,0,.08)'),
      line2: cssVar('--c-line-2', 'rgba(0,0,0,.16)'),
      accent: cssVar('--c-accent', '#0a7d4f'),
      accentSoft: cssVar('--c-accent-soft', 'rgba(10,125,79,.10)'),
      pass: cssVar('--c-pass', '#2f9e5f')
    };
    this._rgbAccent = parseRGB(this.colors.accent, [10, 125, 79]);
    this._rgbBar = parseRGB(this.colors.text3, [134, 134, 139]);
    this._rgbBg = parseRGB(this.colors.bg, [255, 255, 255]);
      this._sprAccent = this.makeSprite(this._rgbAccent, false);
    this._sprDrop = this.makeSprite(this._rgbBar, true);
  };

  Funnel.prototype.makeSprite = function (rgb, isDrop) {
    var S = 26, pad = 6, r = (S - 2 * pad) / 2, cx = S / 2, cy = S / 2;
    var cv = document.createElement('canvas');
    cv.width = S; cv.height = S;
    var g = cv.getContext('2d');
    g.beginPath(); g.arc(cx, cy + 0.4, r, 0, TAU);
    g.shadowColor = 'rgba(8,28,18,' + (isDrop ? 0.20 : 0.32) + ')';
    g.shadowBlur = 3.2; g.shadowOffsetX = 0.8; g.shadowOffsetY = 1.6;
    g.fillStyle = rgba(mix(rgb, BLACK, 0.15), 1); g.fill();
    g.shadowColor = 'transparent'; g.shadowBlur = 0; g.shadowOffsetX = 0; g.shadowOffsetY = 0;
    var hi = mix(rgb, WHITE, isDrop ? 0.5 : 0.72);
    var lo = mix(rgb, BLACK, 0.28);
    var rg = g.createRadialGradient(cx - r * 0.42, cy - r * 0.48, r * 0.12, cx, cy, r * 1.08);
    rg.addColorStop(0, rgba(hi, 1));
    rg.addColorStop(0.5, rgba(rgb, 1));
    rg.addColorStop(1, rgba(lo, 1));
    g.beginPath(); g.arc(cx, cy, r, 0, TAU); g.fillStyle = rg; g.fill();
    g.beginPath(); g.arc(cx - r * 0.34, cy - r * 0.4, r * 0.26, 0, TAU);
    g.fillStyle = 'rgba(255,255,255,' + (isDrop ? 0.26 : 0.5) + ')'; g.fill();
    return { cv: cv, S: S, r: r };
  };

  // Geometry for the current canvas size. Returns null if too small.
  Funnel.prototype.computeLayout = function (W, H) {
    var mobile = W < 560;
    var marginT = mobile ? 44 : 52;              // phase-chip header row
    // Both staggered gate-label tiers (id + count) must fit below plotBot.
    var marginB = mobile ? 70 : 80;              // staggered gate id + count rows (two tiers)
    var marginL = mobile ? 20 : 26;              // room for the rounded left mouth cap
    var marginR = mobile ? 88 : 112;             // spout cap + right-side caption gutter
    var plotX0 = marginL;
    var plotX1 = W - marginR;
    var plotW = plotX1 - plotX0;
    if (plotW < 120) return null;

    var plotTop = marginT;
    var plotBot = H - marginB;
    var plotH = plotBot - plotTop;
    var centerY = plotTop + plotH / 2;

    var colW = plotW / this.m.gates.length;
    var maxHalf = plotH / 2 - 4;
    var mouthFrac = 0.17;                          // spout half-height as a fraction of the mouth
    var hL = maxHalf;
    var hR = maxHalf * mouthFrac;

    var gates = this.m.gates.map(function (g, i) {
      var x = plotX0 + (i + 0.5) * colW;
      return { g: g, x: x, xn: (x - plotX0) / plotW };
    });

    return {
      mobile: mobile, W: W, H: H,
      plotX0: plotX0, plotX1: plotX1, plotW: plotW,
      plotTop: plotTop, plotBot: plotBot, centerY: centerY,
      colW: colW, maxHalf: maxHalf, mouthFrac: mouthFrac,
      hL: hL, hR: hR, marginL: marginL, marginR: marginR,
      gates: gates
    };
  };

  Funnel.prototype.halfAt = function (L, xn) {
    return L.hL - (L.hL - L.hR) * smooth(xn);
  };

  // Trace the rounded funnel body as a closed path of four cubic Beziers:
  // top S-wall, rounded spout cap, bottom S-wall, rounded mouth cap. The
  // control points sit on the horizontal midline so every join is C1-smooth
  // (no straight edges, no sharp corners). `inset` shrinks the envelope.
  Funnel.prototype.tracePath = function (ctx, L, inset) {
    inset = inset || 0;
    var x0 = L.plotX0, x1 = L.plotX1, cy = L.centerY;
    var hL = Math.max(2, L.hL - inset), hR = Math.max(1, L.hR - inset);
    var cxm = (x0 + x1) / 2;
    var bulgeR = clamp(hR * 0.85, 6, L.marginR * 0.38);
    var bulgeL = clamp(hL * 0.16, 8, x0 - 4);      // keep the mouth cap on-canvas
    ctx.beginPath();
    ctx.moveTo(x0, cy - hL);                                              // top of mouth
    ctx.bezierCurveTo(cxm, cy - hL, cxm, cy - hR, x1, cy - hR);           // top S-wall
    ctx.bezierCurveTo(x1 + bulgeR, cy - hR, x1 + bulgeR, cy + hR, x1, cy + hR); // spout cap
    ctx.bezierCurveTo(cxm, cy + hR, cxm, cy + hL, x0, cy + hL);           // bottom S-wall
    ctx.bezierCurveTo(x0 - bulgeL, cy + hL, x0 - bulgeL, cy - hL, x0, cy - hL); // mouth cap
    ctx.closePath();
  };

  /* ---- ball lifecycle ---------------------------------------------- */

  Funnel.prototype.spawnBall = function (L, rnd) {
    var half = this.halfAt(L, 0) * 0.86;
    var y = L.centerY + (rnd() * 2 - 1) * half;
    this.balls.push({
      x: L.plotX0, y: y, px: L.plotX0, py: y,
      vy: 0, next: 0, state: 'alive', alpha: 1, bounced: false,
      r: 2.4 + rnd() * 0.7
    });
  };

  // advance the simulation by dt seconds
  Funnel.prototype.step = function (L, dt) {
    var m = this.m;
    var speed = (L.plotW / 10.5) * (this.reduced ? 0.6 : 1);   // 60% speed under reduced motion
    var budget = Math.max(1, Math.round((m.tested / 10) * (this.reduced ? 0.4 : 1))); // ~40% budget
    var perSec = budget / 10.5;                    // one budget per traverse
    var MAXB = this.reduced ? 96 : 240;

    // spawn (cap live balls for perf)
    this.spawnAcc += perSec * dt;
    while (this.spawnAcc >= 1 && this.balls.length < MAXB) {
      this.spawnAcc -= 1;
      this.spawnBall(L, this.rng);
    }

    var gates = L.gates;
    var alive = [];
    for (var i = 0; i < this.balls.length; i++) {
      var b = this.balls[i];
      if (b.state === 'alive') {
        b.px = b.x; b.py = b.y;                     // previous position -> motion trail
        b.x += speed * dt;
          while (b.next < gates.length && b.x >= gates[b.next].x) {
          var gt = gates[b.next].g;
          if (this.rng() <= gt.pass) {
            b.next++;                               // passed this port
          } else {
            b.state = 'drop';                       // sieved out
            b.vy = 16 + this.rng() * 46;
            break;
          }
        }
        var half = this.halfAt(L, (b.x - L.plotX0) / L.plotW) * 0.86;
        var dy = b.y - L.centerY;
        if (dy > half) b.y = L.centerY + half;
        else if (dy < -half) b.y = L.centerY - half;
        else b.y = L.centerY + dy * 0.985;          // gentle pull toward the spine
        if (b.x <= L.plotX1) alive.push(b);
      } else {
        // dropped: fall + a small bounce off the floor + fade
        b.vy += 90 * dt;
        b.y += b.vy * dt;
        b.x += speed * 0.25 * dt;
        var floor = L.plotBot - (b.r || 2);
        if (!b.bounced && b.vy > 0 && b.y >= floor) {
          b.y = floor; b.vy = -b.vy * 0.34; b.bounced = true;
        }
        b.alpha -= dt * 1.05;
        if (b.alpha > 0 && b.y < L.plotBot + 40) alive.push(b);
      }
    }
    this.balls = alive;
  };

  // Build a stable, at-rest distribution of balls for the static (paused) frame.
  Funnel.prototype.staticBalls = function (L) {
    var rnd = makeRng(0x1234abcd);
    var out = [];
    var gates = L.gates;
    var survive = 1;
    for (var i = 0; i < gates.length; i++) {
      var g = gates[i].g;
      survive *= g.pass;
      var n = Math.round(survive * 26);
      var half = this.halfAt(L, gates[i].xn) * 0.86;
      var xBase = gates[i].x + L.colW * 0.15;
      var k;
      for (k = 0; k < n; k++) {
        out.push({
          x: xBase + (rnd() - 0.5) * L.colW * 0.5,
          y: L.centerY + (rnd() * 2 - 1) * half,
          state: 'alive', alpha: 1, r: 2.4
        });
      }
      if (g.pass < 0.999 && !g.pending) {
        var lost = Math.min(6, Math.round((1 - g.pass) * survive * 22 + 1));
        for (k = 0; k < lost; k++) {
          out.push({
            x: gates[i].x + (rnd() - 0.5) * L.colW * 0.4,
            y: L.plotBot - rnd() * 22,
            state: 'drop', alpha: 0.5 - rnd() * 0.25, r: 2.2
          });
        }
      }
    }
    return out;
  };

  /* ---- drawing ------------------------------------------------------ */

  Funnel.prototype.drawBackground = function (ctx, L) {
    var c = this.colors, m = this.m;
    var acc = this._rgbAccent, bar = this._rgbBar;
    ctx.fillStyle = c.bg;
    ctx.fillRect(0, 0, L.W, L.H);

    // ---- funnel body: soft gradient fill ----
    this.tracePath(ctx, L, 0);
    var grad = ctx.createLinearGradient(L.plotX0, L.centerY, L.plotX1, L.centerY);
    grad.addColorStop(0, rgba(acc, 0.16));
    grad.addColorStop(0.55, rgba(acc, 0.06));
    grad.addColorStop(1, rgba(mix(this._rgbBg, WHITE, 0.5), 0.85));       // near-white spout end
    ctx.fillStyle = grad;
    ctx.fill();

    // ---- softly tinted phase regions + inner shadow, clipped to the body ----
    ctx.save();
    this.tracePath(ctx, L, 0);
    ctx.clip();
    for (var p = 0; p < m.bands.length; p++) {
      var band = m.bands[p];
      var xa = L.plotX0 + band.lo * L.colW;
      var xb = L.plotX0 + (band.hi + 1) * L.colW;
      ctx.fillStyle = rgba(acc, p === 1 ? 0.09 : (p === 2 ? 0.055 : 0.028));
      ctx.fillRect(xa, L.plotTop - 8, xb - xa, (L.plotBot - L.plotTop) + 16);
    }
    // inner shadow: a blurred stroke of the same path, kept to the interior
    // by the active clip.
    this.tracePath(ctx, L, 0);
    ctx.shadowColor = 'rgba(15,45,30,0.22)';
    ctx.shadowBlur = 18;
    ctx.lineWidth = 6;
    ctx.strokeStyle = 'rgba(0,0,0,0.28)';
    ctx.stroke();
    ctx.restore();

    // ---- crisp edge ----
    this.tracePath(ctx, L, 0);
    ctx.lineWidth = 1.4;
    ctx.strokeStyle = rgba(acc, 0.5);
    ctx.stroke();

    // ---- gate ports (rounded bars with a circular opening) ----
    var gates = L.gates;
    var i, x, half;
    for (i = 0; i < gates.length; i++) {
      var g = gates[i].g;
      x = gates[i].x;
      half = this.halfAt(L, gates[i].xn);
      var yTop = L.centerY - half, yBot = L.centerY + half;
      var barW = L.mobile ? 4 : 5;
      var portR = clamp(half * 0.18, 3.5, 8);
      var gap = portR + 1.5;
      if (g.pending) {
        // pending gate (0 cleared) — dashed rounded bar + dashed port ring
        ctx.save();
        ctx.setLineDash([2.5, 3.5]);
        ctx.lineWidth = 1.4;
        ctx.strokeStyle = rgba(bar, 0.7);
        roundRectPath(ctx, x - barW / 2, yTop, barW, yBot - yTop, barW / 2);
        ctx.stroke();
        ctx.beginPath(); ctx.arc(x, L.centerY, portR, 0, TAU); ctx.stroke();
        ctx.restore();
      } else {
        // active sieve: two rounded bar segments leaving a circular port
        ctx.fillStyle = rgba(bar, 0.5);
        var hTop = (L.centerY - gap) - yTop;
        if (hTop > 0.5) { roundRectPath(ctx, x - barW / 2, yTop, barW, hTop, barW / 2); ctx.fill(); }
        var hBot = yBot - (L.centerY + gap);
        if (hBot > 0.5) { roundRectPath(ctx, x - barW / 2, L.centerY + gap, barW, hBot, barW / 2); ctx.fill(); }
        // the port itself — a soft accent ring the balls pass through
        ctx.beginPath(); ctx.arc(x, L.centerY, portR, 0, TAU);
        ctx.fillStyle = rgba(acc, 0.10); ctx.fill();
        ctx.lineWidth = 1.6; ctx.strokeStyle = rgba(acc, 0.85); ctx.stroke();
      }
    }

    // ---- phase header pill chips (over the tinted regions) ----
    for (p = 0; p < m.bands.length; p++) {
      this.drawPhaseChip(ctx, L, m.bands[p], p);
    }

    // ---- entry caption (bottom-left, at the mouth of entry) ----
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    ctx.font = '600 ' + (L.mobile ? 11 : 12) + 'px ' + FONT;
    ctx.fillStyle = c.text2;
    ctx.fillText(fmt(m.tested) + ' tested', L.plotX0 + 2, L.plotBot + (L.mobile ? 18 : 20));

    // ---- qualified-pairs caption (right of the spout) ----
    // Clear the rounded spout bulge (same geometry tracePath uses) so the count
    // never crowds the cap, then keep a small gutter to the canvas right edge.
    var spoutBulge = clamp(L.hR * 0.85, 6, L.marginR * 0.38);
    var cx = L.plotX1 + Math.max(12, spoutBulge + 6);
    ctx.textAlign = 'left';
    ctx.fillStyle = c.text3;
    ctx.font = '11px ' + FONT;
    ctx.fillText('qualified', cx, L.centerY - 20);
    ctx.fillText('pairs today', cx, L.centerY - 8);
    ctx.fillStyle = c.accent;
    ctx.font = '700 ' + (L.mobile ? 17 : 20) + 'px ' + FONT;
    ctx.fillText(m.qualNow + ' of ' + m.qualTarget, cx, L.centerY + 12);

    // ---- per-gate labels below the funnel (staggered two tiers) ----
    this.drawGateLabels(ctx, L);
  };

  Funnel.prototype.drawPhaseChip = function (ctx, L, band, p) {
    var c = this.colors, acc = this._rgbAccent;
    var xa = L.plotX0 + band.lo * L.colW;
    var xb = L.plotX0 + (band.hi + 1) * L.colW;
    var bandW = xb - xa, bcx = (xa + xb) / 2;

    ctx.textAlign = 'center';
    ctx.font = '600 ' + (L.mobile ? 11 : 12) + 'px ' + FONT;
    var title = band.name;
    if (ctx.measureText(title).width > bandW - 26) title = PHASE_SHORT[band.id] || title;
    if (ctx.measureText(title).width > bandW - 22) ctx.font = '600 ' + (L.mobile ? 10 : 11) + 'px ' + FONT;
    var tw = ctx.measureText(title).width;
    var pw = Math.min(bandW - 6, tw + 22);
    var ph = L.mobile ? 20 : 22;
    var py = L.mobile ? 4 : 6;
    var pxx = bcx - pw / 2;

    // pill
    roundRectPath(ctx, pxx, py, pw, ph, ph / 2);
    ctx.fillStyle = rgba(acc, p === 1 ? 0.16 : 0.10);
    ctx.fill();
    ctx.lineWidth = 1;
    ctx.strokeStyle = rgba(acc, 0.24);
    ctx.stroke();
    // title (clipped to the pill so it never bleeds past a narrow band)
    ctx.save();
    roundRectPath(ctx, pxx, py, pw, ph, ph / 2);
    ctx.clip();
    ctx.fillStyle = c.text;
    ctx.textBaseline = 'middle';
    ctx.fillText(title, bcx, py + ph / 2 + 0.5);
    ctx.restore();
    // gate range under the pill
    ctx.textBaseline = 'alphabetic';
    ctx.font = '10px ' + FONT;
    ctx.fillStyle = c.text3;
    ctx.fillText(band.first + '–' + band.last, bcx, py + ph + (L.mobile ? 11 : 12));
  };

  Funnel.prototype.drawGateLabels = function (ctx, L) {
    var c = this.colors;
    var gates = L.gates;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'alphabetic';

    var row0 = L.plotBot + (L.mobile ? 30 : 32);   // tier A id
    var row0b = row0 + 12;                          // tier A count
    var row1 = L.plotBot + (L.mobile ? 30 : 32) + 20; // tier B id (staggered lower)
    var row1b = row1 + 12;

    var sameTierGap = L.colW * 2;                   // neighbours two columns apart share a tier

    for (var i = 0; i < gates.length; i++) {
      var g = gates[i].g;
      var x = gates[i].x;
      var tierLow = (i % 2 === 1);
      var idY = tierLow ? row1 : row0;
      var cntY = tierLow ? row1b : row0b;

      ctx.strokeStyle = c.line;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(Math.round(x) + 0.5, L.plotBot + 2);
      ctx.lineTo(Math.round(x) + 0.5, idY - 9);
      ctx.stroke();

      ctx.font = '600 11px ' + FONT;
      ctx.fillStyle = g.pending ? c.text3 : c.text2;
      ctx.fillText(g.id, x, idY);

      ctx.font = '11px ' + FONT;
      var cntTxt = g.pending ? '—' : fmt(g.cleared);
      var cntW = ctx.measureText(cntTxt).width;
      if (cntW + 3 <= sameTierGap) {
        ctx.fillStyle = g.pending ? c.text3 : c.text;
        ctx.fillText(cntTxt, x, cntY);
      }

      // short name: rotated inside the funnel (desktop only, where the bar is
      // tall enough to be legible)
      if (!L.mobile) {
        var half = this.halfAt(L, gates[i].xn);
        if (half > 34) {
          ctx.save();
          ctx.translate(x - 4, L.centerY + half - 6);
          ctx.rotate(-Math.PI / 2);
          ctx.textAlign = 'left';
          ctx.font = '10px ' + FONT;
          ctx.fillStyle = c.text3;
          ctx.fillText(g.short, 0, 0);
          ctx.restore();
          ctx.textAlign = 'center';
        }
      }
    }
  };

  Funnel.prototype.drawBalls = function (ctx, L, list) {
    var i, b;
    // ---- faint motion trails (alive balls only, batched) ----
    ctx.save();
    ctx.globalAlpha = 0.12;
    ctx.strokeStyle = rgba(this._rgbAccent, 1);
    ctx.lineCap = 'round';
    ctx.beginPath();
    var any = false;
    for (i = 0; i < list.length; i++) {
      b = list[i];
      if (b.state !== 'alive' || b.px == null) continue;
      if (b.x - b.px < 0.4) continue;               // no visible travel -> no trail
      ctx.moveTo(b.px, b.py);
      ctx.lineTo(b.x, b.y);
      any = true;
    }
    if (any) { ctx.lineWidth = 2.4; ctx.stroke(); }
    ctx.restore();

    // ---- ball bodies (pre-shaded sprites, scaled) ----
    var acc = this._sprAccent, drp = this._sprDrop;
    for (i = 0; i < list.length; i++) {
      b = list[i];
      var sp = b.state === 'drop' ? drp : acc;
      var R = (b.r || 2.4) + (b.state === 'drop' ? 0 : 0.6);
      var k = R / sp.r;
      var dw = sp.S * k;
      ctx.globalAlpha = clamp(b.alpha, 0, 1);
      ctx.drawImage(sp.cv, b.x - (sp.S / 2) * k, b.y - (sp.S / 2) * k, dw, dw);
    }
    ctx.globalAlpha = 1;
  };

  /* ---- canvas fit cache (measured only on resize, never per frame) ---- */

  Funnel.prototype.heightFor = function (cssW) {
    return cssW < 560 ? 340 : 460;
  };

  Funnel.prototype.measureCss = function () {
    var r = this.canvas.getBoundingClientRect();
    return Math.max(1, Math.round(r.width || this.canvas.clientWidth || 320));
  };

  Funnel.prototype.ensureFit = function () {
    if (!this._cssW) this._cssW = this.measureCss();
    var cssW = this._cssW;
    var H = this.heightFor(cssW);
    if (!this._fit || this._fit.w !== cssW || this._fit.h !== H) {
      this._fit = fitCanvas(this.canvas, H, cssW);
      this.layout = null;     // size changed -> geometry must be recomputed
    }
    return this._fit;
  };

  Funnel.prototype.drawFrame = function () {
    var fit = this.ensureFit();
    var L = this.layout || this.computeLayout(fit.w, fit.h);
    this.layout = L;
    if (!L) {
      fit.ctx.fillStyle = this.colors.bg;
      fit.ctx.fillRect(0, 0, fit.w, fit.h);
      return;
    }
    this.drawBackground(fit.ctx, L);
    this.drawBalls(fit.ctx, L, this.balls);
  };

  /* ---- run loop / paused frame ------------------------------------- */

  Funnel.prototype.renderPaused = function () {
    var fit = this.ensureFit();
    var L = this.layout || this.computeLayout(fit.w, fit.h);
    this.layout = L;
    if (!L) { fit.ctx.fillStyle = this.colors.bg; fit.ctx.fillRect(0, 0, fit.w, fit.h); return; }
    this.drawBackground(fit.ctx, L);
    this.drawBalls(fit.ctx, L, this.staticBalls(L));
  };

  Funnel.prototype.loop = function (ts) {
    if (this.rafId === null) return;
    var self = this;
    // ~60 fps when the tab is visible; ~30 fps when it is hidden. (Off-screen
    // the loop is fully stopped by the IntersectionObserver, not throttled.)
    var interval = document.hidden ? 1000 / 30 : 1000 / 60;
    var elapsed = ts - this.lastFrame;
    if (elapsed >= interval) {
      var dt = Math.min(0.05, elapsed / 1000);     // clamp big gaps (tab was away)
      this.lastFrame = ts;
      var fit = this.ensureFit();                  // cheap: no refit unless resized
      var L = this.layout || this.computeLayout(fit.w, fit.h);
      this.layout = L;
      if (L) {
        this.step(L, dt);
        this.drawBackground(fit.ctx, L);
        this.drawBalls(fit.ctx, L, this.balls);
      } else {
        fit.ctx.fillStyle = this.colors.bg;
        fit.ctx.fillRect(0, 0, fit.w, fit.h);
      }
    }
    this.rafId = window.requestAnimationFrame(function (t) { self.loop(t); });
  };

  Funnel.prototype.wantRun = function () { return !this.paused && this.visible; };

  Funnel.prototype.maybeRun = function () {
    if (this.wantRun()) {
      if (this.rafId === null) {
        var self = this;
        this.lastFrame = 0;                        // fresh clock -> no dt spike
        this.rafId = window.requestAnimationFrame(function (t) { self.loop(t); });
      }
    } else {
      this.stopLoop();
    }
  };

  Funnel.prototype.stopLoop = function () {
    if (this.rafId !== null) { window.cancelAnimationFrame(this.rafId); this.rafId = null; }
  };

  Funnel.prototype.setPaused = function (p) {
    this.paused = !!p;
    try {
      if (window.localStorage) window.localStorage.setItem('qm-funnel-paused', this.paused ? '1' : '0');
    } catch (e) { /* storage unavailable — the toggle still works this session */ }
    if (this.btn) {
      this.btn.setAttribute('aria-pressed', this.paused ? 'true' : 'false');
      this.btn.textContent = this.paused ? 'Play funnel' : 'Pause funnel';
    }
    if (this.paused) {
      this.stopLoop();
      this.renderPaused();
    } else {
      this.maybeRun();
      if (this.rafId === null) this.drawFrame();   // resumed while off-screen: keep it painted
    }
  };

  Funnel.prototype.buildControl = function () {
    var self = this;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'funnel__control';
    btn.setAttribute('aria-pressed', this.paused ? 'true' : 'false');
    btn.textContent = this.paused ? 'Play funnel' : 'Pause funnel';
    btn.addEventListener('click', function () { self.setPaused(!self.paused); });
    // insert directly after the canvas, inside #gate-funnel
    if (this.canvas.parentNode) {
      this.canvas.parentNode.insertBefore(btn, this.canvas.nextSibling);
    }
    this.btn = btn;
  };

  Funnel.prototype.start = function () {
    var self = this;
    this._cssW = this.measureCss();

    try {
      this.paused = !!(window.localStorage && window.localStorage.getItem('qm-funnel-paused') === '1');
    } catch (e) { this.paused = false; }

    this.buildControl();

    var scheduled = false;
    function onResize() {
      if (scheduled) return;
      scheduled = true;
      window.requestAnimationFrame(function () {
        scheduled = false;
        self.readColors();
        self._cssW = self.measureCss();   // the ONE getBoundingClientRect per resize
        self._fit = null;                 // force a re-fit at the new size
        self.layout = null;
        if (self.rafId === null) {           if (self.paused) self.renderPaused(); else self.drawFrame();
        }
      });
    }
    if (typeof ResizeObserver !== 'undefined') {
      this._ro = new ResizeObserver(onResize);
      this._ro.observe(this.canvas);
    } else {
      window.addEventListener('resize', onResize);
    }

    // visibility: fully stop the loop when off-screen (IntersectionObserver),
    // resume when it scrolls back into view; only throttle (not stop) when the
    // tab is hidden.
    if (typeof IntersectionObserver !== 'undefined') {
      this._io = new IntersectionObserver(function (entries) {
        self.visible = !!(entries[0] && entries[0].isIntersecting);
        self.maybeRun();
      }, { threshold: 0.01 });
      this._io.observe(this.canvas);
    }
    this._onVis = function () { self.lastFrame = 0; };   // wake the clock on return
    document.addEventListener('visibilitychange', this._onVis);

    // Animation is content: draw immediately and start unless the viewer paused.
    if (this.paused) {
      this.renderPaused();
    } else {
      this.drawFrame();
      this.maybeRun();
    }
  };

  Funnel.prototype.destroy = function () {
    this.stopLoop();
    if (this._ro) { this._ro.disconnect(); this._ro = null; }
    if (this._io) { this._io.disconnect(); this._io = null; }
    if (this._onVis) { document.removeEventListener('visibilitychange', this._onVis); this._onVis = null; }
    if (this.btn && this.btn.parentNode) { this.btn.parentNode.removeChild(this.btn); this.btn = null; }
  };

  /* 6. mount(el, data) — public entry */

  function mount(el, data) {
    if (!el || !data) return null;
    ensureStyles();

    // tear down a prior instance so its rAF loop + observers do not leak and
    // keep drawing into the canvas we are about to remove (public re-entry point)
    if (el._qmFunnel && typeof el._qmFunnel.destroy === 'function') {
      el._qmFunnel.destroy();
      el._qmFunnel = null;
    }

    var model = buildModel(data);

    var table = el.querySelector('table');
    if (table && table.classList) table.classList.add('visually-hidden');

    var oldCanvas = el.querySelector('canvas.qm-funnel__canvas');
    if (oldCanvas && oldCanvas.parentNode) oldCanvas.parentNode.removeChild(oldCanvas);
    var oldBtn = el.querySelector('button.funnel__control');
    if (oldBtn && oldBtn.parentNode) oldBtn.parentNode.removeChild(oldBtn);

    var canvas = document.createElement('canvas');
    canvas.className = 'qm-funnel__canvas';
    canvas.style.width = '100%';
    canvas.style.display = 'block';
    canvas.setAttribute('role', 'img');
    canvas.setAttribute('aria-label', ariaSentence(model));
    el.insertBefore(canvas, el.firstChild);

    var f = new Funnel(canvas, model);
    f.start();
    el._qmFunnel = f;
    return f;
  }

  /* 7. Records grid — keep the "record, in numbers" figures in step with the same sanctioned source the funnel reads (funnel-stats.json), so a census update refreshes both surfaces instead of only the canvas. The HTML literals stay as the no-JS fallback; this only overwrites them with the identical values from the JSON when JS is on. */

  function fillRecordsGrid(data) {
    if (!data) return;
    var vals = {
      strategies_tested: data.strategies_tested,
      backtests_completed: data.backtests_completed,
      optimization_census_cells_measured: data.optimization_census_cells_measured,
      gates_total: data.gates_total,
      qualified_pairs_current: data.qualified_pairs_current,
      qualified_pairs_target: data.qualified_pairs_target
    };
    var gs = data.gates || [];
    for (var i = 0; i < gs.length; i++) {
      if (gs[i] && gs[i].id === 'Q08') { vals.q08_strategies_cleared = gs[i].strategies_cleared; break; }
    }
    if (data.live && data.live.closed_positions != null) {
      vals.live_closed_positions = data.live.closed_positions;
    }
    Object.keys(vals).forEach(function (k) {
      var v = vals[k];
      if (v == null || isNaN(+v)) return;         // never blank out a fallback with a bad value
      var nodes = document.querySelectorAll('[data-stat="' + k + '"]');
      for (var j = 0; j < nodes.length; j++) nodes[j].textContent = fmt(v);
    });
  }

  /* 8. Auto-init on DOMContentLoaded */

  function autoInit() {
    var el = document.getElementById('gate-funnel');
    if (!el) return;
    var src = el.getAttribute('data-src') || '/public-data/funnel-stats.json';
    fetch(src, { cache: 'no-cache' })
      .then(function (r) { if (!r.ok) throw new Error('http ' + r.status); return r.json(); })
      .then(function (json) { fillRecordsGrid(json); mount(el, json); })
      .catch(function (e) {
        // Leave the static fallback table + HTML figure literals visible and
        // legible on failure (they already match the sanctioned snapshot).
        if (window.console) console.warn('QMFunnel:', e && e.message);
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', autoInit);
  } else {
    autoInit();
  }

  window.QMFunnel = { mount: mount };
})();
