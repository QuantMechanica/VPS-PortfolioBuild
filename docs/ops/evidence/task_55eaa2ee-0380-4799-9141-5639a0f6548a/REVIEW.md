# Basket marginal-book input contract (41112/41119): rework 1/3

Task: `55eaa2ee-0380-4799-9141-5639a0f6548a` · Reviewer: Claude (Opus), one pass, no provider call, no Kimi retry.
Supersedes the contract part of `KIMI_DELIVERY.md` and carries out the corrections in
`docs/ops/evidence/2026-09-26_astra_takeover/basket_marginal_method_review/REVIEW.md`.

**Verdict: READY_CONDITIONAL for one encoding only: split full-risk leg sleeves in paired
full-roster `book_sim` runs. REQUIRES_BOUNDED_CHANGE before the governed
`marginal_contributions` command or its concentration/expectancy fields can be used for a basket.**
The whole-basket single-sleeve encoding is rejected because its loss-rule proxy understates the daily low.
The split half-risk encoding is rejected because it halves exposure. Nothing should run today:
41112 is Q08 `FAIL_HARD` (work item `21b31c7c`), so it gets no marginal simulation as a failed parent.
41119 is Q08 `pending` (`795b0250`) and has no authenticated closure stream.

## Brief check (done before execution)
The rendered task prompt contains `REVIEW.md`, `counterexample.json`, `46.875`, `23.4375`,
`money_basis` and `No further Kimi retry`. Sources hash-match the reviewed versions:
book_sim `4a02c63a…`, financing_lib `89723c36…`, ftmo_cost_adjusted_export `871a148c…`
(canonical HEAD `d8eb22d9`).

## Numeric evidence
`consumer_contract_check.py` → `consumer_contract_check.json` (sha256 `4aeb73d2…`). It runs one
synthetic basket through the actual `prepare_sleeve`, `account_path_metrics`,
`_to_first_passage_roster` and `fp.build_grid`, using the real `live_commission.json`.
Fixture: XAU leg profit +500 / MAE −100, XAG leg −300 / MAE −800. Both legs close at the same
instant. Basket risk is r = 0.15625 %, source risk is 1.0 %. All 14 checks are true.

| Encoding | net (scaled) | worst daily low (account path = fp grid) | book_risk_percent | BOOK_EXPECTANCY |
|---|---|---|---|---|
| A whole basket, XAU row first | 29.921875 | **−48.203125** | 0.15625 | 0.09575 |
| B whole basket, XAG row first | 29.921875 | **−125.585938** | 0.15625 | 0.09575 |
| D split legs, each r | 29.921875 | −141.953125 (= per-leg envelope) | **0.3125** | 0.09575 |
| E split legs, each r/2 | **14.960938** | −70.976562 | 0.15625 | 0.09575 |

The correct per-basket expectancy for this fixture is 29.921875 / 156.25 = 0.1915.

## Corrections to the prior delivery
1. **Risk normalization.** Native leg rows already share the basket's single $1000 (1 %) source risk.
   `prepare_sleeve` (factor = `risk_percent / SOURCE_RISK_PERCENT`) and `fp.build_grid` (factor =
   `risk_pct / SOURCE_RISK_PCT`) scale each sleeve independently. Legs therefore need
   `risk_percent = r` each to keep the money right (D = A). Legs at r/2 halve exposure (E = A/2), so the
   Kimi contract is withdrawn. "Two full-risk sleeves" is correct in money terms only. The
   nominal metadata is still wrong, as set out in the gaps below.
2. **money_basis.** The writer `framework/include/QM/QM_Common.mqh:1908` emits
   `money_basis=FULL_POSITION_LIFECYCLE_ACTUAL_V1` along with `profit`, `swap`, `fee`, `commission`,
   `entry_commission`/`exit_commission` and `net = profit + swap + commission`. The earlier claim
   that the raw export has no money basis was wrong. It has no **risk-money** field.
3. **Commission.** `prepare_sleeve` rebuilds net from `profit` and ignores native `net` and
   `commission`. The registry commission therefore replaces the native one and is not charged twice
   (prior counterexample: 90, not 80). `write_financed_stream` rewrites `swap` and `net` and leaves
   `profit` alone, so financing is also replaced, not stacked.
4. **Seeds.** There are three separate contracts:
   - Q07 entry-rejection seeds are strategy-stress exports and are never a baseline.
   - Book Monte Carlo seeds are the block-bootstrap `seed` in `evaluate_book`/`fp.build`, plus the
     `seed..seed+4` replicates in `marginal_contributions`.
   - Cost arms are `CostConfig` settings.

   None of these can stand in for another.

## Point 1: producer/consumer contracts
- **Leg symbol.** *Established:* each row carries a real `symbol` and its own magic. Every consumer
  costs a row by `spec.symbol`, never by `row['symbol']` (`_commission_for_trade`, `_trade_swap`,
  `_symbol_cost`). *Measured:* XAU and XAG are both class `commodity` (5e-5 notional, flat 0). Under
  that class, commission and the governed uniform stress arm (+1 bps, $2/lot) are unaffected by which
  symbol hosts the sleeve (A = C, U = V). A per-symbol stress table does change the result
  (whole 26.92 vs split 24.20).
  *Hazard:* the work-item label `QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1` normalizes into the
  default `forex` class. On the 1-lot/10k test row it is charged 5.00 instead of 0.50. Roster
  rows must use DWX leg symbols.
