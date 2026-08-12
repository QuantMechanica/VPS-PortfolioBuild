---
card_schema_version: 2
ea_id: QM5_20038
slug: vwap2s-revert
status: DRAFT
g0_status: APPROVED
symbol: SP500.DWX
timeframe: M5
variant_id: VWAP2S_REVERT_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20038
execution_contract_status: DRAFT
target_symbols: [SP500.DWX, XAUUSD.DWX]
expected_trades_per_year_per_symbol: 300
g0_approval_reasoning: "R1 Berkowitz-Logue-Noser 1988 JF43 DOI 10.1111/j.1540-6261.1988.tb02591.x; R2 mechanical 09:30-16:00 ET VWAP-tag window with frozen target/stop; R3 SP500.DWX and XAUUSD.DWX M5 ticks; R4 deterministic DEV-guarded proxy, no ML"
last_updated: 2026-07-22
expected_pf: 1.25
expected_dd_pct: 12.0
source_id: BERKOWITZ-LOGUE-NOSER-1988
ml_required: false
r1_track_record: PASS
r1_reasoning: "Peer-reviewed Journal of Finance 43(1), 1988, DOI 10.1111/j.1540-6261.1988.tb02591.x establishes VWAP as an execution benchmark, while the two-sigma fade is explicitly kept as an empirical QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Mechanical M5 anchored tick-volume VWAP/sigma calculation, shallow-slope and hash-bound DEV side guard, next-bar entry, frozen VWAP target, frozen three-sigma stop, and cash-close exit."
r3_data_available: PASS
r3_reasoning: "SP500.DWX and XAUUSD.DWX M5 tick histories and the DST-aware US cash calendar are available for DEV 2018-2023, OOS 2024, and sealed 2025."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic arithmetic and a frozen pre-OOS measurement artifact; no learned model, grid, martingale, discretionary tape read, or centralized-volume dependency."
source_citations:
  - type: academic_paper
    citation: "Berkowitz, S. A., Logue, D. E. & Noser, E. A. Jr. (1988). The Total Cost of Transactions on the NYSE. The Journal of Finance 43(1):97-112. DOI 10.1111/j.1540-6261.1988.tb02591.x."
    location: "Definition and institutional use of a volume-weighted average-price execution benchmark; not evidence for a two-sigma reversion edge."
    quality_tier: B
    role: primary
---

# Session-anchored VWAP two-sigma reversion

## Source-defined rules

Berkowitz, Logue and Noser (1988), *The Total Cost of Transactions on the
NYSE*, *The Journal of Finance* 43(1), 97-112, DOI
https://doi.org/10.1111/j.1540-6261.1988.tb02591.x, develop a
volume-weighted average-price measure of execution cost and establish VWAP as
an institutional execution benchmark. The paper does not establish a
two-sigma band fade, a shallow-slope filter, a three-sigma stop, or an alleged
63% reversion rate.

This card therefore tests an anchored broker-tick-volume proxy on `M5` as a QM
hypothesis. `SP500.DWX` is the direct US-index port and `XAUUSD.DWX` is a
cross-asset benchmark-port hypothesis. Broker tick counts are not represented
as centralized exchange volume or tape/order-flow evidence.

## QM interpretations

Every rule in this section belongs to variant `VWAP2S_REVERT_BASELINE`.

**GUARD: no side into OOS unless the DEV empirical-reversion proof passes (else it is generic Bollinger).**

- **Session and estimator.** Use `America/New_York` and the official US cash
  calendar. Anchor each symbol independently at 09:30 ET and end at 16:00 ET,
  or at the official early close. For each completed `M5` bar `i`, set
  `TP_i=(high_i+low_i+close_i)/3`, `w_i=tick_volume_i`,
  `VWAP=sum(w_i*TP_i)/sum(w_i)`, and population
  `sigma=sqrt(sum(w_i*(TP_i-VWAP)^2)/sum(w_i))`. Missing or zero weights and
  non-positive sigma are invalid.
- **Shallow-slope gate.** At each completed bar, set
  `slope_abs=abs(VWAP_t-VWAP_t-1)` and `slope_ref` to the median of all earlier
  completed absolute one-bar VWAP changes in that session, excluding the
  current change. Qualify only when `slope_abs <= slope_ref`; without an
  earlier change there is no trade.
- **Tag and entry.** A LONG tag requires `low <= VWAP-2*sigma`; a SHORT tag
  requires `high >= VWAP+2*sigma`. Both bands touched in one bar fails closed.
  Require the shallow-slope gate at that close, freeze `V0=VWAP` and
  `S0=sigma`, then enter the fade at the next `M5` open strictly before the
  session close. Permit at most one LONG and one SHORT attempt per
  symbol/session and only one open position at a time; a failed side cannot
  re-enter that session.
