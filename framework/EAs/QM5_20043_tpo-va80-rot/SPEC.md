<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`

Copy this file to:
  framework/EAs/QM5_<NNNN>_<slug>/SPEC.md

Replace every <ANGLE_BRACKETED_PLACEHOLDER>. Validator rejects placeholders.
All seven sections below are MANDATORY for Q01 PASS.
-->

# QM5_<NNNN>_<slug> — Strategy Spec

**EA ID:** QM5_<NNNN>
**Slug:** `<slug>`
**Source:** `<source_id>` (see `strategy-seeds/sources/<source_id>/`)
**Author of this spec:** Codex
**Last revised:** <YYYY-MM-DD>

---

## 1. Strategy Logic

Plain prose, no jargon. Describe the signal the EA trades. Include the formula
or rule that decides entry and exit.

> Example: "Long when 21-EMA(close) crosses above 55-EMA(close) on the close
> of a D1 bar AND ADX(14) > 25. Exit when 21-EMA crosses below 55-EMA, or at
> 2× ATR(14) trailing stop, or on Friday close."

<DESCRIBE THE STRATEGY LOGIC HERE>

---

## 2. Parameters

Table of every input parameter, its default, range, and meaning.

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `<param_1>` | <value> | <lo>-<hi> | <one-line description> |
| `<param_2>` | <value> | <lo>-<hi> | <one-line description> |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `<SYMBOL_1.DWX>` — <why this fits>
- `<SYMBOL_2.DWX>` — <why this fits>

**Explicitly NOT for:**
- `<SYMBOL.DWX>` — <why this does not fit>

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `<M5 / M15 / H1 / H4 / D1>` |
| Multi-timeframe refs | `<list any cross-TF reads>` or `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | `<approx number>` |
| Typical hold time | `<minutes / hours / days>` |
| Expected drawdown profile | `<one line>` |
| Regime preference | `<trend / mean-revert / volatility-expansion / breakout / news-driven>` |
| Win rate target (qualitative) | `<low/medium/high>` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `<source_id>`
**Source type:** `<paper / book / forum / video / OWNER / AI>`
**Pointer:** `<URL or local path or strategy-seeds/sources/<source_id>/>`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_<NNNN>_<slug>.md`

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
| v1 | <YYYY-MM-DD> | Initial build from card | <build commit hash> |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