- **Cost/money basis.** *Established:* see corrections 2 and 3. Configured spread/slippage is
  an additive venue delta on top of Darwinex-embedded fills.
- **Source risk.** *Established:* linear scaling per sleeve (correction 1). *Assumed:* the EA sizes the
  basket to an aggregate $1000. This rests on the SPEC/packet statement and has not been reconciled
  against row MAE.
- **Timestamps.** *Established:* rows carry MT5 `DEAL_TIME`/entry datetimes (server clock) as
  integers. Both consumers treat them as UTC epochs and bucket by Europe/Prague. Every incumbent
  stream shares this convention. It is the known unmeasured clock/DST mapping and is not a basket
  defect.
- **MAE.** *Established:* `mae_acct` is the worst floating `POSITION_PROFIT + POSITION_SWAP`, capped at
  the commission-inclusive net. `prepare_sleeve` subtracts the target commission again, which is
  conservative only in the capped case. The financed writer only makes MAE worse.

## Point 2: findings per encoding
- **Whole basket (one sleeve, mixed rows): rejected, loss-rule shortcut.** `_daily_sleeve` and
  `fp.sleeve_daily` sum same-day trades in sequence as `cum + mae`, then `cum += net`. Two legs that
  close together therefore offset one leg's trough with the other leg's *realized* net. The daily
  low depends on row order (−48.2 vs −125.6). Both are less severe than the per-leg envelope (−142.0),
  which contradicts `PROXY_LABEL` (`CONSERVATIVE_SIMULTANEOUS_ACTIVE_MAE_ENVELOPE`). The error flows
  straight into the fp breach probabilities and the payout LCB. Concentration also books all basket
  risk to the host symbol.
- **Split legs at r each: READY_CONDITIONAL.** Money is correct. The daily low equals the conservative
  per-leg envelope in both consumers. Per-leg commission, stress and financing identities are correct.
  The account caps are unchanged: 5 %/10 % is tested on the summed book. Demonstrated gaps:
  - (a) `_concentration` and `book_risk_percent` count the basket twice (0.3125 vs 0.15625). The
    same doubled figure would reach `genesis_manifest` `total_book_risk_percent`.
  - (b) `marginal_contributions` "add" takes exactly one `SleeveSpec` per plan row. Both legs
    cannot be added, risk-swept or ex-top3-tested atomically, and a lone leg is a naked metals
    position.
  - (c) The dependence matrix and the dominant-sleeve breach attribution split the basket into legs.
  - (d) Legs are not deployable units: one EA instance and one risk input trade both legs.
- **All encodings: denominator.** `BOOK_EXPECTANCY` divides by `1000·risk·rows`, so basket expectancy
  comes out halved (0.09575 vs 0.1915). This is a reporting field only.
- **Not found:** no double commission, no double financing and no money double-risk in the
  split-at-r encoding.

## Point 3: minimum next evidence and command (only after an authenticated 41119 Q08 closure)
1. Seal the closure stream. Reconcile per row: `net = profit + swap + fee + commission`, commission
   split, row count against the tester report. Keep failed history.
2. Split rows by `symbol` into `41119_XAUUSD_DWX.jsonl` and `41119_XAGUSD_DWX.jsonl`. Run
   `write_financed_stream(symbol=<leg>)` on each and record both sha256s and their sealed stats.
3. Build two rosters: the frozen D2g6 roster, and a roster with D2g6 plus both legs at r. If the
   test is a reallocation, the second roster lowers named incumbent risks so the summed
   *money* risk is unchanged. Run each through `book_sim.py --roster … --financed-streams <root>` (no
   `--candidate-plan`). `<root>` holds byte-identical, sha-checked copies of the D2g6 financed
   streams plus the two leg files. Use the same fixed window and run once per `--seed` from
   20260921 to +4, in the normal arm and the governed uniform stress arm.
4. Recompute concentration, expectancy and symbol risk out of band, counting the basket once.
   Report only research deltas: P80, payout LCB, breach probabilities and dependence. Admission and
   the full calendar-to-cash KPI are out of scope. Stress fails on both books are reported as a
   system-wide finding.

## Point 4: paired plan
Run identical seeds, window, engine and cost arm across:
- Arm 0: D2g6.
- Arm A ("add"): D2g6 plus legs at r. Money risk goes up by r.
- Arm R ("reallocate"): D2g6 with r taken off named sleeves, plus legs at r. Account caps unchanged.

For each arm report ΔP80, ΔLCB with its replicate SE, Δbreach, legs-combined daily
correlation and lower-tail ratio against the XAU cluster (10403/10700/41219). If payout-ever
LCB < 0.80, no P80 is published.

## Highest-value next action
None runs now. Open one bounded engineering ticket only once 41119 has an authenticated Q08
closure: a `marginal_contributions` sleeve group with a shared risk allocation and single-count
concentration/expectancy. Until then the paired full-roster runs above are the lawful route.
No strategy, risk, pipeline, Shadow or KPI state was changed.
