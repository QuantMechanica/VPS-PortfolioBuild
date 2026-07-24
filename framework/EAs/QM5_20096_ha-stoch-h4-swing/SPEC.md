# QM5_20096_ha-stoch-h4-swing — Strategy Spec

**EA ID:** QM5_20096
**Slug:** `ha-stoch-h4-swing`
**Source:** `FF-HUGHBRISS-2011-HASTOCH`
**Author of this spec:** Claude (board-advisor; codex cross-review per build run 2026-07-24)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

Trend-following H4 pullback re-entry. Long: close above SMA100(close); >=2 consecutive red Heiken-Ashi bars immediately before a green HA flip bar; Stochastic(8,3,3, low/high) %K crosses above %D on the flip bar with %D below 50. Enter market at next H4 open. Exit: closed HA colour flip against the trade (market close), else 50-pip initial SL trailed each H4 close to the low/high of HA bar[2] (ratchet only). No TP. Short is the exact mirror (zone %D>50).

Authoritative hook-level spec: `docs/ops/source_harvest/strategies/STR-097-ha-stoch-h4-swing/04_spec_final.md`
(reconciled Claude/Codex, tie-breaks documented in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 100 | 100 | H4 SMA of close (trend gate; source-fixed) |
| `strategy_stoch_k` | 8 | 8 | stochastic %K (source-fixed) |
| `strategy_stoch_d` | 3 | 3 | stochastic %D (source-fixed) |
| `strategy_stoch_slowing` | 3 | 3 | slowing (source-fixed) |
| `strategy_stoch_zone` | 50.0 | 50 | cross must occur in bottom/top half (QM variant HASTOCH_097_ZONE50) |
| `strategy_pullback_min_bars` | 2 | 2 | opposite-colour HA bars before flip (variant _PB2) |
| `strategy_sl_pips` | 50.0 | 50 | initial stop (source-fixed) |

---

## 3. Symbol Universe

GBPUSD.DWX (slot 0), EURAUD.DWX (1), USDCHF.DWX (2), EURCAD.DWX (3) — the four source-demonstrated pairs. Magics 200960000-200960003.

---

## 4. Timeframe

H4 single-timeframe; all decisions on closed bars, one evaluation per new bar.

---

## 5. Expected Behaviour

Episodic trend-following: clusters in trending regimes, silent in chop. Est. 12-35 trades/yr/symbol (above the Q02 floor of 5). Long holds possible (no TP); Friday-close flattens weekends. Losing streaks in ranging markets expected; 50-pip fixed initial risk.

---

## 6. Source Citation

Hugh Briss (2011), "Swing trading with heiken ashi and stochs", ForexFactory thread 340556, https://www.forexfactory.com/thread/340556-swing-trading-with-heiken-ashi-and-stochs — posts #1/#2 (rules), #16 (author-selected 50-pip stop + HA[2] trail), #8 (HA-flip exit), #44 (closed-candle signalling). Card: QM5_20096 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (framework); risk anchored on the 50-pip initial stop; per-trade cap <=1%; KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run, ledger STR-097).
