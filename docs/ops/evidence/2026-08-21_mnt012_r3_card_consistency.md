# MNT-012: R3 card consistency repair

- Task: `c96cef85-c8b9-410d-9401-2f6453b0ace2`
- Verified: `2026-08-21T10:28:14Z`
- Branch: `agents/board-advisor`
- Scope: metadata consistency only; no factory, terminal, compile, work-item, or verdict action

## Premise and disposition

The measured premise was confirmed. Both approved cards declared
`r3_data_available: PASS` in frontmatter while their R-gate tables declared R3
`UNKNOWN`. The body explanations identify unresolved external/custom-symbol data,
so `UNKNOWN` is the supported status. The frontmatter is now `UNKNOWN` and the G0
reasoning says why; the approved G0 decision and strategy mechanics were not
changed.

| Card | Authoritative approved card | Generated repository mirror | R3 frontmatter | R3 body | SHA-256 after repair |
|---|---|---|---|---|---|
| `QM5_1457_as-predict-bonds` | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1457_as-predict-bonds.md` | `C:/QM/repo/framework/EAs/QM5_1457_as-predict-bonds/docs/strategy_card.md` | `UNKNOWN` | `UNKNOWN` | `7a6eedbd046cf841e214b355638f530842a9abf18879c81cc3145080ee3cdcef` |
| `QM5_1459_as-lumber-gold` | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1459_as-lumber-gold.md` | `C:/QM/repo/framework/EAs/QM5_1459_as-lumber-gold/docs/strategy_card.md` | `UNKNOWN` | `UNKNOWN` | `5fc8d3e987098ec508795d67bb06b8d95278ac9c278fb0859aaef78f2e926aa0` |

For each card, the authoritative approved file and generated repository mirror
are byte-identical at the recorded hash. The mirrors are intentionally ignored
build products and were not force-added to Git; the authoritative files live in
the strategy-farm artifact store.

## Verification

Reproduction commands from `C:/QM/repo`:

```powershell
Get-FileHash -Algorithm SHA256 `
  'D:\QM\strategy_farm\artifacts\cards_approved\QM5_1457_as-predict-bonds.md', `
  'C:\QM\repo\framework\EAs\QM5_1457_as-predict-bonds\docs\strategy_card.md', `
  'D:\QM\strategy_farm\artifacts\cards_approved\QM5_1459_as-lumber-gold.md', `
  'C:\QM\repo\framework\EAs\QM5_1459_as-lumber-gold\docs\strategy_card.md'

python -m pytest tools/strategy_farm/tests/test_mnt012_build_guards.py -q
```

Result: `10 passed in 0.93s`.

Direct calls to `parse_card_frontmatter`,
`strategy_card_r_gate_consistency`, and `_card_r_gate_ready` established for both
cards:

- frontmatter R3 = `UNKNOWN`
- body R3 = `UNKNOWN`
- no `frontmatter_body_mismatch` error
- the remaining fail-closed error is
  `r3_data_available_body_not_PASS:UNKNOWN`
- build readiness = `false`

This is the intended result: the contradiction is removed, while neither card
can be emitted as build-ready until its R3 data dependency becomes approved and
the card is deliberately updated.
