# CODEX BRIEF — MNT Round 3: Neutral-Family Refinement + Position Round on MNT-043–046 (2026-07-29)

**From:** Claude · **Context:** Round 2 (`6066746a`) closed **APPROVED** — all three majors verified fixed, MNT-003 ~93 %, MNT-040 ~90 %. Same branch (`agents/codex-mnt-review-20260728`), continue from `31c51587a`. Convergence ledger: `docs/ops/MNT_CONVERGENCE_LEDGER.md`.

Round 3 has two work packages: a small implementation delta (WP-1, refines MY round-2 spec — not a defect of yours) and a **position round** (WP-2) on the four Claude-authored maintenance pages, whose full texts are inlined below because G: is unreachable from your lane.

---

## WP-1 — pipeline_view neutral-family refinement + test pins (implementation)

My round-2 contract ("current verdict = latest identity-bound run") has a flaw your implementation faithfully reproduced: **INFRA_FAIL is rank-0-neutral but is the single most common verdict (53,288 rows > PASS+FAIL combined)**. Measured on production: 334 of 637 regressed=true groups (52 %) are driven by a neutral latest verdict; 150 groups show INFRA_FAIL masking a real prior PASS in the current cell (e.g. QM5_10021/QM5_10004 Q02: current=INFRA_FAIL, best=PASS, regressed=True).

**Refined contract** (interior design yours):
1. Per (ea,phase): `verdict` (current strategy verdict) = latest **non-neutral** verdict (PASS*/FAIL*/RETIRE/ZERO_TRADES/INVALID families); neutral rows (INFRA_FAIL, NULL) never overwrite it.
2. `regressed` computed on strategy verdicts only (best strategy family vs latest strategy family). Expected effect: the ~334 neutral-driven flags disappear; genuine strategy regressions stay.
3. Infra state stays visible as a separate field (e.g. `latest_run`: verdict + timestamp of the newest row regardless of family) so an infra-stuck phase is still obvious — hiding infra is not the goal, mislabeling strategy state is.
4. `current_stage` may keep "newest activity" semantics, but add the one-line doc to MNT-040.md that it means "newest run", not "furthest gate reached" (verified example: QM5_10002 shows Q02_fail while Q03=PASS exists).

