# QM5_20097_three-little-pigs-mtf-sma — Strategy Spec

**EA ID:** QM5_20097
**Slug:** `three-little-pigs-mtf-sma`
**Source:** `BP-HARMONICPHIL-2013-3LP`
**Author of this spec:** Claude (board-advisor; codex cross-review per build run 2026-07-24)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

Multi-timeframe SMA trend swing. Long only when the H4 trigger close is above SMA55 of the last CLOSED W1 bar and SMA21 of the last CLOSED D1 bar; trigger = H4 bar that touches SMA34 (low <= SMA) and closes above it; enter market at next H4 open. Initial SL = SMA34 minus 0.25*(HighestATR14+LowestATR14 over 30 closed H4 bars) in pips, capped at 100 pips from entry; per H4 close the SL ratchets to the recomputed SMA34-offset (never widens). No TP (open target). Re-entry only on a fresh full signal (post #105). Short mirrors.

Authoritative hook-level spec: `docs/ops/source_harvest/strategies/STR-103-three-little-pigs-mtf-sma/04_spec_final.md`
(reconciled Claude/Codex, tie-breaks documented in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_w1` | 55 | 55 | weekly SMA (source-fixed) |
| `strategy_sma_d1` | 21 | 21 | daily SMA (source-fixed) |
| `strategy_sma_h4` | 34 | 34 | H4 SMA (source-fixed) |
| `strategy_atr_period` | 14 | 14 | H4 ATR (source-fixed) |
| `strategy_atr_lookback` | 30 | 30 | ATR high/low window (in-thread precedent, variant TLP_103_ATRLB30) |
| `strategy_atr_offset_fact` | 0.25 | 0.25 | offset = fact*(ATRhigh+ATRlow) (source-fixed) |
| `strategy_max_sl_pips` | 100.0 | 100 | stop-distance cap (post #40, variant _CAP100G) |

---

## 3. Symbol Universe

AUDUSD.DWX (0), EURGBP.DWX (1), EURJPY.DWX (2), EURUSD.DWX (3), GBPUSD.DWX (4), USDCAD.DWX (5), USDCHF.DWX (6), USDJPY.DWX (7) — the source's eight pairs. Magics 200970000-200970007.

---

## 4. Timeframe

H4 execution; W1 and D1 gates on their last closed bars (multi-TF, no forming-bar reads). MN1 not used.

---

## 5. Expected Behaviour

Swing trend-capture with re-entries; clusters in aligned W1/D1 trends. Est. 12-35 trades/yr/symbol (above floor). Weekend holds from the source are OVERRIDDEN by framework Friday-close (documented deviation). ATR-scaled variable risk per trade, capped at 100 pips.

---

## 6. Source Citation

harmonicphil (2013), "3 Little Pigs Trading System", BabyPips forums thread 54174, https://forums.babypips.com/t/3-little-pigs-trading-system/54174 — post #1 (ruleset), #40 (100-pip cap), #70 (30-bar ATR window precedent), #99/#100 (offset trail), #105 (fresh-signal), #108 (weekend holds; overridden). Card: QM5_20097 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (source intent 1%); risk on the ATR-scaled capped stop; per-trade cap <=1%; KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run, ledger STR-103).
