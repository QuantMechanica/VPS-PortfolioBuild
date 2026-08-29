# OWNER-Entscheid 2026-08-29: Fleet-Claim-Stagger 60 s → 10 s

**Receipt (wörtlich):** „Aggressive 10 Sekunden" — Antwort auf die Orchestrator-Vorlage
(Empfehlung 30 s; Optionen 15/30/60), nachdem gemessen war, dass der 60-s-Stagger
(OWNER 2026-08-15, Anti-Thundering-Herd) bei kurzen DL-089-Zellen (3–8 min) der letzte
Parallelitäts-Begrenzer der Flotte ist (~90 Abschlüsse/h Deckel).

## Umsetzung

`tools/strategy_farm/terminal_worker.py`: `CLAIM_SPACING_SECONDS = 10.0` (vorher 60.0),
Kommentar mit Receipt. Die eigentliche Crash-Protektion tragen seither die
Admission-Gates (Commit-Headroom 24 GB, CPU 97/90 %, RAM, Disk); der Stagger bleibt nur
Ramp-Shaping. Rollback = Konstante zurück auf 60.0.

Hinweis Umsetzungszeitpunkt: Der Edit liegt im Working Tree; das File trug zeitgleich
uncommittete Codex-P96-Arbeit (Lock-Scope-Hoisting), daher kein Sofort-Commit durch den
Orchestrator — die Konstante gilt ab Worker-Respawn, der Commit erfolgt mit oder nach
der P96-Lieferung. Verifikation nach Adoption: Zellen-Rate und parallele Tester.
