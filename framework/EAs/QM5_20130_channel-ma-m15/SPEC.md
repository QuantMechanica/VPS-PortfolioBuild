# QM5_20130_channel-ma-m15 - Strategy Spec

**EA ID:** QM5_20130
**Slug:** `channel-ma-m15`
**Source:** FF-MICKEYMAR-CHANNELMA-707474 (see card QM5_20130)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

M15 channel-MA system: EMA(55) on highs / EMA(55) on lows = channel;
EMA(33) on closes = signal. Long when the signal crosses above the upper
channel (strict edge); short below the lower. NORMAL entry at market when
price is within 40 pips of the channel; DELAYED entry via a pending limit
at the per-bar-refreshed EMA33 while the signal stays valid (cancelled on
invalidation). SL 40 pips; no TP; exit at the opposite signal with the
reverse routed through the same normal/delayed workflow. One position.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-079-channel-ma-m15/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ch_period` | 55 | 55 | channel EMA (source-fixed) |
| `strategy_sig_period` | 33 | 33 | signal EMA (source-fixed) |
| `strategy_delay_pips` | 40.0 | 40 | normal/delayed threshold (source-fixed) |
| `strategy_sl_pips` | 40.0 | 40-50 | hard stop (40 = coherence choice) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design. Magics 201300000-201300001.

---

## 4. Timeframe

M15 execution; closed-bar reads; pending lifecycle per closed bar.

---

## 5. Expected Behaviour

~100-200 signals/yr/symbol; noise filtered by the channel per the
author's design thesis; fixed-40/BE and 210/session modes = variants.

---

## 6. Source Citation

MickeyMar (~2017), "Channel MA Short-Term System", ForexFactory thread
707474, https://www.forexfactory.com/thread/707474/channel-ma-short-term-system
— posts #1-2 (settings, rules, stops, targets, delayed entry). Card:
QM5_20130 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 10, ledger STR-079).
