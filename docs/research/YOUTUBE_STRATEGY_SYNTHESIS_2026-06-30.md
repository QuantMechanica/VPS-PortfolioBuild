# YouTube / book strategy synthesis — Balke + Davey + channel batch-2

**Date:** 2026-06-30 · **Author:** Claude (synthesis) · **Source video analysis:** agy
**Raw inputs:** `D:\QM\strategy_farm\research_charters\{BALKE,DAVEY}_STRATEGIES_2026-06-30.md`,
`CHANNELS_BATCH2_STRATEGIES_2026-06-30.md` · **Reference:** `docs/research/BALKE_RANGE_BREAKOUT_QM5_12700_2026-06-27.md`

Division of labour per OWNER's standing rule: **agy = video-watching only; Claude = all
synthesis.** None of the recommended candidates use grid/martingale (DL-081 not triggered);
all are single-position hard-stop designs. Provenance: rules ≠ copyright (OWNER 06-12) — we
mechanize the *logic*, never copy appendix source verbatim.

---

## TIER 1 — card these (best-first)

### A1. Turnaround Tuesday — index weekly long-only mean-reversion · **TOP PICK**
Slug `balke-turnaround-tuesday`. Equity indices are structurally long-biased; a bearish
Monday creates a short-lived oversold that dip-buyers reverse Tuesday (behavioral calendar
anomaly). **Entry:** long only; Monday close (immediate) *or* Tuesday breakout of Monday
high (DD-reducing) — backtest both; gate Monday bearish + price > daily 200 SMA. **Exit:**
TP ~1.5–2.0% or Monday-high; SL below Monday low (~1.0%); **hard time-exit Tuesday close**.
H1/D1, ~15–35 tr/yr/symbol (very low-freq). Symbols GER40/US30/SPX500/NAS100 (multi-market
default test = 4 cheap candidate sleeves). **Mechanizable as-is.** *Why it earns a slot:*
weekly MR on a calendar clock is **orthogonal** to our intraday index *momentum* sleeves and
12700's FX breakout → very likely corr < 0.3, and index cost (~$4.4/trade) makes gross≈net.
This directly attacks the book's binding constraint (need ~8–12 *uncorrelated* sleeves).

