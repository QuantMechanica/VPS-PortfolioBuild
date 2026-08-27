# 550db748 — Q13-Budget-Vertrag (OWNER-Vorlage, nicht aktiv)

- Datum: 2026-08-27
- Router-Task: `550db748-239c-4596-9efc-ffd50fc73224`
- Status: **GOVERNANCE DRAFT — REVIEW, NICHT VERSIEGELT, NICHT AKTIV**
- Gegenstand: v4 Q13 `Parameter Optimization & Freeze`
- Aktivierungswirkung dieses Dokuments: **keine**

## 1. Entscheidung in einem Satz

Vor dem ersten echten Q13-Numeriklauf soll OWNER entweder einen konservativen
Deckel von **1 Parameter × höchstens 5 Werte** oder einen mittleren Deckel von
**3 Parametern × höchstens 5 Werte je Parameter** versiegeln. Empfehlung:
**konservativ starten**; der bestehende Null-Parameter-Pfad bleibt in jedem Fall
Default und endet weiter als `NO_PARAMETER_CHANGE`.

## 2. Vertragsentwurf

### 2.1 Geltungsbereich und Zähleinheit

Der Vertrag gilt je einzelner Q13-Admission und je `(EA, Symbol)`-Paar. Er
erlaubt ausschließlich bereits im Parent-EA verdrahtete, mechanische numerische
Inputs. Er genehmigt weder neue Strategie-Mechanik noch ein Recompile, einen
Gate-Skip, eine Schwellenänderung, ML im EA, Live-Setfiles oder Deploy.

Ein Parameter wird in einer Zelle isoliert variiert; alle übrigen numerischen
Inputs bleiben am Parent-Wert und die in Q12 versiegelte Filterkombination bleibt
fix. Es gibt kein Parameter-Vollkreuz.

### 2.2 Default und harte Obergrenzen

1. `parameter_count=0` bleibt zulässig und ist der Default. Dann gilt der
   bestehende explizite Null-Trial-Vertrag; Q13 endet unverändert als
   `NO_PARAMETER_CHANGE`.
2. Ohne OWNER-versiegelte Budgetoption darf kein `opt_param_grid.json` für einen
   Q13-Lauf registriert oder enqueued werden.
3. Jeder deklarierte Parameter enthält den unveränderten `parent_value` als
   Pflichtwert und Kontrollzelle.
4. Je Parameter sind höchstens fünf verschiedene Kandidatenwerte zulässig,
   **einschließlich** Parent-Wert.
5. Die Anzahl der Parameter ist durch die gewählte Option K oder M begrenzt.
6. Ein Überschreiten irgendeines Deckels ist kein Warnfall, sondern
   `BUDGET_CONTRACT_EXCEEDED`; Enqueue und Auswahl müssen fail-closed stoppen.
7. Eine weitere Q13-Admission für dasselbe Paar darf den Deckel nicht umgehen.
   Alle in derselben Q12→Q14-Lineage geprüften numerischen Hypothesen werden für
   Budget und DSR kumuliert.

### 2.3 Pflichtdeklaration vor Hash-Versiegelung

Die Q13-Deklaration muss vor der ersten Zelle vollständig und unveränderlich
enthalten:

- `contract_id`, `gate_contract_version=v4`, EA, Symbol, Timeframe;
- Q11- und Q12-Work-Item-/Evidence-Bindung;
- Parent-Build-, Setfile- und Include-Closure-Hashes;
- gewählte Budgetoption und deren OWNER-Entscheid-ID;
- `parameter_count`, Parameterreihenfolge und je Parameter:
  - exakter Inputname und Typ,
  - Parent-Wert,
  - geordnete Kandidatenwerte,
  - zulässige technische Bounds und Interaktionsconstraints,
  - ökonomisch/mechanische Hypothese,
  - erwartete Wirkungsrichtung bzw. Plateauform,
  - Widerlegungskriterium,
  - Frequenzprüfung;
