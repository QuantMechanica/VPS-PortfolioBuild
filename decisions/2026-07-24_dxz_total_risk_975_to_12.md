# Decision: DXZ live book TOTAL_RISK 9.75% -> 12.0%

- Date: 2026-07-24
- Status: **accepted (OWNER directive)** — computation done and validated; manifest generation
  NOT started, pending OWNER go on the two open questions in "Application" below.
- Owner: OWNER (2026-07-24: "es traden nicht alle EAs gleichzeitig also trotzdem risk hoch auf 12%")
- Scope: sizing only. Composition (the live Final-24), the per-sleeve cap (1.0), and the
  weighting method (capped inverse-vol) are UNCHANGED.
- Book: DXZ account 4000090541, live since 2026-07-19.

## OWNER rationale

The summed risk 9.75% is the theoretical all-sleeves-stop-out-simultaneously bound, not a
drawdown figure. The sleeves are decorrelated across sessions, symbols and timeframes and do
not fire together: median 2, p95 6, max 11 of 24 sleeves active on the same day over 2 028
days. The book is therefore under-levered relative to the account's kill limits.

**Claude's precision note (recorded, does not change the decision):** the non-simultaneity is
already priced into the max-DD and worst-day figures below — those are computed from the
aligned daily portfolio streams, not from summing stop-loss risks. The argument correctly
explains why 9.75 was never a DD number; it does not create headroom beyond what the DD
figures already show. The decision stands on the DD figures, and those support it.

## This is MORE conservative than an already-ratified OWNER decision

`decisions/2026-07-15_book_resize_to_10pct_dd_1pct_cap.md` (status: accepted) ratified exactly
this reasoning nine days earlier and set the target at **sum-risk 19.62% / ~9.7% realized
max-DD**, explicitly calling 9.75% "under-levered".

That decision was **never applied and never formally superseded**. The 24-sleeve weekend book
(07-17) and the Final-24 (07-19) both deployed at 9.75; neither decision document references
the resize. `decisions/REGISTRY.md` has no entry for it.

Consequence: 12.0% is not an escalation beyond ratified policy — it is a partial, conservative
step toward a target OWNER already approved. This gap should be closed explicitly: either
12.0 supersedes the 19.62 target, or 19.62 remains the standing target and 12.0 is an interim
stage. **Not decided here.**

## Kill limits (DXZ, account death if breached)

- **Daily DD 5%** (EUR 5 000) · **Total DD 20%** (EUR 20 000).
  Source: mission baseline (OWNER 2026-05-09), `decisions/2026-07-15_book_resize_to_10pct_dd_1pct_cap.md`.
- The all-simultaneous tail (every sleeve stops out on one day = the summed sleeve risk) must
  stay under 20%: such a day is account death, not a drawdown. At TOTAL_RISK 12.0 the tail is
  **12.0%**, i.e. 8 points under the total-kill.
- Correction on the record: an earlier chat statement in this session put the 5% limit on a
  *monthly* basis. It is **daily**. The monthly figures below are retained as context but are
  not the binding constraint.

## Computed result — live Final-24 composition, sealed basis, 2 028 days

Stream basis: `D:/QM/reports/portfolio/dxz_final_20260719` (24 sleeve streams, the same sealed
bundle the deployed manifest was built on).

| Metric | 9.75 (deployed) | **12.0 (this decision)** | Kill limit |
|---|---:|---:|---|
| Sharpe | 2.4091 | 2.3737 | — |
| Return, simple / CAGR | 8.98% / 6.99% p.a. | **11.40% / 8.43% p.a.** | — |
| Annualised vol | 3.73% | 4.80% | — |
| Realized max-DD (8 y) | 2.587% | **3.385%** | 20% total |
| Worst day | -0.857% | **-1.126%** | **5% daily** |
| p99 / p99.9 day | -0.578% / -0.852% | -0.737% / -1.119% | — |
| Days below -2% (of 2 028) | 0 | **0** | — |
| Days below -5% (of 2 028) | 0 | **0** | daily kill |
| All-simultaneous tail | 9.75% | **12.0%** | 20% total |
| Worst calendar month | -2.036% (2022-05) | -2.660% (2022-05) | — |
| Worst intra-month DD | 2.036% | 2.660% | — |
| Months with DD > 3% (of 99) | 0 | **0** | — |
| Sleeves at cap 1.0 | 1 | 3 | — |
| Simultaneously active: median / p95 / max | 2 / 6 / 11 | 2 / 6 / 11 | — |

Binding constraint is the daily kill: worst historical day -1.126% leaves a 3.87-point buffer
under -5%, a factor of 4.4. Realized max-DD 3.385% is a factor of 5.9 under the 20% total kill,
and still well under OWNER's own ~10% realized-DD target from 07-15.

Cost of the move: Sharpe -0.035. Cap redistribution pushes weight off the optimal inverse-vol
allocation as two more sleeves hit 1.0 — the deliberate no-concentration trade-off already
accepted on 07-15.

## Method and validation

Capped inverse-vol, CAP 1.0, identical algorithm to `gen_dxz_final_manifest.py`:
inverse-vol weights over daily net-of-cost PnL, scaled to TOTAL_RISK, sleeves exceeding the cap
clipped to 1.0 with the excess redistributed pro-rata by inverse-vol to uncapped sleeves,
iterated to convergence.

**Validation:** re-running the algorithm at TOTAL_RISK 9.75 reproduces the deployed manifest's
`risk_percent` for all 24 sleeves to within 5e-7 (rounding). The 12.0 figures come from the same
verified code path.

## Sleeve allocation 9.75 -> 12.0

Three sleeves sit at the 1.0 cap; the remaining 21 scale uniformly by x1.313.

