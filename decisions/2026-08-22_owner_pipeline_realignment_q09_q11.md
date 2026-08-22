# OWNER-Entscheid 2026-08-22 (spätabends): Pipeline-Rückführung auf den Vault-Kanon

Autorität: OWNER, explizit im Orchestrator-Chat 2026-08-22 ~21:20–21:35Z.
Protokoll: Claude (Orchestrator). Evidenz der Vorlage:
`docs/ops/evidence/2026-08-22_ultracode_q09_push_12969_13213.md` §4/§7.

## 1. Befund (Vorlage)

Vault `03 Pipeline/Pipeline Overview.md` (Z. 34, 64–66, 101–102): **Q09 = News Impact
Mode**; Q10-Dependency-Gate = **nur** Q09 `CONFIG_LOCKED`; **Portfolio = Q11 (OWNER)** nach
Q10 bzw. nach Q16. Die Implementierung seit 2026-08-04 koppelt zusätzlich einen
`Q09_PORTFOLIO`-Sibling mit `PASS_PORTFOLIO` an Q10 (`q09_news_schema.assert_q10_dependency_gate`,
`farmctl._q10_dependency_context/_bind_q10_dependencies`, Runner-Bind für Q08 FAIL_SOFT,
Autopilot-Paired-Rescue, `q10_confirmation_contract` Pflichtfelder, `candidate_qualifications`-
Trigger). Folge: Portfolio-Admission wird vor Q10 und vor die Optimierung gezogen; EAs werden
gegen ein Buch bewertet, in dem sie z. T. selbst Incumbent sind (13213, 12849, 12855, 12708,
11129 …).

## 2. Entscheidungen (alle genehmigt)

**E1 — Q10-Gate = nur CONFIG_LOCKED.** `Q09_PORTFOLIO` bleibt als Messung erhalten, wird
informationale Abhängigkeit (jedes Verdikt), Input für Q11. Kein Abbruchkriterium vor Q10.

**E2 — Q09_NEWS-Arm für jeden Q08 PASS/FAIL_SOFT** ohne Portfolio-Vorbedingung (Vault:
EDGE_SOFT läuft zu Q09 weiter). Identitäts-/Hash-Authentifizierung unverändert.

**E3 — Ziel-Reihenfolge der Gates (OWNER-Wortlaut):**
1. Gesamtrun **vor** Newsfilter (Baseline; heute = Q08-Baselinelauf, künftig explizit als
   Q10a „Baseline Full Run" zu führen),
2. Newsfiltertest **inkl. Empfehlung FTMO-geeignet ja/nein** (Q09, beide Achsen),
3. Optimization **Pattern Filter** — bis zu **drei Filter je Richtung** (DL-089-Zensus /
   Q14-Hebel),
4. **Parameter-Optimierung** (Q15 DEV-Sweep),
5. **neuerlicher Gesamtrun mit den besten Settings** → Vergleich gegen den Gesamtrun vor
   News (Q16 Head-to-Head; Referenz = Schritt 1),
6. **Portfolio-Build erst als Abschluss aller Gates** (Q11).
Konsequenz: Gate-Manifest v2 → v3 (Q10a Baseline, Q09, Q14/Q15, Q16 vs. Baseline, Q11);
kein Gate fällt weg, die Reihenfolge und die Q10-Abhängigkeit ändern sich.

**E4 — OWNER-DEC-MQ5-DRIFT-LIVE genehmigt:** governed Rebuild-Welle mit Canary für
QM5_10706, 12989, 1567, 13128, 10847 (mq5 editiert ohne Recompile) und QM5_13213
(MAE-Hook-Gate). Muster MNT-020 (Canary-Zeile, Adjudikation: execution_identity == neuer
EX5-Hash, zero-trades allein nie PASS). T_Live bleibt unberührt; Live-Deploy weiterhin nur
über signiertes Manifest (OWNER).

## 3. Umsetzung

- Codex-Ticket `OPS-Q10-REALIGN-E1-E2` (Schema-Migration v5→v6, Gate, Cascade, Runner,
  Autopilot, q10-Contract, Tests, Dry-Run-Evidenz) — Prio 96.
- Codex-Ticket `OPS-GATE-MANIFEST-V3-E3` (Manifest v3 + Cockpit/phase_label + Vault-
  Pipeline-Seiten) — Prio 90, nach E1/E2.
- Codex-Ticket `OPS-REBUILD-WAVE-E4` (6 EAs, Canary zuerst) — Prio 92.
- Claude: Review-Close aller drei, Vault-Mirror (`03 Pipeline`, `12 ToDo`), Heartbeat.

Bis E1/E2 live sind, bleiben die betroffenen Q09-Zeilen (13213 u. a.) fail-closed gehalten —
keine Handbindung, keine Verdikt-Mutation.
