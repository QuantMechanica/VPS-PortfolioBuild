# QM5_20172_wti-fri-bear — Strategy Spec

**EA ID:** QM5_20172
**Slug:** `wti-fri-bear`
**Source:** `GORSKA-MOP-WTI-FRIBEAR-2026`
**Author of this spec:** Development
**Last revised:** 2026-07-29

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_20172_wti-fri-bear_card.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_20172_wti-fri-bear.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_lookback_d1` | 252 | (see source) | (see strategy logic) |
| `strategy_min_abs_return_pct` | 0.0 | (see source) | (see strategy logic) |
| `strategy_entry_grace_minutes` | 67 | [67] | Nominal D1-bar allowance: measured 61.6-minute XTI session offset plus the card's five-minute executable grace. |
| `strategy_atr_period` | 20 | (see source) | (see strategy logic) |
| `strategy_atr_sl_mult` | 3.0 | (see source) | (see strategy logic) |
| `strategy_max_hold_days` | 2 | (see source) | (see strategy logic) |
| `strategy_max_spread_points` | 1500 | (see source) | (see strategy logic) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 8–25; Q02 floor >=5 |
| Cadence note | at most one genuine Friday package per broker week, only in a negative 252-D1 regime |
| Typical hold time | Friday open to framework Friday close; next-D1/stale repair if needed |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | per card thesis |
| Win rate target (qualitative) | medium |

The registered `XTIUSD.DWX` D1 session begins 61.6 minutes after the nominal
D1 bar timestamp. The 67-minute nominal-bar allowance implements the approved
five-minute first-executable-tick window without widening the executable
opportunity. Q02 also uses the mandatory 30-minute pre/post blackout with the
DXZ compliance profile; legacy news mode remains off.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `GORSKA-MOP-WTI-FRIBEAR-2026`
**Pointer:** `strategy-seeds/sources/GORSKA-MOP-WTI-FRIBEAR-2026/source.md`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_20172_wti-fri-bear_card.md`

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
| v1 | 2026-07-26 | Initial source-backed build | OWNER commodity/energy sleeve mission |
| v2 | 2026-07-29 | Reconcile Q02 truth | Original Q02=`DRAFT_DEFECT`; stale-result re-enqueue quarantined `BLOCKED_STALE_BUILD_RESULT`; no fresh Q02 before coordinated restart |

