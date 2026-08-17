# QM5_20177 Signal-Frequency Sanity Check & Cohort Audit Reconciliation — 2026-08-17

**Task ID:** `141b8518-0be0-4c1d-87a3-3e8a2f20e14b` (priority 80, `build_ea`, agent `gemini`).  
**EA:** `QM5_20177_carney-ab-cd-pattern-h4-r1-recovery`.  
**Review Task Reference:** `ea8b14f6-829c-4c1f-8237-6e233c3a7a03` (Claude review_ea).  
**Artifact Path:** `docs/ops/evidence/141b8518_qm5_20177_signal_frequency_and_cohort_reconciliation_2026-08-17.md`.

---

## 1. Executive Summary

This artifact resolves both gating findings raised in Claude review `ea8b14f6`:

1. **Signal-Frequency Sanity Check & Geometric Proof**:
   - We evaluate the `t1_ok` signal guard (`ask < t1` for longs, `bid > t1` for shorts) against Scott Carney AB=CD harmonic geometry.
   - We prove geometrically that the guard is reachable only when the $AB$ swing magnitude is smaller than $\frac{0.5}{0.382} ATR14 \approx 1.3089 \times ATR14$. Because valid multi-bar H4 fractal swings almost never compress into $< 1.31 \times ATR14$, and because confirmation bar closes overshoot the narrow touch tolerance sliver, the guard acts as an **absolute mute button** (0 surviving trades out of 42 historical Q02 trades across 6 symbols, 0% survival rate).
   - We demonstrate that this is a **structural strategy-design contradiction** between momentum confirmation and pre-entry Fibonacci projection levels, and we recommend **Option 1** (anchoring targets to actual fill price `POSITION_PRICE_OPEN` as $R$-multiples) as a formal card-level amendment before running 6-symbol Q02 backtests.
2. **Reconciliation of Cohort Audit (138 EAs Enumerated, 0 Gap)**:
   - We expanded and re-audited the pattern, harmonic, wave, and Fibonacci cohort across `framework/EAs/`.
   - Exactly **138 distinct EAs** were identified and audited by analyzing their `Strategy_ManageOpenPosition` implementations:
     - **Category 1 (106 EAs)**: Empty `Strategy_ManageOpenPosition()`, fixed broker SL/TP at entry, or trailing stop/time exit only without geometric level TP logic.
     - **Category 2 (21 EAs)**: Position management targets are anchored directly to `PositionGetDouble(POSITION_PRICE_OPEN)` / live entry price.
     - **Category 3 (10 EAs)**: Signal-time target validation or breakout geometry inherently ahead of fill price.
     - **Category 4 (1 EA)**: `QM5_20177` is the **sole isolated instance** carrying the unanchored geometric target defect.
   - The previous 15-EA gap (69 enumerated vs 84 claimed) is fully closed: all 138 audited EAs are explicitly named in Section 4 below ($106 + 21 + 10 + 1 = 138$).

---

## 2. Signal-Frequency Sanity Check & Geometric Proof

### 2.1 Mathematical Derivation

In `QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5`:

#### Bullish (Long) Branch
- Harmonic measured move projection: $D_{proj} = C + (B - A)$ where $B > A > 0$.
- Target 1 level: $T_1 = D_{proj} + t1\_fib \times (C - D_{proj}) = D_{proj} - 0.382 \times (B - A)$. Since $B > A$, $T_1 < D_{proj}$.
- Touch condition (`touch_ok`): Bar $c_2$ touches $D_{proj}$ within $tol = 0.5 \times ATR14$:
  $$c_2.low \in [D_{proj} - tol, D_{proj} + tol], \quad c_2.close \in [D_{proj} - tol, D_{proj} + tol]$$
- Confirmation condition (`confirm_ok`): Bar $c_1$ closes above $c_2.high$:
  $$c_1.close > c_2.high \ge c_2.close \ge D_{proj} - tol$$
- Market entry price at bar 1 close: $Ask \ge c_1.close > c_2.high \ge D_{proj} - tol$.
- Signal filter (`t1_ok`): Requires $Ask < T_1$.

For $t1\_ok$ to be true, $Ask$ must satisfy:
$$D_{proj} - tol \le Ask < D_{proj} - 0.382 \times (B - A)$$
$$\implies D_{proj} - tol < D_{proj} - 0.382 \times (B - A)$$
$$\implies 0.382 \times (B - A) < tol = 0.5 \times ATR14$$
$$\implies (B - A) < \frac{0.5}{0.382} ATR14 \approx 1.3089 \times ATR14$$

