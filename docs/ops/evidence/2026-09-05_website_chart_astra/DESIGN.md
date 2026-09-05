# Astra chart study 01

Task `56d1f4a1-199b-4884-8e91-39cb41a469df`. Independent design for OWNER comparison; REVIEW only. All deliverables are confined to this evidence folder and committed on canonical `agents/board-advisor` under the scheduled cycle's explicit rule. Website/deploy files were read only; Claude's v2 renderer was not read or copied.

The design gives the price action priority: white plotting surfaces, hairline scales, compact terminal legends, a 68% candle body/slot ratio and thin wicks. Volume occupies a separate lower strip. Session labels use separate rows so overlapping London/NY windows stay legible. Muted EMA and Bollinger lines remain subordinate to candles. The equity panel uses the identical palette and draws every supplied point without smoothing; pale red gaps from the running peak reveal drawdowns.

| Role | Colour |
|---|---|
| Plot / surrounding panel | `#ffffff` / `#f5f6f7` |
| Text / scale / grid | `#26323d` / `#84909b` / `#edf0f2` |
| Rising / falling candles | `#168775` / `#cc625d` |
| EMA 20 / EMA 50 / Bollinger | `#557eae` / `#b38c4c` / `#92a5b7` |

**Calibration.** Read-only 2022–2024 export aggregates provide return dispersion, median ranges and gap sizes: EURUSD H1 18,614 bars; gold D1 771; NDX D1 772. `calibration.json` binds each source hash and aggregate. Only aggregate parameters enter the generator; no historical OHLC samples are embedded. A seeded stochastic volatility process, changing drift, session activity, varying body/wick extensions and range-linked volume produce the displayed paths. Intraday opens are continuous; modest daily session gaps use the calibrated gap scale. The three short displayed samples have return dispersion approximately 0.083%, 0.588% and 1.228%, respectively. These are illustrative samples, not a distribution-fit claim or a reconstructed market episode. Gold's three phases and sweep are intentionally staged for explanation.

**Data and API.** `window.QMChartsAstra.candles(element, {instrument,tf,seed,bars,overlays,sessions,height})` and `.equity(element,{series,height})` return a redraw/destroy handle. Candles expose their generated bars; equity requires the supplied data rather than silently substituting synthetic performance. `hero-equity.json` is an exact copy of the 471-point, 24-sleeve combined backtest (2017–2025), SHA-256 `5dfeb456603dadbdef093d845cf8b8267d2935df349fe8208bbbd90e690692ce`. `style.css` is the unchanged site stylesheet. Canvas uses device-pixel scaling and ResizeObserver. All rendering is static, including reduced-motion mode; pointer inspection changes the OHLC legend and crosshair. Canvas accessible labels identify synthetic prices and backtest provenance.

**Verification and limits.** Headless Chrome renders at 1400 and 420 CSS pixels show all four charts; mobile is a full-height capture so no chart is omitted. At DPR 1 and 2 with reduced motion, all canvases contain drawn pixels, OHLC invariants hold, the page has no horizontal overflow or script errors, and all 471 equity points are retained. `verification.json` records measurements. `node --check` passed. The browser preview must be served over HTTP for the local equity fetch. Fonts use the local system fallback when Inter is absent. Holidays, DST/session calendars and exact tick microstructure are not modelled; EMA warm-up starts at the first synthetic close. The chart remains explanatory artwork, not a backtest, trade signal or evidence that any strategy earns a profit. The OWNER still decides whether the aggregate performance curve is suitable for publication.

Preview: `python -m http.server 8768 --bind 127.0.0.1 --directory C:/QM/repo/docs/ops/evidence/2026-09-05_website_chart_astra`, then open `http://127.0.0.1:8768/preview.html`. This task does not publish the concept.
