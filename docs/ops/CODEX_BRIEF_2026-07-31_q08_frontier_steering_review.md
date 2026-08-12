# CODEX BRIEF — Q08-Frontier-Steering (10582 / 20039 / 20007): Plan-Review R1 (Topic D)

**Ticket-Klasse:** ops_issue · **Autor des Plans:** Claude · **Reviewer:** Codex (du)
**Protokoll (Ledger Topic D):** Adversarialer Review, explizite **Zustimmungs-%**.
`>= 90 %` -> Claude führt die Stufen einzeln aus (staged, je Snapshot) und postet
Evidenz; Verifikation der Ausführung folgt als eigenes Ticket. `< 90 %` ->
Findings, Runde 2. **Dein Review ist strikt read-only — keine Requeues, keine
Setfile-Edits, keine DB-Writes.**

## Recon-Befund (Claude-Workflow 2026-07-31, evidenzgebunden)

1. **10582/XAUUSD — NICHT die Backfill-Klasse.** Die XAUUSD-H6-Setfiles TRAGEN
   strategy_*-Zeilen (ablation_00.set: 12), aber ihnen fehlt der Section-Header
   `; strategy-specific params`. `q08_5_neighborhood_runner.py::parse_setfile_assignments`
   erntet nur Zuweisungen NACH diesem Header -> assignments leer ->
   ValueError -> INVALID -> DL082 INFRA_RECYCLE -> INFRA_FAIL-Schleife. Die
   Setfiles stammen vom alten Generator (05-29/06-13); der aktuelle
   `gen_setfile.ps1` emittiert den Header. `backfill_setfile_strategy_params.py`
   ist hier bewusst NO-OP (bail bei vorhandenem `^strategy_=`). Evidenz:
   `D:\QM\reports\work_items\95015420-...\QM5_10582\Q08\XAUUSD_DWX\aggregate.json`.
   Vermutlich eigene Sub-Klasse innerhalb der 158 undiagnostizierten Q08-INFRA_FAILs.
2. **20039/NDX — Q06 (Stress HARSH) INFRA_FAIL 07-27 = Cold-Cache-Transient**
   (`invalid_summary: NO_HISTORY, INCOMPLETE_RUNS, ...` — dokumentierte
   Selbstheiler-Klasse, aber Q06 hat KEINEN hourly Self-Heal-Sweep). Nie
   requeued; Q05 PASS liegt vor. Cache ist seit Factory-ON 07-31 warm.
3. **20007 — kein Defekt, reine Queue-Tiefe.** GDAXI/NDX Q02 pending unclaimed,
   Rang ~#484/#486 von 2140 (claim-order per `farmctl.pending_claim_order_sql`);
   Stale-XAUUSD-Row #513 (pending seit 07-23). SP500 korrekt ausgeschlossen
   (kein pending/active). OWNER hat 20007 NDX/XAUUSD/GDAXI am 2026-07-26 auf
   die Prioritätsspur gesetzt; die FRISCHEN Rows (07-31) tragen das Flag nicht.
4. **E-Lane gesund:** 20183 pending; 20184 aktiv auf T8; 11592 GBPUSD-Q04 =
   echter Merit-FAIL (kein Eingriff), EURUSD-Q02 bereits per Sweep re-pending.

## Plan (Ausführung Claude, eine Stufe pro Aktion, je Snapshot)

**Stufe 1 — 20039 (billigster Win):**
`python tools/strategy_farm/requeue_stranded_infra.py --phases Q06 --wave 1
--apply --snapshot-out D:\QM\reports\state\requeue_q06_20260731.json`.
Wave-1-Kohorte = 5 gestrandete Q06-Rows farmweit — Mitglieder im Review listen
und bestätigen, dass keine davon konfliktiert.

**Stufe 2 — 10582 Header-Fix, dann EIN Q08-Requeue:**
(a) In den 4 XAUUSD-H6-Setfiles (base + ablation_00/01/02, Pfad
`framework/EAs/QM5_10582_mql5-ema-pred/sets/`) GENAU EINE Kommentarzeile
`; strategy-specific params` unmittelbar vor dem strategy_-Block einfügen —
minimal-invasiv statt Voll-Regen (Regen riskiert Parameter-Drift gegen
bestehende Q02–Q07-Evidenz; MT5 ignoriert `;`-Zeilen, Backtest bit-identisch).
Ausführung direkt im kanonischen Checkout `C:\QM\repo` (der Q08-Runner liest
dort — Worktree-Falle vermeiden), Commit mit expliziten Pathspecs.
(b) Verify: `parse_setfile_assignments` liefert >0 je Datei.
(c) `requeue_stranded_infra.py --phases Q08 --wave 1 --apply --snapshot-out
D:\QM\reports\state\requeue_q08_20260731.json` — Wave-Mitglieder listen.

**Stufe 3 — 20007 Prioritätsspur wiederherstellen:**
`payload_json '$.priority_track'=true` auf exakt 3 Rows: 0928164a (GDAXI),
6dce5d90 (NDX), 80c64b67 (XAUUSD) — Wiederanwendung der OWNER-Entscheidung vom
07-26 auf die frischen Rows; SP500 bleibt draußen. **Offener Punkt an dich:**
benenne den sanktionierten Mechanismus (farmctl-Subcommand, falls vorhanden;
sonst minimales, gesnapshottetes UPDATE-Skript — Vorher/Nachher-Rows als Evidenz).

## Review-Schwerpunkte

1. **Setfile-Byte-Bindung:** Bindet irgendein Validator/Manifest die
   Setfile-Bytes (SHA) an bestehende Q02–Q07-Evidenz, sodass die eingefügte
   Kommentarzeile Evidenz als stale markieren würde? (file:line — wenn ja,
   Konsequenz benennen: Regen-Pfad oder vintage_stale-Doktrin akzeptieren.)
2. Wave-1-Mitgliedschaft beider Requeues (wer außer 20039/10582 wird berührt —
   akzeptabel?). `requeue_stranded_infra.py`-Flags gegen die Quelle prüfen.
3. priority_track: Mechanismus + Nebenwirkungen auf die Claim-Order (×10-Sprung
   — verdrängt er laufkritische Metall-Rows unangemessen?).
4. Kollisionsfreiheit mit laufender Factory (T8 aktiv, 7 aktive Rows).

## Deliverable

`docs/ops/evidence/2026-07-31_q08_frontier_steering_review.md`: Zustimmungs-%,
Findings je Schwerpunkt, Wave-Mitgliederlisten, priority_track-Mechanismus.
Danach `update-task <id> --state REVIEW --artifact-path <deliverable>
--verdict "<kurz>"`.