- Q12-Filterfreeze und die Regel „ein Parameter je Zelle, übrige am Parent";
- Fenster `2019..2025`, objektive Kennzahl `return_to_maxdd`,
  Aktivitätsboden und Konsistenzregel;
- `declared_trial_count_before`, berechneter Zuwachs und
  `declared_trial_count_effective_after`;
- exakte physische Zellenzahl und Terminal-h-Budget;
- SHA-256 der kanonisch serialisierten Gesamterklärung.

Fehlt ein Feld oder driftet ein Hash, bleibt Q13 auf Hold. Nachträgliches
Erweitern einer versiegelten Kandidatenliste ist verboten; es erfordert eine
neue, kumulativ budgetierte Admission.

### 2.4 Hypothese, Widerlegung und Frequenz je Parameter

Jeder Parameter braucht eine kausale, vor Ergebnisansicht formulierte Hypothese.
„Wert X testet besser" oder eine bloße Nachoptimierung der beobachteten Kurve ist
keine Hypothese. Zulässig ist beispielsweise: „Ein höherer Exit-Puffer lässt den
strukturell erwarteten Swing auslaufen, erhöht aber oberhalb des Plateaus den
Drawdown; deshalb wird ein lokales Plateau um den Parent erwartet."

Das Widerlegungskriterium muss vorab messbar sein und mindestens festlegen:

- kein Kandidat erfüllt die versiegelte Konsistenzregel; oder
- ein Kandidat bricht in irgendeinem gewerteten Jahr den Aktivitätsboden; oder
- der erwartete robuste Plateauverlauf fehlt und nur ein isolierter Bestwert
  erscheint; oder
- der spätere versiegelte Holdout/Q14-Vergleich bestätigt den DEV-Vorteil nicht.

Die Frequenzprüfung bleibt die von DL-088 ratifizierte Regel: weniger als
**10 distinkte Entry-Tage in irgendeinem gewerteten Jahr** (bei Teiljahren
pro rata) macht einen Wert inadmissible. Er wird vor der Leistungsauswahl
ausgeschlossen. Der Aktivitätsboden darf nicht nach Ergebnisansicht geändert
werden.

### 2.5 Auswahl- und Konsistenzregeln

Die Regeln entsprechen dem versiegelten DL-088/DL-089-Muster:

1. Auswahl ausschließlich auf DEV/IS; keine Holdout-Einsicht während der Wahl.
2. Jeder Wert wird gegen die gemeinsame gleichjährige Parent-Kontrolle mit
   eingefrorenem Q12-Filter verglichen.
3. Ein Wert qualifiziert nur, wenn mindestens zwei Drittel der Auswahljahre je
   mindestens `+5 %` relative Verbesserung in `return_to_maxdd` zeigen und kein
   Jahr die Frequenzprüfung bricht.
4. Gewählt wird der Median des robust qualifizierenden Plateaus, niemals der
   einzelne Bestwert.
5. Qualifiziert kein Wert, bleibt der Parent-Wert.
6. Mehrere Parameter werden nur one-at-a-time bewertet; es gibt kein Vollkreuz.
   Die deterministisch kombinierten Plateauwerte müssen anschließend gemeinsam
   den bestehenden Full-Window- und Q14-Vergleich bestehen.
7. Alle deklarierten Nicht-Parent-Hypothesen erhöhen die DSR-Trialzahl, auch wenn
   sie später inadmissible oder verworfen sind. Kein Survivorship-Rabatt.

### 2.6 Trial- und Zellzählung

Für Parameter `i` mit `V_i` Kandidatenwerten (Parent enthalten) gilt:

```text
declared_trial_increment = Σ(V_i - 1)
physical_Q13_cells       = 7 × (1 + ΣV_i) + 2
terminal_hours           = physical_Q13_cells × 7.2 / 60
```

