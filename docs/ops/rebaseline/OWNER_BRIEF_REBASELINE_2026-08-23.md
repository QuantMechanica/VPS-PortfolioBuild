# OWNER-Brief — Pipeline-Rebaseline & Weg zu 25 (2026-08-23)

**Von:** Claude (Orchestrator, `agents/board-advisor`) · **Read-only-Synthese** aus zwei
unabhängigen Analysen: Weg-zu-25 (`PATH_TO_25_CANDIDATES_2026-08-23.md`) und Archiv-Abgleich
(`STRATEGY_ARCHIVE_V4_RECONCILIATION_2026-08-23.md`). Keine DB-Schreibung, kein Enqueue, keine
Fabrik-/T_Live-Änderung.

---

## 1 · Stand in einem Satz

**25 EAs durch alle Gates ist heute kein Durchsatz-Problem, sondern ein Kaputt-Gate-Problem.**
**Null** Paare sind je bis zum terminalen Optimierungs-Gate (v3 Q16 / v4 Q14 Head-to-Head)
lückenlos gültig. Das ökonomische News-Gate `Q09_NEWS` hat in der **gesamten Historie 0 echte
PASS** (49 REVIEW_REQUIRED, 29 INFRA_FAIL, 18 PENDING_RUNNER, 1 CONFIG_LOCKED, 1 INVALID —
Census). Die Opt-Gabel lief nie zu Ende: Q16 = 0 Zeilen je, Q15 = 1 (nur CHALLENGER_SPAWNED),
Q14 = 14 (11 OPT_ELIGIBLE / 3 OPT_REJECTED, kein terminaler PASS). Mehr Strategien in die Basis
zu backfillen erzeugt **keinen** buchfähigen Kandidaten, solange diese zwei Gates nicht als
passierbar bewiesen sind. Der Weg ist **sequenziell, nicht parallel skalierbar**.

Gate-Manifest v4 (linear Q00..Q17, 3 Makro-Phasen) ist gemergt, aber die Laufzeit ist bis zum
OWNER-Cutover weiter v3 (`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`).

## 2 · Was heute gebaut wurde (OPEN_ITEMS §0c/§0d)

- **Archivmatrix produktiv** — `strategy_archive.html` (2.984 Karten, 5.377 Löcher, 4.661 Paare
  mit Q02-PASS aber ohne Q03), stündlich, aus `strategies.html` verlinkt.
- **Detailseiten** lösen `ea_*.html` ab — 3.194 Seiten mit voller Card, allen Läufen,
  MT5-Reportlinks, Grund-Spalte (Commit `4e4fbc257`).
- **DL-090 Aufbewahrung gelaufen** — 43.056 Dateien quarantäniert, 6,91 GB frei.
- **SH-1 Taxonomie live** (111.399 Zeilen, 0 Drift), **SH-3** Annahme widerlegt, Nachfolger
  (typisierte Spalten) beauftragt, wartet auf OFF-Fenster.
- **SH-2 Artefakt-Identität** offen — braucht **OWNER-Factory-OFF-Fenster** + Review; Codex
  `rb-sh2-sh3` ist **in Arbeit** (nicht duplizieren).
- **Balke/XAUUSD** = gemessener, OWNER-genehmigter Negativbefund, kein Rerun.
- Rebaseline-Werkzeuge: Census (`rebaseline_census.py`), Backfill-Planner (Dry-Run,
  `backfill_planner.py`), Archiv-Abgleich (`reconcile_archive_backfill.py`).

## 3 · Der Weg zu 25 — Zahlen, Stunden, Engpässe

**Kohorte an der Front (nach Census-Korrektur):** 3 Paare bei Q10, 23 bei Q08, 10 bei Q07, 23
bei Q06, 10 bei Q05, 26 bei Q04, 277 bei Q03. Actionable insgesamt 7.062.

