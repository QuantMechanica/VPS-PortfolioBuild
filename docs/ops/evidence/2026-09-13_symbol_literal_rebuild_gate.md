# Symbol-literal repair at the natural rebuild — build gate + first five patches

**Date:** 2026-09-13
**Author:** Claude (build-tooling)
**Rule owner:** OWNER (2026-09-13, on top of the 2026-09-06 Hard Rule)

## Rule

Hard Rule (OWNER 2026-09-06): **symbols are inputs, never code literals.** `.DWX`
is only the factory custom-symbol suffix; live (Darwinex Zero) and FTMO charts
carry the bare broker name. Two source shapes silently break live behaviour and
are the target of the fail-closed lint `framework/scripts/lint_ea_symbol_literals.py`:

- `symbol_literal_comparison` — an `==`/`!=` comparison against a `"<NAME>.DWX"` literal.
- `symbol_literal_global` — a mutable global scalar `string x = "<NAME>.DWX";` later
  used in a comparison (the literal hides one hop away).

OWNER 2026-09-13: the debt is repaired **only at the natural rebuild.** Whenever an
EA is (re)compiled through the factory build gate, its source must be free of these
lint violations, otherwise the build is refused with a clear reason class and the
`REVIEW_REWORK` source-repair authority in `tools/strategy_farm/compile_work_items.py`
takes over. Mass rebuilds are forbidden (a rebuilt `.ex5` is a new identity), so this
gate is the **only** place the legacy debt shrinks.

## Mechanism

`framework/scripts/build_check.ps1` — new block `EA_SYMBOL_LITERAL_REBUILD_GATE
(OWNER 2026-09-13)`, placed directly after the existing `EA_SYMBOL_HARDCODED` block
and in the same style. When an `$EALabel` is being checked it runs:

```
python -X utf8 framework/scripts/lint_ea_symbol_literals.py --ea-root <the EA's own directory>
```

- lint exit 0 (clean) -> nothing; the EA's debt is gone.
- lint exit 1 (violations) -> `Add-Failure "EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX:
  <n> violation(s) in <ea label>; symbols are inputs (OWNER 2026-09-06); repaired at
  the natural rebuild (OWNER 2026-09-13); run framework/scripts/lint_ea_symbol_literals.py
  --ea-root <dir>"`. `<n>` counts the `symbol_literal_comparison` / `symbol_literal_global`
  lines returned for that EA.
- lint tool missing, or any exit code other than 0/1 -> `Add-Failure
  EA_SYMBOL_LITERAL_REBUILD_SCANNER_FAILED` (**fail closed**, like the neighbouring
  `EA_SYMBOL_HARDCODED_SCANNER_FAILED`).

The distinct `_REBUILD_GATE`/`ratchet` split: the pre-existing `EA_SYMBOL_HARDCODED`
inventory scanner (`ea_symbol_literal_inventory.py`) still FAILs post-cutover files and
WARNs the 1326 pre-cutover WARN findings; this new gate additionally enforces the
narrower, live-breaking lint (b) at each compile. The existing block is unchanged.

### Rollback

`QM_SYMBOL_LITERAL_REBUILD_GATE=0` downgrades the refusal to a warning (same text plus
`gate disabled by env`). Backtests are never blocked by this env; the gate only runs at
the compile phase of the build check.

## Verification

- `powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw
  framework/scripts/build_check.ps1)) | Out-Null"` -> exit 0 (parses).
- New test `tools/strategy_farm/tests/test_build_check_symbol_literal_rebuild_gate.py`
  (slices the gate block into a harness with stub Add-Failure/Add-Warning): 4/4 pass —
  violating EA -> one `_REQUIRES_FIX` failure; clean EA -> nothing; env `=0` ->
  warning not failure; missing lint tool -> `_SCANNER_FAILED`.
- Neighbouring `test_buildcheck_predicate_fix.py`: 19/19 still pass (no regression).

## The five EAs patched (all pending their FIRST compile)

Confirmed read-only against `farm_state.sqlite`:
`SELECT count(*) FROM work_items WHERE ea_id=? AND phase='COMPILE_EA' AND
verdict='COMPILE_OK'` = **0** for every one, so patching the `.mq5` does not recompile
an EA of established identity. Only the `.mq5` sources were touched (never set files),
and default symbol values are kept equal to the previous literals, so backtests are
unchanged. Comparisons now use the canonical base-name compare `QM_MagicSymbolCanonical`
(defined `framework/include/QM/QM_MagicResolver.mqh:134`, reachable via `QM_Common.mqh`),
which strips `.DWX` and maps the FTMO oil alias `USOIL -> XTIUSD`, so a live bare-name
chart matches.

| EA | shape fixed | lint before | lint after |
|----|-------------|-------------|------------|
| QM5_41113_xauxag-mhalfagree-rv | g_leg_xau/g_leg_xag globals -> inputs (`strategy_xau_symbol`/`strategy_xag_symbol`), InputsValid compare canonicalised | 3 | 0 |
| QM5_41123_xauxag-mpath-eff-rv | same as 41113 | 3 | 0 |
| QM5_41142_eurusd-month-end-benchmark-fix-hedge-flow | added `strategy_host_symbol` input; two `_Symbol != "EURUSD.DWX"` compares canonicalised (NoTradeFilter + OnInit) | 2 | 0 |
| QM5_41179_xtixng-mcoxstuart-rv | g_leg_xti/g_leg_xng globals -> inputs (`strategy_xti_symbol`/`strategy_xng_symbol`), InputsValid compare canonicalised | 3 | 0 |
| QM5_41189_xtixng-mlad-rv | same as 41179 | 3 | 0 |

Pattern followed: `QM5_41470_usdjpy-gotobi-nakane-fix-symfix` and
`QM5_41473_brent-tom-mom-symfix` (patched earlier today). For the two-leg baskets the
`.DWX`-literal globals were made empty and populated from the new inputs at the top of
`OnInit` (before any use); the frozen-input `Strategy_InputsValid` symbol checks were
switched to `QM_MagicSymbolCanonical(...) == QM_MagicSymbolCanonical("...DWX")` — the
`.DWX` reference literal now sits inside a canonicalisation call, which is not a
symbol-identity comparison and is not a lint violation.

`build_gate_hardening.py` audit (`python -X utf8 tools/strategy_farm/build_gate_hardening.py
--repo-root . --ea-label <label>`): all five exit 0 with empty `failures`. The four basket
EAs additionally report a pre-existing `card_error: card missing` (a warning-class
condition, not a symbol issue); 41142 has its card. These card notes are reported, not
"fixed", per instruction.

## Scope remaining

The first repo-wide lint run (2026-09-13) found **1670 violations across 838 EA
directories**. There is no allow-list and no mass rebuild: each of the 838 is repaired
**only when it naturally rebuilds** through this gate. Shrinking is always allowed; the
ratchet ledger is meant to be rewritten downward.

### Post-cutover EAs already carrying inventory FAIL findings

Four EAs new since the 2026-09-06 cutover carry `EA_SYMBOL_HARDCODED` **FAIL** findings
from the inventory scanner: **QM5_41374, QM5_41389, QM5_41397, QM5_41399**. Read-only DB
check: **none has a `COMPILE_OK` row** (all 0), so none is a compiled/established
identity. They are outside the five assigned here and were **not patched** — reported for
follow-up commissioning. (Had any been compiled, a rebuild would be an OWNER-only
decision.)
