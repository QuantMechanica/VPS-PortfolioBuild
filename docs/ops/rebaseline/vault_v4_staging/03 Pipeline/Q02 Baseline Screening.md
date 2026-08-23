# Q02 — Baseline Screening

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q02 |
| **Makrophase** | 1 · Strategie beweist sich |
| **v3-Herkunft** | Q02 (Baseline Screening) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q01 Build & Spec]] · → [[Q03 Parameter Sweep]] |

**Herkunft:** v4 Q02 = v3 Q02 (Baseline Screening), ID und Kriterien unverändert (ROT). Ein sauber gemessenes Q02-FAIL bleibt terminal (Rebaseline-Direktive §1); `INFRA`/`INVALID`/fehlende Historie sind kein wirtschaftliches Strategie-FAIL.

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** IS 2017-01-01 → 2022-12-31 (**OOS data NEVER touched here**)
**Spec version:** 2026-05-23 (post-rewrite)

---

## Purpose

Q02 is the first real backtest gate. It asks: does this EA produce a statistically meaningful, profitable signal on its target symbol universe? It's a **strict pass/fail filter**, not an optimisation run.

A Q02 PASS means the EA cleared three concrete thresholds on the in-sample window. A Q02 FAIL kills the EA on that symbol — full stop, no second chances unless the EA is rebuilt under a new ID.

---

## Hard Gate Criteria (all must PASS per symbol)

| Criterion | Threshold | Source |
|---|---|---|
| **Profit Factor** | **> 1.10** (OWNER 2026-07-25, war 1.20 — `decisions/2026-07-25_q02_pf_floor_120_to_110.md`; flat floor, DL-082 evidence-strength curve implementiert aber disabled) | OWNER 2026-07-25 (Ursprung: balanced profile 2026-05-23) |
| **Trade count** | **≥ max(5 × Fensterjahre, 5)** (rate-basiert) | Recalibrated 2026-06-26 (`p2_baseline.py` `Q02_TRADES_MIN`); implementiert zugleich den Economics-Frequenz-Floor ≥5 Trades/Jahr — darunter RETIRE (Operating Rules 2026-07-03) |
| **Max Drawdown** | **< 25%** (OWNER 2026-07-15, war 15%) | OWNER 2026-07-15 (Ursprung: cushion vs DXZ 20% kill rule 2026-05-23) |
| Backtest model | Model 4 (Every Tick Based on Real Ticks) | Hard Rule, no exceptions |
| Risk mode | Fixed Risk $1,000 per trade | Hard Rule for backtest phases |
| Window | **max(2017-01-01, symbol_first_data) → 2022-12-31**, min 3 years IS | IS embargo; per-symbol window |

**Per-symbol verdict.** A symbol either meets all three thresholds (PF, Trades, DD) or it FAILS for that EA. Mixed results across symbols are normal — only PASS symbols advance to Q03.

**Short-history symbols.** Indices and some instruments only have data from 2018 (e.g. NDX.DWX, WS30.DWX) or later. Per-symbol window adapts: start = `max(2017-01-01, symbol_first_data)`, end = `2022-12-31`. Symbols with < 3 years available IS are skipped for this EA (not tested at Q02).

**No fallbacks.** If a backtest produces no usable report, the verdict is FAIL — never "use the previous attempt's data". A re-run gets a fresh verdict.

**Zero-trades is NOT a Q02 verdict** — see next section.

---

## What Q02 explicitly does NOT do

