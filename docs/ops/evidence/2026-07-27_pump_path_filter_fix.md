# Pump artifact path filter — 2026-07-27

## Verdict

Fixed. The pump no longer treats all of `framework/EAs/`,
`framework/include/QM/`, or `strategy-seeds/` as generated output. It commits only
EA binaries (`.ex5`), generated set files, the generated magic resolver, the two
registry files, calibration/event-vocabulary outputs, `public-data/`, and
`artifacts/`. A dirty source path is returned in `rejected_dirty_paths`; eligible
generated files can still be committed in the same pass, avoiding the dirty-guard
deadlock.

## Root cause and blast radius

Before this change, `ARTIFACT_COMMIT_ALLOWLIST` admitted whole source directories
and `_auto_commit_build_artifacts()` used prefix matching. The commit loop then
collapsed any EA match to the entire EA directory. Consequently a generated `.ex5`
change staged the adjacent `.mq5` and `SPEC.md`, and any changed include header was
eligible. The original defect is directly visible in `a35c08338`, which owns the
383-line `QM_PropFirm.mqh` rewrite absent from feature commit `622299a45`.

The reproducible audit was:

```
git log --all --pretty=format:"@@%H %s" --name-only \
  --grep="^build: pump auto-commit"
```

Classifying a commit as contaminated when it touched `framework/include/`,
`framework/EAs/**/*.mq5`, an EA `SPEC.md`, `tools/`, `docs/`, `decisions/`, or
`strategy-seeds/` found **3,104 contaminated commits among 5,918 pump
auto-commits**. This is historical provenance damage; this change is forward-only
and does not rewrite history.

## Implementation

- `tools/strategy_farm/farmctl.py`: `_is_generated_factory_artifact()` is the
  fail-closed path classifier. File allow-list entries match exactly.
- EA outputs are staged as individual `.ex5`/`.set` paths; the EA directory is no
  longer collapsed into one pathspec.
- Non-generated dirty paths are reported in `rejected_dirty_paths`. They remain
  dirty (and therefore visible to the existing build guard), while generated
  outputs are still committed. This both protects source provenance and lets the
  artifact lane self-heal.
- Hash binding and source ownership are unchanged.

## Verification

```
python -m unittest \
  tools.strategy_farm.tests.test_auto_build_routing.ArtifactAutoCommitTests
```

Result: **2 tests passed**. The regression fixture presents a dirty
`QM_PropFirm.mqh` beside a dirty `.ex5`; the git-add pathspec contains only the
binary and the result reports the rejected header.

No factory switch, terminal, backtest, live setting, or work item was touched.
