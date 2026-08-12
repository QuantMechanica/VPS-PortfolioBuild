# QM5_11887_lien-double-bollinger-bands-regime — Strategy Spec

**EA ID:** QM5_11887
**Slug:** `lien-double-bollinger-bands-regime`
**Source:** `b840c053-5cd2-5e17-b25b-d495e73a33ab`
**Author of this spec:** Codex
**Last revised:** 2026-08-06

---

## 1. Strategy Logic

On each completed H4 bar, the EA classifies price against Bollinger envelopes
with a common 20-bar lookback and inner/outer deviations of 1 and 2 standard
deviations. A signal requires six consecutive completed bars inside the inner
envelope, followed by a close into the upper or lower trend zone while remaining
inside the corresponding outer envelope. The trade opens at the next H4 open.

The stop is placed 15 pips beyond the crossed inner-band boundary. There is no
fixed take-profit. A long exits when an H4 close falls back to or below the inner
upper band; a short exits when an H4 close rises back to or above the inner lower
band. The V5 Friday-close and hard-risk controls remain authoritative.

This is distinct from the existing immediate Double-Bollinger zone-entry builds
(`QM5_11304` and `QM5_11476`): this card requires a six-bar range dwell before
the H4 transition and does not add their middle-band slope condition.

---

## 2. Parameters

| Parameter | Default | Validated range | Meaning |
|---|---:|---:|---|
| `strategy_bb_period` | 20 | 2–250 | Common lookback for the inner and outer Bollinger envelopes. |
| `strategy_bb_dev_inner` | 1.0 | >0 and below outer deviation | Inner envelope that defines the range/trend boundary. |
| `strategy_bb_dev_outer` | 2.0 | above inner deviation | Outer envelope that caps an admissible transition entry. |
| `strategy_range_dwell_bars` | 6 | 1–100 | Consecutive range-zone closes required immediately before the trigger bar. |
| `strategy_sl_pips_behind_zone` | 15 | 1–1000 | Stop distance beyond the crossed inner-band boundary. |
| `strategy_spread_cap_pips` | 20 | 1–1000 | Entry-only wide-spread guard; zero modeled DWX spread fails open. |

Framework inputs, including risk, news, Friday-close, seed, and stress controls,
are defined in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

The approved ten-pair FX universe and deterministic magic slots are:

| Slot | Symbol | Portfolio role |
|---:|---|---|
| 0 | `EURUSD.DWX` | euro / US-dollar major |
| 1 | `GBPUSD.DWX` | sterling / US-dollar major |
| 2 | `USDJPY.DWX` | yen and rates-sensitive major |
| 3 | `USDCAD.DWX` | Canadian-dollar / oil-linked major |
| 4 | `USDCHF.DWX` | Swiss-franc defensive major |
| 5 | `AUDUSD.DWX` | Australian-dollar commodity major |
| 6 | `NZDUSD.DWX` | New-Zealand-dollar commodity major |
| 7 | `EURJPY.DWX` | euro / yen cross |
| 8 | `GBPJPY.DWX` | sterling / yen cross |
| 9 | `AUDJPY.DWX` | Australian-dollar / yen risk cross |

Symbols outside this list, and any slot/symbol mismatch, fail configuration
authorization. Indices, metals, energy, crypto, and unregistered FX pairs are not
authorized by this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar()` consumption on the attached H4 chart |
| Signal bars | trigger at shift 1; dwell state at shifts 2 through 7 by default |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 28 per approved card |
| Typical hold time | several H4 bars while price remains outside the inner envelope |
| Expected drawdown profile | isolated fixed-risk losses; one position per symbol/magic; no stacking |
| Regime preference | range compression followed by a directional H4 expansion |
| Exit character | dynamic trend-exhaustion exit on re-entry into the inner range |

---

## 6. Source Citation

**Source ID:** `b840c053-5cd2-5e17-b25b-d495e73a33ab`
**Source type:** practitioner book / educational session
**Pointer:** Kathy Lien, *Battle Tested Forex Trading Strategies* (2011),
Double Bollinger Bands chapter, slides 20–33; approved card copy at
`docs/strategy_card.md`
**R1–R4 verdict (Q00):** R1–R4 PASS in the OWNER-approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). No live or deployment action is part of this
build.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Complete and refresh partial June artifact against current V5 framework | Build task `36c852fe-b44c-472d-8c57-d5dea843971e` |
