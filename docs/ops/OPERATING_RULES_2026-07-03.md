# Operating Rules — konsolidiert aus der Nacht 2026-07-02/03 (OWNER-ratifiziert)

Bindend für alle Agenten (Claude, Codex, agy) und alle Sessions. Ergänzt die Hard Rules
im Vault; bei Konflikt gelten Vault-Hard-Rules zuerst.

## Gates & Ökonomie

1. **Frequenz-Floor bestätigt (OWNER 07-03):** Q02 verlangt ≥5 Trades/Jahr/Symbol.
   Begründung: Wirtschaftlichkeit (VPS-Kostendeckung). Below-Floor-EAs werden RETIRED,
   nicht requeued — auch bei starkem PF (Präzedenz: 12914 PF 1.58, 12917 PF 1.65).
   Keine Gate-Ausnahmen ohne expliziten OWNER-Entscheid. Higher-Freq-Card-Varianten
   sind der legitime Weg.
2. **Gates bleiben bewusst konservativ** — niemals nächtlich/eigenmächtig aufweichen.
3. **Challenger-Swap an der Buchtür (OWNER 07-03):** Bei Q09-Ablehnung wegen
   `correlation_above_max_corr` wird automatisch der Verdrängungs-Tausch bewertet
   (Buch-mit-Challenger vs. Buch-mit-Amtsinhaber auf Portfolio-Sharpe/MaxDD; Task
   c57721a9). `CHALLENGER_SUPERIOR` → OWNER-Q12-Review. **NIE Auto-Swap** — Live-
   Änderungen nur über das Manifest-Protokoll (OWNER + Claude).
4. **Prescreen-Fenster für Saison-/Kalender-EAs:** Kalender-Strategien MÜSSEN mit
   Fenstern getestet werden, die ihr Handelsfenster überlappen (Ganzjahres-Prescreen).
   H2-Default-Prescreen auf ein Apr–Jun-Fenster = strukturell 0 Trades = False FAIL
   (Präzedenz 12917).

## Card- & Strategie-Beschaffung

5. **Qualität vor Volumen:** ~10 neue Cards/Woche Richtwert. Jede Card braucht:
   Primärquellen-Zitat (Video-Links von agy gelten NICHT als R1-Beleg — Halluzinations-
   Präzedenz), erwartete Frequenz ≥ Floor, Kill-Kriterien, KEINE nachträglichen
   Parameter-Sweeps außer im Card dokumentiert.
6. **Survivor-Port-Playbook:** Gate-Passierer werden auf unkorrelierte Träger portiert
   (Parameter GELOCKT — Port-Reinheit; ein scheiternder Port stirbt als Port, wird nicht
   re-gefittet). Präzedenzen: 12567 (→ Buch), 12915 → 12966/67/68.
7. **News-Kalender-als-Signal** ist ein zulässiges Muster (Pre-FOMC/Pre-ECB-Klasse),
   solange Positionen VOR dem Event geschlossen werden (Blackout-Grenze respektiert)
   und der Stale-Calendar-Fail-Closed greift.
8. **agy = Video/Quellen-Extraktion ONLY**; jede agy-Behauptung braucht zitierbare
   Timestamps/Links; Lücken als UNKNOWN, nie plausibel gefüllt. Synthese = Claude,
   Code = Codex.

## Factory-Betrieb

9. **Keine manuellen codex/agy-Exec-Sessions bei laufender Factory-Automatik** — sie
   kollidieren mit Pump/Pacer/Orchestrierungs-Slots und werden gecullt. Arbeit gehört
   in die Task-Queues (agent_tasks/tasks); die Lanes führen aus. Manuelle Sessions nur
   in OWNER-genehmigten OFF-Fenstern.
10. **Magic-Registry-Reihenfolge (bindend):** EA-Verzeichnisse ERST anlegen, DANN
    magic_numbers.csv-Zeilen appending, DANN update_magic_resolver.py, DANN im
    generierten Resolver die neuen Magics VERIFIZIEREN, DANN kompilieren. Der
    Regenerator droppt Zeilen ohne EA-Verzeichnis stillschweigend.
