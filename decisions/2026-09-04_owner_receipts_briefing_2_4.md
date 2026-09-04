# OWNER receipts 2026-09-04 (Morgenbriefing, Punkte 2–4)

OWNER (Chat, 2026-09-04T00:58:27Z): „2-4: freigegeben, deiner Empfehlung folgend“ — terminales JA zu den drei
Vorlagen des Morgenbriefings 00:50Z, jeweils in der vom Orchestrator empfohlenen Option.
Jede Entscheidung reserviert genau einen entscheidungsgebundenen `agent_tasks`-Auftrag in der
Claude-Lane (Regel OWNER 2026-08-24); die Worker dürfen nur die hier ausgewiesene Folge umsetzen.

## OWNER-DEC-NEWSGATE-AE-20260904 — News-Gate (a) + (e)
Vorlage: `docs/ops/evidence/2026-09-03_newsgate_proposal_d_analysis.md` (verifiziert).
Entschieden: (a) Label-Fix — die zwei REVIEW-Ergebnis-Dicts in `q09_news_contract.adjudicate`
tragen `target_compliance`/`matrix_scope` (Control-off-Zweig hart `7x1_target_compliance`);
(e) Expansion für Ein-Ziel-Deployments aufschieben: bei genau einem Deployment-Ziel lockt die
8-Zellen-Adjudikation (7x1 Zielspalte) ohne 7x4-Expansion; Mehrziel/FTMO behält die Expansion (V5).
Plus (Empfehlung): den unverdrahteten Zähler `affected_entries` verdrahten (separater Schritt,
eigene Verifikation; kann `material_effect` neu auslösen — deshalb explizit Teil der Freigabe).
Folge für bestehende Zeilen: forward-only; die 43 offenen Expansions-Zeilen erhalten
Append-only-Nachfolger, die aus den versiegelten 8-Zellen-Aggregaten unter der neuen Regel
adjudiziert werden (keine Tester-Läufe, volle Provenienz); alte REVIEW-Zeilen bleiben Evidenz.
Nicht enthalten: Schwellenänderungen (Option b), historische Relabel-Migration.

## OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904 — Buch-Vorlagen
Vorlage: `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` §3, `docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.md`,
`docs/ops/evidence/2026-09-03_g5_deploy_pointer_signing_vorlage.md`.
Entschieden: V2 (a) — `max_pairwise_correlation = 0.50` und `account_weight_budget = 10.0`
werden OWNER_RATIFIED, zusammen mit SP-C3 und den Q15-Hard-Caps (Familie ≤3, Symbol ≤2, 10–15 EAs);
V4 (c) — zweistufiger Sparse-D1-Standard als Methode jetzt (ZK-SBB certify/abstain + COS-Flag),
numerische Schwellen bleiben WORKING_DEFAULT_OPEN_OWNER_ITEM bis zur Kalibrierung auf der ersten
SHA-eingefrorenen Q14-Kohorte; V6 (a) — Buchrisiko 9,75 % halten (keine Codeänderung);
Epoch (b) — `deployment_epoch_utc = 2026-07-19T13:50:00Z` (Go-live) mit Semantik „went-live“.
Folge: Builder-Status auf OWNER_RATIFIED mit Verweis auf dieses Receipt; Standard in
`portfolio_correlation.py` umsetzen; G5-Signaturkommando auf die 07-19-Epoch stellen.
Nicht enthalten: Signatur/Mint des Live-Pointers, Freeze-Lift, Buchbau, T_Live (bleiben OWNER-Akte).

## OWNER-DEC-FTMO-RULEPACK-COHERENCE-20260904 — FTMO-Rulepack V2
Vorlage: OWNER-Board 18:45Z (Evaluator lehnt Rulepack V2 ab).
Entschieden: Option (a) — einen Official-Rules-Snapshot 2026-09-02 im Evaluator-Schema
(`qm.ftmo-official-rules-snapshot/v1`) aus denselben Quellen wie der Economic-Terms-Snapshot
minten und die Evaluator-Pins (profile_version 2, as_of 2026-09-02, Snapshot-SHA) sowie die
Quellenbindungen des Rulepacks V2 nachziehen; keine Regelsemantik erfinden, jede Zahl mit Quelle.
Nicht enthalten: Änderung von FTMO-Regeln oder Bewertungsschwellen; FTMO-Kauf (NO-BUY steht).

Umsetzung: Opus-Workflows mit adversarialer Verifikation; Merge nur bei grünem Verdikt;
Ergebnisse in `docs/ops/OPEN_ITEMS_STATUS.md` und im OWNER-Board.