### B1. Commodity Trend / Breakout — Crude & Gold (Donchian+ADX+ATR-trail) · **TOP PICK**
Slug `davey-commodity-trend-breakout`. Buy-stop at 20-bar high / sell-stop at 20-bar low
only when ADX(11) > ~20; symmetric long/short (Davey symmetry rule). **Exit:** stop-and-
reverse on opposite signal; 3.0×ATR(14) volatility trail; time-exit after N flat bars
(simple exits = Davey's robustness finding). D1/120m, ~10–30 tr/yr (low-freq). **Crude
first** (confirm `.DWX` symbol — adds a *new asset class* to an index/gold-heavy book =
top diversification), Gold second (check corr vs 10069/10513 at Q11). **Mechanizable
as-is** (≤3 inputs: lookback, ADX-thresh, ATR-mult).

### A2. Trend Tracer — swing-structure breakout (Crude/Gold) · needs-design
Slug `balke-trend-tracer-swing`. Break of last confirmed swing high/low when structure is
HH/HL; ADX>20–25 filter is the key non-correlation lever. SL beyond protecting swing, RR
2–3 or swing-trail. H4/D1, ~10–40 tr/yr. **Open design choice:** swing detection (ZigZag
settings vs Williams Fractals) + trail rule — pin these (≤2–3 DOF) before carding. Crude
variant = highest diversification.

### B2. Euro Night MR — overnight FX mean-reversion (EURUSD) · needs-design, COST-GATED
Slug `davey-euro-night-mr`. Buy-limit = avg(High,X) − Y·ATR(Z), mirror short; hard SL; TP
via one-shot WFA; entries until 01:00 ET, hard exit 07:00 ET; 105-min bars. Medium-freq FX
→ **same cost-danger zone as pre-optimization 12700**; only card with the 12700 discipline
baked in (widen Y to cut frequency, lift per-trade size). Lower priority than A1/B1.

---

## TIER 2 — hold / conditional
- **A3 Go-Long** (intraday index long-bias): cost-OK but long-only beta likely correlates
  with existing long-side index sleeves → build only if Q11 shows it adds.
- **B3 Euro Day reversal**: same EUR underlying + cost profile as B2 → variant, build only
  if B2 validates and they prove mutually uncorrelated.

## REJECTED (logged so they aren't re-proposed)
- **Ninja Turtle Scalper** (Balke, M1–M15 Donchian FX/Gold): hundreds–thousands tr/yr =
  the textbook high-freq-FX-dies-on-commission trap 12700 was built to escape.
- **Batch-2 grid/zone EAs** — Waka-Waka Gold Scalper, Spectra Zone Scalper: grid/zone-
  recovery, violate the DL-081 1%-basket cap (the T-WIN bounded-grid card already covers
  the *bounded* version of this concept).
- **Code-Trading Genetic-Evolved Indicator**: needs a code-gen pipeline, ML-adjacent,
  overfitting-prone.
- **Iman Categorical Trading**: discretionary state-classification, not deterministically
  codeable.
- **ICT FVG Bot** (Mr CapFree): same imbalance family we already proved has no mechanical
  edge ([silver-bullet finding] — single-entry net-neg all symbols).

## Batch-2 honest verdict
Lower novelty than Balke/Davey. The clean-but-generic baselines (Code-Trading MACD-trend
200EMA+ATR; Balke SMA-20/50-cross+ADX+ATR) are mechanizable but low-edge-expectation
(typical Q04 deaths); de-prioritize vs Tier-1. The one valuable meta-point — "100 EAs on
one account / EA-Studio multi-strategy portfolio" — simply **validates our own portfolio
layer** (it is literally our model); not a card.

---

## Davey METHODOLOGY → gate/process adoptions (highest ROI, ~zero backtest cost)
These improve *selection*, not build volume — the lever the book actually needs.

1. **WFE gate at Q04.** Walk-Forward Efficiency = annualized OOS net ÷ annualized IS net.
   **Pass ≥ 50% (prefer 60–70%), auto-discard < 30%.** Adds a *magnitude* check to the
   current PF-net>1.0 walk-forward pass (catches edges that survive directionally but decay).
2. **Monte-Carlo trade-order shuffle at Q08 → size from 95% worst-case MaxDD.** We already
   hold the full q08 trade stream, so this is free; complements PBO/DSR with a sizing bound.
3. **Bar-perturbation / noise permutation (Q08 robustness).** Edge must survive small price
   noise — catches fits to exact bar prints.
4. **Zero-optimization multi-market baseline (card-promotion gate).** Raw default-param
   logic must show edge across ≥2–3 instruments before optimization — formalizes our
   "fixed card-default params = legit OOS" into a multi-symbol requirement (supports
   building A1×4 indices / B1×2 commodities at once).
5. **≤2–3 optimization inputs + long/short symmetry (prebuild validation).** Fewer DOF =
   fewer Q04 false-passes.
6. **Conservative-friction mandate = hard rejection.** Already partly live via the per-class
   commission table; Davey reinforces making it a hard reject and validates our index/
   commodity preference.
7. **Portfolio correlation cap < 0.3 (Q11/DL-064).** Concrete threshold for the
   anticorrelation layer — also the metric for whether A3 / a 2nd Gold sleeve earns a slot.
8. **Incubation kill-criterion (Q12–Q14).** 6–12mo demo; if live equity drifts below the
   95% Q08-MC band → retire as "not real." Objective kill tied to the MC band.
9. **Random-entry ("Monkey") control (diagnostic).** Random-entry + same-exits version; if
   results match, the *entry has no edge*. Cheap pre-gate sanity check.

---

## Recommended sequencing
1. Adopt methodology #1 (WFE), #4 (multi-market baseline), #7 (corr<0.3) — selection-side,
   route gate-wiring to Codex.
2. Card **A1 Turnaround Tuesday ×4 indices** (best new diversifier, mechanizable as-is).
3. Card **B1 Commodity Trend on Crude** then Gold (new asset class).
4. A2 after the swing-detection design decision; B2 only with 12700 cost-discipline.
5. Feed each survivor through Codex's Round24 admission screen (ops 97e655fe) at Q08.
