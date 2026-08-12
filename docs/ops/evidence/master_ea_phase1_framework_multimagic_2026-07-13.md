# Master-EA Phase 1 — Framework Multi-Magic Design Note

Date: 2026-07-13
Branch: `agents/codex-master-ea-p1`

## Scope

Phase 1 adds opt-in, per-strategy magic and percentage-risk support to the V5
entry path. It does not add a master EA, dispatcher, registry row, or strategy
module.

The intended call pattern after `QM_FrameworkInit` is:

```cpp
const int strategy_magic = QM_MagicFor(sub_ea_id, sub_slot);
QM_TM_OpenPosition(req, out_ticket, strategy_magic, strategy_risk_percent);
```

## Functions changed

- `QM_MagicFor(ea_id, slot)` resolves through `QM_MagicChecked` and,
  after framework initialization, deduplicates the resolved magic in the
  instance's owned-context list. It fails before initialization so it cannot
  return a tradeable-but-unowned context.
- `QM_FrameworkOwnsMagicSymbol` recognizes registered sub-strategy contexts.
  `QM_FrameworkCloseAllOwnedPositions` retains its old single-magic fast path
  when no contexts exist and uses the ownership walk when contexts are present.
  Contexts reset on initialization and shutdown.
- `QM_KillSwitchRegisterMagic` adds those same opt-in contexts to the shared
  kill switch. Initial trips and halted-state retries flatten positions and
  delete pending orders for the host plus every registered sub-magic. The
  distribution-divergence emergency path deletes those pendings immediately.
- `QM_TM_OpenPosition` and `QM_Entry` have trailing optional
  `explicit_magic` and `explicit_risk_percent` parameters. A positive magic is
  accepted only when it is the host magic or a context registered by
  `QM_MagicFor`, then copied unchanged into `MqlTradeRequest.magic`, so the
  opening order/deal retains the original sub-EA identity.
- `QM_RiskSizerRiskMoney(equity, explicit_risk_percent)` and
  `QM_LotsForRisk(symbol, sl_points, explicit_risk_percent)` add the opt-in
  percentage path without mutating global risk configuration. Portfolio weight,
  the configured per-trade money cap, volume quantization, and margin ceiling
  still apply.
- `risk_sizer_smoke.mq5` covers explicit percentage sizing, non-mutation of the
  legacy configuration, and the hard-cap case.

The q08 history walk and stream serialization were not changed. Registered
contexts make their opening deals framework-owned, and the explicit magic is on
the opening deal used by the existing two-pass attribution.

Review note for the later integration gate: the current framework JSONL writer
collects owned position IDs but does not serialize their opening magic; it writes
one host-EA file. Per-magic regression must therefore read opening-deal history
directly, or a later scoped change must add the opening magic to each q08 row.
That serializer change is intentionally excluded here because the Phase 1 brief
explicitly required q08 to remain unchanged.

## Backward compatibility

Existing two-argument `QM_TM_OpenPosition`, `QM_Entry`, and `QM_LotsForRisk`
calls compile unchanged. Their optional values are zero, which preserves the
existing behavior:

- magic still resolves with
  `QM_MagicChecked(g_qm_entry_ea_id, req.symbol_slot, _Symbol)`; this deliberately
  preserves existing same-EA multi-slot/basket behavior;
- sizing still calls the untouched two-argument `QM_LotsForRisk`, including
  fixed-money mode;
- the additional ownership list is empty unless an EA explicitly calls
  `QM_MagicFor` after initialization;
- the legacy single-symbol close and kill-switch paths remain selected when
  that list is empty.

No process-wide magic or risk setting is temporarily overwritten, so an
explicit call cannot leak its context into a later default call.

## Verification

- Explicit-risk unit fixture strict compile: PASS, 0 errors / 0 warnings.
  - Log: `C:\QM\worktrees\codex-master-ea-p1\framework\build\compile\20260713_093041\risk_sizer_smoke.compile.log`
  - Summary: `D:\QM\reports\compile\20260713_093041\summary.csv`
- Required force rebuild of `QM5_12567_cum-rsi2-commodity`: PASS, 0 errors /
  0 warnings.
  - Log: `C:\QM\worktrees\codex-master-ea-p1\framework\build\compile\20260713_093123\QM5_12567_cum-rsi2-commodity.compile.log`
  - Summary: `D:\QM\reports\compile\20260713_093123\summary.csv`
- Required non-breakage smoke: PASS, 11 trades.
  - XAUUSD.DWX, D1, 2025, Model 4, T6, one run, minimum 1 trade
  - Net profit: $2,247.62; profit factor: 4.40
  - Summary: `D:\QM\reports\smoke\QM5_12567\20260713_093206\summary.json`
  - Evidence: `D:\QM\reports\framework\22\20260713_093206_QM5_12567_T6_XAUUSD_DWX_run_smoke.md`

Per the task delegation, Claude will run the authoritative 2017–2025
cent-exact gate (73 trades / $4,676.76) after review. No live terminal or
`T_Live` path was used.
