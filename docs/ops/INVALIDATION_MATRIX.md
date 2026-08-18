# INVALIDATION_MATRIX — welche Änderung welches Gate ungültig macht

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-18 · Work Order Runde 5 §6
**Artefakt der Auszählung:** `artifacts/audit_invalidation_count_20260818.json`
**Erzeuger:** `tools/strategy_farm/portfolio/audit_invalidation_count.py`

Der OWNER-Grundsatz — *„Ändern sich EA, Setfile oder Binary, werden die betroffenen Gate-Tests
wiederholt. Ein Verdikt gilt nur für das Artefakt, an dem es gemessen wurde."* — existierte bisher
als Praxis. Hier ist er ein Artefakt, damit ein Re-Run keine Ermessensentscheidung mehr ist.

---

## 1 · Die Matrix

| Änderungsklasse | invalidiert | Begründung |
|---|---|---|
| **Binary geändert** (`.ex5`-SHA256 abweichend) | **Q02–Q10 vollständig**, für jedes (EA, Symbol) dieser Binary | Belegt: 12 von 43 Verdikten kippten allein durch Recompile, ein Stream verlor 13 % seiner Trades. Ein Verdikt ist eine Aussage über eine Binary, nicht über einen Namen. |
| **Setfile: Wert eines Strategie-Inputs geändert** | **Q02–Q10 vollständig** für dieses (EA, Symbol) | Der Wert geht in die Handelslogik ein; die Trade-Reihe ist eine andere. |
| **Setfile: fehlender Input ergänzt** | **Prüfbedingt** — invalidierend **nur wenn der ergänzte Wert vom kompilierten Default abweicht** | MT5 nimmt bei fehlendem Schlüssel den Default der Binary. Ergänzung == Default ⇒ das Verhalten war schon vorher dieses. Abweichung ⇒ wie „Wert geändert". Das ist ein **prüfbares Kriterium**, keine Einschätzung: Default aus dem Quelltext, Wert aus dem Setfile, Vergleich. Betroffen: die 2 exponierten EAs, 37 Verdikte. |
| **Setfile: nur Metadaten/Kommentare** (`build_hash`, Header, Reihenfolge) | **nichts** | Kein Lauf-Input. **Aber:** ein Setfile-Rewrite durch `gen_setfile.ps1` ohne `-EALabel` degradiert nebenbei echte Inputs (news/seed/friday) — dann greift Zeile 2, nicht diese. Die Klasse gilt nur für nachgewiesen unveränderte Wertfelder. |
| **Symbol- oder Historie-Änderung** (anderes Host-Symbol, neu importierte `.DWX`-Historie, anderes Custom-Archiv) | **alle Gates dieses Symbols** | Die Eingangsdaten sind andere. Ein Verdikt über XAUUSD.DWX-Vintage A sagt nichts über Vintage B. |
| **Extraktor geändert** (E-2) | **kein Gate** | Ändert die **Auswertung**, nicht den **Lauf**. Die Gates lesen die Evidenzdateien direkt (`q05_stress_medium.py:94`) und haben `ea_metrics` nie konsultiert. Wo Evidenz existiert, genügt Neuauswertung — **ohne Rechenzeit**. Nur wo die Evidenz selbst fehlt, muss der Lauf wiederholt werden. |

### Die letzte Zeile im Klartext

Eine Extraktor-Reparatur erzeugt **keinen neuen Messwert**. Sie liest einen bereits gemessenen Wert
aus einer bereits geschriebenen Datei, die der Extraktor bisher nicht geöffnet hat. Der DD eines
Q08-Laufs steht seit dem Lauf in dessen `aggregate.json` als `mc_maxdd_p95_pct`; dass er in
`ea_metrics` fehlt, macht ihn nicht ungemessen.

**Die Verwechslung, gegen die diese Zeile gerichtet ist,** ist die naheliegende: „`ea_metrics` ist
zu 69 % leer, also müssen 69 % der Läufe wiederholt werden." Falsch in beide Richtungen — die
Reparatur füllt einen Teil ohne jeden Lauf, und der große Rest ist durch keine Reparatur erreichbar,
weil die Evidenz gelöscht ist (`EXTRACTOR_FIX_REPORT.md` §0).

---

## 2 · Die Auszählung, 91 Pool-Paare

