---
ea_id: QM5_13036
slug: balke-go-long-regime
type: strategy
strategy_id: YT-BALKE-2026-07_GO-LONG-REGIME
source_id: YT-BALKE-FXBOT-2026-07
source_citation: "René Balke — Fx Bot Trading (2026), Revealing All My Simple Trading Strategies (and Settings) That Made Me €25335, YouTube video hgSq8KVgMLI; transcript-verified extraction: D:/QM/strategy_farm/artifacts/research/4ce26882_balke_go_long_verification_2026-07-07.md."
source_citations:
  - type: video
    citation: "René Balke — Fx Bot Trading. Revealing All My Simple Trading Strategies (and Settings) That Made Me €25335. YouTube, 2026. Video ID hgSq8KVgMLI."
    location: "https://www.youtube.com/watch?v=hgSq8KVgMLI"
    quality_tier: C
    role: primary
  - type: internal_research
    citation: "QM transcript-verified Go-Long dossier (proxy-fetched captions, per-rule timestamps, GAP register, unverified-claims register, TaT cross-check), ticket 4ce26882, 2026-07-07."
    location: "D:/QM/strategy_farm/artifacts/research/4ce26882_balke_go_long_verification_2026-07-07.md"
    quality_tier: B
    role: primary_evidence
  - type: internal_research
    citation: "Earlier agy charter (idealized rule set, superseded where it conflicts with the transcript-verified dossier), BALKE_STRATEGIES_2026-06-30.md Strategy 3."
    location: "D:/QM/strategy_farm/research_charters/BALKE_STRATEGIES_2026-06-30.md"
    quality_tier: C
    role: secondary
sources:
  - "[[sources/YT-BALKE-FXBOT-2026-07]]"
concepts:
  - "[[concepts/equity-index-long-bias]]"
  - "[[concepts/session-window-exposure]]"
  - "[[concepts/trend-regime-gate]]"
  - "[[concepts/time-exit]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [long-only, index-beta-harvest, session-window, time-exit, regime-gated, disaster-stop, single-position, intraday-flat-no-swap]
target_symbols: [NDX.DWX, GDAXI.DWX]
primary_target_symbols: [NDX.DWX]
markets: [NDX.DWX, GDAXI.DWX]
single_symbol_only: true
logical_symbol: QM5_13036_GO_LONG_REGIME_M15
period: M15
timeframes: [M15, D1]
expected_trade_frequency: "One session-long entry per eligible trading day per symbol; the D1 SMA200 regime gate historically leaves roughly 60-70% of days eligible on major indices, so approximately 170 trades/year/symbol."
expected_trades_per_year_per_symbol: 170
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.10
expected_dd_pct: 15.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, news_blackout_firm_windows]
g0_approval_reasoning: "OWNER chat order 2026-07-07 (Balke long-only = quasi index investing; map with 1% daily risk, positive trend regimes only). G0 approval 2026-07-07 (Claude): R1 author live-account claims (€15k→€40k) registered UNVERIFIED in the dossier; tier-C provenance acceptable per QM5_12552/13031 precedent — Q02-Q11 is the judge; R2 fully deterministic (fixed clock times + D1 SMA200 gate + fixed-multiple disaster stop; per-rule transcript timestamps in the dossier); R3 NDX.DWX + GDAXI.DWX in the DWX matrix with M15 real-tick history; R4 no ML, no grid, no martingale — one long position per day, hard stop, time exit."
---

# Balke "Go Long" Regime-Gated Index Day-Exposure (M15 entries, NDX + GDAXI)

## Source

René Balke's live-VPS "Go Long" EA (video hgSq8KVgMLI, transcript-verified 2026-07-07,
ticket 4ce26882): buy the index in the morning, close it flat in the evening, every
trading day — no TP, no SL, no filters ("I do not use the TP I do not use the stop
loss I really just open the position in the morning close it in the evening",
[00:07:40-00:07:47]). Verified session windows (IC Markets server time, GMT+2 winter /
GMT+3 US-DST — the same NY-close convention as Darwinex/DXZ broker time):

- GER40: open 09:05, close 22:55 server time [00:07:11-00:07:15]
- US30 / US Tech: open 10:05, close 23:50 server time [00:07:56-00:08:24]