| EA | Symbol | 9.75 | 12.0 | delta |
|---|---|---:|---:|---:|
| QM5_10919_grimes-overshoot | XTIUSD | 0.9181 | **1.0000** | +0.0819 (cap) |
| QM5_12567_cum-rsi2-commodity | XNGUSD | 0.9797 | **1.0000** | +0.0203 (cap) |
| QM5_13128_pre-fomc-drift-ndx | NDX | 1.0000 | **1.0000** | +0.0000 (cap) |
| QM5_12567_cum-rsi2-commodity | XAUUSD | 0.7465 | 0.9805 | +0.2340 |
| QM5_1556_aa-zak-mom12 | XAUUSD | 0.6017 | 0.7903 | +0.1886 |
| QM5_11165_weiss-rsi-ma | AUDCAD | 0.5230 | 0.6869 | +0.1639 |
| QM5_12969_usdjpy-gotobi-nakane-fix | USDJPY | 0.5100 | 0.6699 | +0.1599 |
| QM5_11708_anon-market-squeeze-d1 | EURUSD | 0.5080 | 0.6672 | +0.1592 |
| QM5_12778_edgelab-audusd-eurjpy-coint | AUDUSD | 0.4905 | 0.6442 | +0.1537 |
| QM5_11132_tm-cum-rsi2 | SP500 | 0.4562 | 0.5992 | +0.1430 |
| QM5_13117_eurgbp-audjpy | EURGBP | 0.4199 | 0.5515 | +0.1316 |
| QM5_11165_weiss-rsi-ma | EURUSD | 0.4127 | 0.5421 | +0.1294 |
| QM5_11421_ohlc-daily-squeeze-reversal | AUDUSD | 0.3614 | 0.4747 | +0.1133 |
| QM5_11421_ohlc-daily-squeeze-reversal | EURUSD | 0.3364 | 0.4418 | +0.1054 |
| QM5_10513_mql5-ichimoku | XAUUSD | 0.3050 | 0.4005 | +0.0956 |
| QM5_12989_grimes-nested-pb-v2 | XAUUSD | 0.2420 | 0.3178 | +0.0758 |
| QM5_10403_et-turtle20x | XAUUSD | 0.2204 | 0.2895 | +0.0691 |
| QM5_10939_grimes-context-pb | GBPUSD | 0.1887 | 0.2479 | +0.0592 |
| QM5_1567_demark-td-reverse-sequential | EURUSD | 0.1791 | 0.2352 | +0.0561 |
| QM5_10911_grimes-complex-pb | GDAXI | 0.1276 | 0.1675 | +0.0400 |
| QM5_13301_balke-minute-range-breakout | GDAXI | 0.0692 | 0.0910 | +0.0217 |
| QM5_10440_mql5-ohlc-mtf | NDX | 0.0577 | 0.0758 | +0.0181 |
| QM5_10706_tv-mon-ls | GBPUSD | 0.0530 | 0.0697 | +0.0166 |
| QM5_13213_balke-gmt3-range-breakout | USDJPY | 0.0431 | 0.0566 | +0.0135 |
| **Sum** | | **9.7500** | **12.0000** | |

## What this decision does NOT cover

1. **Whether the risk change ships with the 2026-07-26 recompile wave or separately.** That wave
   replaces all 24 live binaries (all pre-07-20 bundle; P0.1 deinit-kill live, KS channel dead on
   11 instances). Shipping both together saves a chart session but forfeits clean attribution if
   the book behaves differently in August. OWNER decision pending.
2. **Whether new sleeves join in the same wave.** Six admission-ready candidates exist (see
   `docs/ops/` candidate review); admitting sleeves changes the composition and therefore the
   whole allocation, so it cannot be layered on top of this table.
3. **The standing TOTAL_RISK target** — see the 07-15 gap above.
4. **Live-blend reweighting** (roadmap item, live vol replacing backtest vol as the allocation
   basis) remains open. This decision scales the existing backtest-vol-derived allocation.

## Application (when OWNER gives go)

1. Generate the manifest with the same generator pattern as `gen_dxz_final_manifest.py`, with
   `TOTAL_RISK = 12.0` and `weight_method = "capped_inverse_vol_cap1.0_total12.0"`, on the same
   sealed bundle. Composition unchanged.
2. Regenerate LIVE set files (ENV=live, RISK_FIXED=0, RISK_PERCENT per table, PORTFOLIO_WEIGHT=1.0)
   via `framework/scripts/gen_setfile.ps1`, named `NN_Symbol_TF_EA-Name.set` in chart order.
3. Staging + verify pass: SHA256 factory -> T_Live, magic registry (`ea_id*10000+slot`), set-file
   ENV/risk-mode, news calendar present and current.
4. Written OWNER approval of the manifest.
5. Chart session per the standing go-live procedure (MT5 restart, preset reloads in NN order,
   closing restart, then parse `Profiles/Charts/<profile>/*.chr` for deterministic N/N
   verification against the manifest plus a sum check).
6. AutoTrading toggle: OWNER or Claude only.
7. Update the live-book DD guard HWM seed if the equity base has moved.

## Evidence

- Reweight computation and validation: `scratchpad/reweight12.py` (session artifact) against
  `D:/QM/reports/portfolio/dxz_final_20260719`
- Deployed baseline: `D:/QM/reports/portfolio/portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json`
- Deployed book decision: `decisions/2026-07-19_t_live_dxz_sunday_final_book.md`
- Unapplied resize target: `decisions/2026-07-15_book_resize_to_10pct_dd_1pct_cap.md`
- Kill limits: mission baseline (OWNER 2026-05-09)
