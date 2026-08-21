# Fresh Re-Review — QM5_1673 sperandeo-tvii-trendline-failure-h4 (H4)

- **Task ID:** c74caa66-58ef-4281-a89a-6052d297e165
- **EA ID:** 1673 · **Slug:** sperandeo-tvii-trendline-failure-h4
- **Reviewer:** Claude · **Date:** 2026-08-21
- **Context:** Prior 2026-07-19 RECYCLE verdict is STALE (predates 2026-08-17 rebuild) and
  is NOT reused. This is a fresh independent re-review of the CURRENT build.
- **Artifacts under review:** `.mq5` + `.ex5` rebuilt 2026-08-17 21:38; 14 set files.

## 1. Card fidelity — PASS
Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1673_sperandeo-tvii-trendline-failure-h4.md`.
The source implements exactly the TV-II ch.7 trendline-failure-reversal primitive:
2-pivot trendline (5-bar strength) construction (`FindTrendlinePivots`, mq5:128-172),
tolerance violation = 0.5×ATR14 (mq5:250), 4-bar cancellation-window failure-to-recover
(`DetectFailureSignal`, mq5:213-297), D1 SMA(200) regime gate (`RegimeAllows`, mq5:314-325),
50%-retrace target + structural/ATR-capped stop (`BuildEntryRequest`, mq5:374-421),
30-bar time-stop + counter-signal exit (`Strategy_ExitSignal`, mq5:559-594), 1.5×ATR
break-even + 50%/50% partial (`Strategy_ManageOpenPosition`, mq5:496-557). Side mapping
correct: rising trendline failure → SELL below D1 SMA; falling → BUY above (mq5:291,324).
Simultaneous long+short fails closed (mq5:307-308). Matches card mechanism, not a nearby idea.

## 2. Strategy-input wiring — PASS (no unwired inputs)
All 15 `strategy_*` inputs have real logic use-sites (grep count includes declaration;
each ≥2 = declared + used):
pivot_strength(9), atr_period(6), violation_atr_mult(3), cancellation_bars(4),
trendline_max_age(4), regime_sma_period(4), target_retrace(4), stop_buffer_atr(4),
stop_atr_cap(4), time_stop_bars(3), be_trigger_atr(2), partial_target_frac(2),
partial_close_frac(2), cooldown_bars(3), spread_atr_mult(3). No dead/decorative inputs.
(This EA class had prior unwired-input defects elsewhere; none here.)

## 3. Magic / slot binding — PASS
`ea_id_registry.csv:455` → 1673, slug matches, active. `magic_numbers.csv:16720-16732`:
13 slots (0-12), all dated 2026-08-17 "Codex governed allocator", active. Formula holds:
magic = 1673×10000 + slot (slot0=16730000 … slot12=16730012). No collision (11673 is a
distinct ea_id at 116730000). Rows reflect the CURRENT rebuild, not stale pre-08-17 rows.

## 4. .ex5 freshness — PASS (not stale)
`.mq5` mtime 2026-08-17 21:38:00 · `.ex5` mtime 2026-08-17 21:38:26 (binary NEWER than
source). No stale-binary condition (the "veraltetes .ex5" defect class does not apply).

## 5. Set files (14) — PASS
All 14 sets: `RISK_FIXED=1000` (>0), `RISK_PERCENT=0`, `environment: backtest`
(the 14th is UK100 `q05_stress_medium`, same slot-3 magic/build_hash — a stress variant,
not an extra slot). Correct RISK_FIXED backtest posture per HR.

## 6. Loss-limit / DD guard — PASS (framework default, card-consistent)
EA does not override `QM_KillSwitchInit(ea_id, magic, 3.0, 0.0, 1.0)`
(`QM_Common.mqh:298`). The card states no distinct per-EA kill-switch DD number; its risk
limit is the per-trade `ATR-SL-cap = 3.0`, which IS implemented via `strategy_stop_atr_cap=3.0`
(mq5:45, used mq5:389/402). Framework default is therefore correct, not a silent misconfig.

## 7. build_check — PASS
`powershell -File framework/scripts/build_check.ps1 -EALabel QM5_1673_sperandeo-tvii-trendline-failure-h4`
```
compile_one.result=PASS
compile_one.reason_class=OK
compile_one.errors=0
compile_one.warnings=0
build_check.result=PASS
build_check.failures=0
build_check.warnings=0
```
Report: `D:\QM\reports\framework\21\build_check_20260821_084644.json`.

## 8. news_stale_max_hours — PASS
Source default `qm_news_stale_max_hours = 336` (mq5:25) = limit; ≤ 336. Set files do not
override it, so the compliant default applies.

---

## Overall verdict: APPROVED

All eight checks pass. The current 2026-08-17 build faithfully implements the approved
Sperandeo TV-II trendline-failure card, every strategy input is wired, magic/slot rows are
consistent and collision-free for the current rebuild, the `.ex5` is fresh relative to
source, all 14 set files carry correct RISK_FIXED backtest risk, and a strict build_check
returns PASS with zero failures/warnings.