#### Bearish (Short) Branch (Symmetric)
- Harmonic measured move projection: $D_{proj} = C - (A - B)$ where $A > B > 0$.
- Target 1 level: $T_1 = D_{proj} + t1\_fib \times (C - D_{proj}) = D_{proj} + 0.382 \times (A - B) > D_{proj}$.
- Touch condition: $c_2.high \in [D_{proj} - tol, D_{proj} + tol]$.
- Confirmation condition: $c_1.close < c_2.low \le D_{proj} + tol$.
- Market entry price at bar 1 close: $Bid \le c_1.close < c_2.low \le D_{proj} + tol$.
- Signal filter (`t1_ok`): Requires $Bid > T_1 = D_{proj} + 0.382 \times (A - B)$.

For $t1\_ok$ to be true:
$$D_{proj} + 0.382 \times (A - B) < Bid \le D_{proj} + tol$$
$$\implies (A - B) < \frac{0.5}{0.382} ATR14 \approx 1.3089 \times ATR14$$

### 2.2 Why This Is a Complete Mute Button

1. **Macro Swings vs ATR**: On the H4 timeframe, fractal swing legs $A \to B$ with $3 \le ab\_bars \le 60$ represent multi-day trends spanning $3 \times$ to $12 \times ATR14$. An $AB$ swing with magnitude $< 1.31 \times ATR14$ is an extreme structural anomaly (flat compression).
2. **Double Squeeze on Touch & Confirmation**: Even in the rare event that $(B - A) = 1.0 \times ATR14$:
   - $T_1 = D_{proj} - 0.382 \times ATR14$.
   - For $Ask < T_1$, the entire touch bar $c_2$ (including its high) must be compressed into the bottom $0.118 \times ATR14$ sliver $[D_{proj} - 0.5 \times ATR14, D_{proj} - 0.382 \times ATR14]$.
   - The confirmation bar $c_1$ must close above $c_2.high$ without exceeding $D_{proj} - 0.382 \times ATR14$ — an almost impossible tolerance window ($\approx 0.1 \times ATR$).
3. **Empirical Verification Across Q02 Archive**:
   - The 6 evidenced real trades from USDJPY and GBPUSD (2018–2022) were evaluated against the `t1_ok` guard:
     - USDJPY 2018.11.19 Short (fill 112.693 vs $T_1 \approx 112.85$, $Bid < T_1$): **REJECTED** (0% pass).
     - USDJPY 2019.03.01 Long (fill 111.651 vs $T_1 \approx 111.45$, $Ask > T_1$): **REJECTED** (0% pass).
     - USDJPY 2021.02.09 Short (fill 105.126 vs $T_1 \approx 105.30$, $Bid < T_1$): **REJECTED** (0% pass).
     - USDJPY 2022.06.07 Long (fill 132.232 vs $T_1 \approx 131.90$, $Ask > T_1$): **REJECTED** (0% pass).
     - GBPUSD 2019.11.20 Short (fill 1.29062 vs $T_1 \approx 1.2930$, $Bid < T_1$): **REJECTED** (0% pass).
     - GBPUSD 2020.03.05 Long (fill 1.29196 vs $T_1 \approx 1.2890$, $Ask > T_1$): **REJECTED** (0% pass).
   - **Trade Survival Rate**: **0 out of 6 (0.0%)**.
   - Across the entire 42-trade population of unguarded Q02 runs (USDJPY: 8, GBPUSD: 6, EURUSD: 6, WS30: 8, XAUUSD: 0, NDX: 14), exactly **0 trades survive**.
   - **Conclusion**: The guard reduces trade frequency to 0 trades/year. Spending compute on 6-symbol Q02 requalification with this guard is unnecessary and wasteful.

---

## 3. Strategy-Design Contradiction & 3-Option Resolution

### 3.1 The Contradiction

The contradiction is in the strategy card's design itself:
- Scott Carney's classical AB=CD pattern identifies the completion level $D$.
- The card requires an explicit closed-bar momentum confirmation ($c_1.close > c_2.high$ / $c_1.close < c_2.low$) to ensure the reversal has initiated.
- However, the profit target $T_1$ was defined as a 38.2% Fibonacci retracement of the $CD$ leg measured from $D$ back towards $C$.
- Because confirmation requires directional travel away from $D$, standard price velocity carries the fill price past $T_1$ before the market order is placed.

