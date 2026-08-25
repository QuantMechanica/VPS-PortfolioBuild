# OWNER-Entscheide 2026-08-25 abends (Chat-Receipt, drei Punkte)

**Receipt (wörtlich):** „Requal, FTMO bleibt vorerst ohne neues Konto (wir warten auf die 25!),
16 deterministisch tote Q02 Paare" — Antwort auf die drei offenen Board-Punkte in genannter
Reihenfolge (HMA-Cat-A-Vorlage, FTMO-Trial-Contract, Q02-Dead-16-Vorlage).

## 1. OWNER-DEC-HMA-CATA → **JA: Requalifikation**

Die 9 Cat-A-EAs mit stehendem PASS auf der defekten HMA-Serie (QM_Indicators.mqh:603,
gefixt in Ticket 7dd0f41e) werden requalifiziert, nicht retired.
**Ausgewiesene Folge (Karte):** governed Rebuild via COMPILE_EA je EA → rebuilt EX5 =
**neue Identität ab Q02** (Regel 23.08.); alte Verdikte bleiben unangetastet als Evidenz.
Umsetzung: entscheidungsgebundener Claude-Lane-Auftrag (gem. OWNER-Regel 24.08.).

## 2. FTMO-Trial-Contract (expired) → **PARKEN, kein neues Konto**

Kein neues FTMO-Konto, bis die 25 terminalen Paare stehen. Der `ftmo_trial_pulse`-Check
erwartet `review` — dieses Dokument IST die Review-Entscheidung; die Check-Erwartung wird
auf den Park-Zustand ausgerichtet (Monitoring-Konfiguration, keine Kontoaktion; T_Live/
Live-Konto unberührt).

## 3. 16 deterministisch tote Q02-Paare → **Disposition genehmigt**

Die 16 im approvten Census (Ticket 9e23d73f) als deterministisch tot klassifizierten Paare
(14× ONINIT 12/12-identisch — INPUTSVALID-Pin-Doktrin, nie blind requeuen; 2× LOG_BOMB)
werden administrativ abgeschlossen: append-only Disposition-Rows
`disposition_only=true, owner_decision_id=OWNER-DEC-Q02-DEAD16-20260825`, Muster
OWNER-DEC-STRANDED-182. Keine Verdikt-Überschreibung, alte Zeilen bleiben.
Interpretationsvermerk: Der Receipt-Text nennt Punkt 3 ohne Verb; die einzige auf der
Vorlage stehende Option war diese Disposition. Bei Widerspruch: Rows sind append-only
und ohne Verdrängung rückholbar.

**Scope-Grenze (Regel 24.08.):** T_Live, AutoTrading, Deployment, Gate-Kriterien und
Buchbau bleiben separat autorisiert; diese Entscheide erweitern nichts davon.
