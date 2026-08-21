# QM5_36005_nnfx-coral-trendlord-woodies-harvester — Strategy Spec

**EA ID:** QM5_36005
**Slug:** `nnfx-coral-trendlord-woodies-harvester`
**Source:** `nnfx-coral-trendlord-woodies-harvester-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

On each completed D1 bar, the EA buys when price is above the 20-period Coral SMMA, the Trend Lord proxy is green, Woodies CCI is positive, and Waddah Attar momentum exceeds its Bollinger explosion line; it sells on the inverse state. Every order receives a hard one-ATR stop and no full-volume take-profit. At plus one ATR the EA closes 50% and moves the remaining stop to entry plus or minus one pip, leaving the runner open until Trend Lord changes color. New entries are blocked during the GMT rollover window, genuinely excessive spreads, the card's daily loss limits, or the framework news blackout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_coral_period` | 20 | 14–30 | Period of the card-defined Coral SMMA baseline. |
| `strategy_trendlord_period` | 50 | reviewer confirmation required | Period of the deterministic LWMA-slope color proxy used because the card gives no Trend Lord formula. |
| `strategy_woodies_cci_period` | 14 | 10–20 | Woodies CCI confirmation period. |
| `strategy_wae_fast` | 12 | fixed baseline | Fast MACD period in the deterministic WAE mapping. |
| `strategy_wae_slow` | 26 | fixed baseline | Slow MACD period in the deterministic WAE mapping. |
| `strategy_wae_signal` | 9 | fixed baseline | MACD signal period in the deterministic WAE mapping. |
| `strategy_wae_bb_period` | 20 | fixed baseline | Bollinger period for the WAE explosion line. |
| `strategy_wae_bb_deviation` | 2.0 | fixed baseline | Bollinger deviation for the WAE explosion line. |
| `strategy_wae_sensitivity` | 150 | 100–200 | WAE momentum sensitivity from the card. |
| `strategy_atr_period` | 14 | fixed | ATR period for entry stop, TP1 trigger, and spread filter. |
| `strategy_sl_atr_mult` | 1.0 | fixed | Initial stop distance in ATR units. |
| `strategy_tp1_atr_mult` | 1.0 | fixed | Partial-profit trigger in ATR units. |
| `strategy_tp1_fraction` | 0.50 | fixed | Fraction of position volume closed at TP1. |
| `strategy_be_buffer_pips` | 1 | fixed | Runner stop buffer beyond entry after TP1. |
| `strategy_spread_atr_mult` | 1.8 | fixed | Blocks entry when positive modeled spread exceeds this ATR multiple. |
| `strategy_daily_entry_halt_pct` | 2.0 | fixed | Blocks new entries after this daily realized loss. |
| `strategy_daily_hard_stop_pct` | 2.5 | fixed | Closes exposure and blocks entries at this daily equity loss from starting balance. |
| `strategy_total_hard_stop_pct` | 5.0 | fixed | Closes exposure and blocks entries at this equity loss from the first attach equity. |

Framework inputs, including `RISK_PERCENT`, `RISK_FIXED`, `PORTFOLIO_WEIGHT`, news controls, stress seed, and Friday close, are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `GBPJPY.DWX` — the card's primary liquid JPY-cross target, registered at slot 0.
- `EURJPY.DWX` — a second liquid JPY cross in the card's portable D1 basket, registered at slot 1.
- `AUDNZD.DWX` — the card's non-JPY cross diversifier, registered at slot 2.

**Explicitly NOT for:**

- Any symbol outside the three approved card targets — no unapproved universe expansion is implemented.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Expected trade frequency | 80–160 high-conviction trades per year |
| Typical hold time | Not stated in frontmatter; the D1 runner holds until Trend Lord changes color. |
| Expected drawdown profile | Card prior: 18% expected maximum drawdown; hard strategy gates act at 2.5% daily and 5.0% from initial equity. |
| Regime preference | Not stated in frontmatter; the approved thesis is trend/momentum with volatility expansion. |
| Win rate target (qualitative) | Not used as a build gate; the card records a source claim only. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-coral-trendlord-woodies-harvester-official-source`
**Source type:** verified quantitative model, as recorded by the approved card
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36005_nnfx-coral-trendlord-woodies-harvester.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_36005_nnfx-coral-trendlord-woodies-harvester.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-21 | Initial build from card | 0d80f4b9-bd2e-4719-a877-b015aea4cd23 |
