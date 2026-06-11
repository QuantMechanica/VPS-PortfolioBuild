# QM5_11580_williams-outside-bar-daily-d1 - Strategy Spec

**EA ID:** QM5_11580
**Slug:** williams-outside-bar-daily-d1
**Source:** c6f2601c-1c2d-514f-be1e-2cc3fb379135 (see `sources/larry-williams-long-term-secrets-short-term-trading-1999`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades EURUSD.DWX on D1 after a completed outside bar. A long signal occurs when the last closed bar has a higher high and lower low than the prior bar, then closes below the prior low. A short signal uses the same outside bar but requires the last closed bar to close above the prior high. Entries are market orders at the next D1 open, with no fixed take profit; a profitable position is closed at the next D1 open, otherwise it remains open until the fixed stop is hit.

---

## 2. Parameters

Table of every input parameter, its default, range, and meaning.

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sl_pips | 200 | >0 | Fixed stop distance in pips from entry. |
| strategy_exit_open_window_minutes | 5 | >0 | D1 open execution window for the card's profitable-next-open exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- EURUSD.DWX - The approved card names EUR/USD D1, and EURUSD.DWX is present in `framework/registry/dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Other symbols - The card is a single-instrument EUR/USD adaptation and does not authorize cross-symbol expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | One or more D1 bars until a profitable next-open exit or the 200-pip SL. |
| Expected drawdown profile | Fixed 200-pip stop with no fixed take profit; losses are stop-bounded while profitable exits occur at D1 opens. |
| Regime preference | Reversal at extreme after outside-bar exhaustion. |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c6f2601c-1c2d-514f-be1e-2cc3fb379135
**Source type:** book
**Pointer:** Larry Williams, `Long-Term Secrets to Short-Term Trading`, Wiley 1999; approved card `artifacts/cards_approved/QM5_11580_williams-outside-bar-daily-d1.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11580_williams-outside-bar-daily-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 1901e7f1-f24f-4a17-8bcd-cfe9f824adb6 |