- **DEV empirical-reversion proof.** Before tradable OOS, run a
  measurement-only DEV 2018-2023 pass over identical tags. For each symbol and
  side, label a tag `REVERT` only when frozen `V0` is touched before its frozen
  three-sigma stop or the session close; every other outcome is `FAIL`. Set
  `guard_pass=true` only when `REVERT` is strictly greater than `FAIL` and net
  DEV expectancy after governed venue costs is positive. Persist counts,
  expectancy, inputs, code identity, and a hash. Freeze the symbol/side mask
  before OOS 2024; OOS or sealed 2025 may never recalculate it. A missing or
  mismatched artifact blocks that side.
- **Target, stop, and time exit.** LONG target is frozen `V0` and broker hard
  stop is `V0-3*S0`; SHORT target is `V0` and hard stop is `V0+3*S0`. If the
  next-open fill is already at or through either boundary, do not trade. Close
  any remainder at the official 16:00 ET cash close or early close. No dynamic
  VWAP, trail, breakeven move, scaling, averaging, or partial close is allowed;
  resolve target/stop ambiguity from executable bid/ask tick chronology.
- **Sizing and cost.** Size once from the setfile's locked `RISK_FIXED` amount
  and the actual fill-to-frozen-stop monetary distance; `RISK_PERCENT` is not
  authorized. Resolve commission, spread, tick value, conversions, volume step,
  and stop constraints from governed per-symbol runtime data. Require
  `(commission + spread) / initial_monetary_risk <= 0.10R`; missing data or an
  unrepresentable lot blocks entry.
- **Density.** Approximately 300 trades/year/symbol is an honest, untested
  prior before the empirical guard and all entry/cost gates. It is not the
  unsupported 63% claim and may not be rescued by allowing a failed side.

## Framework execution overrides

- The framework emergency/account kill switch disables entries and may flatten
  an open position before any card-managed target, stop, or time exit.
- The default framework news pause remains active; it may block a tag but may
  not delay-enter after the tagged next `M5` open.
- The framework Friday safety close remains enabled after the card's same-day
  cash-session close.
- No Bollinger-price substitute, RSI overlay, alternate volume feed selected
  after DEV, trailing stop, grid, martingale, pyramid, or loss-dependent sizing
  override is authorized.

## Exit precedence

1. Framework emergency/account kill-switch close.
2. Frozen three-sigma broker hard stop or frozen `V0` target, ordered by
   executable bid/ask tick chronology.
3. Official US cash-session close (16:00 ET or an approved early close); after
   restart or rejected close, retry immediately before entry evaluation.
4. Framework Friday safety close if a position somehow remains open.
5. Guard-artifact expiry or data-hash failure blocks new entries only and never
   disables an existing hard stop or deterministic close.

## Runtime data dependencies

- Primary chart, signal, and order route: `SP500.DWX`, `M5`.
- Sibling symbol — **per-symbol setfile to generate at build**:
  `XAUUSD.DWX`. Generate one setfile for each target; each symbol owns its
  estimator, guard mask, side-attempt keys, position, target, stop, and cost
  state. Results may not be pooled to conceal a failed symbol/side.
- Runtime needs completed-bar broker tick counts. These are relative proxy
  weights only; no centralized-volume or order-flow feed is authorized.
- Tester account currency is USD. Supply current tick value, notional and FX
  conversion, volume step, stop level, commission schedule, and spread for
  each route at its decision tick.
- Pin an IANA timezone database covering `America/New_York` and an official US
  cash calendar, including holidays and early closes, with
  `valid_through=2025-12-31`. Ambiguous conversions fail closed.
- Store the hash-bound measurement-only DEV artifact per symbol and side. Real
  ticks and tick volume must cover DEV 2018-2023, OOS 2024, and untouched
  sealed 2025; every dataset and guard input has
  `valid_through=2025-12-31`. No ML service exists.

## Falsification and requalification

- Stage 1 is measurement-only DEV 2018-2023; Stage 2 freezes the side mask and
  runs OOS 2024, then untouched sealed 2025. Report `SP500.DWX`,
  `XAUUSD.DWX`, LONG/SHORT, target-before-stop counts, and each year
  separately. No failed side enters OOS.
- Apply governed nonzero commission and historical spread, then shift entry and
  exit one tick adversely. Reject a side if its DEV guard fails and reject the
  family if OOS or sealed net expectancy is not positive or any admitted trade
  requires `cost_R > 0.10R`.
- Reject if the estimator is not restart-deterministic, legitimate tick-volume
  feeds materially change the conclusion, or the result requires substituting
  a generic close-price Bollinger fade or centralized volume.
- Dedup boundary: the XAU route is distinct from
  `QM5_12792_gold-asian-drift` and `QM5_12974_xau-asia-session-drift` because
  it is anchored to the 09:30-16:00 ET session, requires a frozen tick-volume
  VWAP two-sigma tag plus a pre-OOS empirical side proof, and fades to frozen
  VWAP. Neither route is an ORB or continuation sleeve.
- Any change to session anchor, price/weight formula, sigma convention, slope
  statistic, tag threshold, guard definition or hash, target, stop, entry time,
  session exit, symbol route, cost model, risk mode, or variant identity
  requires a new binary, new DEV-only proof, and full portfolio
  requalification. An unresolved item is `BLOCKED`; Development may not fill
  it in.
