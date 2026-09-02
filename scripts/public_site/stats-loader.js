/**
 * Populate public KPI elements from the schema-validated public snapshot.
 * The small stats sidecar and legacy /data file are compatibility fallbacks.
 */
(function() {
  const snapshotPath = '/public-data/public-snapshot.json';
  const statsPath = '/public-data/stats.json';
  const fallbackStatsPath = '/data/stats.json';

  function formatNumber(value) {
    return typeof value === 'number' ? value.toLocaleString('en-US') : value;
  }

  function normalizeSnapshot(data) {
    if (!data || !data.pipeline) return null;
    const gateCounts = data.pipeline.by_gate_v4 || {};
    const phases = Object.keys(gateCounts).filter(key => /^Q\d{2}$/.test(key)).length;
    return {
      eas_compiled: data.pipeline.eas_built,
      strategy_cards: data.pipeline.strategy_cards,
      backtests_total: data.pipeline.work_items_total,
      phases
    };
  }

  async function fetchJson(path) {
    const response = await fetch(path);
    if (!response.ok) throw new Error(`${path} returned ${response.status}`);
    return response.json();
  }

  function updateElements(stats) {
    if (!stats) return;
    document.querySelectorAll('[data-stat]').forEach(element => {
      const key = element.getAttribute('data-stat');
      if (stats[key] === undefined) return;
      const value = stats[key];
      if (element.hasAttribute('data-target')) {
        element.setAttribute('data-target', value);
      } else {
        element.textContent = formatNumber(value);
      }
    });

    document.querySelectorAll('[data-stat-template]').forEach(element => {
      let text = element.getAttribute('data-stat-template');
      for (const [key, value] of Object.entries(stats)) {
        text = text.replace(new RegExp(`{${key}}`, 'g'), formatNumber(value));
      }
      element.textContent = text;
    });
  }

  function updateMetaTags(stats) {
    if (!stats) return;
    document.querySelectorAll('meta[data-stat-content]').forEach(meta => {
      let content = meta.getAttribute('data-stat-content');
      for (const [key, value] of Object.entries(stats)) {
        content = content.replace(new RegExp(`{${key}}`, 'g'), formatNumber(value));
      }
      meta.setAttribute('content', content);
    });
  }

  async function loadStats() {
    try {
      let stats = null;
      try {
        stats = normalizeSnapshot(await fetchJson(snapshotPath));
      } catch (snapshotError) {
        console.warn('QuantMechanica: public snapshot unavailable', snapshotError);
      }

      try {
        const sidecar = await fetchJson(statsPath);
        stats = { ...(stats || {}), ...sidecar };
      } catch (sidecarError) {
        if (!stats) stats = await fetchJson(fallbackStatsPath);
      }

      updateElements(stats);
      updateMetaTags(stats);
    } catch (error) {
      console.warn('QuantMechanica: Could not load public statistics', error);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadStats);
  } else {
    loadStats();
  }
})();