- ❌ Optimise parameters (Q03's job)
- ❌ Touch OOS data (Q04's job)
- ❌ Apply commission (Q04's job)
- ❌ Apply stress (Q05/Q06's job)
- ❌ "Soft" pass for EAs that almost made it — there is no soft pass

---

## Zero-Trades Policy (OWNER call 2026-05-23)

A backtest that produced **zero trades** is NOT a Q02 FAIL. It means the EA isn't entering the market at all — the strategy code is fine, the EA just isn't firing.

**Workflow:**
1. Q02 detects zero-trade outcome per (EA, symbol).
2. Symbol-level result = `Q02_NO_TRADES` (distinct from FAIL).
3. If ALL symbols for the EA produced zero trades → EA returns to **Q01 for revision** (not closed).
4. Codex re-versions the EA: `QM5_<NNNN>_<slug>_v2` with widened entry conditions / relaxed filters / lowered thresholds.
5. New version re-enters Q02.
6. Iterate `_v2 → _v3 → _v4 → ...` until either:
   - EA starts trading on at least one symbol → Q02 verdict on those symbols, normal pipeline flow
   - **We genuinely run out of ideas** why the EA doesn't trade → Codex documents the exhaustion in lessons-learned, then EA closed as terminal FAIL

**Key principle:** zero-trade is a *failure mode of the EA implementation*, not a *strategy verdict*. Distinguishing the two is what saves us from killing promising strategies that just need looser triggers.

---

## Pipeline-Op Workflow

1. **Pre-flight:**
   - `.ex5` on disk? `framework/EAs/QM5_<NNNN>_<slug>/`
   - All setfiles generated? (`sets/`, one per symbol in the EA's universe)
   - No V4 legacy name?
2. **Setfile audit:** Symbol with `.DWX` suffix, period H1, Fixed Risk $1,000, Model 4.
3. **Dry-run first** (`--dry-run`) to catch config errors before a real run.
4. **Actual run:** `python framework/scripts/p2_baseline.py --ea QM5_<NNNN> --window 2017-2022`
5. **Wait for reports:** `D:/QM/reports/pipeline/QM5_<NNNN>/Q02/<symbol>/report.htm`
6. **Size check:** Size-0 `.htm` = NO_REPORT (setup problem — investigate before classifying).
7. **Verdict classification** per symbol using the three hard thresholds (PF > 1.10 (OWNER 2026-07-25, war 1.20 — `decisions/2026-07-25_q02_pf_floor_120_to_110.md`; flat floor, DL-082 evidence-strength curve implementiert aber disabled), Trades ≥ rate-Floor, DD < 25% (OWNER 2026-07-15, war 15%)).
8. **Aggregate:** `D:/QM/reports/pipeline/QM5_<NNNN>/Q02/report.csv` with per-symbol PF, Trades, DD, verdict.
9. **Closeout comment** with `report.csv` path and per-symbol summary.

→ Runtime: `framework/scripts/p2_baseline.py` (technischer Dateiname; operatorseitiges Gate Q02)

---

## NO_REPORT: triage protocol

```
1. Size check: ls -la *.htm
2. If size = 0 → setup problem, not EA problem:
   a. Symbol name in setfile correct? (.DWX suffix?)
   b. Symbol visible in MT5 terminal Market Watch?
   c. bases/ folder intact for that terminal?
   d. Server time correct? (GMT+2 outside US DST, GMT+3 during)
3. Never classify as "EA produced no trades" without size verification.
4. Note SETUP_DATA_MISMATCH in the work_item payload.
```

---

## Canonical Symbol Matrix

The active `.DWX` symbol universe (Source of Truth: `framework/registry/dwx_symbol_matrix.csv`, HR1). Full list in [[../06 Infrastructure/Symbol List]].

A given EA's universe is defined in its Q01 SPEC.md — Q02 runs only against that universe, not the full matrix.

---

## What Q02 PASS means

A symbol that passes Q02 has cleared:
- A profitable strategy (PF > 1.10) (OWNER 2026-07-25, war 1.20 — `decisions/2026-07-25_q02_pf_floor_120_to_110.md`; flat floor, DL-082 evidence-strength curve implementiert aber disabled)
- A statistically meaningful, economically viable sample (≥ 5 trades/year over the IS window)
- Acceptable capital risk (DD < 25%) (OWNER 2026-07-15, war 15%)
- On up to six years of clean in-sample data

That's it. It doesn't mean the strategy is robust (Q03), survives commission (Q04), survives stress (Q05/Q06), is seed-stable (Q07), or is statistically valid (Q08). Each downstream gate is its own filter.

A Q02 PASS rate of 5-20% per EA is typical and healthy. EAs that PASS Q02 on >50% of their symbols are suspicious (possible curve-fit) and warrant Q03 plateau scrutiny.