Die sieben Jahre sind wiederholte Messungen derselben Hypothese und erhöhen die
DSR-Trialzahl nicht. Physisch erzeugt der aktuelle Runner jedoch:

- 7 gleichjährige gemeinsame Baseline-Zellen;
- `7 × ΣV_i` Parameterwert-Jahreszellen;
- 2 Full-Window-Zellen (finale Kombination und Parent-Baseline).

Der Trial-Zuwachs muss vor Enqueue im Ledger registriert werden. Jahreszahl und
Parent-Kontrollen dürfen weder aus Kosten- noch aus Trialzählung verschwinden.

## 3. Optionen und Kostenmodell bei 7,2 min/Zelle

| Kennzahl | Option K — konservativ | Option M — mittel |
|---|---:|---:|
| Max. Parameter je Paar | **1** | **3** |
| Max. Werte je Parameter, Parent inkl. | **5** | **5** |
| Max. neue DSR-Trials `Σ(V_i-1)` | **4** | **12** |
| Gemeinsame Jahres-Baselines | 7 | 7 |
| Parameterwert-Jahreszellen | 35 | 105 |
| Finale Full-Window-Zellen | 2 | 2 |
| Physische Q13-Zellen je Paar | **44** | **114** |
| Terminal-h je Paar | **5,28 h** | **13,68 h** |
| Terminal-h für 25 Paare | **132 h** | **342 h** |
| Mehrkosten M gegenüber K | — | **+8,40 h/Paar; +210 h/25 Paare** |

Die Stunden sind additive Terminal-h und behaupten keine Kalenderdauer oder
Parallelisierung. Die gemessenen 7,2 min/Zelle stammen aus
`DURCHSATZ_ANALYSE_40_TAGE_2026-08-27.md` §5.1. Warm-/Optimizer-Gewinne werden
hier bewusst nicht vorweggenommen.

Ein vorhandener, noch nicht aktivierender Beispiel-Grid mit `5+5+4` Werten
würde 11 neue Trials, 107 physische Zellen und **12,84 Terminal-h/Paar** binden.
Er ist Anschauung, keine durch diesen Entwurf genehmigte Admission.

## 4. Empfehlung

**Option K für die erste echte Q13-Kohorte versiegeln.** Begründung:

- entspricht am engsten DL-088s Ein-Hebel-Disziplin;
- begrenzt Suchfreiheitsgrade und DSR-Deflation;
- hält Q13 auf 5,28 h statt 13,68 h pro Paar;
- erzeugt nach wenigen Paaren reale Evidenz, ob ein zweiter oder dritter
  Parameter überhaupt zusätzlichen Erkenntniswert bringt.

Option M bleibt eine explizite spätere Eskalation. Voraussetzung dafür wären
mindestens fünf abgeschlossene Option-K-Paare, ein Bericht über Plateauqualität,
Frequenzbrüche, Q14-Bestätigung und real gemessene Q13-Terminal-h. Eine
Eskalation ist ein neuer OWNER-Entscheid, keine automatische Folge.

## 5. Rückweg

Vor Aktivierung ist der Rückweg trivial: Entwurf ablehnen oder vertagen; kein
Code, Grid, Ledger und keine Queue ändert sich. Der bestehende
`parameter_count=0`-/`NO_PARAMETER_CHANGE`-Pfad bleibt unangetastet.

Nach einer späteren separaten Aktivierung wäre der Rückweg:

1. neue Q13-Admissions auf `parameter_count=0` begrenzen;
2. keine bereits versiegelten/gestarteten Zeilen löschen oder umschreiben;
3. laufende, bereits geclaimte Tests nicht abbrechen;
4. offene noch ungeclaimte Grids nur über einen eigenen OWNER-genehmigten,
   append-only Disposition-Plan schließen;
5. Entscheidung durch einen datierten Nachfolger superseden, nie dieses
   Dokument rückwirkend ändern.

## 6. OWNER-Entscheidungsvorlage

