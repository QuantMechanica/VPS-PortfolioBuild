// ==UserScript==
// @name         QM Codex Usage Scraper
// @namespace    quantmechanica.com/strategy_farm
// @version      1.0.0
// @description  Scrape Codex Cloud analytics page and POST to local VPS receiver (localhost:9090).
// @match        https://chatgpt.com/codex/cloud/settings/analytics*
// @match        https://chatgpt.com/codex/settings/analytics*
// @match        https://chatgpt.com/codex/*analytics*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  const RECEIVER = 'http://127.0.0.1:9090/quota';
  const INTERVAL_MS = 60 * 1000;
  const SOURCE = 'codex';

  function textOf(node) {
    return (node && node.innerText) ? node.innerText.replace(/\s+/g, ' ').trim() : '';
  }

  // Collect every visible number near a "used"/"limit"/"reset"/"hour"/"week" keyword.
  // Codex DOM is React-rendered and class names rotate, so we use the rendered text as ground truth.
  function scrape() {
    const root =
      document.querySelector('main') ||
      document.querySelector('[role="main"]') ||
      document.body;

    const fullText = textOf(root);

    // Heuristic key/value extraction from rendered text.
    const matches = {};
    const patterns = [
      ['hour_used_pct',   /(\d+(?:\.\d+)?)\s*%\s*(?:of\s*)?(?:5[- ]?hour|hourly|hour)/i],
      ['week_used_pct',   /(\d+(?:\.\d+)?)\s*%\s*(?:of\s*)?(?:weekly|week)/i],
      ['hour_used_raw',   /(\d{1,3}(?:,\d{3})*|\d+)\s*(?:\/|of)\s*(\d{1,3}(?:,\d{3})*|\d+)\s*(?:tokens|messages|requests)?\s*(?:in\s*the\s*last\s*5\s*hours|5h|5-hour|hourly)/i],
      ['week_used_raw',   /(\d{1,3}(?:,\d{3})*|\d+)\s*(?:\/|of)\s*(\d{1,3}(?:,\d{3})*|\d+)\s*(?:tokens|messages|requests)?\s*(?:this\s*week|weekly|7-?day)/i],
      ['resets_at_hour',  /(?:resets?|next\s*window|refreshes?)[^.]*?(\d{1,2}:\d{2}\s*(?:AM|PM)?(?:\s*[A-Z]{2,4})?)/i],
      ['resets_at_week',  /(?:weekly\s*resets?|next\s*weekly)[^.]*?([A-Z][a-z]{2,8}\s+\d{1,2})/i],
    ];
    for (const [key, re] of patterns) {
      const m = fullText.match(re);
      if (m) matches[key] = m.slice(1).join(' ');
    }

    // Also dump every <span>/<div> that mentions "limit", "used", "reset", "% of"
    const interesting = [];
    const nodes = root.querySelectorAll('div,span,p,li');
    for (const n of nodes) {
      const t = textOf(n);
      if (!t || t.length > 240) continue;
      if (/limit|used|reset|% of|\bof\b\s+\d|window|hourly|weekly/i.test(t)) {
        interesting.push(t);
      }
    }

    return {
      url: location.href,
      scraped_at: new Date().toISOString(),
      matches,
      interesting: interesting.slice(0, 40),
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
        onerror: () => console.warn('[QM codex] receiver POST failed'),
      });
    } else {
      fetch(RECEIVER, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
        mode: 'cors',
      }).catch(() => console.warn('[QM codex] receiver fetch failed'));
    }
  }

  function tick() {
    try {
      const data = scrape();
      post(data);
      console.log('[QM codex] posted snapshot', data.matches);
    } catch (e) {
      console.error('[QM codex] scrape error', e);
    }
  }

  // First tick after page settles, then every minute.
  setTimeout(tick, 5000);
  setInterval(tick, INTERVAL_MS);
})();
