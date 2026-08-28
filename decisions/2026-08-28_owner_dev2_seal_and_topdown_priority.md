# OWNER-Entscheide 2026-08-28 (Chat-Receipts)

## 1. OWNER-DEC-DEV2-6140-SEAL → **JA**

**Receipt (wörtlich):** „DEV2:ja" — Das unsignierte Build-6140-Rebase-Template
(aus Task 9018743b, V4a Phase 5) ist hiermit OWNER-signiert. Scope: NUR die
DEV2-Validierungs-Lane (disposable) wird auf den aktuellen Factory-Build 6140
gehoben; T1–T10/T_Live unberührt. Zweck: Warm-Paritäts- und Batch-Speedup-Messung
auf einem Build (20 authentifizierte Kalt-Referenzen vom 28.08. liegen bereit).

## 2. OWNER-DEC-TOPDOWN-PRIORITY-20260828 → **Dispatch-Doktrin: höchstes Gate zuerst**

**Receipt (wörtlich):** „Buch erst nach dem höchsten Gate, also nach der ganzen
Optimization, Prios deshalb je höher Gate, desto höher Prio, heißt auch, alle Q02
kommen erst, wenn alles durch die Optimization ist und Q09, etc bis zu Q04
herunter leer ist"

**Festschreibung:** Die Claim-Reihenfolge ordnet strikt absteigend nach Gate-Rang:
Optimierungszweig (Q12–Q14 inkl. deren Zellen/OPT_CENSUS) > Q11 > Q10 > Q09 > …
> Q04 > Q03 > Q02. Untere Gates werden erst bedient, wenn oberhalb nichts
Claimbares existiert. **Präzisierung (Utilization-Klausel):** Bestehende Caps und
Holds bleiben gültig; ist höherrangige Arbeit nur durch Cap/Hold nicht claimbar,
fällt der Slot auf den nächstniedrigeren Rang durch, statt leerzulaufen —
Kapazität wird nie für untere Gates verwendet, solange obere Gates *ungehindert*
claimbare Arbeit haben. Gate-Kriterien selbst bleiben unberührt (reine
Queue-Ordnung, GRÜN + OWNER-instruiert).

**Nachtrag (OWNER-Bestätigung, gleicher Tag):** Utilization-Klausel ausdrücklich
bestätigt („bevor Terminals leer laufen, können sie immer noch aus unteren Gates
Backtests ziehen"). Alters-Health-Checks bleiben UNVERÄNDERT — deren künftige
Meldungen zu Q02/Q04-Tail-Age sind unter dieser Doktrin zur Kenntnis genommen,
keine Defekte, keine Check-Anpassung. Rationale: schnellster Weg zu den 25.
