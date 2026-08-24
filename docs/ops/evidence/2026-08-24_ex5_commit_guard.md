# Fail-closed EX5-Commit-Guard — 2026-08-24

**Router-Task:** `0faad91e-2f5a-4401-ab77-7b3141a88f1b` (ops_issue, P85)
**Lieferung:** Codex-Session (Implementierung + Tests + Hook) — Session endete vor Commit/Evidenz;
Vervollständigung, Review und Installation durch Claude (Orchestrator, gleiche Session wie Beauftragung).

## Incident-Klasse, die geschlossen wird

2026-08-24 verifiziert: 6 EAs (QM5_39001 zweifach — Wiederholung nach Block —, 38001, 38008,
9914, 9947, 35008) committeten frische `.ex5`-Binaries, die NACH einem expliziten
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` ad hoc gebaut wurden (idle Factory-Terminal T4,
Wegwerf-MetaEditor-Profile). Referenz: `docs/ops/evidence/2026-08-24_orchestrator_review_batch_close.md`,
Revert-Commit `6b1e87cb6`, Remediation-Authority `20b966dca`.

## Mechanik

- `tools/strategy_farm/validate_ex5_commit_guard.py`: lehnt jeden Commit ab, der ein
  `framework/EAs/**/*.ex5` staged (added/modified/copied/renamed), sofern kein governed
  COMPILE_EA-Receipt existiert: `work_items`-Zeile mit `kind='compile'`, `phase='COMPILE_EA'`,
  `status='done'`, `verdict='COMPILE_OK'`, deren `ex5_sha256` exakt den gestagten Bytes entspricht
  und deren `mq5_sha256` (falls vorhanden) den gestagten `.mq5`-Sibling bindet.
- Löschungen (`D`) sind bewusst NICHT erfasst — Reverts/Entfernungen bleiben möglich.
- Gate-Kriterien werden nicht berührt; reiner Provenienz-Check.
- Hook: `tools/strategy_farm/hooks/pre-commit`, installiert nach `C:\QM\repo\.git\hooks\pre-commit`
  (Worktrees teilen das hooks-Verzeichnis → gilt für alle Checkouts).

## Verifikation

```text
> python -m pytest -q tools/strategy_farm/tests/test_validate_ex5_commit_guard.py
6 passed in 2.49s
```

Abgedeckt: Ablehnung ohne Receipt, Annahme mit exaktem Receipt, mq5-Sibling-Mismatch,
Nicht-EA-Pfade ignoriert, keine gestagten EX5 = PASS, unlesbare Blobs fail-closed.

## Rollback

`del C:\QM\repo\.git\hooks\pre-commit` entfernt die Durchsetzung; Validator/Tests bleiben
harmlos im Baum. Kein Runtime-/DB-/Gate-Zustand verändert.