**Gemessen**, nicht geschätzt: eine Zeile zählt nur dann als lesbar, wenn ihr `source` kein
Fehlermarker ist **und** die Datei jetzt noch existiert.

| Klasse | Paare | Bedeutung |
|---|---:|---|
| **alle 6 Phasen neu auswertbar** | **39** | kostenlos |
| **teilweise neu auswertbar** | **44** | kostenlos für die vorhandenen Phasen |
| **Re-Run nötig** (keine Phase lesbar) | **5** | Rechenzeit |
| **gar keine Zeilen** | **3** | nie gelaufen — kein Re-Run, sondern ein Erstlauf |

**83 von 91 Paaren liefern mindestens eine Phase ohne einen einzigen Backtest.** Die Erwartung aus
§6 — „die erste Gruppe ist deutlich größer, und E-1 wird dadurch erheblich billiger als es klingt" —
ist bestätigt.

### Je Phase

| Phase | lesbar | Evidenz gelöscht | keine Zeile |
|---|---:|---:|---:|
| Q02 | 56 | 32 | 3 |
| Q04 | 54 | 34 | 3 |
| Q05 | 60 | 27 | 4 |
| Q06 | 59 | 25 | 7 |
| Q07 | 64 | 20 | 7 |
| **Q08** | **81** | **7** | 3 |

**Q08 ist der Glücksfall, und ausgerechnet dort sitzt der Drawdown.** 81 von 91 Paaren tragen ihre
Q08-Evidenz noch, und der DD steht im Aggregat selbst — nicht in einer nachgelagerten Datei.
**E-1 ist für Q08 eine Neuauswertung von 81 Paaren zu Nullkosten.**

Q04 ist der schwierigere Fall: 54 Paare lesbar, aber der DD liegt dort nicht im Aggregat, sondern in
der je Fold referenzierten `summary_path`. Ob diese Fold-Summaries dem Alter entgangen sind, ist
**noch nicht gemessen** — Codex misst es im Zuge der Reparatur, und es ist die einzige Zahl in
diesem Dokument, die noch offen ist.

### Nach Kohorte

| Kohorte | vollständig | teilweise | Re-Run | keine Zeilen |
|---|---:|---:|---:|---:|
| C1 Determinismus-Kontrolle (12) | 11 | 1 | 0 | 0 |
| C2 nur Re-Run (26) | 7 | 19 | 0 | 0 |
| C3 Rebuild + Re-Run (53) | 21 | 24 | 5 | 3 |

Alle 8 echten Rechenfälle liegen in **C3** — der Kohorte, die ohnehin neu gebaut und gelaufen wäre.
**Der Re-Run-Anteil von E-1 ist damit vollständig in einem Batch enthalten, der aus anderen Gründen
schon geplant ist** (§7, `BATCH_SPEC_MERGED.md`). Zusätzliche Rechenzeit allein für E-1: **null.**

---

## 3 · Was daraus für die Reihenfolge folgt

Die in §4 verbindlich gesetzte Reihenfolge — E-2 vor E-1 — ist richtig und wird eingehalten. Eine
Präzisierung ist nötig und wird hiermit gemeldet, nicht eigenmächtig umgesetzt:

> **§5 (Baseline einfrieren) muss vor der Vollextraktion aus §4.1.4 liegen, nicht erst vor E-1.**
> Die Vollextraktion schreibt `ea_metrics` neu — das ist bereits eine Regenerierung im Sinne von §5,
> auch wenn sie keinen Lauf anfasst. Ich habe die Baseline deshalb **vor** dem Codex-Dispatch
> genommen: Snapshot `3472a5d2e1b5`, off-host auf G:. Das Codex-Ticket enthält ausdrücklich
> **kein** DB-Schreibrecht.

Damit lautet die tatsächlich ausgeführte Reihenfolge:

1. Baseline eingefroren (`3472a5d2e1b5`) ✔
2. E-2 Fehlerbild gemessen ✔ · Reparatur dispatcht (Ticket `59c2e32c`)
3. Auszählung ✔ (dieses Dokument)
4. — Verifikation gegen die Gate-Lesequelle, dann Vollextraktion
5. — E-1 auf dem reparierten Extraktor
6. — Re-Run der 8 echten Fälle, im vereinten Batch aus §7
