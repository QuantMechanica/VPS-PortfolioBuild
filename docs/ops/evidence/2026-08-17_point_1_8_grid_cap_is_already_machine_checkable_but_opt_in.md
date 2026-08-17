# Point 1.8 — the 1 % grid bound is already machine-checkable, and its one real gap is that it is opt-in

Covers the v4 brief's 1.8 and prepares decision D3. Inventory before building paid off a third time
today: **the machine-checkable form D3 asks for already exists in code.** What is missing is
narrower and more specific than "define the rule".

---

## First, the "Sofort": nothing was lost

| EA | card on disk | EA dir | source | magic rows |
|---|---|---|---|---:|
| QM5_30001 | yes | yes | 126-line skeleton, `"Unknown Strategy"` | **0** |
| QM5_30005 | yes | yes | skeleton (4,085 B, identical) | **0** |
| QM5_30006 | yes | yes | skeleton | **0** |
| QM5_38007 | yes | yes | skeleton | **0** |

All four approved cards are intact in `cards_approved/`, all four EA directories exist. **No card
was deleted and nothing needs recovering.** What is missing is the magic allocation and the actual
build — the directories hold generated skeletons, not implementations. The registry transaction that
blocked allocation is now **clean**, so restoration is unblocked.

---

## D3 answered against the code, not against opinion

DL-081 sets the invariant and `framework/include/QM/QM_TM_Grid.mqh` implements it in **two layers**:

### Layer 1 — config time, `QM_GridValidateConfig` (`:147`)

Computes the worst case **from the actual grid schedule** (`QM_GridWorstCaseLossMoney`) and rejects
fatally:

```
cap_money = cfg.starting_equity_snapshot * (cfg.worst_case_loss_cap_pct / 100.0)
if (worst > cap_money) -> QM_FATAL EA_GRID_RISK_EXCEEDED {"reason":"worst_case_exceeds_cap"}
```

plus hard caps on `max_levels` and `geo_multiplier`. This is materially stronger than "declared in
the card": it is derived from the configuration that will actually trade.

### Layer 2 — runtime, `QM_GridMaxDrawdownGuard` (`:412`)

```
QM_GridAggregateFloatingPnL()  // sums POSITION_PROFIT + POSITION_SWAP across open levels
if (floating < -cap_money) -> QM_FATAL {"reason":"floating_loss_exceeds_cap"}
```

### So D3's three questions have answers already

| D3 question | answer in code |
|---|---|
| **1 · reference quantity** | **aggregate floating P&L across all open grid levels, swap included**, against `starting_equity_snapshot × cap_pct`. Not per-trade, not per-declared-basket. Matches DL-081: *"once basket floating P&L hits −1 %, everything closes… a more aggressive martingale simply hits the −1 % stop sooner; it cannot raise the cap."* |
| **2 · measurement point** | **both** exist — computed-from-schedule at init, and observed floating P&L at runtime. So the choice in the brief ("declared maximum vs observed maximum") is a false alternative: the implementation already does the stronger thing. |
| **3 · book level** | **not addressed.** The cap is per-EA against that EA's own equity snapshot. N grid EAs on one account each permit 1 %, so the account-level exposure is N × 1 %. |

---

## The one real gap, and it is prospective rather than historical

`QM_GridMaxDrawdownGuard`'s own comment states the problem:

> *"Guard that the strategy **must call on every tick**"*

**Nothing enforces that it is called.** A grid EA that omits the call passes config validation, trades
a bounded-by-construction schedule, and then has **no runtime bound at all** if price moves against
it beyond the schedule's assumptions. That is the unwired-input failure class, at the one place where
the consequence is an uncapped loss.

Measured, so the scope is honest:

```
EAs calling QM_GridInit               : 0 of 3,697
EAs calling QM_GridMaxDrawdownGuard   : 0 of 3,697
```

**This is a prospective gap, not an existing exposure.** No grid EA has ever been built, so the
module has never been exercised in production. It is catchable before the first one ships — which is
exactly now, because DL-082 authorises four of them.

---

## What I propose as the machine-checkable fassung (for D3)

Three checks, all mechanical, no new measurement machinery needed:

1. **Build check — wiring.** Any EA whose card declares grid/martingale/averaging must call both
   `QM_GridInit` and `QM_GridMaxDrawdownGuard`, the latter on the tick path. Fail the build
   otherwise. This is the same shape as the existing unwired-input check and closes the only gap.
2. **Config check — already implemented.** `QM_GridValidateConfig` stays as-is; it is the stronger
   of the two measurement points the brief contemplated.
3. **Evidence check — post-backtest.** Assert that no run of a grid EA logged
   `floating_loss_exceeds_cap`, and record the observed maximum aggregate floating loss as a
   percentage. This turns the runtime invariant into evidence rather than an assumption, and it
   gives 5.4 the per-class number it needs.

### Two questions the code raises that D3 did not, and that I am not deciding

**(a) `starting_equity_snapshot` vs current equity.** The cap is measured against equity captured at
`QM_GridInit` (`:289 AccountInfoDouble(ACCOUNT_EQUITY)`). Over a 60-day FTMO window with drawdown,
1 % of *starting* equity is a growing fraction of *current* equity — while FTMO's own limits are
measured against balance-at-day-start (daily) and `STATIC_INITIAL` (total). The mismatch is small
per cycle and compounding across a challenge. Worth an explicit choice.

**(b) Book-level aggregation.** Per-EA 1 % does not compose. If 5.2 selects three grid sleeves, the
book permits 3 % of simultaneous grid drawdown before any single guard fires. This belongs to 5.3,
but it must be a *constraint fed into selection*, not a check applied afterwards — otherwise 5.2 can
build a roster that 5.3 then has to reject.

---

## And the caveat that argues for admission rather than against it

Grid/martingale changes the **shape** of the drawdown curve: long runs of small gains, then one
large loss. That is precisely the profile that looks strong over 1,349 days and breaks a 60-day
window. So admitting the class makes 5.4's failure decomposition **more** important, not less —
daily-limit, total-limit and timeout failures must be reported separately for grid sleeves, because
their failure mode concentrates in exactly one of those three buckets.

## Deliberately not done

No build check implemented, no card rebuilt, no magic allocated. The wiring check is a framework
change and belongs to the build lane; implementing it while proposing its specification would put an
unreviewed rule into the verdict path.

## Evidence

- `decisions/DL-081_bounded_grid_basket_risk_capped_exception.md` — the invariant
- `decisions/DL-082_grid_cap_extended_commercial_ea_deconstructions.md` — ADOPTED 2026-08-16
  19:49:29 UTC (`e265e2a44`), scope = these four cards
- `framework/include/QM/QM_TM_Grid.mqh:120,147,289,393,412` — worst-case, config validation, equity
  snapshot, aggregate floating P&L, runtime guard
- `framework/include/QM/QM_Errors.mqh:18` — `EA_GRID_RISK_EXCEEDED`
- wiring census: 0 of 3,697 EA sources call `QM_GridInit` or `QM_GridMaxDrawdownGuard`
- card/dir/source/magic inventory for all four DL-082 EAs