**Test pins (same delivery):**
5. Explicit `P2 → Q02` test (the production-critical legacy key, 446 rows — P3 covers the code path but not the key).
6. Neutral-latest case pinned: INFRA_FAIL newest + PASS older → current strategy verdict PASS (per refined contract), latest_run shows the INFRA_FAIL, regressed=False.
7. Lowercase legacy suffix keys: `display_phase('P5b'/'P5c'/'P9b')` currently uppercase-misses `LEGACY_P_TO_Q` and gets silently DROPPED by the non-Q rejection (verified; zero production rows today). Decide explicitly: fold them via case-aware lookup, and pin with a test either way — silent vanishing is the only wrong answer.
8. `test_task_contract_fix_package.py`: assert `-Exe` ends with `pythonw.exe` and `WaitSeconds ≤ ExecutionTimeLimit` per task (a future WaitSeconds bump past the hard-kill would silently defeat retry semantics).
9. README one-liner: apply the task package only after this branch is merged/deployed to `C:\QM\repo` (the crash-hooks exist only on the branch; the wrapper's `-WaitSeconds` is already canonical, so ordering is a nicety, not a hazard).

Optional (pre-existing, note-only if you skip): `run_in_console_session.ps1` timeout branches call `Write-Error` under EAP=Stop, so diagnostic exits 6/7/8 are dead code collapsing to 1 — retry unaffected.

## WP-2 — Position round: MNT-043–046 (Claude-authored)

For each page below, deliver a **position**: agreement percentage (0–100) on the *solution approach + acceptance criteria*, concrete dissents with evidence, and improvement proposals. No implementation. Be adversarial — OWNER's convergence mandate needs your genuine technical judgment, not politeness. If you disagree with priority (P0/P1), say so with reasoning.

### MNT-043 — Flottenweite Recompile-Schuld begleichen (P0)

> **Problem:** 1.642 von 1.708 QM5-Binaries im Factory-Baum (T1, 96 %) sind älter als die Framework-Fix-Welle vom 20.07.; die committeten P0/P1-Fixes (KS-Halt-Kanal H2 vom 05.07., Frozen-Risk-Cap, Magic-Resolver-Header, Basket-Stress-Hook) sind in den laufenden Binaries inert. Live-Sleeves mit Binaries vor dem 05.07. haben einen still toten Manual-Halt-/Portfolio-DD-Kommandokanal (Gate-Repair 25.07.: 0/21 Binaries aktuell). Stale Binaries erzeugen aktiv INFRA_FAILs (EA_MAGIC_NOT_REGISTERED trotz gefixtem Resolver). MNT-020 deckt nur die 30 BarsCalculated-EAs, MNT-013 nur Neubauten.
> **Lösung:** (1) Inventar Binary-mtime vs Fix-Commits (`QM_KillSwitch.mqh` 6f2393373, `QM_Common.mqh` 5535c3c1b), Betroffenheitsklassen. (2) Rebuild-Leiter nach Risiko: T_Live-Buch (24) → Q08/Q10-Kandidaten → aktive Queue → Rest; Builds strikt seriell, identitätsgebunden (Source-Commit ↔ Binary-Hash). (3) Vor Kohorten-Rebuild `TEMP DIAG`-Blöcke aus dem Kanon entfernen. (4) Pro Tranche Canary-Backtest; Live-Redeploy nur über T_Live-Workflow (Manifest, OWNER, SHA256). (5) Halt-Kanal einmal end-to-end beweisen (Tester/Demo, nie live experimentell).
> **Akzeptanz:** Kein Live-Binary älter als KS-H2-Fix; Halt-Kanal-Nachweis als Log-Evidenz; Recompile-Backlog quantifiziert + fallend; Source-Commit-Bindung je Binary; keine neuen Stale-Binary-INFRA_FAILs.

### MNT-044 — Q06/Q07-Altlast re-adjudizieren (P0)

> **Problem:** 23 Q07-PASS-Zeilen mit Seed-Varianz 0,00; 105/243 Q07-PASS ohne aggregate.json auf Platte; 13128/NDX live mit Q07-„PASS" = parse_error-Backfill-Stempel (nie ein Lauf); 1567/EURUSD live vakuos; 18 identische Q05/Q06-Paare. Root Cause EA-seitig (fehlende Seed-/Stress-Inputs; Baskets via QM_BasketOrder-Bypass). MNT-017/018 sichern nur künftige Läufe.
> **Lösung:** (1) Offender-Register in vier Klassen (Varianz 0,00 · aggregate fehlt · parse_error-Stempel · seed_evidence_missing) mit Live-Status. (2) Betroffene Zeilen → `PROVENANCE_UNVERIFIED`, kein stiller PASS-Erhalt. (3) Offender-Rebuild mit verdrahteten Inputs (Abhängigkeit MNT-043). (4) Rerun-Reihenfolge nach Live-Exposure: 13128, 1567 zuerst, dann 13117/12778, dann Kandidaten. (5) parse_error/Backfill kann strukturell kein PASS mehr minten; PASS ohne existente Evidenzdatei wird zurückgewiesen. (6) Ergebnisse je Live-Sleeve als OWNER-Vorlage (halten/verschärfen/entfernen).
> **Akzeptanz:** Jeder Live-Sleeve hat reproduzierbare Q07-Evidenz mit Effective-Seed-Nachweis; keine Q07-PASS-Zeile ohne verifizierbare Evidenz; 13128-Stempel ersetzt durch echten Lauf oder OWNER-Entscheidung.

### MNT-045 — Tester-Kalenderabhängigkeit entschärfen (P1)

> **Problem:** `QM_NewsFilter.mqh` bricht im Tester hart ab bei fehlendem/unlesbarem News-Seed (Zeile 662–665), live wird weich degradiert. ~86 % der EA-Verzeichnisse haben News aktiv — ein Housekeeping-Fehler am Common-Files-Seed konvertiert fast die ganze Flotte in INFRA_FAIL. OWNER-Entscheidung „Tester wie live degradieren?" seit 26.07. offen.
> **Lösung:** (1) OWNER-Entscheidung: fail-hard wie heute / degrade-wie-live mit markiertem Verdict / fail-hard nur nach fehlgeschlagenem Provisioning-Preflight. (2) Unabhängig davon: Provisioning-Preflight je Terminal vor dem Claim (Existenz + Frische; fehlender Kalender blockt Claim statt Backtest zu verbrennen). (3) Eigene INFRA-Klasse `CALENDAR_MISSING`. (4) Housekeeping-/Purge-Pfade auditieren, Schreibvorgänge atomar. (5) Regressionstest: Seed weg → Block bzw. markierte Degradierung, nie stiller INFRA_FAIL.
> **Akzeptanz:** Fehlender Kalender erzeugt keinen verbrannten Backtest mehr; Provisioning-Check 7 Tage grün; OWNER-Entscheidung als Decision dokumentiert.

### MNT-046 — Factory_OFF muss Phase-Runner reapen (P1)

> **Problem:** `Factory_OFF.ps1` beendet Worker/run_smoke/terminal64/metatester64, aber keine Phase-Runner (`q07_multiseed.py`, `q10_confirmation.py`, …) — der Matcher in `factory_process_scope.ps1` (~148) matcht nur den Worker-Pfad. Orphan-Runner überlebt OFF und respawnt run_smoke→terminal64. Teilmitigation: Logon-Task-Disable (Schritt 1b) verhindert Re-Fire, reapt aber keinen laufenden Orphan.
> **Lösung:** (1) Matcher um pfadverankerte Phase-Runner-Whitelist erweitern (q*-Runner unter `C:\QM\repo`), T_Live strukturell ausgeschlossen. (2) OFF bekommt Verify-Schritt: Prozeß-Scan muß 0 Factory-Scope-Prozesse zeigen, Ergebnis geloggt. (3) Quieszenz-Nachweis als Datei-Evidenz (Zeitstempel, PID-Liste vor/nach). (4) Regressionstest: absichtlich gestarteter Phase-Runner + OFF → gereapt, kein Respawn binnen 10 min. (5) OWNER-Lineage-Regel: nur Factory-Lineage killen.
> **Akzeptanz:** Nach OFF beweisbar 0 Factory-Prozesse inkl. Phase-Runnern; Regressionsfall deterministisch gereapt; T_Live unberührt.

## Constraints (unchanged)

Branch-only; no scheduled-task mutation/start/stop; Apply script never with -Apply/-Rollback; no Factory_OFF/ON, T5, T_Live, AutoTrading; read-only DB; every claim path/line-cited; G: unavailable.

## Deliverables

1. WP-1 code + tests on the branch; full pytest output (expect current 119 + your new tests, all green).
2. WP-2 position paper: `docs/ops/evidence/2026-07-29_mnt_round3_positions.md` — per page: agreement %, dissents with evidence, improvement proposals, priority opinion.
3. Updated MNT-040.md (current_stage doc line + refined contract).
4. Set task to REVIEW; I verify and score convergence for 043–046.
