# QM5_13212_mulham-us500-org — Strategy Spec

**EA ID:** QM5_13212
**Slug:** `mulham-us500-org`
**Source:** `YT-MULHAM-2026-07` (see `docs/ops/evidence/mulham_channel_mechanization_dossier_2026-07-13.md`)
**Author of this spec:** Claude
**Last revised:** 2026-07-21

---

## 1. Strategy Logic

Trades the overnight gap between the prior RTH close (23:00 broker, ET+7 fixed
mapping) and the next RTH open (16:30 broker) on US500 as an objective
imbalance whose 50% level acts as a magnet. After the open, the EA waits for
price to retrace back into the gap zone (between the two anchors), then
enters in the gap direction when an M15 bar closes back in that direction
without having closed beyond the gap's 50% level, provided the confirmation
bar shows displacement (range >= 1.2x ATR(14,M15), or a 3-bar Fair Value Gap
if `strategy_fvg_trigger=true`). A degenerate-gap floor (|gap| < 0.25x
ATR(14,D1)) and a liquidity-sweep veto (open already beyond the prior RTH
session's high/low) skip no-edge or already-swept days. Stop loss sits beyond
the retrace extreme plus an ATR buffer; take profit projects the ORG range
one (default) or two multiples beyond the post-open extreme, or targets the
post-open extreme itself, per `strategy_tp_mode`. One setup per day; flat by
22:30 broker regardless of outcome.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_org_min_frac_daily_atr` | 0.25 | 0.0-1.0 | Degenerate-gap floor: skip if \|gap\| < frac * ATR(14,D1) |
| `strategy_atr_period_d1` | 14 | 5-30 | ATR period for the daily degenerate-gap floor |
| `strategy_atr_period_m15` | 14 | 5-30 | ATR period for the M15 displacement gate and spread cap |
| `strategy_displacement_atr_mult` | 1.2 | 0.5-3.0 | Confirmation bar range must be >= mult * ATR(14,M15) |
| `strategy_entry_window_end_hhmm` | 1900 | 1630-2200 | Broker HHMM entry-window close (window starts 16:30) |
| `strategy_flatten_hhmm` | 2230 | 1900-2359 | Broker HHMM time-flatten (avoids the RTH close auction) |
| `strategy_sl_buffer_atr_mult` | 0.1 | 0.0-1.0 | SL buffer beyond the retrace extreme, in ATR(14,M15) units |
| `strategy_tp_mode` | QM_TP_ORG_STDEV_1 | post_open_extreme / org_stdev_1 / org_stdev_2 | TP projection scheme |
| `strategy_fvg_trigger` | false | true/false | Confirmation trigger: ATR displacement (false) or 3-bar FVG (true) |
| `strategy_spread_cap_atr_frac` | 0.15 | 0.0-1.0 | Spread gate cap as a fraction of ATR(14,M15); self-scaling, never gates on zero spread |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `SP500.DWX` — direct port of the card's `US500.DWX` target (US500 is not a
  registered `.DWX` alias; SP500.DWX is the canonical S&P 500 Custom Symbol,
  same underlying index the card's author teaches). Card is single-symbol
  (`single_symbol_only: true`) — the RTH-anchor broker-time mapping (23:00/16:30)
  is calibrated to the US cash session and does not generalize to other index
  opens (DAX/FTSE cash opens land at different broker-clock times).

**Explicitly NOT for:**
- `NDX.DWX` / `WS30.DWX` / `GDAXI.DWX` / `UK100.DWX` — card forbids multi-symbol
  expansion; the fixed 23:00/16:30 anchor times are specific to the US cash
  session and would misalign on other indices' RTH sessions.
- FX pairs — source author states the ORG object requires RTH session
  structure and explicitly does not work on forex.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` (ATR(14,D1) degenerate-gap floor only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M15)` (explicit, not chart-period-default) |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | `hours (16:30-22:30 broker window, same-day flatten)` |
| Expected drawdown profile | `~12% (card expected_dd_pct)` |
| Regime preference | `mean-revert-into-continuation (gap-fill retrace, then trend continuation)` |
| Win rate target (qualitative) | `medium (card expected_pf 1.12)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `YT-MULHAM-2026-07`
**Source type:** `video`
**Pointer:** `Mulham Trading, "EXPOSED — ICT One Trading Setup For Life (Opening Range Gap)" (YouTube XcG9b43jjJo)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13212_mulham-us500-org.md`

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
| v1 | 2026-07-21 | Initial build from card | 73c44f8d-ef36-4068-aaaa-024ec6ee958b |
