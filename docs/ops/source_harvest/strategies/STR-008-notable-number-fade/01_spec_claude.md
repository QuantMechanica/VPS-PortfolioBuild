# STR-008 — Claude independent spec (pre-reconciliation)

Source: thread 1182304 "Notable numbers" (joyny, 2022-2024). Exec TF M5
(2023-06-23 edit: "entries must be checked on M5 bars openings only").
FADE setups only (STR-009 covers the CADJPY reverse).

## Core mechanic (fade)

A "notable number" NN (2-4 digits) defines a price-level lattice: every price
whose last len(NN) digits equal NN (e.g. NN=66 → 1.0766, 1.0866, ... spacing
= 100 points for 2 digits, 1000 points for 3).
BUY when ALL highs AND lows of the previous N trading days sit ABOVE the
level and price comes down and REACHES the level ("from above") →
mean-reversion bounce off the psychological level. SELL mirror below.

## Per-symbol source-fixed setups (author's optimizer output, backtest
2013-2019 + forward 2020-2022 — parameters go 1:1 into the card)

| Symbol | NN | N days | TP % | SL % | Entry window |
|---|---|---|---|---|---|
| EURUSD | 66 | 2 | 0.8 | 0.5 | London open+1h → NY open+1h |
| GBPUSD | 00 | 22 | 0.4 | 0.4 | Sydney open → Sydney close |
| USDJPY | 444 | 20 | 0.25 | 0.25 | any time |
| EURGBP | 66 | 13 | 0.35 | 0.9 | Tokyo open → Sydney close |
| AUDUSD | 33 | 42 | 0.85 | 0.55 | Tokyo open → London close |
| USDCAD | 88 | 9 | 0.15 | 0.75 | London open−1h, 2h long |
| AUDNZD | 333 | 1 | 0.35 | 0.8 | (none stated) |
| AUDCAD | 55 | 43 | 0.4 | 0.6 | 15:00-18:00 "London+2h" |
| EURCAD | 44 | 23 | 0.65 | 0.55 | 17:00-20:00 "London+2h" |

Mechanizations:
- "London+2h" clock times = broker time (author ran MT5 GMT+2/+3). Named
  sessions mechanized in broker time: Sydney 00:00-09:00, Tokyo 02:00-11:00,
  London 10:00-19:00, NY 15:00-24:00 (broker NY-close clock; DOCUMENT as
  interpretation — codex counter-spec settles).
- "Previous N days high/low above level": max/min over N previous BROKER D1
  bars (shift 1..N) strictly above/below the level.
- "Reaches the level" on M5 openings: on a new M5 bar, trigger when the
  PREVIOUS closed M5 bar's range crossed the level (long: low(1) <= level
  while open(1) > level ... simplest faithful: level between low(1) and
  open(1)) AND the N-day condition holds for the level. Enter market at
  current M5 open. One trade per level-touch; re-arm only after price
  leaves the level by (hysteresis) or a new trading day (mechanization
  decision, flag).
- LEVEL SELECTION: the nearest lattice level below (long) resp. above
  (short) current price that satisfies the N-day condition.
- TP/SL = percent of ENTRY PRICE (author: "% of TP/SL targets"; his examples
  translate to pips consistently with price-%).
- One position per symbol; no stacking; window gates entry only.

## Per-symbol config mechanism

EA inputs hold ONE setup (NN string, N, tp_pct, sl_pct, window start/end
broker-hours); per-symbol values ship in per-symbol SET FILES patched from
the card table (deterministic, card-driven; documented in build record).
Defaults in code = EURUSD row.

## Hooks sketch

- NoTradeFilter: params sane; >= N+2 closed D1 bars; M5 chart; nothing else.
- EntrySignal: new M5 bar (own guard); no own position; window check
  (broker-time hours, [start,end)); level scan + N-day gate + touch test;
  market entry; SL/TP absolute from pct of entry via framework helpers.
- Manage: empty. ExitSignal: false. NewsFilterHook: framework default.

## Risks / notes

- Params are author-optimizer output (overfit risk) — recorded honestly;
  forward window 2020-2022 mitigates; our FULL-history Q02+ re-judges.
- Frequency: portfolio-wide ~70/yr on 10 symbols → per-symbol 2-20/yr.
  AUDNZD(1-day) likely highest. Floor risk on USDJPY (15 deals/11yr — BELOW
  the 5/yr floor → EXCLUDE USDJPY from the build cohort per Q02 economics
  floor; document).
- Overlap QM5_10042: prior notable-number build — differentiate in
  reconciliation (10042 = which variant? verify its SPEC).
