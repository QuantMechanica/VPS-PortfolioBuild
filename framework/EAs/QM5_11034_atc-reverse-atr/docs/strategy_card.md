---
ea_id: QM5_11034
slug: atc-reverse-atr
type: strategy
source_id: 9441393d-5ffc-5b43-87be-bd532110f204
source_citation: "Andrei Moraru, Interview with Andrei Moraru (ATC 2011), MQL5 Articles, 2011-10-25, https://www.mql5.com/en/articles/543"
sources:
  - "[[sources/mql5-automated-trading-championship]]"
concepts:
  - "[[concepts/reversal]]"
  - "[[concepts/trailing-stop]]"
indicators:
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, EURJPY.DWX, GBPUSD.DWX, GBPJPY.DWX]
period: H1
expected_trade_frequency: "Always-alternating direction after each closed position, ATR trailing exit; conservative estimate 25-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URL present; R2 deterministic opposite-previous-direction entries and ATR trailing exits mechanical with plausible 25-80 trades/year/symbol; R3 FX DWX testable; R4 fixed non-ML one-position rules."
---

# Previous Direction Reversal With ATR Trail

## Quelle
- Source: [[sources/mql5-automated-trading-championship]]
- URL: https://www.mql5.com/en/articles/543
- Author / institution: Andrei Moraru, MQL5 Articles / Automated Trading Championship 2011
- Date: 2011-10-25
- Location: interview section describing current EA differences and ATR use

## Mechanik

### Entry
- Maintain last closed direction per symbol/magic.
- Initial direction is deterministic input: `initial_direction` = long or short.
- On flat state after a closed trade:
  - If last closed direction was long, open short on the next completed H1 bar.
  - If last closed direction was short, open long on the next completed H1 bar.
- No indicator determines entry; the edge is alternating exposure after the prior trade cycle.
- Do not open if a position is already active for this symbol/magic.

### Exit
- Use ATR-based trailing stop.
- For long positions, trail stop at highest close since entry - `atr_trail_mult` * ATR(`atr_period`).
- For short positions, trail stop at lowest close since entry + `atr_trail_mult` * ATR(`atr_period`).
- Optional hard disaster SL at `hard_sl_atr` * ATR from entry.

### Stop Loss
- P2 baseline: hard SL = 3.0 * ATR(14, H1).
- Trailing stop = 2.0 * ATR(14, H1).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Fixed position volume/risk only.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Trade only after at least `cooldown_bars` bars since previous close.
- Spread <= symbol median spread * 2.
- Optional minimum ATR percentile filter: ATR(14) above 30th percentile of last 250 H1 bars.

## Concepts
- [[concepts/reversal]] - next trade direction is opposite of the previous position.
- [[concepts/trailing-stop]] - ATR controls trailing stop distance.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 article URL with named participant Andrei Moraru. |
| R2 Mechanical | PASS | Source discloses opposite-of-previous-position entry, ATR-only indicator use, trailing stop, and fixed volume. |
| R3 DWX-testbar | PASS | Uses trade-state and ATR on FX symbols available or portable to DWX. |
| R4 No ML | PASS | Fixed parameters, fixed risk, one active position, no adaptive learning or grid. |

## R3
Primary P2 basket: EURUSD.DWX, EURJPY.DWX, GBPUSD.DWX, GBPJPY.DWX.

## Author Claims
- The source says the EA enters in the direction different from the previous position.
- The source says the first position direction was assigned manually.
- The source says ATR is the only indicator and is used to determine trailing-stop size.

## Parameters To Test
- Timeframe: M30, H1, H4.
- Initial direction: long, short.
- ATR period: 14, 21, 34.
- ATR trail multiple: 1.5, 2.0, 2.5, 3.0.
- Hard SL ATR: disabled, 2.5, 3.0, 4.0.
- Cooldown bars: 0, 1, 3.
- Minimum ATR percentile: disabled, 30, 50.

## Initial Risk Profile
This is a sparse reversal/alternation system with weak directional forecasting. Risk depends heavily on trailing-stop behavior and is bounded by hard SL, fixed risk, and one active position per symbol/magic.

## Pipeline-Verlauf
- G0: PENDING.
