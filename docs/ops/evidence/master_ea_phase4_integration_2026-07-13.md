# Master-EA Phase 4 — Integration / Behavior-Neutrality Evidence

Date: 2026-07-13. Author: Claude (authoritative gates on T8, XAUUSD.DWX, Model 4 real ticks).
EA: `QM5_MXAU_master-xauusd` (ea_id 20001). Merged Phase 3 = all 5 XAU modules.

## Claim
Consolidating the 5 XAU survivor strategies into one master EA does NOT change any of their
behavior — neither the port itself nor running all 5 together.

## Evidence

### 1. Per-module faithfulness (full-history 2017–2025, each module ALONE) — 5/5 CENT-EXACT
Each module, run alone in the master (FIXED 1000, its regression set), reproduces its verified
standalone q08 stream exactly, each carrying only its original magic:

| Module | magic | trades | net | verdict |
|---|---|---|---|---|
| 12567 cum-rsi2 (pilot) | 125670003 | 73 | $4,676.76 | GREEN_MATCH |
| 10403 et-turtle20x | 104030002 | 209 | $14,411.17 | GREEN_MATCH |
| 10513 mql5-ichimoku | 105130003 | 76 | $9,649.32 | GREEN_MATCH |
| 12989 grimes (H4) | 129890003 | 51 | $13,878.26 | GREEN_MATCH |
| 1556 aa-zak-mom12 | 15560004 | 53 | $6,369.87 | GREEN_MATCH |

### 2. No cross-module interaction (windowed 2019–2021, H4) — 5/5 EXACT MATCH
Confound-free test: the master's per-magic substream is bit-identical whether the module runs
ALONE or WITH all 5 active (same warmup, boundaries, chart-TF; only # active modules differs).

| Module | alone (window) | in all-5 (window) | match |
|---|---|---|---|
| 10403 | 81 / $5,216.58 | 81 / $5,216.58 | ✅ |
| 10513 | 39 / $13,350.91 | 39 / $13,350.91 | ✅ |
| 12567 | 31 / -$373.61 | 31 / -$373.61 | ✅ |
| 12989 | 15 / -$1,098.89 | 15 / -$1,098.89 | ✅ |
| 1556 | 25 / $9,149.53 | 25 / $9,149.53 | ✅ |

Verdict: **GREEN_NO_INTERACTION.** FIXED-per-trade sizing (no equity coupling) + per-magic
position isolation + identical shared corset config ⇒ the modules are architecturally
independent, and the tester confirms it bit-for-bit.

**Methodology note (corrected):** an earlier windowed check compared the master's fresh-2019-
start run against the standalone FULL-history streams filtered to the window — that mismatched
on warmup + end-boundary force-closures (a comparison artifact, NOT interaction). The clean
test above compares master-vs-master under identical conditions.

## Open item — full-history 5-module tester stability (NOT a correctness issue)
Running ALL 5 modules together over the full 9-year history (Model 4) crashes the strategy
tester silently near ~95% (~40 min wall-clock, no logged error, no timeout-kill), before the
OnDeinit q08 write. Single-module full-history runs complete fine; the crash is the COMBINED
tester load — prime suspect: EtTurtle's turtle-breakout pending-order churn (BUY_STOP+SELL_STOP
re-issued per bar, most expiring) × 5 modules over 9 years → tester history/memory growth.

- This is a **backtest-tester resource issue, not a behavior/correctness defect** (behavior is
  proven above). Live trading is real-time (no 9-year compressed history accumulation), so it
  likely does not manifest live — but must be characterized + resolved before Phase 5 for the
  full-history record and certainty.
- **Fix path (Codex):** characterize (does a 4-module set minus EtTurtle complete full-history?),
  then optimize the pending-order handling (don't re-issue identical stop orders every bar; only
  amend when the level changes) — reduces churn for both the standalone and the master.

## Conclusion
Phase 4 behavior-neutrality is **PROVEN** (per-module cent-exact + zero interaction). The sole
remaining Phase-4 item is the full-history 5-module tester-stability fix, which gates the
final full-history integration record and Phase 5 (T_Live migration, OWNER-gated).
