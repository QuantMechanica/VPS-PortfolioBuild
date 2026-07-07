---
ea_id: QM5_13031
slug: wayward-bbrsi-stopmr
type: strategy
strategy_id: YT-CAPFREE-WAYWARD-2026-07_BBRSI-STOPMR
source_id: YT-CAPFREE-WAYWARD-2026-07
source_citation: "Mr. CapFree (2026), The Wayward Trading Bot... The Wait Is OVER!! (Full Code), YouTube video mtWN6oPIi1Y; full-transcript extraction with timestamps: D:/QM/strategy_farm/artifacts/research/71235187_wayward_bot_full_extraction_2026-07-07.md."
source_citations:
  - type: video
    citation: "Mr. CapFree. The Wayward Trading Bot... The Wait Is OVER!! (Full Code). YouTube, 2026. Video ID mtWN6oPIi1Y."
    location: "https://www.youtube.com/watch?v=mtWN6oPIi1Y"
    quality_tier: C
    role: primary
  - type: internal_research
    citation: "QM full-transcript extraction dossier (proxy-fetched captions, per-rule timestamps, GAP list, unverified-claims register), ticket 71235187, 2026-07-07."
    location: "D:/QM/strategy_farm/artifacts/research/71235187_wayward_bot_full_extraction_2026-07-07.md"
    quality_tier: B
    role: primary_evidence
sources:
  - "[[sources/YT-CAPFREE-WAYWARD-2026-07]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/bollinger-stretch]]"
  - "[[concepts/momentum-exhaustion]]"
  - "[[concepts/stop-order-confirmation-entry]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
strategy_type_flags: [mean-reversion, bb-stretch, rsi-exhaustion, stop-order-rebound-entry, pending-order-trail, atr-hard-stop, atr-trailing-stop, session-window, intraday-scalper, ftmo-sprint-mandate]
target_symbols: [XAUUSD.DWX, NDX.DWX]
primary_target_symbols: [XAUUSD.DWX]
markets: [XAUUSD.DWX, NDX.DWX]
single_symbol_only: true
logical_symbol: QM5_13031_BBRSI_STOPMR_M15
period: M15
timeframes: [M15]
expected_trade_frequency: "M15 mean-reversion scalper; triple filter (candle-size vs slow ATR, BB stretch, RSI exhaustion) plus single-position gate; estimate roughly 2-4 entries/week/symbol in normal vol, i.e. approximately 120 trades/year/symbol; pending orders that never fill reduce realized fills below signal count."
expected_trades_per_year_per_symbol: 120
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.15
expected_dd_pct: 12.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, news_blackout_firm_windows, commission_high_frequency]
g0_approval_reasoning: "OWNER FTMO-sprint mandate (decisions/2026-07-06_ftmo_scalping_grid_mandate.md) G0 approval 2026-07-07 (Claude): R1 video shows the full build with author tester run (claims registered as UNVERIFIED in the extraction dossier; acceptable tier-C provenance per QM5_12552 precedent — Q02-Q11 is the judge); R2 fully deterministic rule set extracted with per-rule transcript timestamps; R3 XAUUSD.DWX and NDX.DWX in the DWX matrix with M15 real-tick history; R4 no ML, no grid, no martingale — single position, hard ATR stop."
---

# Wayward BB+RSI Stop-Order Mean-Reversion Scalper (M15, XAU + NDX)

## Source

- Primary: Mr. CapFree, "The Wayward Trading Bot... The Wait Is OVER!! (Full
  Code)", YouTube video mtWN6oPIi1Y. Full code walkthrough on screen.
- Evidence: full-transcript extraction with per-rule timestamps, GAP register
  and unverified-claims register:
  `D:/QM/strategy_farm/artifacts/research/71235187_wayward_bot_full_extraction_2026-07-07.md`
  (ticket 71235187; captions proxy-fetched after direct access was blocked).
