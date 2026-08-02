# FTMO demo instrumentation package — 2-week run

**Date:** 2026-08-02 · **Authority:** OWNER („lade dort alle EAs die wir dafür
brauchen und die Set Files") · **Account:** FTMO-Demo 1514165262, auto-locks
after 14 days, free.

## Purpose — read this before judging the result

The account expires in two weeks, so **passing Phase 1 (+10 % in 60 days) is
structurally impossible and is not the goal.** This run buys two things a
backtest cannot:

1. **Venue-native execution evidence.** FTMO serves real ticks only for roughly
   the last week backwards, but every forward day produces genuine FTMO fills.
   Two weeks of them calibrate the spread/slippage delta that the
   `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1` path currently has to assume.
2. **Operational rehearsal (Q12-class).** Second account, different symbol
   names, different contract semantics, news filter, magic registry and
   kill-switch behaviour on a parallel book — proven now for free instead of
   later with money.

Sleeve selection therefore optimizes **fills per day**, not expectancy: a D1
sleeve may trade twice in two weeks and calibrate nothing.

## Staged files

Binaries → `…\Terminal\81A933A9…\MQL5\Experts\QM_FTMO\`
Presets → `…\Terminal\81A933A9…\MQL5\Presets\`

| EA | FTMO chart | TF | binary | EX5 SHA-256 (12) | preset |
|---|---|---|---|---|---|
| 13301 | `GER40.cash` | M5 | QM5_13301_balke-minute-range-breakout.ex5 | `d7f10a684bdb` | FTMO_GER40_cash_M5_QM5_13301.set |
| 10911 | `GER40.cash` | H1 | QM5_10911_grimes-complex-pb.ex5 | `a815c73da991` | FTMO_GER40_cash_H1_QM5_10911.set |
| 11165 | `EURUSD` | H1 | QM5_11165_weiss-rsi-ma.ex5 | `8f6d33a3dfb0` | FTMO_EURUSD_H1_QM5_11165.set |
| 10706 | `GBPUSD` | H1 | QM5_10706_tv-mon-ls.ex5 | `01e34b2059de` | FTMO_GBPUSD_H1_QM5_10706.set |
| 12969 | `USDJPY` | M30 | QM5_12969_usdjpy-gotobi-nakane-fix.ex5 | `933d63c036a1` | FTMO_USDJPY_M30_QM5_12969.set |
| 12989 | `XAUUSD` | H4 | QM5_12989_grimes-nested-pb-v2.ex5 | `7f2c298f4a8b` | FTMO_XAUUSD_H4_QM5_12989.set |

All six binaries are byte-identical copies of the T_Live production files
(hashes above match the live book). Preset parameters are **unchanged**; only
the header comment records the FTMO symbol and the source file's SHA-256. The
T_Live originals were not modified.

## Expected behaviour and honest caveats

- **Kill switch:** baselines resolve by `QM5_<ea>_<symbol>.json`. `EURUSD`,
  `GBPUSD`, `USDJPY` and `XAUUSD` baselines exist (Darwinex-derived) and will
  arm — an acceptable safety net, but their distribution is not FTMO-derived.
  For `GER40.cash` **no baseline exists**, so 13301 and 10911 will log
  `KS_BASELINE_ABSENT` and run kill-switch-dormant. That is expected, not a
  defect.
- **News filter** reads the shared `Common\Files` calendar, which the FTMO
  terminal sees automatically. No extra deployment needed.
- **Sizing** is `RISK_PERCENT`, so it adapts to the demo account's balance.
  Index contract semantics differ between `GDAXI` (Darwinex) and `GER40.cash`
  (FTMO); position sizes will not look identical to the live book.
- **Magic numbers** are the live-book values. On a separate account there is no
  collision.
- **AutoTrading** is OWNER's switch, as on T_Live. Nothing in this package
  enables it.

## What to capture at the end

The two-week fill record is the deliverable: per-trade entry/exit prices,
commission and swap on FTMO terms. It feeds the spread-delta calibration
(ticket 225a787d) and replaces the assumed cost charge with a measured one.
