# OWNER-Entscheide 2026-08-27 (Chat-Receipts, Beschleunigungs-Programm)

## 1. V5 → **KEIN KAUF**

**Receipt (wörtlich):** „V5: wir werden nichts kaufen!" — Keine Hardware-Beschaffung
(kein VPS-Upgrade, keine zweite Box, kein Cloud-Burst). Vorlagen-Ticket 30b216c6 storniert.
Beschleunigung läuft ausschließlich über die Software-Hebel V2/V3/V4/V6/V7/V8.

## 2. OWNER-DEC-DL089-PRUNING-20260827 → **JA (dem Grunde nach)**

**Receipt (wörtlich):** „V7: ja" — auf die im Chat ausgewiesene Regel:

> Restliche Jahres-Zellen eines Kandidaten, der den Frequency-Floor (Aktivitätskriterium
> ≥10 Entry-Handelstage je gewertetem Jahr) in einem gemessenen Jahr deterministisch
> gebrochen hat, werden übersprungen; je übersprungener Zelle ein append-only
> `skipped_as_excluded`-Receipt (Zellidentität bleibt deklariert; auslösende
> Floor-Bruch-Zelle referenziert). Konsistenz- und Auswahlregeln bleiben byte-unverändert;
> der Skip ist beweisbar informationsverlustfrei (Ausschluss ist bei Erstbruch endgültig).

**Bindung der Umsetzung:** Ticket 4598b5eb liefert Floor-Break-Messung + exakten
Amendment-Text. Der Orchestrator prüft den Text GEGEN DIESEN RECEIPT-SCOPE — Text im
Scope ⇒ Umsetzung läuft entscheidungsgebunden an (Amendment-Datei zu decisions/DL-089 +
Implementierung mit Tests, Aktivierung hinter Flag/Review wie im Programm üblich);
jede Abweichung über den Scope hinaus geht ERNEUT an OWNER. Notizen erweitern den
Scope nicht (Regel 24.08.).

## 3. V8 (Q13-Budget) → **VERTAGT bis Budgetvorschlag vorliegt**

**Receipt (wörtlich):** „V8 warten wir auf deinen/codex Budgetvorschlag" — kein Entscheid;
Ticket 550db748 liefert die Optionen, dann OWNER-Wahl. Q13 bleibt bis dahin unverändert
(No-Change-Durchreiche).