**Census-Fehldisposition (verifiziert):** die 21 Paare gültig bis Q08 sind alle als
ECONOMIC_FAIL vergraben — 20/21 scheitern nur an der **informationalen** Lane
`Q09_PORTFOLIO=FAIL_PORTFOLIO` (OWNER E1 2026-08-22), ihre ökonomische `Q09_NEWS`-Lane hat
**gar kein** Verdikt. Der Backfill-Planner korrigiert das bereits (kappt die Front bei Q08,
zielt Q09_NEWS neu an) — deshalb ist der Planner das Rückgrat, nicht die rohe Census-Disposition.
Auch die 3 „Q10-gültigen" Paare (QM5_10706/GBPUSD, 11421/EURUSD, 11422/USDCAD) haben ihre
Q09-Gutschrift nur über `PASS_PORTFOLIO` — ihr echtes News-Gate ist maskiert.

**Stunden sind irreführend klein** (25 Kandidaten = 7,0h kumuliert), weil die Phasen-Mediane für
Q09/Q10/Q14/Q15/Q16 ~0 sind — diese Gates liefen praktisch nie. Ein **echter** Q09-v3-Lauf =
8 Configs × bis 3h Zell-Timeout (bis ~24 Terminal-Stunden/Paar), schwerer wenn die Adjudikation
Effekt findet (7×4 = 28 Zellen). Q03 allein für die Tiefe der Basis ≈ 1.544h (~6–7 Wandtage auf
10 Terminals).

**Front ist enqueue-blockiert, nicht enqueue-bereit:** von 1.471 enqueue-fähigen Zeilen liegen
nur 10 in den ersten 1.000 Rängen; die Q08-Front ist gehalten (9 Autoseal-Holds), in-flight
(`q09_news_prerequisite_in_flight` — nicht neu enqueuen) oder REVIEW_REQUIRED. Die 9 Autoseal-
Holds haben **echte Q07/Q08/Quell-Defekte** (5 Q08-Identität/Hash, 1 Closure-Vintage, 2 fehlende
Q07-Aggregate, 1 fehlender Q07-Vorgänger) — kein RELEASE_AFTER_FIX; Fix = Q07/Q08-Regeneration,
keine Sealer-Wiederholung. Q09-Contract-v3 (Seed 17 + Seam) ist jetzt ausführbar.

**Die entscheidende Unbekannte: „Kann überhaupt eine Strategie Q09 passieren?"** Mit 0 PASS in
der Historie gibt es keine belegte Ausbeuterate. **Realistischer Zeitplan: ~3–4 Wochen, WENN**
Q09 in gesunder Rate passierbar ist und die Opt-Gabel im ersten Anlauf funktioniert; **deutlich
länger**, falls die Q09-Rate niedrig ist — dann wird der Engpass die Versorgung mit Q08-gültigen
Strategien und die Q03→Q08-Basis muss viel tiefer getrieben werden.

**Der Plan folgt daraus (drei Produktions-Sonden, sequenziell):** (1) 10 front-nächste Zeilen
inkl. 3 echter Q09-v3-Reruns enqueuen → **erstes ehrliches Q09-Verdikt**; (2) Q07/Q08 für die 9
Autoseal-Holds regenerieren → Q09-Damm öffnen; (3) Opt-Gabel (Q14/Q15/Q16) erstmals end-to-end
auf den 3 Q10-Paaren fahren → beweisen, dass die Gabel überhaupt läuft.

## 4 · Strategy-Archive — Restpunkte

Das Archiv stimmt mit dem Backfill im Kern überein: 4.661 Paare (Q02-PASS ohne Q03) landen bei
beiden Werkzeugen identisch. **Aber:**

- **Nicht manifestgesteuert wo es zählt** — Spaltensatz, Makro-Phasen-Bänder, Lückenkette,
  P2/Q09-Faltung sind hartkodierte Literale (`archive_matrix.py:47-60,108-115`). Es ignoriert
  PHASE_ORDER/advancement_table aus `phase_ids.py`.
- **Beim v4-Flip bricht das Archiv still** (rendert falsch, keine Exception): es liest `phase`
  roh und ignoriert `gate_contract_version`. Worst case: v3-Q10 (Incumbent) und v4-Q10 (News)
  in einer Spalte; v4-Phase-2-Gates unter dem Phase-3-Band; v4-Q17 (Live Burn-In) komplett
  fallengelassen.
