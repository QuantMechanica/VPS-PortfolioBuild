# QM5_9241: H1 Malaysian Engulfing Retest

**EA ID:** QM5_9241

Approved card: `docs/strategy_card.md`; source ID
`ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`, MQL5 article 22419.
Only EURUSD.DWX, GBPUSD.DWX and XAUUSD.DWX; H1. Fixed $1,000 baseline risk.

## 1. Strategy Logic

`Strategy_EngulfDirection` checks the exact bullish/bearish candle comparisons
from the card. Candle range must be at least 0.5 ATR(14) measured at that
engulfing bar, using closed data. The preceding candle high/low is the zone.

`Strategy_EntrySignal` looks back at most eight completed retest bars, arms only
the newest qualified engulfing, and enters on the first tick of the next H1
bar after the first valid retest. It reconstructs setup state from closed bars
after a restart. Missing bars or ATR fail closed; a new engulfing cannot retest
itself. Initial attachment mid-bar is skipped. A filtered first retest consumes
the setup; there is no delayed entry after news ends or repeated attempt on it.

Explicit implementation conventions for independent card-fidelity review:

- A touch intersects the prior candle's high/low interval, including equality.
- Bullish rejection means close > open, with `(min(open,close)-low)/(high-low)`
  at least 0.35. Bearish rejection mirrors the upper wick. A zero-range bar fails.
- The far zone edge is invalidation: low < zone low for buys; high > zone high
  for sells. Equality holds. An intervening invalidation cancels the setup.
- The most recent engulfing supersedes older pending setups, in either direction.

These fill boundary definitions left implicit in the card; they are disclosed
implementation choices, not a claim that newly fetched source code confirmed
them. Review must confirm fidelity before this strategy can enter the pipeline.

The broker SL is zone low minus 0.3 ATR for buys, zone high plus 0.3 ATR for
sells. The hard target is two times the entry-quote-to-normalized-SL distance.
`Strategy_ExitSignal` closes on an opposite qualified engulfing or 24 elapsed
H1 bars (actual bars, not wall-clock hours). No trailing or partial exits.

MAE sampling and Friday handling remain per tick. Rule exits run on closed H1
bars before entry/news guards. Framework magic, risk, spread, news and event
hooks remain active. The strategy has one position per registered magic.

## 2. Parameters

| Input | Default | Validation |
|---|---:|---|
| strategy_retest_bars | 8 | 1–64 |
| strategy_wick_threshold | 0.35 | (0,1] |
| strategy_atr_period | 14 | 2–256 |
| strategy_min_engulf_atr | 0.5 | positive |
| strategy_stop_buffer_atr | 0.3 | positive |
| strategy_target_r | 2.0 | positive |
| strategy_max_hold_bars | 24 | 1–240 |

Card prior: 55 trades/year/symbol, unmeasured. No performance or payout claim.
Compile, smoke, independent review and out-of-sample economic tests are pending.

## 3. Symbol Universe
EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX only, in registered slot order 0/1/2.
## 4. Timeframe
H1 only; all pattern and ATR references use completed H1 bars.
## 5. Expected Behaviour
First retest only, one position per magic; maximum hold 24 actual H1 bars.
The card prior of 55 trades/year/symbol is unmeasured, not a result.
## 6. Source Citation
Approved card: docs/strategy_card.md. Chukwubuikem Okeke, Adaptive Malaysian
Engulfing Indicator (Part 1), MQL5 article 22419, dated 2026-05-12 in the card:
https://www.mql5.com/en/articles/22419 . Boundary conventions are disclosed above.
## 7. Risk Model
RISK_FIXED=1000 and RISK_PERCENT=0 for baseline tests. Framework sizing uses
entry-to-SL distance. SL never widens; hard TP is 2R. Framework kill switch,
spread checks, news controls and Friday handling remain enabled. No live approval.
