---
ea_id: QM5_11592
slug: robo-3candle-fade-h4
type: strategy
source_id: ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
source_title: "RoboForex Strategy Collection — 40+ Mechanical Forex Strategies"
source_author: RoboForex educational team
source_year: 2020
source_citation: "RoboForex Strategy Collection, 2020, p.107, Strategy Three Candles, https://roboforex.com/beginners/analytics/forex-forecast/technical-analysis/"
sources:
  - "[[sources/roboforex-strategy-collection]]"
concepts:
  - "[[concepts/consecutive-close-exhaustion]]"
  - "[[concepts/mean-reversion]]"
indicators: []
period: H4
target_symbols: [EURUSD.DWX, GBPUSD.DWX]
expected_trade_frequency: "Three consecutive H4 closes occur regularly; one-position and exit gates bound realized frequency."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-31
g0_approval_reasoning: "Existing OWNER-governed approval retained from D:/QM/strategy_farm/artifacts/cards_approved/QM5_11592_robo-3candle-fade-h4.md. R1 institutional RoboForex source with page-level citation; R2 deterministic consecutive-close structure; R3 DWX H4 history for EURUSD and GBPUSD; R4 fixed non-learning rules with one position per magic."
---

# QM5_11592 RoboForex Three-Candle Fade H4

## Hypothesis

A sequence of three strictly higher or lower H4 closes is a short-horizon
price extension. Fading the completed run may capture mean reversion before a
new directional leg forms. The thesis is deliberately narrow: the signal is
closed-price structure, not a derived oscillator, prediction model, or
parameter-adaptive rule.

Source citation: RoboForex educational team, *RoboForex Strategy Collection*
(2020), page 107, “Strategy Three Candles.” The pre-existing governed artifact
records R1–R4 as PASS; this branch copy repairs its legacy numeric `ea_id` and
missing schema headings without changing the approved mechanics.

## Rules

### Universe and cadence

- Run one independent instance on `EURUSD.DWX` or `GBPUSD.DWX`.
- H4 only; read completed bars.
- One position per symbol/magic.
- Expected trades per year per symbol: 80 before overlapping-position, news,
  spread, and Friday gates.

### Entry

- Long when `Close[1] < Close[2] < Close[3] < Close[4]`.
- Short when `Close[1] > Close[2] > Close[3] > Close[4]`.
- Enter at market on the next H4 bar after framework, news, spread, and
  Friday-entry clearance.

### Exit and trade management

- Initial stop: `2.0 * ATR(14,H4)`.
- Initial target: `2.5 * ATR(14,H4)`, matching the source’s approximate
  `50/40` reward/risk ratio.
- Trail by `2.0 * ATR(14,H4)`.
- Exit a long after a completed three-close rally and a short after a
  completed three-close decline.
- Framework Friday close remains enabled.

### Risk

- Backtest setfiles: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No grid, martingale, pyramiding, external feed, or adaptive sizing.

## Falsification

Q02 determines whether the approved structural rule produces enough trades
and survives costs on either authorized FX symbol. It must not be promoted
from source reputation or in-sample anecdotes. Persistent-trend losses and
EURUSD/GBPUSD overlap are explicit downstream risks.
