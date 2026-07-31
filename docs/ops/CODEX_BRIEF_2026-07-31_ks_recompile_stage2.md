# CODEX BRIEF — KS-Recompile Stufe 2: Guardrail-Fix + Factory-Build + Canary (KEIN Deploy)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**Autorisierung:** `decisions/2026-07-31_t_live_ks_vintage_recompile_plan_approval.md`
(OWNER-Freigabe der Plan-Schritte 1–5). Plan:
`docs/ops/evidence/2026-07-31_ks_vintage_recompile_plan.md` + Draft-Manifest.

## Aufgaben (exakt Plan-Schritte 2–5)

1. **Guardrail-Reparatur:** Die 7 Time-Exit-Findings beheben — explizite
   `strategy_time_exit_bars` (10919: NDX/SP500/XAUUSD-H4-Sets) bzw.
   `strategy_time_exit_h4_bars` (10939: EURUSD/GDAXI/USDJPY/XAUUSD-H4-Sets) aus
   den EA-Input-Defaults (verhaltensidentisch, wie backfill-Doktrin), dann
   derselbe Validator → PASS. Vintage-Hinweis: diese EAs werden durch das
   Recompile ohnehin MNT-043-stale; Setfile-Ergänzung dokumentieren.
2. **Registry-Caveat vorbereiten:** 12567-Duplikat in `ea_id_registry.csv`
   analysieren und Bereinigungsvorschlag (oder begründete Ausnahme-Textbaustein
   für die OWNER-Signatur) liefern — Magic-Reihenfolge-Regel beachten, nichts
   an magic_numbers.csv/Resolver ändern ohne die dokumentierte Order.
3. **Source-Lock + Build:** sauberen Commit pinnen, alle 29-Member-Closures
   re-hashen (Abweichung vom Draft ⇒ Manifest regenerieren), dann die sieben
   EAs **seriell** über den registrierten Factory-Workflow in immutable Staging
   kompilieren (0 Errors / 0 Warnings; Compiler-Version + Logs + MQ5/Closure/
   EX5-Hashes erfassen). T1–T10-Betrieb nicht unterbrechen; Builds seriell
   (Magic-Resolver-Race).
4. **Non-Live-Canary:** In registriertem Tester-/Demo-Kontext alle 9
   Identitäten `KS_BASELINE_LOADED` beweisen; Kontrakt-Init, News-Blackout,
   Sizing, Orderfluss, Signal-/Trade-Stream-Deltas gegen die Alt-Binaries
   prüfen. Canary-Sets: `RISK_FIXED > 0`, `RISK_PERCENT = 0`. **Jedes
   unerklärte Delta blockt** — ehrlich rapportieren, nicht wegerklären.
5. **Vintage-Bill:** MNT-043/044-Overlay-Events (append-only) gegen die echten
   neuen EX5-Hashes vorbereiten + Liste der admission-relevanten Q-Reruns.
6. **Manifest füllen:** alle Null-Felder des Drafts mit echten Hashes
   (source→closure→EX5→Stage→T_Live-Ziel, Presets, Baselines, Magics,
   Preimages, Canary-Evidenz, Rollback) — Signatur-Feld bleibt leer.

## Do NOT

- KEIN Deploy nach T_Live, kein T_Live-Baum-Write, kein Terminal-/Chart-/
  AutoTrading-Eingriff, kein terminal64-Handstart, kein Overlay-WRITE über die
  vorbereiteten Events hinaus ohne Claudes Review. Factory-Backtests nicht
  stören. Guardrail/Validatoren nicht abschwächen.

## Deliverable

`docs/ops/evidence/2026-07-31_ks_recompile_stage2.md`: Guardrail-PASS-Beleg,
Registry-Analyse, Build-Receipts (Hashes/Logs), Canary-Tabelle 9/9,
Delta-Analyse, gefülltes Manifest (unsigniert). Danach `update-task <id>
--state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