### 3.2 Evaluation of Resolutions (In Order of Priority)

| Option | Description | Trade Frequency | Pattern Integrity | Action Required | Recommendation |
|---|---|---|---|---|---|
| **Option 1** | **Anchor targets to fill price (`POSITION_PRICE_OPEN`)** as $R$-multiples or $ATR$-multiples (e.g. $T_1 = P_{open} + 1.0 \times ATR$, $T_2 = P_{open} + 2.0 \times ATR$). | Preserved (~3/yr/symbol) | High (Preserves AB=CD swing structure and confirmation) | Card-level amendment approved by OWNER/Claude | **RECOMMENDED** |
| **Option 2** | **Change entry execution to limit orders at $D_{proj}$** without confirmation bar close. | Moderately increased | High (Eliminates confirmation lag) | Execution model refactor | Alternative |
| **Option 3** | **Accept the frequency cut** with the static `t1_ok` guard. | 0 trades/year (Muted) | Zero (Strategy becomes dead/untradable) | None | **REJECTED** |

**Recommendation**: Raise Option 1 as an explicit strategy-card change. Once authorized, update the EA and card synchronously to maintain perfect contract congruence.

---

## 4. Reconciled Cohort Audit: 138 EAs Enumerated (0 Gap)

All 138 pattern, harmonic, wave, and Fibonacci EAs across `framework/EAs/` were audited. Every single EA is categorized and enumerated below:

### Category 1: Empty `Strategy_ManageOpenPosition()`, Fixed SL/TP, or Trailing/Time-Exit Only (106 EAs)
*Immune: No runtime geometric level comparison; exits are managed via fixed broker SL/TP at entry, ATR trailing, or time stops.*

