---
ea_id: QM5_11011
slug: the5ers-pinbar-sr
type: strategy
source_id: 1d445184-7c47-57da-9856-a123682a932d
sources:
  - "[[sources/the5ers-blog]]"
concepts:
  - "[[concepts/pin-bar]]"
  - "[[concepts/support-resistance]]"
  - "[[concepts/reversal]]"
indicators:
  - "[[indicators/swing-high-low]]"
  - "[[indicators/atr-stop]]"
period: H4
g0_status: APPROVED
expected_trades_per_year_per_symbol: 35
last_updated: 2026-05-22
r1_track_record: PASS
r1_reasoning: "Single source_id present (The5ers blog, 1d445184); full URL, title, institution, and update date provided."
r2_mechanical: PASS
r2_reasoning: "Pin-bar geometry, S/R level detection, stop-entry trigger, ATR-based SL, 2R TP, and time exit are all fully mechanical."
r3_data_available: PASS
r3_reasoning: "Target symbols EURUSD/GBPUSD/USDJPY/XAUUSD/GER40 DWX use H4 OHLC and ATR only, all available on DWX."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed candle, ATR, and R-multiple rules; no ML, grid, martingale, or adaptive logic; one position per magic."
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS The5ers URL/title cited; R2 PASS mechanical H4 pin-bar S/R stop-entry/exits with plausible 35 trades/year/symbol; R3 PASS OHLC/ATR levels testable on DWX FX/gold/index; R4 PASS fixed non-ML one-position rules."
---

# The5ers Pin Bar Support Resistance Stop Entry

## Quelle
- Source: [[sources/the5ers-blog]]
- Article: "Follow The Money With The Forex Pin Bar Pattern"
- URL: https://the5ers.com/forex-pin-bar/
- Author / institution: The5ers Team
- Date shown: Updated June 21, 2020, 11:38 AM.
- Source location: The article defines a pin bar as a candle with a long tail and short body, says the tail should cover more than 70% of the candle, requires support/resistance context, and gives buy-stop/sell-stop, opposite-tail stop, 2R target, and max-risk guidance.

## Mechanik

Period: H4. Source recommends 1H, 4H, 1D, and 1W; H4 is the default balance of signal quality and frequency.

### Entry
On each closed H4 bar:

1. Define support as the most recent confirmed swing low touched or approached by price at least twice in the last 120 bars within `0.50 * ATR(H4, 14)`.
2. Define resistance symmetrically from confirmed swing highs.
3. Bullish pin bar:
   - Candle range >= `0.75 * ATR(H4, 14)`.
   - Lower wick >= 70% of candle range.
   - Body <= 25% of candle range.
   - Candle low touches support within `0.50 * ATR(H4, 14)`.
   - Place buy stop at pin-bar high plus `0.10 * ATR(H4, 14)`; valid for 3 H4 bars.
4. Bearish pin bar:
   - Candle range >= `0.75 * ATR(H4, 14)`.
   - Upper wick >= 70% of candle range.
   - Body <= 25% of candle range.
   - Candle high touches resistance within `0.50 * ATR(H4, 14)`.
   - Place sell stop at pin-bar low minus `0.10 * ATR(H4, 14)`; valid for 3 H4 bars.
5. No position is open under this magic.

### Exit
- Primary TP: 2.0R, matching the source's initial target at 2x risk.
- Cancel pending stop entry if not filled within 3 H4 bars.
- Signal exit: close if price closes back through the pin-bar midpoint after entry.
- Time stop: close after 20 H4 bars.

### Stop Loss
- Long: below bullish pin-bar low by `0.10 * ATR(H4, 14)`.
- Short: above bearish pin-bar high by `0.10 * ATR(H4, 14)`.

### Position Sizing
P2: fixed $1,000 risk based on initial SL distance. Live: `RISK_PERCENT` per HR4. Source says not to risk more than 1.5% per trade; live sizing must remain inside framework risk limits.

### Zusaetzliche Filter
- Reject pin bars whose total range exceeds `3.0 * ATR(H4, 14)` to avoid extreme news spikes.
- Support/resistance level must be at least 10 bars old.
- Skip entries in framework news blackout windows.
- One position per magic; no pyramiding.
- P3 sweep candidates: wick share `{0.67, 0.70, 0.75}`, level tolerance `{0.25, 0.50, 0.75} * ATR`, pending validity `{2, 3, 5}` bars.

## Target symbols
EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX. The source states the pin bar works on forex pairs and multiple timeframes; implementation uses OHLC-only candle and level rules.

## Concepts
- [[concepts/pin-bar]] - primary
- [[concepts/support-resistance]] - secondary
- [[concepts/reversal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | UNKNOWN | The5ers Team article with full URL, title, institution, and visible update date. |
| R2 Mechanical | UNKNOWN | Source provides candle definition, support/resistance context, stop-entry trigger, SL, and 2R target; level detection and buffers are deterministic research fills. |
| R3 Data Available | UNKNOWN | Uses H4 OHLC, ATR, and swing-derived support/resistance available on DWX symbols. |
| R4 ML Forbidden | UNKNOWN | Fixed candle, level, ATR, and 2R rules; no ML, grid, martingale, online adaptation, or multi-position logic. |

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from The5ers blog third batch.

## Verwandte Strategien
- [[strategies/QM5_11009_the5ers-double-trigger]] - related support/resistance reversal logic with structural confirmation.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD

## Build-EA Notes
- Implement pending stop orders only if the framework allows pending-order mode; otherwise simulate stop-entry by entering at market after a closed bar confirms the stop level was crossed.
- Candle-body and wick calculations must handle bullish and bearish candle bodies symmetrically.
