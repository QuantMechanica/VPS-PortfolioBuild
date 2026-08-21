# OWNER-Vorlage: Optimization Track v2 (Q14–Q16) — 2026-08-21

**Status:** VORLAGE (Masterplan T7). Bausteine mit GELB-Status (neue Q14-Hebel) sind nach
Vollmacht vorab genehmigt, sofern die vier GELB-Bedingungen erfüllt sind — dieses Dokument
erfüllt sie je Hebel. Die Q16-Zusatzkriterien (Overfit-Schwellen) sind **ROT** und brauchen
explizite OWNER-Freigabe. Auftrag: OWNER-Direktive 2026-08-21 (ULTRACODE); Fork-Punkt
Q10-PASS ist OWNER-bestätigt (Masterplan-Entscheidung #5).

## 1 · Mapping: OWNER-Vision ↔ bestehender DL-084-Track

Der Track existiert und läuft (14 Q14-Rows, 1 Challenger). Die Vision wird NICHT als neuer
Track gebaut, sondern als Erweiterung des bestehenden — jede Zeile nennt, was fehlt:

| OWNER-Vision | Ist (DL-084) | Delta |
|---|---|---|
| Optimierung nach dem Kern-Funnel | Fork ab **Q10-PASS** (bestätigt #5) | keins |
| „bis zu 3 Andrea-Unger-Patternfilter, kein Filter = Option" | `PREDICATE_ABLATION` (1 Prädikat, 1 EA verdrahtet, Veto-Semantik) | **neuer Hebel PATTERN_FILTER_COMBO** (§2.1) + T8-Reparatur + T9-Wiring |
| Newsfilter-Varianten optimieren | Q09 = Adjudikation, kein Opt-Hebel | **neuer Hebel NEWS_FILTER** (§2.2) |
| „was die KI vorschlägt" als Parameter | numerische Surfaces modelliert, aber kein Emitter | **Hebel AI_PARAM** + numerischer Dev-Sweep-Emitter (§2.3, T9) |
| „nochmal OOS-Backtest wie Q04" | Q16 nutzt exakt die Q04-Anker-Folds + POST_DEV_HOLDOUT | keins (Fenster rollierend machen, §3.4) |
| „auf Overfit testen — wie?" | No-Change-Kontrolle + Holdout vorhanden | **Overfit-Protokoll formalisieren** (§3, ROT-Anteil) |
| „Gesamttest mit besten Parametern" | Q15-Challenger läuft die UNVERÄNDERTE Q02→Q10-Kaskade; Q10 = kanonischer Full-History-Lauf | keins — der Gesamttest existiert bereits als Challenger-Q10 |
| „dann Portfolio-Bau FTMO + DXZ, daraus Deploy-Setfiles" | Q11_DXZ/Q11_FTMO-Lanes + Builder vorhanden (0 Rows, ungeprobt) | FTMO-Builder-Umbau (Multi-EA-pro-Symbol, OWNER 2026-08-21) + erste Ende-zu-Ende-Probe |

## 2 · Die drei neuen Hebel (je mit den vier GELB-Pflichtfeldern)

**Gemeinsame Disziplin:** 1 Hebel-Klasse pro Q14-Admission; Auswahl DEV/IS-only; Q16
entscheidet versiegelt; Census-Instrument-pro-Parent (kein Recompile im Aktivbestand — ROT).

### 2.1 PATTERN_FILTER_COMBO (kategorial)

- **Hypothese:** Ein Entry-Veto in nachweislich adversen Musterkontexten (bis 3 kombinierte
  Prädikate/Seite aus fester Bank) hebt PF und senkt DD, ohne den Edge-Mechanismus zu ändern.
- **Widerlegungskriterium:** Keine Filter-Zelle schlägt die No-Filter-Kontrollzelle auf DEV
  **und** hält den Vorsprung im Q16-Holdout → Hebel für diesen Parent verworfen.
- **Frequenzprüfung:** Zellen, deren Filterung das Aktivitätskriterium bricht (<10 distinkte
  Entry-Tage in einem gewerteten Jahr), sind **inadmissible** — vor der Messung ausgeschlossen.
- **Parameterzahl:** **1 kategorialer Parameter** (Combo-ID aus vordefinierter Bank; deckt die
  Eingrenzung aus dem Bericht 19.08.). Vorschlag Bank-Größe: ≤ 12 Combos inkl. Pflicht-Zelle
  „kein Filter".
- **Vorbedingungen:** T8 (Prädikate 31/32/92 reparieren, 100 fixen, Fixture-Runner scharf),
  Bug#4 Kurzhistorien-Sperre, T9-Template-Wiring (`strategy_pp_pred_1..3`, 0 = kein Filter).

### 2.2 NEWS_FILTER (kategorial)

- **Hypothese:** Für news-sensitive Parents existiert eine bessere News-Konfiguration als die
  Q09-adjudizierte (temporal × Compliance × min_impact), messbar als PF/DD-Verbesserung bei
  gleicher Compliance-Klasse.
- **Widerlegungskriterium:** Keine Zelle schlägt die adjudizierte Ist-Konfiguration auf DEV
  und im Q16-Holdout → Ist-Konfiguration bleibt.
- **Frequenzprüfung:** wie 2.1 (SKIP_DAY-artige Modi können Trades drastisch senken).
- **Parameterzahl:** 1 kategorialer Parameter, Bank ≤ 8 Zellen (kein Vollkreuz).
- **Abgrenzung:** Q09 bleibt unangetastet (Adjudikations-Gate, kein Best-PF-Picking). Der
  Hebel läuft ausschließlich im vorregistrierten Opt-Track mit Trial-Ledger. Benötigt
  News-Setfile-Emitter (T9).

### 2.3 AI_PARAM (numerisch)

- **Hypothese:** je Trial explizit von der vorschlagenden KI zu formulieren (ökonomischer
  Mechanismus, nicht „Wert X testet gut").
- **Widerlegungskriterium:** je Trial explizit; zusätzlich global: Plateau-Pick (Median),
  niemals Best-Wert.
- **Frequenzprüfung:** wie 2.1.
- **Parameterzahl:** **1 Parameter pro Trial, ≤ 5 Kandidatenwerte** (harte Deckelung; mehr =
  neuer Q14-Antrag). Benötigt numerischen `emit_dev_sweep`-Pfad (T9).

## 3 · Overfit-Protokoll (Antwort auf „wie testen wir Overfit?")

Vier Schichten, drei existieren strukturell schon:

1. **Pre-Registrierung + Trial-Ledger** (existiert, Q14): Zellenzahl vorab fixiert —
   Grundlage jeder Selektionskorrektur.
2. **No-Change-Kontrolle** (existiert, Q16): Der unveränderte Parent läuft im selben
   versiegelten Vergleich mit; der Challenger muss ihn schlagen, nicht nur „gut aussehen".
3. **PBO < 0,40** über die DEV-Trial-Matrix (NEU als Q16-Zusatzkriterium; gleiche Methodik
   wie Q08.7, angewandt auf das Opt-Ledger). **ROT — braucht OWNER-Freigabe.**
4. **DSR** (Deflated Sharpe, korrigiert um die Trial-Anzahl aus dem Ledger) auf der
   Gewinner-Zelle, bewertet im **POST_DEV_HOLDOUT** (NEU als Q16-Zusatz, p < 0,05).
   **ROT.** Dazu §3.4: `comparison_windows` in `opt_program.v1.json` rollierend
   parametrisieren (Holdout endet heute hart 2026-07-31 — frische OOS wächst sonst nicht mit).

## 4 · Nach Q16: Portfolio + Deploy (unverändert + zwei Arbeitspakete)

Q16-Terminal-Kohorte → **Q11_DXZ** (`build_book_dxz.py`, Incumbent-Gate fail-closed) und
**Q11_FTMO** (`build_book_ftmo.py` NACH Umbau `select_one_per_symbol` → Aggregat-
Risikokontrolle, OWNER-Ruling 2026-08-21; FUND_SCORE ≥ 1,0, Bootstrap P(Phase-1) ≥ 0,80)
→ Setfiles via `gen_setfile.ps1` (ENV=live, `RISK_PERCENT × PORTFOLIO_WEIGHT`) → bestehender
Deploy-Prozess (DXZ: Q12/Q13; FTMO: Challenge-Kauf = OWNER, ROT). Arbeitspakete:
FTMO-Builder-Umbau (Programm 07 (b)) + **eine Ende-zu-Ende-Probe beider Builder auf der
ersten realen Q16-Kohorte**, solange Einsatz null ist.

## 5 · Reihenfolge & Vorbedingungen

T8 (Prädikate) → Bug#4 → T9 (Wiring: 3-Slot-Pattern-Inputs, News-Emitter, numerischer
Dev-Sweep-Emitter) → erste PATTERN-Trials auf 2–3 Parents (Pilot) → NEWS/AI_PARAM.
`ea_metrics`-Extraktion (Codex 59c2e32c) bleibt Vorbedingung für DD-basierte Admissions.

## 6 · Entscheidungsbedarf OWNER (gebündelt als Masterplan-Entscheidung #8)

1. Overfit-Zusatzkriterien in Q16: **PBO < 0,40** + **DSR p < 0,05 im Holdout** (ROT).
2. Trial-Budgets je (EA, Symbol): PATTERN ≤ 12 / NEWS ≤ 8 / AI_PARAM ≤ 5 Zellen, 1
   Hebel-Klasse pro Admission (ROT, da Vertragskriterium).
3. Kenntnisnahme: Hebel-Klassen selbst laufen unter GELB (Bedingungen in §2 erfüllt).

**Rollback:** Hebel sind additive Q14-Konfiguration (Admission-seitig abschaltbar);
Q16-Zusatzkriterien = Konfig im Vergleichs-Contract, revertierbar; keine Berührung von
Kern-Funnel, Live oder Verdikt-Historie. **Cost of Waiting:** Der Opt-Track optimiert
weiter nur mit den fünf Alt-Hebeln; die OWNER-Vision (Patternfilter/News/KI-Parameter)
bleibt unbedient; 11 OPT_ELIGIBLE-Rows warten teils auf sinnvolle Hebel.