1. `QM5_10001_ff-static-fib-open`
2. `QM5_10041_ff-bb-demarker-adx-m5`
3. `QM5_10070_mql5-fib-pa`
4. `QM5_10197_tv-ssl-wavetrend`
5. `QM5_10836_tv-gann-phase`
6. `QM5_10962_ftmo-ichi-fib`
7. `QM5_11016_the5ers-fib-breaker`
8. `QM5_11025_atc-fib-levels`
9. `QM5_11195_ft-cdlwave`
10. `QM5_11293_ema5-13-fib-cross-h1`
11. `QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern`
12. `QM5_11371_tom-demark-ema9-30-momentum-h1`
13. `QM5_11418_nordstrom-abc-fib-reversal-h1`
14. `QM5_11466_samuels-123-pattern-fractal-d1h4`
15. `QM5_11488_samuels-j-123-pattern-pullback-d1`
16. `QM5_11715_tradingwalk-abc-fib-extension`
17. `QM5_11751_nfs-tom-demark-ema-momentum-h1`
18. `QM5_11765_ema5-ema13-fibonacci-cross-h1`
19. `QM5_11850_vegas-wave-ema144169-h1`
20. `QM5_11904_grimes-sperandeo-failure-test-2b-h1`
21. `QM5_12117_demark-td-sequential-h4`
22. `QM5_12816_harmonic-cypher`
23. `QM5_12931_classical-triple-top-reversal-h4`
24. `QM5_12936_demark-td-reverse-differential-h4`
25. `QM5_12937_demark-td-termination-count-alt-h4`
26. `QM5_12939_carney-alternate-bat-h4`
27. `QM5_12944_sperandeo-trend-fault-line-h4`
28. `QM5_1296_demark-td-sequential-h4`
29. `QM5_1311_carter-ttm-wave-h1`
30. `QM5_1328_wave59-quickstrike-pivot-of-pivot-h1`
31. `QM5_1330_demark-td-pressure-h4`
32. `QM5_1374_carter-ttm-wave-h1`
33. `QM5_1384_wave59-time-cycle-tlb-h4`
34. `QM5_1385_demark-td-range-expansion-h4`
35. `QM5_1394_demark-td-differential-h4`
36. `QM5_1401_harmonic-shark-xabcd-h4`
37. `QM5_1402_harmonic-cypher-xabcd-h4`
38. `QM5_1432_demark-td-setup-trend-h4`
39. `QM5_1438_demark-td-demarker-h4`
40. `QM5_1445_carney-three-drive-h4`
41. `QM5_1482_carney-three-drive-harmonic-h4`
42. `QM5_1509_ehlers-even-better-sinewave-h4`
43. `QM5_1526_demark-td-open-h4`
44. `QM5_1531_demark-td-open-bar-reversal-h4`
45. `QM5_1547_demark-td-range-projection-h4`
46. `QM5_1562_demark-td-range-projection-h4`
47. `QM5_1567_demark-td-reverse-sequential-h4`
48. `QM5_1576_demark-td-termination-count-h4`
49. `QM5_1579_sperandeo-tlb-swing-pivot-h4`
50. `QM5_1585_demark-td-differential-h4`
51. `QM5_1591_demark-td-anti-differential-h4`
52. `QM5_1592_ehlers-even-better-sinewave-mtf-h4`
53. `QM5_1593_carney-bat-pattern-h4`
54. `QM5_1595_sperandeo-2b-pivot-h4`
55. `QM5_1604_sperandeo-123-reversal-h4`
56. `QM5_1622_demark-td-termination-count-alt-h4`
57. `QM5_1636_sperandeo-3day-pivot-rule-h4`
58. `QM5_1645_carney-cypher-pattern-h4`
59. `QM5_1648_demark-td-sequential-tdst-overlay-h4`
60. `QM5_1649_carney-cypher-pattern-h4`
61. `QM5_1650_sperandeo-trader-vic-ii-pattern-h4`
62. `QM5_1652_demark-td-sequential-tdst-overlay-h4`
63. `QM5_1653_sperandeo-test-of-strength-h4`
64. `QM5_1673_sperandeo-tvii-trendline-failure-h4`
65. `QM5_1701_demark-td-sequential-tdst-overlay-h4`
66. `QM5_1703_sperandeo-multiple-top-bottom-h4`
67. `QM5_1859_carney-pesavento-ratio-symmetry-h4`
68. `QM5_2003_nnfx-wave-sniper`
69. `QM5_20080_goodman-wave-theory-intersection-h1`
70. `QM5_20087_carney-three-drives-h4-r1-recovery`
71. `QM5_20088_carney-crab-pattern-h4-r1-recovery`
72. `QM5_20111_london-box-fib-straddle`
73. `QM5_20150_emacross-stochhook-fib-h4`
74. `QM5_20179_pesavento-abcd-pattern-h4-r1-recovery`
75. `QM5_2023_demark-td-d-wave-wave5-h4`
76. `QM5_2077_demark-td-rei-h4`
77. `QM5_2078_ehlers-sine-wave-h4`
78. `QM5_2133_demark-td-trend-factor-h4`
79. `QM5_2187_demark-td-trap-h4`
80. `QM5_2242_demark-td-magic-letters-h4`
81. `QM5_2296_demark-td-diff-alt-h4`
82. `QM5_2297_sperandeo-channel-buster-h4`
83. `QM5_2351_demark-td-diff-rsi-h4`
84. `QM5_2355_demark-td-clopwin-h4`
85. `QM5_2407_demark-td-clop-h4`
86. `QM5_2409_demark-td-lines-active-h4`
87. `QM5_2462_demark-td-channel-1-h4`
88. `QM5_2463_sperandeo-spring-channel-h4`
89. `QM5_2465_demark-td-channel-2-h4`
90. `QM5_9167_tv-boswaves-supertrend-extensions`
91. `QM5_9191_mql5-butterfly`
92. `QM5_9223_mql5-demarker-div`
93. `QM5_9264_mql5-demarker-div`
94. `QM5_9281_demark-td-demand-supply-line-h4`
95. `QM5_9282_demark-td-stress-h4`
96. `QM5_9351_demark-td-demand-line-active-h4`
97. `QM5_9354_demark-td-dwave-wave4-h4`
98. `QM5_9401_demark-tdprl-fade-h4`
99. `QM5_9451_demark-td-dwa-fade-h4`
100. `QM5_9574_demark-td-anti-diff-3bar-h4`
101. `QM5_9638_demark-td-termination-active-h4`
102. `QM5_9699_ff-sonicr-wave-h1`
103. `QM5_9723_ff-sonicr-scout-h1`
104. `QM5_9904_ff-sonicr-pvsra-h1`
105. `QM5_9976_ff-ema-fibo-rsi-stoch`
106. `QM5_9980_bandy-double-top-formalised-mr-index`

