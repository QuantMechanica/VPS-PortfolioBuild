# DL-087 broad symbol allocation — task 9d2cd6f5

Date: 2026-08-17  
Branch: `agents/board-advisor`  
Router task: `9d2cd6f5-2099-43f7-9cb2-a0626bd58b9a`  
Verdict: `PARTIAL_SAFE_FOR_REVIEW`

## Outcome

Implemented DL-087 in the governed allocator and allocated every identity-clean
legacy-format card. The exact result is:

- Magic rows allocated: **1,144/1,365**.
- EAs allocated: **88/105**.
- Q02 rows enqueued by this operation: **0/1,144 allocated**.
- Blocked by pre-existing EA identity collisions: **17 EAs / 221 rows**.

The 17 blocked EAs were not silently attached to the active strategies that
already own their numeric IDs. Allocating those rows under the worklist slug
would violate the deterministic EA identity registry and make the resolver
represent the wrong strategy.

## Implemented rule

`tools/strategy_farm/governed_magic_allocator.py` now recognizes exactly the
105 entries in `artifacts/fleet_magic_allocation_worklist_20260817.json` whose
`target_symbols_from_card` is empty. The worklist count must be exactly 105 or
the allocator fails closed.

For those entries only, slots are assigned in this exact DL-087 order:

1. GDAXI.DWX
2. NDX.DWX
3. SP500.DWX
4. UK100.DWX
5. WS30.DWX
6. XAUUSD.DWX
7. EURUSD.DWX
8. GBPUSD.DWX
9. USDJPY.DWX
10. USDCHF.DWX
11. AUDUSD.DWX
12. USDCAD.DWX
13. NZDUSD.DWX

Before planning or applying a DL-087-only run, all 13 symbols are re-read from
`framework/registry/dwx_symbol_matrix.csv`. The allocator requires the expected
asset class and `canonical_name_verified=true`; all 13 passed at allocation
time.

No card-declared candidate outside the exact 105 receives this broad set.
`QM5_31003` remains separately withheld by active farm holds.

## Discovery-only marking

No Q02 rows were enqueued. When later bounded enqueue work consumes the apply
receipt, every generated work-item payload must copy this contract:

```json
{
  "allocation_authority": "DL-087",
  "exploratory_symbol_assignment": true,
  "result_authorization": "DISCOVERY_NOT_CARD_VALIDATED",
  "requires_card_amendment_for_downstream": true
}
```

This is embedded in both allocator reports as
`dl087.discovery_payload_contract`. It makes a Q02 PASS a discovery only; a
card amendment is required before downstream treatment as an authorized
card-symbol result.

## Applied rows and resolver proof

The single serial transaction allocated 88 EAs × 13 symbols = 1,144 rows.

- Registry rows: 16,171 → 17,315.
- Resolver rows: 16,140 → 17,284.
- Resolver drops: 0.
- New rows present after regeneration: 1,144/1,144.
- Magic formula: PASS for every new row.
- Slot order: PASS for every allocated EA.
- Resolver composite-key order: PASS.

Durable reports:

- `docs/ops/evidence/9d2cd6f5_dl087_allocation_dry_run_2026-08-17.json`
- `docs/ops/evidence/9d2cd6f5_dl087_allocation_apply_2026-08-17.json`

## Identity collision block

| Worklist ID | Worklist slug | Active registry slug |
|---|---|---|
| QM5_1401 | harmonic-shark-xabcd-h4 | as-caa-offensive |
| QM5_1402 | harmonic-cypher-xabcd-h4 | as-caa-defensive |
| QM5_1485 | bw-awesome-oscillator-saucer-h4 | as-haa-simple |
| QM5_1553 | hopwood-bermaui-rsi-mtf-h4 | aa-comm-term-mom |
| QM5_1562 | demark-td-range-projection-h4 | aa-comm-spot-rev |
| QM5_1582 | ehlers-super-smoother-h4 | aa-smi-cot-timing |
| QM5_1585 | demark-td-differential-h4 | aa-spx-util-risk |
| QM5_1604 | sperandeo-123-reversal-h4 | aa-mom-ex3-filter |
| QM5_1605 | ehlers-spectral-dilation-h4 | aa-jan-yc-risk |
| QM5_1636 | sperandeo-3day-pivot-rule-h4 | mql5-adx-di-trend |
| QM5_9165 | tv-joovier-london-session-breakout | aa-overprice-win |
| QM5_9167 | tv-boswaves-supertrend-extensions | aa-deep-value-spread |
| QM5_9168 | tv-elaris-confluence-scalping | aa-goodwill-roa |
| QM5_9169 | tv-mou-triple-lens-mtf | aa-employee-sat |
| QM5_9280 | brooks-failed-triangle-h4 | mql5-dpo-zero |
| QM5_9281 | demark-td-demand-supply-line-h4 | mql5-dpo-ma-validate |
| QM5_9282 | demark-td-stress-h4 | mql5-keltner-rebound |

These require deterministic EA-ID reallocation/card amendment before their
remaining 221 rows can be added. That repair was not authorized by DL-087 and
was not inferred here.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_governed_magic_allocator.py \
  framework/scripts/tests/test_magic_resolver_binary_search.py \
  framework/scripts/tests/test_magic_resolver_strict_default.py -q
13 passed

python framework/scripts/update_magic_resolver.py --dry-run
PASS (17,284 rows kept; no drops)

Focused DL-087 verification
allocated_eas=88
allocated_rows=1144
resolver_rows_verified=1144
slot_order=PASS
formula=PASS
matrix=13/13 PASS
enqueued_by_allocator=0

git diff --check -- <explicit task paths>
PASS
```

No Q02 work item was enqueued, no gate or factory state was changed, no
terminal was started or interrupted, and neither T_Live nor AutoTrading was
enabled.
