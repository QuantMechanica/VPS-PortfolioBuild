# QM5_41410 XAU/XAG Weekly Alternation — Build And CPU Stop

Date: 2026-09-10  
Branch: `agents/board-advisor`

## Outcome

`QM5_41410_xauxag-walt3-rv` is a new, committed precious-metals
relative-value build. It fades the newest XAU-minus-XAG weekly relative winner
only after exactly three completed weekly relative returns strictly alternate.
The approved card, source decision, identity, two active magic routes, V5
source, logical basket manifest, three fixed-risk presets, deterministic tests,
and compiled binary are present.

The generated source passed the binding PACER audit before compile enqueue:
exit zero, no `EA_FRAMEWORK_INPUT_PINNED` findings. RNG, news, and Friday-close
inputs are not equality compared; stress rejection is checked only for
finiteness and the inclusive `0..1` range.

Governed compile work item `13f0c2ce-f938-42b5-928c-eb1672b528b5`
completed `COMPILE_OK`. MetaEditor reported zero errors and zero warnings, and
the framework build check passed. The binary SHA-256 is
`244a5e72b4167718f20581c95a66d71da686ee48469d8e4f31a3d6e094e62c3a`.

## Q02 Refusal

The first intake dry run selected the one logical basket setfile and returned
`ELIGIBLE` / `would_enqueue=true`. It verified `RISK_FIXED=1000`,
`RISK_PERCENT=0`, the two active magic routes, manifest symbols, source-bound
binary, and explicit XAU/XAG strategy inputs in all presets.

Immediately before apply, five one-second CPU samples were
`72,100,97,94,94`. Maximum load was 100%, average load was 91.4%, and twelve
`terminal64` or `metatester64` processes existed. The ceiling is exclusive:
every sample must be below 97%. Therefore no Q02 apply command was issued and
no Q02 row was created.

Machine-readable evidence is
`artifacts/qm5_41410_q02_cpu_stop_20260910.json`.

## Verification

- canonical dedup: no exact identity; five fuzzy relatives manually resolved
- card schema and ML lint: PASS
- governed magic allocation: two active rows, resolver verified
- reference suite: PASS, 6/6
- PACER input-pin audit: PASS, zero findings
- governed compile: `COMPILE_OK`, 0 errors, 0 warnings
- framework build check: PASS
- first-Q02 intake dry run: ELIGIBLE
- Q02 apply: NOT RUN, CPU ceiling reached

## Resume Condition

Repeat the five-sample guard and require every sample to be strictly below
97%, then rerun the first-Q02 dry run before applying the exact logical canary.
This record does not authorize any live, portfolio, or terminal-control action.