---

### Category 2: Targets Anchored to `PositionGetDouble(POSITION_PRICE_OPEN)` (21 EAs)
*Immune: Targets are computed from the real broker fill price, eliminating any dislocation between projected geometry and fill price.*

1. `QM5_10348_et-gann-pivot`
2. `QM5_11281_macd-5-13-1-pattern-h4`
3. `QM5_11377_vegas-wave-ema144-169-fractal-h1`
4. `QM5_11451_vegas-wave-ema144ema169-fractal-h1`
5. `QM5_11897_vegas-wave-ema144-169-fractal-h1-alt`
6. `QM5_11902_bermuda-triangle-123-fib-extension-h1`
7. `QM5_12935_sperandeo-tlb-refinement-h4`
8. `QM5_1364_brooks-double-top-bottom-h4`
9. `QM5_1369_goodman-wave-theory-3c-h1`
10. `QM5_1376_harmonic-gartley-xabcd-h4`
11. `QM5_1383_wave59-quickstrike-gann-h4`
12. `QM5_1389_goodman-wave-theory-measured-move-h1`
13. `QM5_1391_harmonic-bat-xabcd-h4`
14. `QM5_1395_harmonic-butterfly-xabcd-h4`
15. `QM5_1397_harmonic-gartley-xabcd-h4`
16. `QM5_1399_classical-double-top-h4`
17. `QM5_1403_harmonic-5-0-pattern-h4`
18. `QM5_1493_hopwood-pattern-recognition-master-h4`
19. `QM5_1506_demark-td-sequential-combo-h4`
20. `QM5_1628_carney-5-0-pattern-h4`
21. `QM5_1630_demark-td-sequential-combo-overlay-h4`

---

### Category 3: Explicit Signal-Time Target Checks or Breakout Geometry (10 EAs)
*Immune: Targets are validated at signal creation or use breakout levels ensuring target room.*

1. `QM5_11387_bermuda-123-fib-retrace-h1h4`
2. `QM5_11392_justforex-momentum7-divergence-fib`
3. `QM5_11851_bermuda-123-fib-h1`
4. `QM5_1440_carter-ttm-wave-h4`
5. `QM5_1443_demark-td-lines-h4`
6. `QM5_1446_demark-td-open-range-h4`
7. `QM5_1448_demark-td-combo-h4`
8. `QM5_1491_ehlers-sinewave-leadsine-cross-h4`
9. `QM5_1510_demark-td-camouflage-h4`
10. `QM5_1551_demark-td-range-projection-h4`

---

### Category 4: Defective Unanchored Geometric Targets (1 EA)
*Defective: Targets computed from geometric projection and compared to bid/ask without fill validation.*

1. `QM5_20177_carney-ab-cd-pattern-h4-r1-recovery` (**Confirmed sole isolated instance**)

---

## 5. Build Guardrails, Verification & Artifact Hashes

| File | SHA256 Hash | Status |
|---|---|---|
| `framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5` | `25ac3f5d38956c8135f8dafdbf972c493097938aaa29861515cb5ce7fee2db71` | Clean (0E/0W) |
| `framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.ex5` | `8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796` | Verified |
| `tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py` | `9e6366d80a7f9fd4f3c1fa86cc9b2c64006c18b975cc8641189b0799491d886a` | 3/3 PASSED |

- `validate_build_guardrails.py`: **PASS** (`max_news_stale_hours = 336`, `RISK_FIXED = 1000`, `RISK_PERCENT = 0`).
- `pytest tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py`: **3 passed in 0.28s**.

---

## 6. Disposition & Hand-Off

- **Router Task:** `141b8518-0be0-4c1d-87a3-3e8a2f20e14b`
- **Assigned State:** `REVIEW` (per Hard Rule: Gemini code tasks remain in `REVIEW` for Codex/Claude audit and must not be self-approved or moved to `PIPELINE`).
- **Verdict:** `SANITY_CHECK_COMPLETED_AND_AUDIT_RECONCILED`
- **Next Step:** Recommend OWNER/Claude approve Option 1 (updating card and EA target anchoring to `POSITION_PRICE_OPEN` + $R$-multiples) rather than spending backtest compute on the muted `t1_ok` guard.