Entry mode resolved by the dossier: SINGLE entry per day — no accumulation, no
scale-in, no grid [00:06:57-00:07:02].

## Edge thesis

Structural long bias of equity indices (economic growth + inflation pass-through),
harvested intraday-flat so no swap/financing accrues and no weekend/overnight gap is
held. This is beta harvest, not alpha: the honest prior is THIN — a large share of
the equity premium historically accrues overnight (close-to-open), which this window
deliberately excludes. Q02 gross full-history is the acid test; expected_pf 1.10 is
deliberately modest.

## Rules (V5 mechanization)

All times are broker time (GMT+2/+3 NY-close). Signal evaluation on closed M15 bars.

**Regime gate (OWNER 2026-07-07 — deviation from source, see below):**
- Eligible day only if previous D1 close > SMA(200, D1) on the traded symbol.
- Evaluated once per day on the first M15 bar at/after the entry time.

**Entry:**
- NDX.DWX: at the first M15 bar open at/after 10:05 broker time.
- GDAXI.DWX: at the first M15 bar open at/after 09:05 broker time.
- Direction: LONG only. One position per symbol per day (single_position gate);
  no re-entry after any same-day exit.

**Exit (in priority order):**
1. Hard time exit: NDX.DWX flat at 23:50 broker; GDAXI.DWX flat at 22:55 broker.
2. Disaster stop (deviation from source): hard SL at entry_price −
   InpSL_ATR_Mult × ATR(14, D1), default multiplier 2.5 — sized so an SL hit costs
   the full per-trade risk budget; it should fire only on tail days, the time exit
   is the normal exit.
3. Framework Friday-close and news-blackout exits per corset (blackout suppresses
   NEW entries; the framework may flatten per firm-window rules).

**Position sizing:**
- Backtest: RISK_FIXED sized off the SL distance (framework standard).
- Live: RISK_PERCENT = 1.0 (OWNER cap: 1% daily risk; single entry/day means
  per-trade risk == per-day risk).

**No-trade filter:**
- Regime gate (above), news blackout (mandatory, high-impact windows per news
  calendar), and the framework session/holiday guards. No RSI or volatility
  filters (the transcript-verified source has none; the 06-30 charter's RSI>75 /
  ATR filters were idealizations and are NOT part of this card).

Frequency estimate: 170 trades per year per symbol

## Documented deviations from source (all deliberate)

1. **D1 SMA200 regime gate — OWNER order 2026-07-07.** Source trades every day
   unconditionally [00:07:47-00:07:49]. The gate implements "nur in positiven
   Trend-Regimen" and is the card's defining variant. (A gate-off ablation is the
   natural Q02 comparison if the machinery proposes one.)
2. **Disaster stop injected.** Source has no SL — non-compliant with DXZ/FTMO
   daily-loss guards. The 2.5×ATR(14,D1) stop caps tail days at the 1% budget
   while leaving the normal day untouched.
3. **News blackout added** per Edge Lab charter (source has none).
4. **Symbols:** source runs GER40/US30/UStech; we card NDX.DWX + GDAXI.DWX
   (US30→WS30 port possible later; SP500.DWX is backtest-only and deliberately
   not used).

## GAPs / unverified claims (from dossier 4ce26882)

- Author performance claims (€15k deposit → €40k; "profitable last few months")
  are UNVERIFIED marketing claims — registered, not relied upon.
- Video B ("I changed my Go Long Expert Advisor Inputs", I6l-rJ7_h8U) is deleted/
  private — the settings above come from the live-VPS walkthrough in video A only.
- Dossier section-3 timestamps have a known mm:ss formatting quirk; the fetched
  transcript is preserved at docs/ops/youtube-transcripts/hgSq8KVgMLI/ for
  verification.

## Cost & compliance notes

- Intraday-flat ⇒ swap/financing irrelevant — the .DWX tester swap-$0 defect does
  not bias this card (rare honest case).
- Index commission ~$4.4/round-turn: at ~170 trades/yr the cost drag is small but
  Q04 judges it.
- FTMO compatibility: single 1%-risk position per symbol per day fits the
  Σ ≤ 1%/symbol worst-case mandate shape; DXZ book admission would additionally
  face the Q09/Q11 correlation gate against existing long-index sleeves — that
  was the original Tier-2 hold reason and remains the honest risk of this card.