- **8 echte Defekt-Löcher:** das Archiv faltet Q09_NEWS+Q09_PORTFOLIO und akzeptiert das
  informationale PASS_PORTFOLIO als „Q09 bestanden", um ein falsches Q10-Loch zu zeichnen.
- **Spec-Status §11a:** F1/F3/F6/F7/F8 fertig; F2 (Q10.1–Q10.3) durch v4-Entscheid überholt;
  F4 (Stale-Pass) blockiert auf SH-2 (Banner-Fallback korrekt); F5 (Leerzell-Gründe) offen;
  AC#4 Chip-Tooltips ohne Datum+Work-Item-ID; AC#3 gefährdet (Footer kann Legacy P9/P10 drucken).

## 5 · Entscheidungsschlange (max 5) — Empfehlung + Auffangregel

| # | Entscheid | Empfehlung | Auffangregel-Frist |
|---|---|---|---|
| 1 | **Factory-OFF-Fenster für SH-2 (-512)** terminieren — schaltet Archiv-F4 frei; Codex `rb-sh2-sh3` bereit; kein AI-Seat toggelt die Fabrik | OWNER nennt ein OFF-Fenster; bis dahin läuft der F4-Banner korrekt weiter | **ROT** (Fabrik/OFF) — keine Auffangregel; OWNER-Fenster nötig |
| 2 | **v4-Nummerierung fürs Archiv bestätigen; -502 (Q10.1–Q10.3) als überholt schließen** | Archiv übernimmt v4 Q00..Q17 am Flip; -502 formell schließen (`74e72403`) | reversibel, dokumentierbar → **12h Auffangregel**: ich schließe -502 als superseded und stelle T1/T2 an |
| 3 | **Tranche-1A-Frontsonde** (10 front-nächste Zeilen, inkl. 3 Q09-v3-Reruns), append-only, ~7 Fabrikstunden — liefert das **erste ehrliche Q09-Verdikt** | ausführen (GELB/reversibel, `--append-only-rerun-of` auf jeder RERUN_INFRA, Symbol-Cap 3 respektiert) | **12h Auffangregel**: ich enqueue die 10 als append-only Kinder |
| 4 | **Archiv-Loch-Semantik-Kontrakt** (IA-Entscheid, ist Claude-Arbeit): (a) zieht das Archiv Löcher für OWNER/manuelle Gates oder eigenes Band; (b) Frontmatter-Zweitquelle separat; (c) Archiv-Loch == Backfill FILL_MISSING wo sie übereinstimmen sollen | ich erstelle die kurze Entscheidungsnotiz, die T4 implementiert | reversibel → **12h Auffangregel**: ich fixiere (a)/(b)/(c) |
| 5 | **QM5_13036 auf XAUUSD ausspielen? (-513)** — Kandidatenmenge = **ROT** | vertagen bis Q09 als passierbar bewiesen (Sonde #3) etwas zu bewerten gibt | **ROT** (Kandidatenpool) — keine Auffangregel |

---

**Nächster Schritt:** Sonden 1–3 als Router-Tasks kommissionieren (die 3 Produktionsläufe sind
das Rückgrat des Wegs zu 25), die Archiv-Manifest-Härtung (T1–T4) an Codex vor dem v4-Flip. Die
Ausbeuterate von Q09 aus Sonde #1 bestimmt, ob 3–4 Wochen halten.

**Evidenz:** `docs/ops/rebaseline/PATH_TO_25_CANDIDATES_2026-08-23.md`,
`docs/ops/rebaseline/STRATEGY_ARCHIVE_V4_RECONCILIATION_2026-08-23.md`,
`docs/ops/rebaseline/BACKFILL_PLAN_2026-08-23.md`, `docs/ops/evidence/2026-08-23_rb-q09-autoseal.md`,
`docs/ops/OPEN_ITEMS_STATUS.md §0c/§0d`.
