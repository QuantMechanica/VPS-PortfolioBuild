# FTMO time-to-first-payout — full pipeline + speed levers (2026-07-10)

OWNER ask: "win an FTMO challenge FASTER — waiting through P1, P2, then the first payout
is not efficient enough." Terminals for this workstream: **T8–T10** (Codex owns T1–T7).

## Method
Conservative worst-case-aligned intraday-MAE reconstruction over the **12/12 fresh-MAE
FTMO book** (`tools/strategy_farm/portfolio/ftmo_phase1_mae.py` build_daily), block
bootstrap (block=5). Full chain modelled: **Phase 1 (+10%) → Phase 2 (+5%) → Funded
(first payout after ≥14 cal days & in profit)**, each phase on a fresh 100k, with
**staged de-risking** (per-stage scale). One Challenge fee (€540) buys P1+P2, refunded on
first payout. Day counts are ACTIVE days; book runs **1 active ≈ 1.32 calendar days**
(2281 active over 3005 cal days). This is a LOWER bound on pass / UPPER bound on time.

Tools: `ftmo_full_pipeline.py`, `ftmo_speed_parallel.py`, `ftmo_sleeve_speed.py`
(all in `tools/strategy_farm/portfolio/`). Data: the two CSVs alongside this file.

## Result 1 — full chain to first payout (single account)
| config (P1/P2/fund scale) | P(reach payout) | median cal days | dominant fail |
|---|---|---|---|
| aggressive 6/4/2 | 18% | 67 | P1 daily-breach |
| balanced 5/3/2 | 30% | 96 | P1 daily-breach |
| steady 4/3/2 | 41% | 120 | P1 max-breach |
| safe 3/3/2 | 50% | 158 | P1/P2 max-breach |

Higher scale = faster but far less likely; daily-breach in Phase 1 is the killer at scale.

## Result 2 — parallel challenges (FTMO cap K=5) — the certainty lever
| config | K | P(≥1 paid) | 1st payout median cal days | E[# funded] | E[net fee-burn] |
|---|---|---|---|---|---|
| aggressive 6/4/2 | 5 | 63% | **59** | 0.90 | €2212 |
| balanced 5/3/2 | 5 | 84% | 76 | 1.51 | €1886 |
| **steady 4/3/2** | **5** | **93%** | **86** | **2.03** | **€1603** |
| safe 3/3/2 | 5 | 97% | 104 | 2.51 | €1344 |

Parallelism turns an 18–50% coin-flip into a 63–97% near-certainty of a first payout, and
typically yields **2 funded accounts**, not one. But it barely moves the *speed of the
first* one (min of K draws from the same book) — that floor is set by the book itself.

## Result 3 — the real speed lever is book density
Per-sleeve decomposition (`ftmo_sleeve_speed_decomp_2026-07-10.csv`):
- **10163 NDX.DWX H1 is NET-NEGATIVE in the book** (PF 0.94, −$950/yr) → remove it, it is
  pure drawdown ballast. Immediate, no-downside book fix (action: Codex/book).
- Density engine = **11476 USDJPY H1** (330 trades/yr, $28.7k/yr) but thin PF 1.11 and
  worst MAE −$10.4k — it drives speed *and* most of the daily-breach risk.
- Best edge-per-drawdown = 10700 / 10848 (XAUUSD H1, PnL/|MAE| ~50).

Speed of a sub-book at matched $30k/yr return (P1 +10%):
| book | sleeves | P(pass) | median cal days |
|---|---|---|---|
| full 12 | 12 | 64% | 65 |
| top8 by edge/DD | 8 | 60% | 51 |
| top6 by edge/DD | 6 | 54% | 42 |
| top4 by edge/DD | 4 | 77% | 79 |

Concentration to the top-edge sleeves buys ~20% speed (65→51 cal days) at matched return.
Materially faster than that needs MORE high-frequency, PF>1.2, low-MAE sleeves — a build
target for Codex (T1–T7), validated on T8–T10.

## Recommendation
1. **Run K=5 parallel FTMO challenges** with **staged de-risking** at the **steady 4/3/2**
   config → 93% chance of a first payout in ~86 cal days (~12 wk), ~2 funded accounts,
   ~€1600 net fee-burn (dwarfed by the funded upside; fee refunded on payout).
2. **Exceed K=5 via multiple prop firms** (FTMO + 1–2 others) to raise certainty / cut
   time further and diversify firm-specific rules.
3. **Remove 10163** from the FTMO book now; **build a "speed book"** of high-frequency
   PF>1.2 low-MAE sleeves (Codex/T1–T7) — that is the only lever that makes the *first*
   payout genuinely faster (target: P1 in <30 cal days).
