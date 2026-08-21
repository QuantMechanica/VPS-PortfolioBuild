# QM5_1673 sperandeo-tvii-trendline-failure-h4 — Independent Rebuild Review (2026-08-21)

**Reviewer:** Claude (independent gating review)
**EA:** QM5_1673 "sperandeo-tvii-trendline-failure-h4"
**Rebuild commit:** a0bb4bf42 (2026-08-17)
**Verdict:** PASS — cleared into Q02+ automated backtest pipeline.

## Context
The only prior completed review was a stale RECYCLE (2026-07-19) that found "only .mq5,
no .ex5" — it predates the 2026-08-17 full rebuild and describes a nonexistent-binary
state. This review evaluates the CURRENT rebuilt artifact fresh. A compiled current
.ex5 now exists; the old defect is resolved.

## Checklist
1. Card fidelity — PASS. Sperandeo TV-II trendline-failure reversal faithfully
   implemented: 5-bar pivot detection (IsPivotLow/High, .mq5:90-126); 2-pivot trendline
   construction (FindTrendlinePivots :128-172); violation = close beyond line by
   0.5×ATR(14) with first-violation guard (:250-264); 4-bar cancellation-window
   failure-to-recover (:266-281); D1 SMA(200) regime gate with correct side mapping
   (RegimeAllows :314-325); 50%-prior-range target from construction pivot to
   pre-violation extreme (BuildEntryRequest :392-408); structural SL ±0.5×ATR capped at
   3.0×ATR (:388-403); 30-bar time-stop + counter-signal exit (:577-591);
   BE-at-1.5×ATR + 50% partial at 50% target (:531-555); 0.3×ATR spread filter
   (:327-335); 18-bar directional cooldown (:337-372); 144-bar trendline staleness.
2. All inputs wired — PASS. Every strategy_* and framework input has a use-site; no
   dead inputs.
3. Host slot / magic binding — PASS. req.symbol_slot=0 (.mq5:418) is the framework
   host-slot reference (QM_Entry.mqh:107-113), resolving to the per-symbol magic
   QM_MagicChecked(ea_id, qm_magic_slot_offset, _Symbol) (QM_Common.mqh:225). Setfile
   offsets match magic_numbers.csv slots 0-12 exactly (magic_base 16730000). No
   hardcoded slot-0 cross-symbol contamination.
4. Set files risk mode — PASS. All 13 backtest sets + UK100 stress-medium variant:
   RISK_FIXED=1000, RISK_PERCENT=0.
5. Loss limits — PASS. Card SL (pre-violation extreme + 0.5×ATR, cap 3.0×ATR) wired via
   strategy_stop_buffer_atr / strategy_stop_atr_cap; no silent QM_Common default
   override; card defines no daily-loss/drawdown limit.
6. Broker-time / GMT — PASS. No custom session logic; Friday-close uses broker hour via
   framework; cooldown/time-stop use timezone-agnostic elapsed seconds.
7. News stale guard — PASS. qm_news_stale_max_hours=336 (at ceiling, not exceeded).

## Build check
Command: pwsh -File framework\scripts\build_check.ps1 -EALabel
"QM5_1673_sperandeo-tvii-trendline-failure-h4" -Strict
Result: build_check.result=PASS, failures=0, warnings=0; compile PASS, 0 errors,
0 warnings. Report: D:\QM\reports\framework\21\build_check_20260821_084132.json.
Independently reproduces the self-reported strict build_check PASS 0/0.

## Binary currency
Not stale. Committed .ex5 and .mq5 share identical mtime; build_check recompiled the
current source cleanly to .ex5 at 2026-08-21 08:41:32, confirming the binary derives
from current source.

## Symbol coverage
13 symbols registered/set-filed (GDAXI, NDX, SP500, UK100, WS30, XAUUSD, EURUSD,
GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD; slots 0-12) plus one UK100
q05_stress_medium variant. All slot offsets match the registry.

## Conclusion
PASS. QM5_1673 is cleared for Q02+ automated backtesting.