- Author performance claims ($1k to ~$2M tester run [01:14], "no running
  drawdowns" [00:57]) are UNVERIFIED and play no role in this card's case;
  the pipeline decides.

## Hypothesis

When a single M15 bar is abnormally large relative to a slow volatility
baseline AND price stretches beyond the outer Bollinger Band with RSI at an
exhaustion extreme, the move is disproportionately likely to snap back toward
the band mean. Entering via a stop order placed back toward the mean (rather
than at market) requires the reversal to begin before risk is taken —
filtering out continuation moves ("falling knife" protection, video [17:48]).
Index CFDs and gold are the mandate-preferred venue because round-trip
commission is small relative to the M15 profit unit (FX scalping is
commission-dead per the QM cost model).

## Market universe and timeframe

- Symbols: XAUUSD.DWX (primary), NDX.DWX. Per-symbol EA instances, no basket.
- Timeframe: M15 signal bar (literal token: M15). All indicator computations
  on closed M15 bars.

## Entry

All conditions evaluated once per new M15 bar on the last CLOSED bar
(index 1) — deliberate V5 deviation from the video's index-0 tick loop, which
the extraction dossier flags as repainting [GAP 3].

Indicators: Bollinger Bands(period=20, deviation=2.0, close) [10:09];
RSI(period=14, close) [10:22]; ATR(period=1000) as slow volatility baseline
("thousand ATR to smooth it") [10:29].

1. Candle-size filter [15:52]: (high[1] - low[1]) > ATR[1] * atr_multiplier
   (default 1.0).
2. Stretch + exhaustion, long setup [16:15, 16:22]: close[1] < lower_band[1]
   AND RSI[1] < 50 - rsi_filter (default rsi_filter=30, i.e. RSI < 20).
3. Stretch + exhaustion, short setup [16:50, 16:56]: close[1] > upper_band[1]
   AND RSI[1] > 50 + rsi_filter (i.e. RSI > 80).
4. Entry mechanism [24:38, 25:33]: no market entry. Long setup places a
   BUY STOP at ask + ATR * order_distance_atr (default 0.2); short setup
   places a SELL STOP at bid - ATR * order_distance_atr.
5. Pending-order trail [32:09-32:56]: while the pending is unfilled, if the
   recomputed entry level moves favorably (buy-stop: new level below current
   order price; sell-stop: above), modify the order to the new level with SL
   re-anchored at the same ATR distance.
6. Single-exposure gate [33:49]: no new order while any position OR pending
   of this EA exists on the symbol (order_positions_total == 0).
7. Spread gate [25:15]: send/hold orders only while (ask - bid) <
   max_spread_points * point (per-symbol input; default 10 points must be
   re-based per symbol at build: gold and NDX use wider absolute caps than
   the video's FX-scale default — set from median DWX spread * 2).

## Exit

- Initial stop loss [25:07]: entry -/+ ATR * sl_atr (default 2.0).
- Take profit [25:28]: Bollinger middle band value at signal time (static at
  placement; not updated afterward — faithful to source).
- Trailing stop [28:10, 30:53]: distance ATR * trailing_sl_atr (default 0.2),
  moved only in the favorable direction AND only once beyond entry price
  (profit lock-in only); respects broker SYMBOL_TRADE_STOPS_LEVEL [29:17].
- Session exit: outside [start_hour, end_hour) delete pendings AND flatten
  open positions — deliberate V5 correction of the source's session-exit leak
  (extraction dossier GAP 5: video deletes pendings only [28:21]).
- Framework Friday close and news-window handling apply on top (Manage/Exit
  ordered before the news gate per the 2026-07-02 audit rule).

## Risk and sizing

- RISK_FIXED for backtests, RISK_PERCENT for live (V5 hard rule replaces the
  video's calc_lots variants; the video's own default was 2% of balance
  [19:10]).
- FTMO mandate cap: single position with a hard ATR stop at all times, so the
  worst case per symbol equals the per-trade risk percent. Live risk_percent
  MUST be set <= 1.0 so the total per-symbol worst case stays within the
  OWNER mandate (decisions/2026-07-06_ftmo_scalping_grid_mandate.md). No
  scale-in, no averaging, no grid in this card.
- Expected drawdown class: medium; MR scalper loses in strong trend regimes.

## Filters

- Session window inputs start_hour/end_hour (defaults at build: 07:00-19:00
  broker time, i.e. liquid EU+US hours; calm-session MR on index off-hours is
  a possible v2, not this card).
- News: framework news filter active (FTMO firm-window compliance axis
  included for the live track).
- Spread gate as in Entry rule 7.

## Falsification

- Q02 gross full-history (2017-2025) PF < 1.20 at the card frequency floor
  kills the family — no parameter rescue beyond the card's stated defaults
  plus the standard Q03 trial grid.
- Q04 walk-forward with commission: if net fold PF collapses on NDX but not
  XAU (or vice versa), keep the surviving symbol only — the mechanism is
  per-symbol.
- If fills are dominated by trailing-pending chases (fill rate < ~25% of
  signals), the stop-entry mechanic is not adding its claimed value here;
  treat as structural failure, not a tuning target.

## Q08-Q11 risks

- 8.4 regime dependence: MR scalpers die in sustained trends; expect soft-gate
  pressure there rather than at 8.9 frequency (this card is high-frequency by
  QM standards).
- DL-072 cost cushion: gross expectancy per trade must clear 2x worst-case
  commission; on XAU/NDX the commission unit is small but the M15 profit unit
  is also small — this is the card's most likely honest killer.
- Q09: intraday XAU MR should be near-orthogonal to the D1 swing book; NDX MR
  overlaps conceptually with nothing currently admitted.
- Tick-model sensitivity: stop entries + tight trails are fill-model
  sensitive; Model 4 real-tick only (standard), and Q10/Q11 confirmation
  matters more than usual.

## Implementation notes

- V5 framework build; closed-bar evaluation via IsNewBar on M15; set
  QM_EntryRequest.symbol_slot explicitly (build rule 2026-07-05).
- Pending-order management (place/trail/delete) uses the framework trade
  context (filling-mode resolver, magic scoping); one pending OR one position
  max at any time.
- ATR period 1000 is intentional (slow baseline; on M15 about 10 trading
  days) — do not "fix" it to 14; it normalizes candle-size, order-distance,
  SL and trail units [10:29].
- TP at the middle band captured at signal time; do not re-target after
  placement.
- Deliberate deviations from source (all documented above): closed-bar
  signals, session flatten includes positions, framework sizing/news/Friday
  handling. Everything else stays faithful to the extraction dossier;
  on-screen-only details are marked GAP there and resolved here by explicit
  card defaults, not guesses.
- Inputs (build defaults): bb_period=20, bb_deviation=2.0, rsi_period=14,
  rsi_filter=30, atr_period=1000, atr_multiplier=1.0, sl_atr=2.0,
  trailing_sl_atr=0.2, order_distance_atr=0.2, max_spread_points (per
  symbol), start_hour=7, end_hour=19.
