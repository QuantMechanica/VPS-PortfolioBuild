# Codex brief — the build pump sweeps hand-authored framework source into artifact commits

Date: 2026-07-27
Priority: high. This silently destroys change provenance.

## The defect

Adversarial verification on 2026-07-27
(`docs/ops/evidence/2026-07-27_propfirm_implementation_verification.md`, FINDING 2)
established that a 383-line hand-authored rewrite of
`framework/include/QM/QM_PropFirm.mqh` was committed under:

```
a35c08338 build: pump auto-commit 1 factory artifact path(s)
 framework/include/QM/QM_PropFirm.mqh | 383 +++++++++----- (336 insertions, 47 deletions)
```

while the labelled feature commit for that same work contains no header change at all:

```
622299a45 feat(framework): prop-firm phase selector (Phase 1/2/Funded) in QM_PropFirm
 docs/ops/evidence/...implementation.md | 301 +
 framework/tests/mql5/QM_PropFirm_compile_probe.mq5 | 15 +
 (QM_PropFirm.mqh NOT among them)
```

Verify with `git show a35c08338 --stat` and
`git log --oneline -- framework/include/QM/QM_PropFirm.mqh`.

**No runtime consequence** — HEAD is correct and binaries were built from it. This is a
provenance and revert-safety defect:

- `git revert 622299a45` to "undo the phase selector" would leave the enum and
  validators live in the header, because an unrelated build commit owns them.
- Bisecting a regression to the feature lands on an unlabelled `build: pump auto-commit`.
- It contradicts the pump's own contract. The standing note is "Pump committet nur
  Artifacts" — the pump is supposed to commit generated factory artifacts only.

## What to do

1. **Locate the pump** and its path filter. Find what it considers a "factory artifact
   path". Cite file:line.
2. **Establish the blast radius.** How often has this already happened? Search git
   history for commits matching `build: pump auto-commit` that touch paths under
   `framework/include/`, `framework/EAs/**/*.mq5`, `tools/`, `docs/`, `decisions/` or
   any other hand-authored area. Report the count and the most significant instances.
   This is the important number: if it is large, a lot of provenance is already lost.
3. **Fix the filter** so the pump can only commit generated artifacts. Prefer an
   explicit allow-list of generated paths over a deny-list of source paths — a
   deny-list fails open on every new source directory.
4. **Fail loudly, not silently.** If the pump encounters a dirty file outside its
   allow-list, it must report it rather than sweeping it in or silently skipping the
   run. Note the known interaction: any dirty file blocks all builds via the
   dirty-guard, so the pump cannot simply refuse and stall the factory. Design for
   both constraints and say how you resolved the tension.
5. **Test it.** Add a test that a source file dirty in the tree is NOT swept into a
   pump commit. Put it wherever the pump's existing tests live.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT interrupt running backtests or touch `C:/QM/mt5/T_Live`.
- The pump runs on a schedule; do not leave the factory unable to commit artifacts.
  If your fix could stall the build lane, say so explicitly and gate it.
- Commit with explicit pathspecs.
- Evidence over claims: cite the commits and file:line.

## Deliverable

The fix, plus `docs/ops/evidence/2026-07-27_pump_path_filter_fix.md` recording the
root cause, the historical blast radius count, the fix, and the test.