### `OWNER-DEC-Q13-BUDGET-CONTRACT-20260827` — OPEN

| Feld | Vorlage |
|---|---|
| Kategorie | Gate governance / Q13 budget |
| Frage | Soll Option K (max. 1 Parameter × 5 Werte inkl. Parent; max. +4 Trials; 5,28 Terminal-h/Paar) als Q13-Default versiegelt werden und Option M bis zu einem separaten Eskalationsentscheid gesperrt bleiben? |
| Empfehlung | **JA — Option K.** Erst reale Q13/Q14-Evidenz sammeln; Option M nicht vorwegnehmen. |
| JA-Wirkung | Der Entscheid autorisiert ausschließlich die Ausarbeitung einer separaten hash-versiegelten Aktivierung und ihrer Tests. Bis diese reviewed ist, bleibt Q13 No-Change. |
| NEIN-Wirkung | Keine Budgetoption wird aktiviert; Q13 bleibt `parameter_count=0`/`NO_PARAMETER_CHANGE`. OWNER kann Option M oder eine andere Grenze separat beauftragen. |
| VERTAGT-Wirkung | Wie NEIN, aber Wiedervorlage nach den ersten belastbaren Warm-/Optimizer-Kostenmessungen. |
| Cost of wait | Kein Factory-Stopp. Echte Q13-Numerik startet nicht; Q12 und der No-Change-Pfad laufen unverändert weiter. |
| Rückweg | Admissions wieder auf Null-Parameter begrenzen; append-only Evidenz erhalten; keine laufenden Tests abbrechen. |
| Evidenz | dieses Dokument; DL-088; Optimization-Track-Vorlage; Durchsatzanalyse §5 |
| Severity | `action` |

Explizite Antwortzeile:

```text
OWNER-DEC-Q13-BUDGET-CONTRACT-20260827: JA | NEIN | VERTAGT
OWNER-NOTIZ: <optional; "Option M" ist kein implizites JA für Option K>
```

Eine Antwort dokumentiert nur die Governance-Entscheidung. Sie enqueued nichts,
ändert kein Gate und autorisiert weder T_Live noch AutoTrading.

## 7. Reproduzierbare Evidenz

Quellbindungen (SHA-256):

| Quelle | SHA-256 |
|---|---|
| `docs/ops/DURCHSATZ_ANALYSE_40_TAGE_2026-08-27.md` | `eb3d95e38062c2027628b7dd02270f310a1dd371a776e3ed0548ac1c52e631ed` |
| `docs/ops/OPT_TRACK_V2_VORLAGE_2026-08-21.md` | `0a84a57d2a4198f51394bd0d43baa298e8b66049d25c2ccec5b530ba566a455a` |
| `decisions/DL-088_optimization_track_v2_levers_and_overfit_contract.md` | `cdbb9fbd4dce7a18b0757b81bcd4644057c98497bc78d850061882a7c25d5f1f` |
| `tools/strategy_farm/opt_census_select.py` | `f34a131e9eca889246561e51619d58e605e76e07750e98eaea04937ae4e3e256` |
| Beispiel-Grid `QM5_41097.../opt_param_grid.json` | `da81af4c509201df8b6107e0782d73b08a102052546278db4a0cc0a9515ed572` |

Rechenprüfung:

```powershell
python -c "# Formel aus §2.6 für P=1/3, V=5, Y=7, 7.2 min/Zelle"
```

Verifizierte Resultate:

- Option K: `trial_increment=4`, `cells=44`, `5.28 h/Paar`, `132 h/25`
- Option M: `trial_increment=12`, `cells=114`, `13.68 h/Paar`, `342 h/25`
- Beispiel `5+5+4`: `trial_increment=11`, `cells=107`, `12.84 h/Paar`

Keine Datei außerhalb dieses Evidenzdokuments wurde für diesen Auftrag
verändert. Es gab keinen DB-, Queue-, Worker-, Flag-, Gate- oder Live-Write.
