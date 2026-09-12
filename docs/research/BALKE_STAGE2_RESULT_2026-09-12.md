# Balke stage-2 matrix result (QM5_41405, 2026-09-12, tool-adjudicated)

Program `WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025`, 350 cells MEASURED (real ticks, Model 4, 2019-2025), 50 configurations.
Rules: card QM5_41405 (pre-registered 2026-09-11) + stage-A plan sections 4-5; script `tools/strategy_farm/session_tools/adjudicate_balke_stage2_41405.py`;
surface `docs/research/balke_stage2_41405/surface_20260912.csv`, JSON `result_20260912.json`.

## Hypotheses (1.10x plateau margin, fixed before any cell ran)

| Hypothesis | Challenger (best plateau) | Incumbent (best plateau) | Verdict |
|---|---|---|---|
| H-CLOCK | c20 BROKER_DST/SKIP_DAY/buf0/bandon: 1.72 | c04 GMT3_FIXED/SKIP_DAY/buf0/bandon: 1.65 | **H-CLOCK REFUTED -> keep GMT3_FIXED** |
| H-OUTSIDE | c20 BROKER_DST/SKIP_DAY/buf0/bandon: 1.72 | c16 BROKER_DST/AS_IS/buf0/bandon: 1.57 | **H-OUTSIDE REFUTED -> keep AS_IS** |
| H-BUFFER | c22 BROKER_DST/SKIP_DAY/buf20/bandon: 1.72 | c20 BROKER_DST/SKIP_DAY/buf0/bandon: 1.72 | **H-BUFFER REFUTED -> keep buffer 0** |
| H-BAND | c21 BROKER_DST/SKIP_DAY/buf0/bandoff: 1.72 | c20 BROKER_DST/SKIP_DAY/buf0/bandon: 1.72 | **H-BAND REFUTED -> keep band on** |
| H-BALKE | c48 BROKER_DST/AS_IS/buf0/bandoff: 2.53 | c04 GMT3_FIXED/SKIP_DAY/buf0/bandon: 1.65 | **H-BALKE SURVIVES (challenger >= 1.10x)** |

## Control and top configurations (plateau order)

Score = costed net / max-DD per year (costed = native net - 5 USD per lot RT); DEV median 2019-2022; OOS median 2023-2025.

| cfg | clock | outside | buffer | band | Balke | plateau | DEV | OOS median | OOS pooled PF | costed net 7y | trades |
|---|---|---|---|---|---|---|---|---|---|---|---|
| c00 | GMT3_FIXED | AS_IS | 0 | on |  | 1.55 | 1.96 | 0.91 | 1.21 | 47,297 | 523 |
| c48 | BROKER_DST | AS_IS | 0 | off | yes | 2.53 | 2.82 | 0.24 | 1.15 | 98,331 | 1647 |
| c49 | BROKER_DST | AS_IS | 20 | off | yes | 2.53 | 2.25 | 0.80 | 1.15 | 81,896 | 1630 |
| c20 | BROKER_DST | SKIP_DAY | 0 | on |  | 1.72 | 1.99 | 1.20 | 1.39 | 65,576 | 496 |
| c21 | BROKER_DST | SKIP_DAY | 0 | off |  | 1.72 | 1.94 | -0.02 | 1.10 | 65,486 | 1624 |
| c22 | BROKER_DST | SKIP_DAY | 20 | on |  | 1.72 | 1.49 | 0.65 | 1.37 | 52,103 | 497 |
| c23 | BROKER_DST | SKIP_DAY | 20 | off |  | 1.72 | 1.41 | 0.16 | 1.10 | 49,102 | 1615 |
| c04 | GMT3_FIXED | SKIP_DAY | 0 | on |  | 1.65 | 1.96 | 0.91 | 1.22 | 49,361 | 521 |
| c05 | GMT3_FIXED | SKIP_DAY | 0 | off |  | 1.65 | 1.89 | -0.13 | 1.02 | 37,829 | 1488 |
| c06 | GMT3_FIXED | SKIP_DAY | 20 | on |  | 1.65 | 1.40 | 0.70 | 1.35 | 50,811 | 518 |
| c07 | GMT3_FIXED | SKIP_DAY | 20 | off |  | 1.65 | 1.24 | -0.16 | 1.07 | 34,117 | 1476 |

Inadmissible configurations: none.
Top plateau configuration: c48; OOS confirmation versus control c00: False.

## Not claimed

No live authorisation, no verdict/counter change. Fade-only-day economics and the winter/summer split are reported separately (Astra stage-2 ticket); this document adjudicates the five pre-registered hypotheses only.

## Final rule (plan section 5 applied to the stage-2 top plateau configuration)

Top plateau configuration = c48 (Balke: range 00:00-07:30 broker time via M30 bars, exit 18, band off,
buffer 0, AS_IS): plateau 2.53 vs 1.65 for the best fixed-clock configuration (H-BALKE margin met), but the
OOS confirmation FAILS: OOS median costed return-to-maxDD 0.24 (2023 0.24 / 2024 -0.02 / 2025 3.51) versus
0.91 for the control c00 (0.91 / -0.63 / 3.72); OOS pooled costed PF 1.15 (control 1.21).

**Verdict: STAGE2_CONTROL_STANDS.** Final configuration for QM5_41398/41405 lineage remains the stage-A/B
result: fixed UTC+3 clock, range 00:00-08:00 (H1 bars), exit 18, outside rule AS_IS, buffer 0, ATR band on
(c00). H-CLOCK, H-OUTSIDE, H-BUFFER and H-BAND are refuted at the 1.10x plateau margin; H-BALKE clears the
plateau margin but not the pre-registered OOS confirmation.

Observation (not a selection): Balke's own configuration trades every day (about 235 trades/yr versus 75)
and earns roughly twice the 7-year costed net (98.3k vs 47.3k USD), beating c00 on costed net in 5 of 7
years, with worse drawdown-normalised OOS years 2023-2024. A dedicated, separately pre-registered program
(e.g. band-off/daily-straddle economics under DXZ costs, or a two-sleeve portfolio test) would be the way to
pursue it; this document does not re-select.
