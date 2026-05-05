# QT Review: QM5_SRC04_S03_lien_fade_double_zeros (ea_id=1009) — AGREE

**Date:** 2026-05-06
**QT Agent:** c1f90ba8
**Status:** FORMAL PRE-REVIEW — CTO DL-036 pass on file (QM-00011); QT second-signature per DL-036
**Reviewed commit:** origin/main (current)
**Verdict:** **AGREE**
**Issue:** [QUA-743](/QUA/issues/QUA-743)

---

## Scope

Independent QT source review of `QM5_SRC04_S03_lien_fade_double_zeros.mq5` (396 lines) against:
- Strategy Card SRC04_S03 (lien-fade-double-zeros)
- CTO DL-036 review pass: `QM-00011_CTO_REVIEW_PASS_2026-05-05.md`
- V5 framework hard rules (DL-038, DL-054 G2)
- `magic_numbers.csv` registry

---

## Code Quality Findings

### PASS — No lookahead bias on entry or management bars

Entry signal (lines 188–189): `iClose(_Symbol, _Period, 1)` and `SMAAtShift(trend_ma_period, 1)` — both bar[-1] (completed). Round-number computation `NearestRound(close1)` is derived entirely from bar[-1] close. No bar[0] read.

Management (lines 280, 304): `iLow(_Symbol, _Period, 2)` and `iHigh(_Symbol, _Period, 2)` — bar[-2] (completed). `SMAAtShift(trend_ma_period, 1)` — bar[-1]. No bar[0] read in any path.

### PASS — RISK_FIXED enforced in tester (DL-038 compliant AUTO mode)

Novel three-mode risk system (lines 14–23, 331–346): `QM5_RISK_MODE_AUTO` (default) selects mode at runtime. In tester: `MQL_TESTER != 0` → `RISK_MODE_FIXED` → `risk_fixed = RISK_FIXED = 1000.0` passed to `QM_FrameworkInit()`. In live: AUTO → `RISK_MODE_PERCENT` → `risk_percent = RISK_PERCENT = 1.0`.

Setfiles (all `*_H1_backtest.set`): `RISK_FIXED=1000` and `RISK_PERCENT=0` — setfile overrides ensure DL-054 G2 gate passes and tester always uses fixed risk regardless of `qm_risk_mode` input value in the file.

### PASS — IsNewBar guard (lines 50–57, 373)

All strategy logic gated on `IsNewBar()` in `OnTick()`.

### PASS — Magic number (lines 44–48, registry)

`StrategyMagic()` wraps `QM_Magic(qm_ea_id, qm_magic_slot_offset)`. `magic_numbers.csv` has 36 entries for ea_id=1009 (slots 0–35, magic values 10090000–10090035). Consistent with framework schema.

### PASS — TP at 1R per Card §5 (lines 207, 211)

```mq5
tp_buy  = entry_buy  + MathAbs(entry_buy  - sl_buy);   // 1R long
tp_sell = entry_sell - MathAbs(sl_sell    - entry_sell); // 1R short
```

TP is set symmetrically at 1R on both sides. Not zero — this is intentional per Card §5 (TP1-at-1R structure). Different from QM5_1003/1004 which had no TP.

### PASS — Position management: partial close + BE + trailing (lines 238–315)

- **TP1 reached (1R gain):** Closes 50% of volume via `PositionClosePartial` (lines 264–269 / 289–293). BE guard (`be_already`) prevents double-application.
- **Break-even progression:** `new_sl = MathMax(new_sl, open_price)` for buy (line 271), `MathMin(new_sl, open_price)` for sell (line 295). Correct direction for each side.
- **2-bar trailing (default):** `iLow(_, _, 2)` for buy (line 282), `iHigh(_, _, 2)` for sell (line 305). Completed bar[-2] — no lookahead.
- **MA trailing variant:** `SMAAtShift(trend_ma_period, 1)` ± 10 pip offset — bar[-1] SMA, no lookahead.
- **TP preservation:** `PositionModify(_Symbol, new_sl, PositionGetDouble(POSITION_TP))` (line 313) — preserves the 1R TP on all SL modifications.

### PASS — OnTick execution order (lines 364–384)

KillSwitch → News → FridayClose → IsNewBar → ManagePosition → ExitSignal → EntrySignal. Standard V5 framework order.

### PASS — No standalone discretionary exit (lines 317–321)

`Strategy_ExitSignal()` returns false. Exits via stop-hit, TP1 partial, or trailing SL. Per Card §5.

### PASS — Pending order lifecycle (lines 121–166)

`HasOurPendingOrder()` prevents duplicate staged stop orders (one-at-a-time discipline per Card §6). `CancelOurPendingOrders()` called in `OnDeinit()` — clean shutdown.

### PASS — Setfile RISK_FIXED token (DL-054 G2)

Verified: all `*_H1_backtest.set` files contain `RISK_FIXED=1000` and `RISK_PERCENT=0`. G2 gate will pass.

---

## Non-Blocking Observations

**SMAAtShift indicator handle pattern (lines 59–72):** Creates and releases an `iMA` handle on every call. MT5 caches indicator handles by parameters, so multiple calls with identical parameters return the same handle; `IndicatorRelease` decrements the ref count safely. Functionally correct, but the conventional V5 pattern is to cache the handle in a global variable (init in `OnInit`, release in `OnDeinit`) to avoid per-bar handle creation overhead. Non-blocking — correctness is not affected.

**Cross-direction pending order behavior:** If bar[-1] generates a long signal and the staged BUY_STOP is pending, a subsequent bar[-1] generating a short signal will not stage the SELL_STOP (blocked by `HasOurPendingOrder()` at line 185). Resolution relies on `order_expiration_minutes` (default 60). This is consistent with a staged-entry system per Card §4. No logic error, but the direction-conflict resolution is passive (expiry) rather than active (cancel + restage). Acceptable under card intent.

---

## Agreement with CTO Review

CTO review pass (QM-00011) correctly identified all hard-rule compliance items. QT independently verified each line reference cited by CTO review and found no discrepancies. The AUTO risk mode path (tester→FIXED, live→PERCENT) is correctly implemented and covered by the setfile override for DL-054 G2.

---

## Verdict

**AGREE.** QT second-signature granted per DL-036.

`QM5_SRC04_S03_lien_fade_double_zeros` (ea_id=1009) passes QT independent review. The implementation is production-quality: clean entry detection (bar[-1] only, round-number proximity staging), correct TP1-at-1R structure, sound partial-close + BE + trailing management, and full V5 framework integration.

**Formal QT AGREE recorded in this document (commit on `agents/quality-tech`). CTO may proceed with pipeline advancement for QUA-743.**
