# OWNER-Vorlage: Fail-Soft für Q05/Q06 — 2026-08-21

**Status:** VORLAGE — ROT (Gate-Kriterien). Keine 12h-Auffangregel; wird erst nach
expliziter OWNER-Freigabe aktiviert. Auftrag: OWNER-Direktive 2026-08-21 („Q05 und Q06
können auch Fail Soft erzeugen und der EA kommt damit trotzdem weiter"), Masterplan-
Entscheidung #2.

## Ist-Zustand (Code-Kanon, verifiziert)

- **Q05** (`framework/scripts/q05_stress_medium.py`): PF > 1.0 ∧ DD < 25 % ∧ ≥ 20 Trades.
  Besitzt bereits **zwei** Nicht-Hard-Kill-Pfade: `FAIL_DD_PORTFOLIO_REVIEW` (DD-Bruch bei
  PF > 1.0 → Park, DL-082 §4) und die Salvage-Lane direkt-zu-Q08 auf Probation-Gewichten
  (OWNER 2026-07-05). Nur `pf_below_floor` (gross unprofitabel) ist terminal.
- **Q06** (`q06_stress_harsh.py`): gleiche Schwellen + geseedete 10 %-Trade-Rejection.
  Emittiert heute ausschließlich `PASS` / `FAIL` / `INVALID` — **kein** Soft-Pfad.
- **Mechanik:** Keine Schema-Änderung nötig. `work_items.verdict` ist freier TEXT; die
  Taxonomie kennt `PASS_SOFT`/`FAIL_SOFT` bereits. Aktivierung = Token in zwei
  farmctl-Policy-Dicts (`cascade_pass_verdicts` ~:16342, `phase_prev_verdicts` ~:19934)
  + Emission im Q06-Runner.

## Vorschlag

**Q05: keine Änderung.** Die OWNER-Intention („kommt trotzdem weiter") ist dort durch
Park + Salvage-Lane bereits erfüllt; `pf_below_floor` soll terminal bleiben — ein gross
unprofitabler EA hat keinen Edge, den ein Softpfad retten könnte.

**Q06: neues Verdikt `PASS_SOFT`** mit enger Band-Definition:

| Bedingung | Wert |
|---|---|
| Post-Stress-PF | **0,95 ≤ PF < 1,00** (unter Stress marginal; Basis-Edge existiert, da Q05-PASS Voraussetzung ist) |
| DD post-stress | < 25 % (unverändert hart) |
| Trades | ≥ 20 (unverändert hart) |
| Weiterleitung | → Q07 mit persistentem Flag `probation:q06_soft` |
| Anti-Stacking | `q06_soft` **+** Q08 `EDGE_SOFT` (DL-072 Cushion 1–2×) = terminal FAIL — zwei Soft-Urteile stapeln sich nie |
| Dashboards | eigener Chip, nie als PASS gerendert |

Begründung: Die 10 %-Rejection ist ein synthetischer Worst-Case. Ein EA, der gross
profitabel ist (Q05-PASS) und unter Synthetik-Stress marginal unter 1,0 rutscht, wird
von den eigentlichen Richtern (Q07 Multi-Seed, Q08 Davey 10 Sub-Gates) weiterhin voll
geprüft. DD und Frequenz bleiben unangetastet — die DD-Decke wurde erst am 15.07.
auf 25 % angehoben; eine weitere Aufweichung würde genau die Größe schwächen, an der
FTMO-Bücher hängen.

## Optionen

- **A (empfohlen): Erst messen, dann scharf schalten.** Eine read-only-Query zählt
  historische Q06-FAILs im Band 0,95–1,00 (Kohortengröße = erwarteter Ertrag der
  Regel). Aktivierung nur, wenn das Band ≥ 2 % der Q06-FAILs stellt; sonst lohnt die
  Komplexität nicht. Aufwand: 1 Query + Konfig-Change + Runner-Emission (Codex, T10).
- **B: Sofort aktivieren** ohne Vormessung.
- **C: Verwerfen** — Q06 bleibt hard-kill; Q05-Pfade gelten als ausreichende Erfüllung
  der Direktive.

## Rollback

Konfig-only: Token aus den zwei Policy-Dicts entfernen; bereits geschriebene
`PASS_SOFT`-Rows bleiben als Evidenz stehen (append-only, kein Verdikt wird
überschrieben). Blast-Radius: nur Q06-Weiterleitung; keine Live-, Deploy- oder
T_Live-Berührung.

## Kosten des Wartens

Gering. Der Funnel-Engpass sind Q04/Q08-Merit-Kills, nicht Q06-Marginalfälle. Es geht
kein Kandidat verloren — FAIL-Rows bleiben requeue-fähig, die Regel kann rückwirkend
auf die historische Kohorte angewendet werden (Re-Adjudikation ohne Re-Run, da das
Band aus vorhandenen Reports lesbar ist).

## Bei Freigabe (Reihenfolge T10)

1. Sizing-Query auf historische Q06-FAILs (read-only, GRÜN).
2. Bei Band ≥ 2 %: Q06-Runner emittiert `PASS_SOFT`; zwei Policy-Dicts erweitert;
   Dashboard-Chip; Anti-Stacking-Check in Q08-Adjudikation.
3. Vault-Seiten Q06 + Pipeline Overview aktualisieren (Verweis auf diese Vorlage
   ersetzt durch Entscheid).
