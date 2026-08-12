# Independent review — Wave-2 framework defect audit items 1–3

Router task: `5f860f79-dfb8-4188-aa80-1890aa606ef1`  
Review scope: items 1–3 in
`docs/ops/FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md`  
Implementer: Claude  
Independent reviewer: Codex  
Verdict: **RECYCLE / changes required**

Router closure confirmed at `2026-07-20T16:43:23+00:00`: state `RECYCLE`,
artifact path bound to this document, and the verdict records item 1 as the
blocking failure while items 2–3 pass their scoped review.

## Blocking finding — item 1 does not preserve configured state across restart

The configured FTMO anchor is documented as a post-init setter. That call order
cannot restore its own persisted state:

1. A new terminal process starts with the global anchor configuration at its
   defaults: offset `0`, `use_max_balance_equity=false`.
2. `QM_KillSwitchInit` computes the default day/anchor and calls
   `QM_KillSwitchRestoreState` at line 490.
3. A valid same-day file saved by the configured preset contains offset `-1` and
   max-B/E `true`. Restore rejects it at lines 199–201 because its configuration
   does not match the still-default globals.
4. `QM_KillSwitchInit` then unconditionally calls `QM_KillSwitchSaveState` at
   line 491. That truncates/replaces the valid configured file with the fresh
   default anchor and `halted=false`.
5. The documented `QM_KillSwitchSetDayAnchor(-1, true)` call later invokes restore
   at line 553, but now sees the default-config file written in step 4, rejects it,
   and saves the new fresh anchor. The prior daily halt and depletion baseline
   are gone.

This is the exact restart path item 1 claims to protect. The later round-trip
hardening in `841449513` added the configuration match, but the init/save/setter
lifecycle makes that match destructive under non-default configuration.

Deterministic source-order/model proof:

```json
{
  "init_restore_line": 490,
  "init_save_line": 491,
  "setter_restore_line": 553,
  "setter_save_line": 554,
  "first_restore_matches": false,
  "persisted_after_init_save": {
    "offset": 0,
    "max_be": false,
    "halted": false,
    "anchor": 94000.0
  },
  "setter_restore_matches": false,
  "configured_halt_restored": false
}
```

Required before approval:

- Make the selected anchor configuration available before the first restore/save,
  or otherwise guarantee that init cannot overwrite a mismatched persisted file
  before the post-init setter can consume it.
- Add a regression test for a same-day persisted `offset=-1`, `max_be=true`,
  `halted=true` state across the documented `Init` + `SetDayAnchor` restart
  sequence. It must retain both the halt and the original day-start baseline.
- Retain a default-anchor restart case so the correction does not regress existing
  users.

Per the implementation/review separation rule, the reviewer did not modify the
kill-switch implementation.

## Item 2 — live compliance axis: review PASS within scoped claim

Current code applies temporal and compliance axes with AND semantics, fails
closed when live calendar reads/metadata fail, uses the same min-impact filter
and per-impact FTMO/5ers tables as the tester path, and filters events by the
symbol's currencies. The ±60-minute native query bounds the current rules
(maximum table value is five minutes). The MQL5 reference confirms that native
calendar timestamps and query bounds use trade-server time:
<https://www.mql5.com/en/docs/calendar/calendarvaluehistory>.

Later E5/E10 changes are present in current code, but they are not used to widen
this review beyond item 2's compliance-axis claim.

## Item 3 — filling-mode resolution: review PASS within scoped claim

Current framework order paths resolve FOK/IOC from `SYMBOL_FILLING_MODE`, and
pending requests use `ORDER_FILLING_RETURN`. Direct `OrderSend` calls are
centralized through `QM_TradeContextSend`; Entry, BasketOrder, TradeManagement,
Exit, Grid, and kill-switch close paths set a filling policy. The MQL5 symbol
property reference explicitly requires RETURN for pending orders regardless of
execution mode:
<https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants>.

## Validation and limits

```text
python -m pytest -q
  tools/strategy_farm/tests/test_basket_order_helper_static.py
  tools/strategy_farm/tests/test_news_filter_fresh_boundary_static.py
11 passed, 2 subtests passed
```

The review also inspected implementation commits `eb5195a14`, `fadd5eaf8`, and
`ce7516286`, plus current follow-up hardening and every direct framework
`OrderSend` call. Items 4 onward remain design/register work and were explicitly
outside this closure scope.

Factory workers and the pump were active, so no reviewer-launched MetaEditor,
tester, or manual execution session was started. The implementer's historical
compile claim was not substituted for independent acceptance of item 1.
