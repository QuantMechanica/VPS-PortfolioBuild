# QM5_11722_tc-m5-s8-triple-bb-rsi-stoch - Strategy Spec

**EA ID:** QM5_11722
**Slug:** `tc-m5-s8-triple-bb-rsi-stoch`
**Source:** `40a4454c-64ff-5015-8538-9f7b32abc0e9`
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades the Carter M5 Strategy #8 mean-reversion pattern. A long setup requires the prior closed setup bar to touch or pierce the lower Bollinger Band BB(50,2), with RSI(3) below 20 and Stochastic %K below 20. On the next closed bar, price must close back above the lower BB(50,2), RSI(3) must recover above 20, and Stochastic must confirm by reaching 40 or crossing above %D; shorts mirror the rule at the upper band with RSI above 80 and Stochastic above 80. Entries are market orders on the next M5 bar; the stop is the BB(50,3) outer band capped at 15 pips, and the take profit is the SMA50 / Bollinger middle line captured at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 50 | 10-200 | Common Bollinger/SMA lookback period from the card. |
| `strategy_bb_entry_dev` | 2.0 | 1.0-4.0 | Entry band deviation, the card's red BB(50,2). |
| `strategy_bb_stop_dev` | 3.0 | 2.0-5.0 | Stop reference band deviation, the card's yellow BB(50,3). |
| `strategy_bb_outer_dev` | 4.0 | 3.0-6.0 | Outer triple-band context from the card; not used as an entry trigger. |
| `strategy_rsi_period` | 3 | 2-20 | RSI lookback period. |
| `strategy_rsi_long_level` | 20.0 | 1-50 | Long setup/recovery RSI threshold. |
| `strategy_rsi_short_level` | 80.0 | 50-99 | Short setup/recovery RSI threshold. |
| `strategy_stoch_k` | 6 | 2-30 | Stochastic %K period. |
| `strategy_stoch_d` | 3 | 1-20 | Stochastic %D period. |
| `strategy_stoch_slow` | 3 | 1-20 | Stochastic slowing. |
| `strategy_stoch_long_setup` | 20.0 | 1-50 | Long setup Stochastic %K threshold. |
| `strategy_stoch_short_setup` | 80.0 | 50-99 | Short setup Stochastic %K threshold. |
| `strategy_stoch_long_confirm` | 40.0 | 20-70 | Long confirmation Stochastic %K threshold. |
| `strategy_stoch_short_confirm` | 60.0 | 30-80 | Short confirmation Stochastic %K threshold. |
| `strategy_sl_cap_pips` | 15 | 1-100 | Factory stop cap in pips applied to the BB(50,3) stop reference. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed M5 major FX symbol available in the DWX matrix.
- `GBPUSD.DWX` - card-listed M5 major FX symbol available in the DWX matrix.
- `USDJPY.DWX` - card-listed M5 major FX symbol available in the DWX matrix.
- `AUDUSD.DWX` - card-listed M5 major FX symbol available in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research/backtest symbols must use canonical `.DWX` names from `framework/registry/dwx_symbol_matrix.csv`.
- Indices, metals, and energies - the approved card's R3 row names only the four FX symbols above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Expected trade frequency | high-frequency intraday, from card period M5 and expected annual trade count |
| Typical hold time | not specified in card frontmatter; expected intraday M5 mean-reversion holds |
| Expected drawdown profile | not specified in card frontmatter; bounded per-trade by BB(50,3) / 15-pip factory cap |
| Regime preference | mean-reversion after Bollinger extension |
| Win rate target (qualitative) | medium to high, because the target is the SMA50 mean after an extreme-band reversal |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `40a4454c-64ff-5015-8538-9f7b32abc0e9`
**Source type:** book
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (5 Minute Time Frame)`, Strategy #8, local ref `sources/tc-20-forex-strategies-m5-367145560`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11722_tc-m5-s8-triple-bb-rsi-stoch.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-23 | Initial build from card | a154216d-8741-42fa-8aae-492728d667bd |
