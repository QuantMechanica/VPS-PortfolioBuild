# CODEX BRIEF — 20007-Prioritätsspur: persistente Quelle + Exact-ID-Controller (OWNER-JA 2026-07-31)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**OWNER-Entscheid 2026-07-31:** JA zum NDX-Backfill inkl. akzeptierter
Verdrängung (Rang 577→7, ~570 Rows verdrängt, davon 46 Q04+) — Referenz: dein
D-R1-Quantifizierung (Ticket `695f5585`, Finding 4).

## Aufgaben (deine eigene R1-Empfehlung, zweiteilig)

1. **Persistente Quelle reparieren:** `strategy_priority.compute_scores()`
   liefert für QM5_20007 `priority_track=false, tf=NA, asset=unknown,
   unresolved symbols`. Ursache in Karte/Scorer beheben (Symbol-/TF-Auflösung
   bzw. explizite OWNER-Prioritätsregistry), sodass KÜNFTIGE 20007-Rows das
   Flag über `_q02_priority_track_required` erben. Test dafür.
2. **Exact-ID-Controller** (neues kleines Tool, z. B.
   `tools/strategy_farm/set_priority_track.py`): dry-run-first; wiederholbares
   `--work-item-id`; verlangt erwarteten status+phase+payload-SHA256 je Row
   (CAS); `BEGIN IMMEDIATE`; exakte Rowcount-Assertions; dauerhaftes
   Pre/Post-Journal (D:\QM\reports\state\); Farm-Event; guarded revert.
3. **Re-Zensus + Apply auf genau die dann noch gültigen Ziele:** unmittelbar
   vor Apply neu erheben. Stand R1: nur `6dce5d90` (NDX, pending, Flag fehlt)
   ist sinnvoll mutierbar; `0928164a` (GDAXI) ist terminal failed
   (Lock-Storm-Klasse → normale Recovery-Klassifikation, NICHT flaggen);
   `80c64b67` (XAU) trägt das Flag bereits (recovery-class). Ist NDX zwischen-
   zeitlich geclaimt/verändert → CAS schlägt fehl → dokumentieren, nicht forcen.
4. Verdrängungs-Delta nach Apply einmal messen (in-memory Claim-Order vor/nach)
   und rapportieren.

## Do NOT

- Keine Wave-/Bulk-Mechanik; keine anderen Rows; kein Factory-Eingriff;
  niemals T5/T_Live. SP500-Rows bleiben ausgeschlossen.

## Deliverable

`docs/ops/evidence/2026-07-31_priority_track_controller.md`: Commits, Tests,
Dry-Run- + Apply-Journal, Re-Zensus, Verdrängungsmessung. Danach `update-task
<id> --state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
