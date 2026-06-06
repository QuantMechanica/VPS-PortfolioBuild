---
ea_id: QM5_10922
slug: grimes-kc-fade
type: strategy
source_id: fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
source_citation: "Adam H. Grimes, A shift in perspective, 2019-03-04, https://www.adamhgrimes.com/a-shift-in-perspective/; How I Trade (part 2/2), 2023-11-06, https://www.adamhgrimes.com/how-i-trade-part-2-2/"
sources:
  - "[[sources/adam-grimes-blog]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/keltner-extension]]"
indicators:
  - "[[indicators/keltner-channel]]"
  - "[[indicators/atr]]"
  - "[[indicators/ema]]"
target_symbols: [SP500.DWX, NDX.DWX, GER40.DWX, XAUUSD.DWX]
period: H4
expected_trade_frequency: "Keltner outside-band exhaustion fade on H4; conservative estimate 12-30 trades/year/symbol."
expected_trades_per_year_per_symbol: 18
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 source URLs cited; R2 deterministic H4 Keltner fade entry/exit with plausible 12-30 trades/year/symbol; R3 DWX indices/metals testable with SP500 T6 caveat; R4 fixed non-ML one-position rules."
---

# Grimes Keltner Extension Fade

## Quelle
- Source: [[sources/adam-grimes-blog]]
- Citation: Adam H. Grimes, "A shift in perspective", 2019-03-04, https://www.adamhgrimes.com/a-shift-in-perspective/
- Supplemental: Adam H. Grimes, "How I Trade (part 2/2)", 2023-11-06, https://www.adamhgrimes.com/how-i-trade-part-2-2/
- Source location: The Keltner article frames outside-band events as unusual and asks what happens after the market goes outside the band, with moving-average slope as a context variable. The "How I Trade" post says overextension suggests the dominant group may be out of ammunition and the next move may be back against the big move.

## Mechanik

### Entry
- Evaluate on H4 close.
- Keltner channel:
  - Midline = EMA(20).
  - Upper = EMA(20) + 2.25 * ATR(20).
  - Lower = EMA(20) - 2.25 * ATR(20).
- Short fade:
  - Prior bar closes above the upper Keltner channel.
  - Distance from Close to EMA(20) >= 2.25 * ATR(20).
  - EMA(20) slope over 5 bars is flat or negative, or current bar closes back inside the channel.
  - Trigger: enter short when Close crosses back below the upper channel within 3 bars of the outside-band close.
- Long fade mirrors the short fade below the lower channel.

### Exit
- Target 1 = EMA(20) touch.
- Fallback target = 1.25R if EMA touch occurs beyond 1.25R.
- Time exit after 8 H4 bars.

### Stop Loss
- Short stop = highest high since outside-band event + 0.20 * ATR(20).
- Long stop = lowest low since outside-band event - 0.20 * ATR(20).
- Reject if stop distance is > 3.0 * ATR(20).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default percent risk if approved.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Do not take fades when the last 5 closes all remain outside or touching the same channel band; that is `grimes-slide` territory.
- Spread cap = 10% of stop distance.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/keltner-extension]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and full article URLs are cited. |
| R2 Mechanical | PASS | Source gives outside-band and overextension/reversion logic; card fixes channel, slope, trigger, stop, and exit rules. |
| R3 DWX-testbar | PASS | OHLC/Keltner/ATR rules are testable on DWX index CFDs and metals; SP500.DWX is backtest-only. |
| R4 No ML | PASS | Fixed channel fade; no ML, online adaptation, adding-to-losers, grid, or martingale. |

## R3
Primary P2 basket: SP500.DWX, NDX.DWX, GER40.DWX, XAUUSD.DWX.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10918_grimes-slide]] - opposite treatment of repeated band pressure; this card fades isolated outside-band events only.
- [[strategies/QM5_10919_grimes-overshoot]] - both are reversals, but this card requires only channel extension/re-entry, not mature-trend climax.

## Lessons Learned
- TBD during pipeline run.
