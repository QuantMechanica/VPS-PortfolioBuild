# QM5_20101_simplicity-ha-ema100-london - Strategy Spec

**EA ID:** QM5_20101
**Slug:** `simplicity-ha-ema100-london`
**Source:** FF-ZEIMAN-SIMPLICITY-1010582 (see card QM5_20101)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

H1 Heiken-Ashi trend-flip system inside a fixed GMT signal window. A long
requires the last closed H1 close above EMA(100), an HA colour flip red→green
across shifts 2→1, and the signal bar's open time inside [06:00, 06:00+9h)
UTC; shorts mirror below the EMA. One netted position per campaign: SL one
trade tick beyond the signal HA extreme; 2/3 of the volume closes at +1R
(source orders A/B, "TP = SL"); the remaining 1/3 (order C) has no TP and its
SL trails one tick beyond each newly closed HA candle's extreme, never
widening, until hit. No opposite-flip market exit (the trailed stop realizes
the trend change — deliberate fidelity difference vs QM5_9977). Management
runs around the clock; only signal formation is session-gated. Campaign risk
1% TOTAL (explicit more-restrictive decision; source risked 1% per order).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-002-simplicity-ha-100ema-london/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 100 | 100 | H1 EMA trend gate (source-fixed) |
| `strategy_session_start_gmt` | 6 | 6 | signal window start, UTC (source-fixed) |
| `strategy_session_hours` | 9 | 8-9 | window length (source "8-9 hours"; variant SIMP_002_NINEH) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1), USDCHF.DWX (2), USDJPY.DWX (3) — the source's
four pairs. Magics 201010000-201010003.

---

## 4. Timeframe

H1 execution; all reads on closed H1 bars (shifts >=1); HA recursion from raw
OHLC, seed depth >=150 bars.

---

## 5. Expected Behaviour

London/NY-morning trend capture; author concedes stop-out clusters in flat
regimes (source post #6) — expected and judged by Q02+. Est. 60-150
campaigns/yr/symbol. Partial-close at +1R then runner trailing; netting
mechanization of the source's three orders.

---

## 6. Source Citation

zeiman (Mantas, UK) (n.d., ~2021), "Trading System 'Simplicity'", ForexFactory
thread 1010582, https://www.forexfactory.com/thread/1010582 — post #1 (full
ruleset), #6 (flat-market concession), #8 (cfudge raw-candle variant, not
adopted). Card: QM5_20101 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (1% CAMPAIGN intent — one netted
position); SL = signal-HA extreme ± 1 tick; per-trade cap <=1%; KS_DAILY_LOSS
3%; KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 2, ledger STR-002).
