# Q11 — Incumbent Full-History Confirmation

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q11 |
| **Makrophase** | 2 · Strategie wird optimiert / requalifiziert |
| **v3-Herkunft** | Q10 — „Incumbent Full-History Confirmation" |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q10 News Impact + FTMO Recommendation]] · → [[Q12 Pattern Filter Selection]] |

**Herkunft:** v4 Q11 = v3 Q10 (Incumbent Full-History Confirmation), Kriterien/Schwellen
(PF > 1.0 ∧ DD < 25%) unverändert (ROT).

> **Lese-Hinweis zur Nummerierung:** Der Fließtext unten ist der **verbatim v3-Text** und nennt
> dieses Gate „Q10", die News-Abhängigkeit `Q09_NEWS`/`Q09 CONFIG_LOCKED` und das Buch-Gate
> „Q11". Storage-Tokens und Code (`assert_q10_dependency_gate`, `q10_confirmation.py`) bleiben
> bis zur v4-Migration v3. v4-Mapping: dieses Gate = **Q11**, News-Dependency = **Q10**
> (`Q10_NEWS CONFIG_LOCKED`), Buch = **Q15**. Nachfolger unter v4 ist das verpflichtende
> Optimierungssegment ab **Q12 Pattern Filter Selection**. Mapping: [[Gate Manifest v4 Diff]].

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** **Full available history per symbol**, with the Q09-chosen news mode applied
**Spec version:** 2026-05-23 (new phase, OWNER call)

---

## Purpose

Q10 is the **closing per-(EA, symbol) verdict**. When an EA has survived Q01 through Q09, Q10 runs the single canonical backtest — full available history, real commission, chosen news mode — that confirms the EA is actually ready for portfolio consideration.

OWNER call 2026-05-23: "Wenn ein EA Q09 übersteht, brauchen wir für Q10 einen Backtest für das Symbol über den gesamten verfügbaren Zeitraum. Das ist der Abschluss und der EA ist auf dem Symbol tatsächlich bereit um eine Portfolio Analyse zu machen."

This is the run whose numbers go into the Q11 portfolio decision. Everything before Q10 was a filter; Q10 is the confirmation.

---

## Hard Gate Criteria

| Criterion | Threshold |
|---|---|
| **Profit Factor** | **PF > 1.0** |
| **Max Drawdown** | **DD < 25%** (Code-Kanon `q10_confirmation.py` `DD_PCT_MAX=25.0`; 15→25 im Zuge der DD-Decken-Anhebung OWNER 2026-07-15) |
| **Window** | Full available history per symbol (typically 2017 → present, but symbol-specific where data is shorter) |
| **Parameters** | Q03 plateau-median (locked) |
| **News mode** | Q09 `CONFIG_LOCKED` choice, enforced fail-closed (`assert_q10_dependency_gate`: Q09_NEWS CONFIG_LOCKED + PASS_PORTFOLIO sibling of same lineage required — since 2026-08-04 the old default-apply is retired) |
| **Commission** | $7/lot baseline (no stress multiplier — this is the canonical run) |
| **Slippage / spread** | Broker baseline (no stress — Q05/Q06 already validated stress survival) |

**Per-symbol verdict.** Runs per (EA, symbol) that made it through Q09. A PASS at Q10 means: this EA, on this symbol, is portfolio-ready.

---

## Why a separate canonical run

Q02-Q09 each tested specific aspects of robustness (IS, OOS folds, stress, seeds, statistical). Each produced its own backtest data. None of them produced the **single, end-to-end, real-conditions run** that represents what we expect to see live.

Q10 fills that gap. It's the backtest you'd link to a fund manager if they asked "show me what this EA does." Full history, realistic commission, chosen news handling, no stress overrides — just the EA's natural behaviour.

Q10 also produces the **canonical equity curve** that appears in:
- The EA detail page's hero chart
- Q11 portfolio construction analysis
- The OWNER-facing strategy archive

---

## What Q10 explicitly does NOT do

- ❌ Re-optimise anything (parameters frozen since Q03)
- ❌ Apply stress (Q05/Q06 already validated)
- ❌ Run multiple seeds (Q07 already validated)
- ❌ Re-run statistical tests (Q08 already validated)
- ❌ Touch the live account in any way

---

## Workflow

1. Pipeline-Op reads Q09 chosen-mode list per EA.
2. For each (EA, symbol) PASSed through Q09:
   - Compose the canonical setfile: Q03 plateau-median params + Q09 chosen news mode + baseline commission + no stress overrides.
   - Run: `python framework/scripts/q10_confirmation.py --ea QM5_<NNNN> --symbol <S> --mode <N>`
   - Single backtest, full available history for that symbol.
3. Compute PF and DD on the result.
4. Verdict: PF > 1.0 AND DD < 25% → PASS, else FAIL.
5. Output:
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q10/<symbol>/report.htm` (canonical report — this is the one OWNER and the dashboard link to)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q10/<symbol>/equity_curve.json` (parsed equity series for chart rendering)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q10/report.csv` (per-symbol verdict)

→ Runtime: `framework/scripts/q10_confirmation.py`

---

## Dashboard Display

Q10 is the **primary section** of the EA detail page (above the gate-by-gate accordion). It shows:

```
Q10 Full-History Confirmation · NDX.DWX
  Period: 2018-08-12 → 2026-05-23 (~7.8 years, full available)
  Trades: 412
  Net P&L: +$28,460
  Profit Factor: 1.42
  Max Drawdown: $3,890 (8.7%)
  News config: temporal=PRE30_POST30 · compliance=DXZ (Q09 CONFIG_LOCKED)
  Equity curve: [inline SVG, monthly resolution]
  Full MT5 report ↗
  Verdict: PASS ✓ — portfolio-ready on this symbol
```

The Q10 numbers are what feeds Q11 portfolio analysis. The earlier gates remain visible (accordion below) for evidence trail but the operator's attention goes to Q10.

---

## After Q11 PASS (v3: „After Q10 PASS")

- Unter v4 folgt der **verpflichtende lineare Optimierungspfad**: weiter zu
  **[[Q12 Pattern Filter Selection]]** → Q13 Parameter Optimization & Freeze → Q14
  Best-Settings Head-to-Head. „Keine Verbesserung" (`KEEP_INCUMBENT`) ist ein zulässiges
  terminales Requalifikationsergebnis.
- Die kanonische Equity-Kurve wird zur Referenzserie für die Korrelationsanalyse
  (Q08.1 gegen das bestehende Portfolio) und für die Buchbewertung (Q15).

## After Q11 FAIL (v3: „After Q10 FAIL")

- Symbol is removed from the EA's active universe.
- If all Q09-PASS symbols fail Q10, the EA is closed (terminal FAIL).
- A Q10 FAIL after Q08 PASS is **noteworthy** — it usually means a regime change between the statistical-validation period and the present, or a Q08 measurement quirk. Lessons-learned entry mandatory.
