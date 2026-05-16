// ==UserScript==
// @name         QM Claude Usage Scraper
// @namespace    quantmechanica.com/strategy_farm
// @version      1.0.0
// @description  Scrape claude.ai usage settings page and POST to local VPS receiver (localhost:9090).
// @match        https://claude.ai/settings/usage*
// @match        https://claude.ai/settings/billing*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  const RECEIVER = 'http://127.0.0.1:9090/quota';
  const INTERVAL_MS = 60 * 1000;
  const SOURCE = 'claude';

  function textOf(node) {
    return (node && node.innerText) ? node.innerText.replace(/\s+/g, ' ').trim() : '';
  }

  function scrape() {
    const root =
      document.querySelector('main') ||
      document.querySelector('[role="main"]') ||
      document.body;

    const fullText = textOf(root);

    const matches = {};
    const patterns = [
      ['five_hour_used_pct', /(\d+(?:\.\d+)?)\s*%\s*(?:of\s*)?(?:5[- ]?hour|hourly|hour)/i],
      ['week_used_pct',      /(\d+(?:\.\d+)?)\s*%\s*(?:of\s*)?(?:weekly|week)/i],
      ['opus_used_pct',      /opus[^%]{0,60}(\d+(?:\.\d+)?)\s*%/i],
      ['sonnet_used_pct',    /sonnet[^%]{0,60}(\d+(?:\.\d+)?)\s*%/i],
      ['five_hour_resets',   /(?:5[- ]?hour|hourly)\s*(?:limit\s*)?resets?\s*(?:at|in)?\s*([^.\n]{1,60})/i],
      ['week_resets',        /(?:weekly|week)\s*(?:limit\s*)?resets?\s*(?:at|in|on)?\s*([^.\n]{1,60})/i],
      ['plan_label',         /\b(Free|Pro|Max|Team|Enterprise|Claude\s+Pro|Claude\s+Max)\s*(?:plan|tier)?/i],
    ];
    for (const [key, re] of patterns) {
      const m = fullText.match(re);
      if (m) matches[key] = m.slice(1).join(' ').trim();
    }

    // Snapshot all progress bars / meters with their aria-valuenow + label.
    const meters = [];
    const meterNodes = root.querySelectorAll('[role="progressbar"], progress, meter, [aria-valuenow]');
    for (const m of meterNodes) {
      const valueNow = m.getAttribute('aria-valuenow');
      const valueMax = m.getAttribute('aria-valuemax') || m.max || '100';
      const label =
        m.getAttribute('aria-label') ||
        textOf(m.closest('section,div,li,article')) ||
        '';
      if (valueNow) {
        meters.push({
          value_now: valueNow,
          value_max: valueMax,
          label: label.slice(0, 200),
        });
      }
    }

    // Also dump interesting text nodes mentioning quota/limit/reset.
    const interesting = [];
    const nodes = root.querySelectorAll('div,span,p,li,h1,h2,h3,h4');
    for (const n of nodes) {
      const t = textOf(n);
      if (!t || t.length > 240) continue;
      if (/limit|used|reset|% of|\bof\b\s+\d|window|hourly|weekly|opus|sonnet/i.test(t)) {
        interesting.push(t);
      }
    }

    return {
      url: location.href,
      scraped_at: new Date().toISOString(),
      matches,
      meters,
      interesting: interesting.slice(0, 60),
      full_text_head: fullText.slice(0, 2000),
    };
  }

  function post(payload) {
    const body = JSON.stringify({
      source: SOURCE,
      data: payload,
      scraped_at: payload.scraped_at,
    });
    if (typeof GM_xmlhttpRequest === 'function') {
      GM_xmlhttpRequest({
        method: 'POST',
        url: RECEIVER,
        headers: { 'Content-Type': 'application/json' },
        data: body,
        timeout: 5000,
        onerror: () => console.warn('[QM claude] receiver POST failed'),
      });
    } else {
      fetch(RECEIVER, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
        mode: 'cors',
      }).catch(() => console.warn('[QM claude] receiver fetch failed'));
    }
  }

  function tick() {
    try {
      const data = scrape();
      post(data);
      console.log('[QM claude] posted snapshot', data.matches);
    } catch (e) {
      console.error('[QM claude] scrape error', e);
    }
  }

  setTimeout(tick, 5000);
  setInterval(tick, INTERVAL_MS);
})();
