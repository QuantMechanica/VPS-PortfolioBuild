# Item-bound custom-history poison isolation — 2026-09-02

Task: `3b25f49e-220f-4b17-b596-470ae8050e15`

## Repair

`terminal_worker.py` now distinguishes two item-bound `CLAIM_LOCAL` causes:

- `manifest has no archive rows for claimed symbols: ...`
- `claim declares no .DWX host/conversion/basket history symbols`

These causes fail only the item and create the durable, non-restart hold
`CUSTOM_HISTORY_SYMBOL_NOT_IN_MANIFEST`. They do not quarantine the terminal and
do not engage fleet containment. Other claim-local faults retain the existing
bounded terminal quarantine. The claim selector also checks a valid signed
manifest before claiming a candidate, so a known poison row is held and skipped
without consuming a worker slot.

The two production poison rows are now pending, unclaimed, and covered by active
holds with the exact code above:

| Work item | EA | Phase | Declared custom history |
|---|---|---|---|
| `4a6d441f-89b7-4e95-b492-b28f5aba3a12` | QM5_21525 | Q02 | XTIUSD.DWX, XCUUSD.DWX |
| `7ff04187-385e-4b3d-9064-7348b50b3733` | QM5_21524 | Q02 | XTIUSD.DWX, XCUUSD.DWX |

The governed hold planner returned `conflicting_active_hold` for each exact row,
which is the expected fail-closed result when the requested hold is already
active. Earlier T1/T4/T5/T9 quarantine records were bounded 15-minute artifacts
from the pre-fix behavior; no new terminal quarantine is created by the repaired
path.

Release condition: an OWNER-signed archive manifest must cover every declared
`.DWX` symbol, followed by an explicit governed hold release.

## Verification

`pytest tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py`
passes 28 tests. Added coverage proves both named item-bound messages return
`FAIL_CLOSED` without a terminal marker and that the durable hold is active,
audited, and `release_on_restart=0`. Existing coverage continues to prove that a
terminal-bound `CLAIM_LOCAL` copy failure is quarantined without fleet-wide
containment.
