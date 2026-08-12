# QM5_20127_sisyphus-2ma-rsi2-d1 - Strategy Spec

**EA ID:** QM5_20127
**Slug:** `sisyphus-2ma-rsi2-d1`
**Source:** FF-SISYPHUS-2MARSI-574065 (see card QM5_20127)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

D1 trend-pullback mean reversion: LONG when Close(1) > SMA200(1), Close(1)
< SMA5(1) and RSI(2)(1) < 5 (strict; SMA default type, flagged); SHORT
mirror (RSI > 95). Entry at market on the new bar; exit option 1 — when
the just-closed bar touches the SMA5 (long: High(1) >= SMA5(1)), close at
market (next-open approximation, flagged). No source SL/TP → house
catastrophe stop 4×ATR(14) at entry, never moved (separately tagged).
One position; seven USD majors.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-073-sisyphus-2ma-rsi2/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_slow` | 200 | 200 | source-fixed |
| `strategy_ma_fast` | 5 | 5 | source-fixed |
| `strategy_rsi_period` | 2 | 2 | source-fixed |
| `strategy_buy_level` | 5.0 | 5 | source-fixed |
| `strategy_sell_level` | 95.0 | 95 | source-fixed |
| `strategy_atr_period` | 14 | 14 | catastrophe stop |
| `strategy_emergency_atr_mult` | 4.0 | 4 | house addition (flagged) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1), AUDUSD.DWX (2), NZDUSD.DWX (3),
USDJPY.DWX (4), USDCHF.DWX (5), USDCAD.DWX (6) — source-explicit. Magics
201270000-201270006.

---

## 4. Timeframe

D1 execution; closed-bar reads only.

---

## 5. Expected Behaviour

~10-30 campaigns/yr/symbol × 7; diversification is the source's variance
argument; per-symbol floor applies.

---

## 6. Source Citation

Sis.yphus (~2015), "A Proven Simple Strategy (2MAs, 1 RSI)", ForexFactory
thread 574065,
https://www.forexfactory.com/thread/574065/a-proven-simple-strategy-2mas-1-rsi
— post #1 (rules + option-1 exit + 7 pairs + no-SL statement). Card:
QM5_20127 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade at the catastrophe
stop); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 9, ledger STR-073).
