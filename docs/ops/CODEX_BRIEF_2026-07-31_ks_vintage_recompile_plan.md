# CODEX BRIEF — KS-ABSENT-Vintage: Quellbeweis + Recompile-Deploy-Plan (KEIN Deploy)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**Befund (Claude, evidenzgebunden):**
`docs/ops/evidence/2026-07-31_ks_arming_after_owner_restart.md` — 9 Sleeves
loggen nach ZWEI unabhängigen T_Live-Re-Inits (07-29 + 07-31) deterministisch
KS_BASELINE_ABSENT, obwohl Dateien in beiden Loader-Pfaden liegen (n 30..331).
Build-Datum trennt perfekt: LOADED = Builds ≥ 07-13, ABSENT = Builds
06-28/07-04. Hypothese: Pre-Fix-Include (KillSwitch-Source-Fix, MNT-043-
Recompile-Schuld).

## Aufgaben (read-only gegenüber T_Live; keine Builds auf Live deployen)

1. **Quellbeweis:** `git log`/`git diff` über
   `framework/include/QM/QM_KillSwitchKS.mqh` (+ ggf. QM_Common-Aufrufkette):
   identifiziere den Fix-Commit zwischen 2026-07-04 und 2026-07-13 und zeige
   die exakte Defekt-Mechanik der Vorversion (Pfad-/Namenskonstruktion?
   fehlender FILE_COMMON-Fallback? anderes Event-Verhalten). file:line-Beleg,
   der erklärt, warum GENAU die alten Binaries ABSENT loggen.
2. **Betroffenen-Matrix:** je der 7 EAs (10911, 10919, 10939, 11132, 11421,
   12567, 12989): aktueller Quellstand kompilierbar? Weitere seit 06-28
   eingeflossene Quelländerungen, die ein Recompile mitziehen würde
   (Verhaltensrelevanz je EA benennen — Recompile darf die Handelslogik nicht
   still ändern; falls doch Änderungen anstehen: auflisten, nicht verschweigen).
3. **Deploy-Plan als Vorschlag** (OWNER-gated, NICHT ausführen): Build der 7
   im Factory-Kontext, SHA-Manifest Factory→T_Live, Magic-Registry-Check,
   vintage_stale-Konsequenzen je EA dokumentiert, Re-Init-Schritt =
   Sonntags-Session. Ein JSON-Manifest-Entwurf + Schrittliste genügt.
4. Randnotiz prüfen: 10476/10692/10715/10940-Logs sind Alt-Sleeves ohne
   frischen Init — bestätigen, dass keine verwaisten Charts im Profil hängen
   (read-only, z. B. via Journal/Chart-Zählung im Pulse).

## Do NOT

- Kein Deploy, kein Compile-Output nach T_Live, kein Terminal-/Chart-Eingriff,
  kein AutoTrading. Factory-Backtests nicht stören.

## Deliverable

`docs/ops/evidence/2026-07-31_ks_vintage_recompile_plan.md`: Fix-Commit +
Mechanik, Betroffenen-Matrix, Deploy-Plan-Entwurf. Danach `update-task <id>
--state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
