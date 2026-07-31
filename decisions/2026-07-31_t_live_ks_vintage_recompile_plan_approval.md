# Decision — KS-Vintage Recompile/Deploy-Plan: Freigabe (Stufe 1)

**Date:** 2026-07-31 · **Authority:** OWNER (stehende Freigabe, Chat 2026-07-31:
„gib den Recompile-Deploy-Plan frei sobald er da ist" + „alle Freigaben
erteilt") · **Reviewer/Recorder:** Claude

## Approved

Der Plan `docs/ops/evidence/2026-07-31_ks_vintage_recompile_plan.md`
(Ticket `5690506f`, Draft-Manifest
`2026-07-31_ks_vintage_recompile_manifest_DRAFT.json`) ist **als Plan
freigegeben**. Root-Cause quellbewiesen: Commit `d8b741d0` (2026-07-06) ersetzte
den illegalen Drive-Letter-Baseline-Pfad durch den sandbox-relativen Pfad; die
sieben Alt-Binaries (Builds 06-28/07-04) tragen das alte Literal einkompiliert
(live per `KS_BASELINE_ABSENT.expected_path` belegt). Kein Restart kann das
heilen; neue Binaries sind erforderlich.

Freigegeben sind damit die **Vorstufen (Plan-Schritte 1–5)**: Source-Lock,
Guardrail-Reparatur der 7 dokumentierten 10919/10939-Time-Exit-Findings (mit
Validator-PASS, keine Abschwächung), serieller Factory-Build in immutable
Staging (außerhalb T_Live, ohne T1–T10 zu stören), Non-Live-Canary
(KS_BASELINE_LOADED 9/9 + Kontrakt-/News-/Sizing-/Orderfluss-Prüfung,
unerklärte Deltas blocken), MNT-043/044-Vintage-Overlay gegen die echten neuen
Hashes.

## Explicitly NOT yet authorized

Plan-Schritte 6–9 (finales Manifest, Deploy nach T_Live, Re-Init) erfordern die
**schriftliche OWNER-Signatur auf dem ausgefüllten Manifest** (Hard-Rule-
Workflow). Diese Signatur muss ausdrücklich abdecken:

1. Die verhaltensrelevanten Mitfahrer des Recompiles — insbesondere 10911s
   neuen 1,0 %-Per-Trade-Risk-Cap, die News-Gating-Änderungen (können gültige
   Signale blocken), Execution-Contracts (Init-Fail bei falschem TF/Freitag)
   und Risk-/Order-Härtungen. Kein „KS-only"-Etikett.
2. Die Registry-Caveats: physisches 12567-Duplikat in `ea_id_registry.csv` und
   globaler `validate_registries.py`-FAIL (Alt-Backlog) — vor Signatur
   bereinigen ODER exakte Baseline-Ausnahme mitzeichnen.
3. Das Sonntagsfenster (Markt zu) + Rollback-Preimages.

## Evidence-Vintage

MNT-043 gilt: neue EX5 ⇒ append-only `EVIDENCE_VINTAGE_STALE`-Overlay + Rerun
der admission-relevanten Q-Evidenz. Alte Verdicts bleiben historisch, werden
nie vererbt.