11. **Terminal-Prozess-Selektion IMMER pfadverankert** (`\mt5\T<n>\`) UND explizit
    `-notmatch 'T_Live'`. Nie bare `T<n>`-Substrings (Case-Insensitive-Match auf 'mt5'
    killte T_Live am 07-02).
12. **Dedizierte Testfenster** erfordern: Factory_OFF + Watchdog/FactoryON/Reconciler
    disabled + codex_parallel=0 + Kill aller Streu-run_smoke-Wrapper. Der post-run-
    Pump-Hook jedes run_smoke-Laufs reaktiviert sonst die Factory (Resurrection-Kette
    07-02). Restore-Checkliste danach vollständig abarbeiten.
13. **Gemini-Scheduled-Lane defekt** (SYSTEM-Kontext ohne G:-Zugriff → Tasks stranden
    IN_PROGRESS): bis zum Codex-Fix deaktiviert lassen; agy-Tasks via Foreground-
    One-Shot aus Session 1 (nur in OFF-Fenstern, s. Regel 9) oder nach Lane-Fix.
14. **Evidence-Dokumente gehören ins kanonische Checkout** (C:\QM\repo), nicht in
    Agenten-Worktrees (7 gestrandete Docs am 07-02 gerettet). Codex-Prompts müssen den
    Zielpfad explizit nennen.

## Bergungs-Operationen (Schatzsuche 07-03)

15. **Recovery in Wellen, nie flutend:** Requeues aus dem False-FAIL-Archiv gestaffelt
    (~100–150/Welle), Sperrliste (requeue_excluded_eas.txt, 160 Cost-Doomed-FX)
    respektieren, Überlebens-Klassen zuerst. Offene Operationen: C4-Re-Verdikt
    (70 beweisbare PASS_SOFT-Opfer), C2-Param-Diff (583 EAs auf leeren Sets beurteilt),
    C6/C8 (10069-Redump + 941 Storm-INFRA_FAILs). Task-IDs: 69d126f2, bffea48b, 54387422.

## T-WIN (abgeschlossen)

16. **T-WIN-Original + v7 = archiviert** (18-Zellen-Dossier docs/research/
    TWIN_FINAL_DOSSIER_2026-07-02.md; OWNER-Sign-off über Archiv-Status einholen).
    Fade @Exhaustion 1.5–2.0% = dokumentierter **Schock-Regime-Satellit** (2024-Klasse),
    Reaktivierung nur als bewusste OWNER-Regime-Wette. 12821-Q02-Requeues gestoppt.
    Die Basket-Primitive (Cluster-Stop, Re-Projektion, Divergenz-Gate, Equity-Sizing)
    bleiben Framework-Bestand für künftige Basket-EAs.

## Sizing (offener OWNER-Design-Punkt)

17. Cluster-EAs: `strategy_stop_engage_move_pct`-Sizing (implementiert 07-02) macht
    DL-081-1%-Stops real. Für Single-Symbol-EAs bleibt RISK_FIXED-Backtest /
    RISK_PERCENT-Live unverändert. Die generelle Lot-Skalierungs-Architektur
    (Equity-basiert vs. Risikobudget) ist ein dokumentierter OWNER-Entscheid für Q12+.

## Steuerung nach dem Engpass-Wechsel (OWNER-ratifiziert 2026-07-03, Chat)

18. **Orthogonalität schlägt Volumen.** Der Engpass ist nicht mehr "Survivors
    produzieren", sondern "unkorrelierte Return-Streams produzieren" (Beweis: 12915
    volle Kaskade, an Q09 corr=0.35 zu 11132 gescheitert). Neue Karten werden primär
    nach Return-Treiber-Klasse gesteuert (Event/Kalender, Energie, JPY-Crosses,
    Long-Vol-Charakter, Session-Struktur), NICHT nach weiteren Index/Metall-Swing-MR-
    Varianten. Jede neue Karte benennt im `review_focus`, welchen Treiber sie dem Buch
    hinzufügt.
19. **Prop-Track = gleichrangiges Design-Ziel (WS4-Upgrade).** DXZ ist VaR-gefüllt;
    Wachstum kommt aus FTMO/5%ers, und dort bindet TARGET-COVERAGE (Round24: 0 ADMIT /
    13 BACKUP, Engpass Renditedichte, nicht Risiko). Prop-Track-Karten: Trade-Dichte
    ≥~25/Jahr/Symbol, Index/Commodity bevorzugt (Kommission irrelevant), hartes
    Intraday-DD-Design (Day-Flat, strukturelle Stops, Tages-Loss-Cap). FX-High-Freq
    bleibt tot (Kommission). Erste Slate: QM5_12985–12988
    gemäß OWNER-Anweisung vom 2026-07-03. Screening weiter ausschließlich auf Codex'
    report.htm-Basis (BASIS LESSON 06-30, kein paralleler q08-Screen).
20. **Live-Book-Puls.** Das Live-Buch (T_Live, Konto 4000090541) bekommt eine eigene
    automatisierte Überwachung (Log-basiert, strikt read-only auf T_Live-Dateien, kein
    Prozess-Zugriff): Heartbeat der Terminal-Logs, AutoTrading-Status, offene
    Positionen, Fehler-Muster → `D:/QM/reports/state/live_book_pulse.json` + Alarm.
    NIGHTWATCH überwacht die Fabrik, der Live-Puls das Buch — getrennte Verantwortung.
21. **Self-Review wird geflaggt.** Wenn Claude-Lane-Arbeit mangels Codex-Quota von
    Claude reviewt wird, trägt das close-review-Verdict das Präfix `SELF_REVIEW:` und
    der Vorgang kommt auf die Codex-Spot-Check-Liste (Stichprobe nach Quota-Reset).
    Cross-Agent-Review bleibt der Normalfall, sobald Quota es erlaubt.
22. **Frontier-Priorität explizit.** Buch-/Prop-Kandidaten (aktive Kaskaden, Ports,
    neue Slates) laufen mit Prioritäts-Flag durch die Queue; Recovery-Wellen füllen nur
    Leerlauf auf (Queue-Tiefe ~13 Tage bei ~450 Verdicts/Tag — ohne Priorisierung ist
    jeder neue Sleeve ein Mehrwochen-Ereignis).
24. **Coding-Default = Claude-Headless-Lane (Sonnet 5).** OWNER 2026-07-03: Programmier-
    Tasks — auch übernommene Codex-Aufgaben — laufen über die Headless-Claude-Lane
    (ANTHROPIC_MODEL default `claude-sonnet-5`, verifiziert; Lane-Caps um
    repo_edit/tests/ops erweitert). Codex bleibt für Spot-Checks/Reviews und die
    FTMO-Terminals reserviert, solange sein Wochenkontingent knapp ist (aktuell 79%).
    Interaktive Session = Steuerung/Review/chirurgische Fixes, nicht Massen-Code.
23. **Zustandsverändernde Factory-Operationen NUR aus dem Kanon** (`C:\QM\repo`).
    Worktrees sind für Code-Änderungen, NIEMALS für Factory-Betrieb (repair, pump,
    Sweeps, Bulk-Verdicts): Worktrees enthalten nur ~225 von 2.657 EA-Dirs — ein
    Hygiene-Lauf von dort invalidiert die Queue falsch (Vorfall 2026-07-03 07:42,
    5.167 Items, 100% falsch, restauriert). Technische Guards (Task-Auftrag offen):
    absoluter EA-Dir-Anker, Kanon-Selbstcheck mit Hard-Abort, Mass-Invalidation-
    Circuit-Breaker (>200 Items/Lauf → Abbruch + Alarm). Agenten-Prompts für
    Factory-Ops müssen `cd C:/QM/repo` explizit vorgeben.

## Amendment 2026-07-24 (OWNER-approved audit implementation)

**Rule 13 superseded.** The "gemini" scheduled lane runs **agy headless** and is
**operational**, not defective — it completed a real dispatch on 2026-07-23 16:30Z (rc=0)
and its lane heartbeats are healthy (audit evidence
`docs/ops/source_harvest/audit/evidence/pipeline__scheduled_tasks.txt`;
`QM_StrategyFarm_GeminiOrchestration_15min` enabled). The lane **stays ENABLED**; the old
"keep disabled until Codex-Fix" text is stale and no longer binds. agy job constraints per
current memory are unchanged (server-side headless `agy -p --dangerously-skip-permissions`,
≤6 URLs/job, citations mandatory). Reference: `docs/ops/source_harvest/audit/AUDIT_REPORT.md` §1.
