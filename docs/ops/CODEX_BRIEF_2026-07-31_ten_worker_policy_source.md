# CODEX BRIEF — Runtime-Activation Worker-Policy auf 10-Terminal-Kohorte (OWNER-JA 2026-07-31)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**OWNER-Entscheid 2026-07-31 („alle Freigaben erteilt"):** Die 10-Worker-Policy
ist autorisiert. Kontext: T5 wurde 2026-07-31 ~13:43Z nach kontrolliertem
Model-4-Positivbeweis reaktiviert (`docs/ops/evidence/2026-07-31_t5_reactivation.md`);
Flotte läuft 10/10, T5 claimt Arbeit. Der Runtime-Activation-Vertrag kodiert
aber noch die 9-Worker/T5-Quarantäne — jedes Factory_OFF/ON scheitert
fail-closed, bis Quelle + frische OWNER-Decision die 10er-Kohorte tragen.

## Aufgaben (Quellarbeit; KEIN Factory-Zyklus, KEIN Decision-Mint)

1. **Worker-Policy-Quelle aktualisieren:** In
   `tools/strategy_farm/factory_runtime_activation.py` (+ Template
   `factory_runtime_activation.v1.template.json` und allen Stellen, die die
   Policy pinnen — greppe nach `disabled` / `T5` / worker-count über
   Factory_ON.ps1, factory_restart_health.ps1, start_terminal_workers-Pfad):
   Kohorte = **T1–T10, disabled = []**. Die Validator-Semantik bleibt exakt
   (Policy wird weiter hart validiert — nur der SOLL-Wert ändert sich).
2. **Tests nachziehen:** test_factory_runtime_activation und alle Suites, die
   die 9er-Policy asserten; keine Skips/Abschwächungen — Assertions auf die
   neue Soll-Kohorte. Negative Tests behalten (falsche Kohorte → Reject).
3. **Builder-Kompatibilität:** `build_runtime_activation_decision.py` muss die
   neue Policy aus der Quelle übernehmen (nicht hart verdrahtet doppelt) —
   prüfen, ggf. anpassen. Der eigentliche Decision-Mint erfolgt erst im
   Sonntags-Rebind durch Claude (nicht in diesem Ticket).
4. **Hinweis dokumentieren:** Die betroffenen Dateien gehören zu den 12
   runtime-decision-gebundenen Quellen — der Sonntags-Rebind ist ohnehin
   Pflicht; im Deliverable die exakte Liste der geänderten gebundenen Dateien
   aufführen.

## Do NOT

- Kein Factory_OFF/ON, kein Decision-Artefakt erzeugen/ändern, keine
  Scheduled-Task-/Flag-/DB-Mutation; niemals T_Live. disabled_terminals.txt
  nicht anfassen (ist bereits korrekt abwesend).

## Deliverable

`docs/ops/evidence/2026-07-31_ten_worker_policy_source.md`: Commits,
Testlauf-Summary, Liste der geänderten decision-gebundenen Dateien. Danach
`update-task <id> --state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
