# CODEX BRIEF — FACTORY_MUTATION.lock: Stale-Reap im Claim-Pfad + Dead-Holder-Alarm

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**Incident 2026-07-31 (behoben, Evidenz
`D:\QM\reports\state\stale_mutation_lock_reaped_20260731T2033Z.json`):**
T5-Worker PID 15308 nahm 19:20:06Z das Mutation-Lock im Claim und starb
(Watchdog-Kohorten-Recycle ~19:30Z während RAM-Commit-Pause). Der verwaiste
Lock blockierte **die gesamte Flotte lautlos für >70 Minuten** (letzter Verdict
19:31Z, active=0, 2.168 pending; alle 10 Worker lebten und idlden). Claude
reapte manuell mit Identitäts-Check (PID tot + created_at-Match); Claims liefen
20:41Z wieder an.

## Aufgaben

1. **Stale-Reap in der Lock-Klasse** (`factory_mutation_lock.py`, damit ALLE
   Nutzer profitieren — terminal_worker, codex_fleet_pacer,
   run_worktree_clean_task, set_priority_track, q08_single_target_requal,
   maintenance_control): Beim Acquire-Fehlschlag (busy): Lock-JSON lesen; wenn
   (a) PID nachweislich tot UND (b) created_at älter als Schwelle (z. B. 120 s)
   UND (c) Datei lesbar (kein offener Exklusiv-Handle = kein lebender Halter),
   dann Identitäts-geprüfter Reap (Content-Vergleich unmittelbar vor Delete,
   Evidenz-Append nach `D:\QM\reports\state\mutation_lock_reaps.jsonl`), danach
   Acquire-Retry. Lebende Halter NIE reapen; Lese-Fehler = kein Reap
   (fail-closed Richtung Warten).
2. **Dead-Holder-Alarm:** `live_book_pulse.py` (oder passender Health-Check in
   farmctl health) prüft das Lock: Alter > N Minuten mit totem PID ⇒ FAIL-Check
   mit action_hint; Alter > M Minuten auch mit lebendem PID ⇒ WARN. Ein
   flottenweiter Stillstand darf nie wieder stumm sein.
3. **Todesursache 15308 forensisch:** Watchdog-Log 19:15–19:35Z — hat der
   Watchdog-Recycle den Worker in der Commit-Pause gekillt, während er das Lock
   hielt? Falls ja: Recycle-Pfad entweder lock-aware machen (vor Kill kurz auf
   Lock-Freigabe warten) ODER dokumentiert dem Reap überlassen (mit Punkt 1
   ist der Tod dann benign) — begründete Wahl, keine stille.
4. **Tests:** Orphan-Lock (toter PID) → Claim heilt sich selbst inkl.
   Evidenz-Zeile; lebender Halter → kein Reap, normales Warten; Race zweier
   Reaper → genau einer gewinnt (Content-CAS via Re-Read vor Delete).

## Do NOT

- Lock-Semantik für lebende Halter nicht verändern; keine Timeout-Verkürzung
  der Admission; kein Factory-Zyklus; niemals T5-Sonderbehandlung (T5 ist
  regulärer Flottenteil).

## Deliverable

`docs/ops/evidence/2026-07-31_mutation_lock_stale_reap.md`: Commits, Tests,
Forensik-Befund zu 15308, Alarm-Nachweis (synthetischer Orphan → FAIL-Check).
Danach `update-task <id> --state REVIEW --artifact-path <deliverable>
--verdict "<kurz>"`.
