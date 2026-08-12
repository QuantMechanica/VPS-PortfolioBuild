# Independent Q10 Survivor Census and Concentration Review

**Router task:** `c2b505e6-c1f7-41d1-8a73-7a4f4a14dc3f`

**Analyst:** Codex

**Snapshot:** immutable pre-XTI-cohort backup, opened with `mode=ro&immutable=1`

**Scope:** census and portfolio triage only; no EA, setfile, registry, work-item, terminal, or gate mutation

## 1. Verdict

The immutable snapshot contains **40** completed Q10 PASS rows but only **34** distinct
`(ea_id, symbol)` survivor sleeves, spanning **32** EAs and **13** symbols. The difference
is repeated confirmation/ablation evidence, not six additional sleeves. Five keys have
more than one Q10 PASS row: QM5_10145/XAUUSD has three; QM5_10911/GDAXI,
QM5_11421/EURUSD, QM5_12567/XAUUSD, and QM5_13301/GDAXI have two each. [SQL Q1, Q4]

The dated inverse-vol roster contains **24** filename entries, of which **23** have return
rows. It overlaps **22** of the **34** Q10 survivors. The two roster-only keys are not
gate-clean in this snapshot: QM5_10440/NDX has a completed Q10 FAIL and its roster CSV is
header-only; QM5_12567/XNGUSD has a completed Q08 FAIL_HARD and no Q10 PASS. [SQL Q5,
Q7; `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10440_NDX_104400003_daily_returns.csv:1`;
`D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_12567_XNGUSD_125670002_daily_returns.csv:2`]

This is a **historical-Q10 census**, not a declaration of current deploy eligibility. The
snapshot's `candidate_qualifications` table has **zero** rows, so it contains no current
hash-bound qualification record with which to prove formal gate cleanliness. [SQL Q6]

Portfolio concentration is material. XAUUSD accounts for **9/34 (26.5%)** sleeves;
EURUSD and GDAXI each account for **4/34 (11.8%)**. Together those three symbols are
**17/34 (50.0%)** of the survivor set. [SQL Q2] Mechanically, trend/continuation/breakout
accounts for **13/34 (38.2%)**, mean-reversion/exhaustion/reversal for **12/34 (35.3%)**,
calendar/session effects for **7/34 (20.6%)**, and fixed-pair statistical spread trading
for **2/34 (5.9%)**. [SQL Q3]

The dated return screen identifies one realized correlation bloc at the DL-083
`regime_corr_admit_max` reference level of **0.15**: QM5_10403/XAUUSD,
QM5_10513/XAUUSD, and QM5_1556/XAUUSD are connected through correlations of
**+0.294803** and **+0.210373** to QM5_10403. No rostered Q10-survivor pair reaches the
DL-083 reject reference of **0.40**. [C1, R1-R20, R22-R23; DL-083 at
`C:/QM/repo/decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md:11-20`]
These are ordinary full-period daily-return correlations, not the regime-split
correlations required by DL-082/DL-083, so they are a triage signal and **not** an
admission verdict.

## 2. Definitions and method

1. A survivor is a distinct `(ea_id, symbol)` with at least one `work_items` row where
   `phase='Q10'`, `status='done'`, and `verdict='PASS'`. [SQL Q1]
2. Where a sleeve has repeated Q10 PASS rows, metrics come from its most recently updated
   PASS row (`updated_at DESC, id DESC`). [SQL Q1]
3. PF, trades, and maximum drawdown are `ea_metrics.profit_factor`,
   `ea_metrics.trades`, and `ea_metrics.drawdown_pct` joined by `work_item_id`. Every
   metric triplet in the census is from SQL Q1.
4. `Roster=Y` means the dated `invvol_stage1_20260804/daily` directory has a CSV for the
   key. It is membership in that research roster, not proof of T6/T_Live deployment.
   [SQL Q5; R1-R24]
5. Family labels are an analyst-controlled, mutually exclusive economic-mechanism map.
   `TC` = trend/continuation/breakout, `MR` = mean-reversion/exhaustion/reversal,
   `CS` = calendar/session, and `SA` = fixed-pair statistical spread. Sources are F1-F32.
6. Correlation C1 is Pearson correlation across the **2,348** common dated observations
   in each non-empty roster CSV, including zero-return days; the common input interval is
   lines **2-2349** of each R-file. [C1; R1-R23]

## 3. Sleeve census

Every identifier, symbol, Q10 selection, PF, trade count, and drawdown value below is
returned by SQL Q1. `Roster` is reproduced by SQL Q5 and R1-R24.

| EA / symbol | Family | PF | Trades | Max DD % | Roster |
|---|---|---:|---:|---:|:---:|
| QM5_1328 / EURJPY | MR [F1] | 1.09 | 58 | 9.81 | N |
| QM5_1556 / XAUUSD | TC [F2] | 1.93 | 53 | 2.68 | Y [R22] |
| QM5_1567 / EURUSD | MR [F3] | 1.50 | 73 | 8.83 | Y [R23] |
| QM5_10123 / XAUUSD | TC [F4] | 1.52 | 101 | 2.95 | N |
| QM5_10128 / XAUUSD | TC [F5] | 1.05 | 433 | 6.13 | N |
| QM5_10142 / SP500 | MR [F6] | 1.27 | 67 | 4.61 | N |
| QM5_10145 / XAUUSD | TC [F7] | 1.38 | 314 | 4.83 | N |
| QM5_10183 / XAUUSD | TC [F8] | 1.23 | 347 | 6.69 | N |
| QM5_10403 / XAUUSD | TC [F9] | 1.31 | 209 | 7.34 | Y [R1] |
| QM5_10513 / XAUUSD | TC [F10] | 1.98 | 104 | 4.14 | Y [R2] |
| QM5_10692 / NDX | MR [F11] | 1.08 | 686 | 14.87 | N |
| QM5_10706 / GBPUSD | CS [F12] | 1.51 | 284 | 19.93 | Y [R3] |
| QM5_10911 / GDAXI | TC [F13] | 1.15 | 331 | 14.78 | Y [R4] |
| QM5_10919 / XTIUSD | MR [F14] | 4.84 | 30 | 1.85 | Y [R5] |
| QM5_10938 / GDAXI | TC [F15] | 1.27 | 61 | 6.87 | N |
| QM5_10939 / GBPUSD | TC [F16] | 1.58 | 92 | 6.19 | Y [R6] |
| QM5_11132 / SP500 | MR [F17] | 1.49 | 73 | 3.01 | Y [R7] |
| QM5_11165 / AUDCAD | MR [F18] | 1.14 | 207 | 4.41 | Y [R8] |
| QM5_11165 / EURUSD | MR [F18] | 1.07 | 260 | 3.81 | Y [R9] |
| QM5_11421 / AUDUSD | MR [F19] | 1.16 | 90 | 5.59 | Y [R10] |
| QM5_11421 / EURUSD | MR [F19] | 1.15 | 92 | 6.45 | Y [R11] |
| QM5_11422 / USDCAD | TC [F20] | 1.24 | 197 | 13.25 | N |
| QM5_11708 / EURUSD | MR [F21] | 1.30 | 178 | 4.37 | Y [R12] |
| QM5_12567 / XAUUSD | MR [F22] | 1.61 | 73 | 2.37 | Y [R13] |
| QM5_12778 / AUDUSD | SA [F23] | 1.19 | 210 | 3.57 | Y [R14] |
| QM5_12969 / USDJPY | CS [F24] | 1.54 | 331 | 2.02 | Y [R15] |
| QM5_12989 / XAUUSD | TC [F25] | 1.72 | 51 | 6.48 | Y [R16] |
| QM5_13013 / NDX | TC [F26] | 1.35 | 71 | 3.82 | N |
| QM5_13036 / GDAXI | CS [F27] | 1.04 | 1,352 | 8.08 | N |
| QM5_13117 / EURGBP | SA [F28] | 1.44 | 208 | 3.05 | Y [R17] |
| QM5_13128 / NDX | CS [F29] | 2.29 | 57 | 1.25 | Y [R18] |
| QM5_13213 / USDJPY | CS [F30] | 1.16 | 1,624 | 22.80 | Y [R19] |
| QM5_13301 / GDAXI | CS [F31] | 1.28 | 742 | 14.49 | Y [R20] |
| QM5_20048 / XTIUSD | CS [F32] | 1.28 | 61 | 1.18 | N |

Two documentation gaps affect family provenance. The selected EA directories for
QM5_1567 and QM5_13301 contain no `SPEC.md`; their provisional families therefore come
from the implementation descriptions and strategy inputs in F3 and F31. This does not
alter their Q10 census membership. [SQL Q1; F3; F31]

## 4. Concentration

### 4.1 Symbol

| Symbol | Sleeves | Share |
|---|---:|---:|
| XAUUSD | 9 | 26.5% |
| EURUSD | 4 | 11.8% |
| GDAXI | 4 | 11.8% |
| NDX | 3 | 8.8% |
| AUDUSD | 2 | 5.9% |
| GBPUSD | 2 | 5.9% |
| SP500 | 2 | 5.9% |
| USDJPY | 2 | 5.9% |
| XTIUSD | 2 | 5.9% |
| AUDCAD | 1 | 2.9% |
| EURGBP | 1 | 2.9% |
| EURJPY | 1 | 2.9% |
| USDCAD | 1 | 2.9% |

All counts and shares in this table are SQL Q2 output. The main portfolio-selection
pressure is therefore not “find the best PF” but “prove marginal value inside the XAUUSD,
EURUSD, and GDAXI blocks.” This follows DL-082's requirement to evaluate capped
inverse-vol contribution through delta Sharpe, delta drawdown, worst day, and
regime-split correlation. [`C:/QM/repo/decisions/2026-07-19_DL-082_portfolio_first_admission_and_gate_recalibration.md:46-53`]

### 4.2 Family

| Economic family | Sleeves | Share | Main concentration |
|---|---:|---:|---|
| TC — trend/continuation/breakout | 13 | 38.2% | XAUUSD Donchian/momentum/Ichimoku plus Grimes continuation |
| MR — mean reversion/exhaustion/reversal | 12 | 35.3% | RSI/squeeze/reversal variants, including two multi-symbol EAs |
| CS — calendar/session | 7 | 20.6% | fixing, weekday/event, and intraday range/time windows |
| SA — fixed-pair statistical spread | 2 | 5.9% | two fixed FX-cross baskets |

All counts and shares in this table are SQL Q3 output. The classification does not claim
that every sleeve within a family is correlated; section 5 tests realized daily returns
where roster evidence exists.

## 5. Correlated blocs, near-duplicates, and orthogonality

### 5.1 Realized-return screen

- **XAU trend bloc (selection required):** QM5_10403/QM5_10513 is **+0.294803** and
  QM5_10403/QM5_1556 is **+0.210373**; QM5_10513/QM5_1556 is only **+0.068454**.
  [C1; R1, R2, R22] This is the only connected component at absolute correlation
  **>=0.15** among the **22** rostered Q10 survivors. [C1; R1-R20, R22-R23] It breaches the
  DL-083 diagnostic admit reference but remains below the **0.40** reject reference;
  the correct next action is a sealed-book marginal/leave-one-out comparison, not an
  automatic rejection. [DL-083 at
  `C:/QM/repo/decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md:13-20`]
- **GDAXI watch pair:** QM5_10911/QM5_13301 is **+0.135267**, just below the
  **0.15** reference. [C1; R4, R20] It is not the same mechanism—Grimes H1 complex
  pullback versus Balke timed range breakout—but its symbol overlap warrants the
  regime-split test before adding risk.
- **No reject-level pair:** the maximum absolute full-period daily correlation across
  the rostered-Q10 matrix is **0.294803**, so no pair reaches **0.40**. [C1; R1-R20,
  R22-R23]
  This is encouraging, but zero-heavy daily series can suppress correlations and C1 is
  not a crisis-regime substitute.

### 5.2 Structural near-duplicates

- **Same EA, different symbol:** QM5_11165/AUDCAD versus EURUSD and
  QM5_11421/AUDUSD versus EURUSD are parameter/mechanism duplicates by construction
  [F18; F19], yet their realized correlations are **-0.001240** and **+0.024975**.
  [C1; R8-R11] Treat them as separate sleeves for now, but charge shared implementation
  risk at portfolio review.
- **Cumulative RSI pair:** QM5_11132 and QM5_12567 use the same cumulative-RSI(2),
  SMA(200), ATR-stop, and time-exit skeleton. [F17; F22] Their SP500/XAUUSD realized
  correlation is **+0.053340**. [C1; R7, R13] Mechanically redundant research does not
  translate into redundant realized P&L here.
- **Cointegration skeleton:** QM5_12778 and QM5_13117 both use a fixed two-leg D1 log
  spread, **60**-bar z-score, absolute entry threshold **2.0**, exit band **0.5**, and
  per-leg ATR protection, but on different pairs and betas. [F23; F28] Their host-sleeve
  daily correlation is **-0.032042**. [C1; R14, R17] They are implementation cousins but
  realized diversifiers in this sample.
- **Balke range variants:** QM5_13301 explicitly describes itself as the
  minute-precision variant of QM5_13213. [F30; F31] Their USDJPY/GDAXI correlation is
  **+0.008319** despite **573** simultaneous active-return days and active-day Jaccard
  **0.3196**. [C1; R19, R20] Timing/mechanism concentration exists, but return redundancy
  does not.
- **D1 squeeze cousins:** QM5_11421/EURUSD and QM5_11708/EURUSD both implement daily
  squeeze/reversal stop entries. [F19; F21] Their correlation is **+0.030259**. [C1;
  R11, R12]
- **Related continuation designs:** QM5_10123 and QM5_10403 are both D1 20-day
  Donchian/Turtle breakouts [F4; F9], but QM5_10123 has no dated return file, so that
  pair cannot be tested. [SQL Q5] QM5_10939 and QM5_12989 are closely related
  multi-timeframe Grimes continuation-pullback designs [F16; F25], yet their realized
  correlation is only **+0.076455**. [C1; R6, R16]

### 5.3 Redundant versus orthogonal

**Redundancy candidates:** the live XAU trend bloc is the only evidenced return-level
redundancy candidate. The four additional unrostered XAU trend sleeves—QM5_10123,
QM5_10128, QM5_10145, and QM5_10183—should not receive optimization budget unless a
fresh fixed-risk return series shows marginal value versus the existing XAU block.
[SQL Q1, Q3, Q5]

**Orthogonal candidates:** low correlations preserve the portfolio case for same-code
cross-symbol sleeves, the two cointegration baskets, the Balke range variants, and the
daily-squeeze cousins. Calendar/event sleeves also supply a distinct mechanism, but
low sample counts make parameter optimization especially selection-bias-prone. DL-082
explicitly makes DSR/PBO more load-bearing as trials increase.
[`C:/QM/repo/decisions/2026-07-19_DL-082_portfolio_first_admission_and_gate_recalibration.md:21-22`]

## 6. Portfolio-first optimization priorities

These are research-budget priorities, not gate, admission, or deployment verdicts.
DL-082 requires marginal contribution at capped inverse-vol weight, and DL-083 says
delta Sharpe must not be the sole driver. [`C:/QM/repo/decisions/2026-07-19_DL-082_portfolio_first_admission_and_gate_recalibration.md:46-53`;
`C:/QM/repo/decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md:15-18`]

| Priority | Sleeve / block | Evidence | Portfolio rationale | Recommended research target |
|---:|---|---|---|---|
| 1 | QM5_13213 / USDJPY | PF **1.16**, **1,624** trades, DD **22.80%** [SQL Q1]; max absolute roster correlation **0.070752** [C1; R1-R20, R22-R23] | Largest drawdown and deepest sample in an otherwise low-correlation sleeve | Predeclare a small range-quality/session-exit lattice aimed at DD and worst-day reduction; require unchanged mechanics and fresh OOS/DSR/PBO evidence |
| 2 | QM5_10706 / GBPUSD | PF **1.51**, **284** trades, DD **19.93%** [SQL Q1]; max absolute roster correlation **0.070752** [C1; R1-R20, R22-R23] | Strong standalone edge and low correlation, but book-level DD burden is high | Tight, theory-linked sweep-quality/stop-management study; optimize marginal DD, not headline PF |
| 3 | QM5_13301 / GDAXI | PF **1.28**, **742** trades, DD **14.49%** [SQL Q1]; corr **+0.135267** to QM5_10911 [C1; R4, R20] | High sample and useful mechanism, but both DD and near-threshold GDAX overlap matter | Joint leave-one-out comparison with QM5_10911; only then test range/session filters for DD reduction |
| 4 | Live XAU trend bloc | QM5_10403 **1.31/209/7.34%**, QM5_10513 **1.98/104/4.14%**, QM5_1556 **1.93/53/2.68%** (PF/trades/DD) [SQL Q1]; bloc correlations above [C1; R1, R2, R22] | Largest symbol block and only correlation component above the admit reference | Optimize the **selection/weight**, not all three EAs independently: sealed-book leave-one-out, regime correlation, delta worst-day, and ops contribution |
| 5 | QM5_11422 / USDCAD | PF **1.24**, **197** trades, DD **13.25%**; absent dated roster [SQL Q1, Q5] | Unique cohort symbol offers potential diversification, but no dated portfolio series supports it yet | First regenerate a governed fixed-risk return series and marginal evaluation; only optimize if diversification survives |
| 6 | QM5_20048 / XTIUSD | PF **1.28**, **61** trades, DD **1.18%**; absent dated roster [SQL Q1, Q5] | Orthogonal seasonal-energy thesis with low measured DD, but limited sample | Prioritize portfolio admission evidence over parameter search; keep the holiday set and mechanics locked |

**Protect rather than optimize:** QM5_10919/XTIUSD at PF **4.84**, **30** trades, DD
**1.85%**, and QM5_13128/NDX at PF **2.29**, **57** trades, DD **1.25%** have attractive
but low-count evidence. [SQL Q1] Broad tuning would spend selection-bias budget where
the current portfolio case is already strong; re-confirmation and marginal evaluation
are higher value.

**Deprioritize until marginal evidence exists:** QM5_10692/NDX (PF **1.08**, **686**
trades, DD **14.87%**), QM5_13036/GDAXI (PF **1.04**, **1,352** trades, DD **8.08%**),
and QM5_1328/EURJPY (PF **1.09**, **58** trades, DD **9.81%**) are outside the dated
roster and combine thin PF or limited sample with meaningful DD. [SQL Q1, Q5] Do not
spend optimization trials merely to lift standalone PF; first demonstrate a plausible
DL-082 marginal role.

## 7. Gate-cleanliness exceptions in the dated roster

| Roster key | Roster evidence | Latest relevant gate evidence | Finding |
|---|---|---|---|
| QM5_10440 / NDX | Header only; **0** return rows [`D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10440_NDX_104400003_daily_returns.csv:1`; SQL Q5] | Q10 `done/FAIL`; later Q08 `done/INFRA_FAIL`; latest Q09_NEWS `failed/INFRA_FAIL` [SQL Q7] | **Not gate-clean; remove from any active portfolio interpretation.** |
| QM5_12567 / XNGUSD | **2,348** return rows [`D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_12567_XNGUSD_125670002_daily_returns.csv:2-2349`; SQL Q5] | Q08 `done/FAIL_HARD`; Q09_NEWS `done/REVIEW_REQUIRED`; no Q10 row or Q10 PASS [SQL Q7] | **Not gate-clean; historical return data must not be mistaken for admission.** |

The other **22** roster/Q10-overlap keys are historical Q10 PASS sleeves by the report's
definition. [SQL Q1, Q5] They still cannot be called currently qualified because the
formal qualification table is empty in this snapshot. [SQL Q6]

## 8. Reproduction evidence

### SQL source

All queries below were executed against:

```text
file:D:/QM/strategy_farm/state/backups/farm_state_before_xti_cohort_block_20260812T164553Z.sqlite?mode=ro&immutable=1
```

### SQL Q1 — distinct survivor selection and metrics

```sql
WITH q10 AS (
  SELECT w.*,
         ROW_NUMBER() OVER (
           PARTITION BY ea_id, symbol
           ORDER BY updated_at DESC, id DESC
         ) AS rn,
         COUNT(*) OVER (PARTITION BY ea_id, symbol) AS pass_rows
  FROM work_items AS w
  WHERE phase = 'Q10' AND status = 'done' AND verdict = 'PASS'
)
SELECT q.ea_id, q.symbol, q.id AS work_item_id, q.pass_rows,
       q.setfile_path, q.evidence_path, q.updated_at,
       m.profit_factor, m.trades, m.drawdown_pct,
       m.status AS metric_status, m.verdict AS metric_verdict, m.source AS metric_source
FROM q10 AS q
LEFT JOIN ea_metrics AS m ON m.work_item_id = q.id
WHERE q.rn = 1
ORDER BY CAST(REPLACE(q.ea_id, 'QM5_', '') AS INTEGER), q.symbol;
```

### SQL Q2 — symbol concentration

```sql
WITH q10 AS (
  SELECT ea_id, symbol,
         ROW_NUMBER() OVER (
           PARTITION BY ea_id, symbol ORDER BY updated_at DESC, id DESC
         ) AS rn
  FROM work_items
  WHERE phase = 'Q10' AND status = 'done' AND verdict = 'PASS'
)
SELECT REPLACE(symbol, '.DWX', '') AS symbol,
       COUNT(*) AS sleeves,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM q10
WHERE rn = 1
GROUP BY symbol
ORDER BY sleeves DESC, symbol;
```

### SQL Q3 — family concentration

```sql
WITH q10 AS (
  SELECT ea_id, symbol,
         ROW_NUMBER() OVER (
           PARTITION BY ea_id, symbol ORDER BY updated_at DESC, id DESC
         ) AS rn
  FROM work_items
  WHERE phase = 'Q10' AND status = 'done' AND verdict = 'PASS'
), family(ea_id, economic_family) AS (
  VALUES
    ('QM5_1328','MR'),('QM5_1556','TC'),('QM5_1567','MR'),
    ('QM5_10123','TC'),('QM5_10128','TC'),('QM5_10142','MR'),
    ('QM5_10145','TC'),('QM5_10183','TC'),('QM5_10403','TC'),
    ('QM5_10513','TC'),('QM5_10692','MR'),('QM5_10706','CS'),
    ('QM5_10911','TC'),('QM5_10919','MR'),('QM5_10938','TC'),
    ('QM5_10939','TC'),('QM5_11132','MR'),('QM5_11165','MR'),
    ('QM5_11421','MR'),('QM5_11422','TC'),('QM5_11708','MR'),
    ('QM5_12567','MR'),('QM5_12778','SA'),('QM5_12969','CS'),
    ('QM5_12989','TC'),('QM5_13013','TC'),('QM5_13036','CS'),
    ('QM5_13117','SA'),('QM5_13128','CS'),('QM5_13213','CS'),
    ('QM5_13301','CS'),('QM5_20048','CS')
)
SELECT f.economic_family, COUNT(*) AS sleeves,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM q10 AS q JOIN family AS f USING (ea_id)
WHERE q.rn = 1
GROUP BY f.economic_family
ORDER BY sleeves DESC;
```

### SQL Q4 — cohort size and repeated Q10 PASS rows

```sql
SELECT COUNT(*) AS pass_rows,
       COUNT(DISTINCT ea_id || '|' || symbol) AS sleeves,
       COUNT(DISTINCT ea_id) AS eas,
       COUNT(DISTINCT symbol) AS symbols
FROM work_items
WHERE phase = 'Q10' AND status = 'done' AND verdict = 'PASS';

SELECT ea_id, symbol, COUNT(*) AS pass_rows
FROM work_items
WHERE phase = 'Q10' AND status = 'done' AND verdict = 'PASS'
GROUP BY ea_id, symbol
HAVING COUNT(*) > 1
ORDER BY pass_rows DESC, ea_id, symbol;
```

### SQL Q5 — dated roster reconciliation

The `roster` VALUES are a direct transcription of R1-R24 filenames; `has_rows=0`
denotes the header-only R24 file.

```sql
WITH q10 AS (
  SELECT ea_id, symbol,
         ROW_NUMBER() OVER (
           PARTITION BY ea_id, symbol ORDER BY updated_at DESC, id DESC
         ) AS rn
  FROM work_items
  WHERE phase = 'Q10' AND status = 'done' AND verdict = 'PASS'
), roster(ea_id, symbol, has_rows) AS (
  VALUES
    ('QM5_10403','XAUUSD.DWX',1),('QM5_10513','XAUUSD.DWX',1),
    ('QM5_10706','GBPUSD.DWX',1),('QM5_10911','GDAXI.DWX',1),
    ('QM5_10919','XTIUSD.DWX',1),('QM5_10939','GBPUSD.DWX',1),
    ('QM5_11132','SP500.DWX',1),('QM5_11165','AUDCAD.DWX',1),
    ('QM5_11165','EURUSD.DWX',1),('QM5_11421','AUDUSD.DWX',1),
    ('QM5_11421','EURUSD.DWX',1),('QM5_11708','EURUSD.DWX',1),
    ('QM5_12567','XAUUSD.DWX',1),('QM5_12778','AUDUSD.DWX',1),
    ('QM5_12969','USDJPY.DWX',1),('QM5_12989','XAUUSD.DWX',1),
    ('QM5_13117','EURGBP.DWX',1),('QM5_13128','NDX.DWX',1),
    ('QM5_13213','USDJPY.DWX',1),('QM5_13301','GDAXI.DWX',1),
    ('QM5_1556','XAUUSD.DWX',1),('QM5_1567','EURUSD.DWX',1),
    ('QM5_12567','XNGUSD.DWX',1),('QM5_10440','NDX.DWX',0)
)
SELECT (SELECT COUNT(*) FROM q10 WHERE rn=1) AS q10_sleeves,
       (SELECT COUNT(*) FROM roster) AS roster_entries,
       (SELECT SUM(has_rows) FROM roster) AS nonempty_roster_entries,
       (SELECT COUNT(*) FROM roster r JOIN q10 q USING(ea_id,symbol)
         WHERE q.rn=1) AS q10_roster_overlap,
       (SELECT COUNT(*) FROM roster r LEFT JOIN q10 q
          ON q.ea_id=r.ea_id AND q.symbol=r.symbol AND q.rn=1
         WHERE q.ea_id IS NULL) AS roster_not_q10_pass;
```

### SQL Q6 — formal qualifications

```sql
SELECT COUNT(*) AS qualification_rows FROM candidate_qualifications;
```

### SQL Q7 — roster-only gate history

```sql
WITH target(ea_id, symbol) AS (
  VALUES ('QM5_10440','NDX.DWX'), ('QM5_12567','XNGUSD.DWX')
), ranked AS (
  SELECT w.*,
         ROW_NUMBER() OVER (
           PARTITION BY w.ea_id, w.symbol, w.phase
           ORDER BY w.updated_at DESC, w.id DESC
         ) AS rn
  FROM work_items AS w JOIN target AS t USING (ea_id, symbol)
  WHERE w.phase IN ('Q08','Q09_PORTFOLIO','Q09_NEWS','Q10')
)
SELECT ea_id, symbol, phase, status, verdict, id, updated_at, evidence_path
FROM ranked
WHERE rn=1
ORDER BY ea_id, phase;

WITH target(ea_id, symbol) AS (
  VALUES ('QM5_10440','NDX.DWX'), ('QM5_12567','XNGUSD.DWX')
)
SELECT t.ea_id, t.symbol,
       SUM(CASE WHEN w.phase='Q10' AND w.status='done' AND w.verdict='PASS'
                THEN 1 ELSE 0 END) AS q10_pass_rows
FROM target AS t
LEFT JOIN work_items AS w USING (ea_id, symbol)
GROUP BY t.ea_id, t.symbol;
```

### C1 — daily-return correlation calculation

For every non-empty R-file, parse `date` and
`daily_return_eur_at_RISK_FIXED_1000`; inner-join each pair on `date`; calculate:

```text
r = sum((x-mean(x))*(y-mean(y))) /
    sqrt(sum((x-mean(x))^2) * sum((y-mean(y))^2))
```

Zero-return days remain in the series. Pairwise common observation count is the number
of joined dates. Active-day Jaccard is `|nonzero(x) intersect nonzero(y)| / |union|`.

### R1-R24 — dated roster inputs

R1-R23 contain a header at line 1 and **2,348** daily rows at lines **2-2349**. R24 is
header-only at line 1.

- R1 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10403_XAUUSD_104030002_daily_returns.csv:1-2349`
- R2 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10513_XAUUSD_105130003_daily_returns.csv:1-2349`
- R3 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10706_GBPUSD_107060001_daily_returns.csv:1-2349`
- R4 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10911_GDAXI_109110003_daily_returns.csv:1-2349`
- R5 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10919_XTIUSD_109190001_daily_returns.csv:1-2349`
- R6 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10939_GBPUSD_109390001_daily_returns.csv:1-2349`
- R7 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_11132_SP500_111320000_daily_returns.csv:1-2349`
- R8 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_11165_AUDCAD_111650002_daily_returns.csv:1-2349`
- R9 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_11165_EURUSD_111650000_daily_returns.csv:1-2349`
- R10 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_11421_AUDUSD_114210003_daily_returns.csv:1-2349`
- R11 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_11421_EURUSD_114210000_daily_returns.csv:1-2349`
- R12 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_11708_EURUSD_117080000_daily_returns.csv:1-2349`
- R13 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_12567_XAUUSD_125670003_daily_returns.csv:1-2349`
- R14 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_12778_AUDUSD_127780000_daily_returns.csv:1-2349`
- R15 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_12969_USDJPY_129690000_daily_returns.csv:1-2349`
- R16 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_12989_XAUUSD_129890003_daily_returns.csv:1-2349`
- R17 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_13117_EURGBP_131170000_daily_returns.csv:1-2349`
- R18 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_13128_NDX_131280000_daily_returns.csv:1-2349`
- R19 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_13213_USDJPY_132130000_daily_returns.csv:1-2349`
- R20 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_13301_GDAXI_133010010_daily_returns.csv:1-2349`
- R21 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_12567_XNGUSD_125670002_daily_returns.csv:1-2349`
- R22 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_1556_XAUUSD_15560004_daily_returns.csv:1-2349`
- R23 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_1567_EURUSD_15670007_daily_returns.csv:1-2349`
- R24 `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/QM5_10440_NDX_104400003_daily_returns.csv:1`

### F1-F32 — family provenance

- F1 `C:/QM/repo/framework/EAs/QM5_1328_brooks-3bar-reversal-h4/SPEC.md:11-13`
- F2 `C:/QM/repo/framework/EAs/QM5_1556_aa-zak-mom12/SPEC.md:11-13`
- F3 `C:/QM/repo/framework/EAs/QM5_1567_demark-td-reverse-sequential-h4/QM5_1567_demark-td-reverse-sequential-h4.mq5:3`; `C:/QM/repo/framework/EAs/QM5_1567_demark-td-reverse-sequential-h4/QM5_1567_demark-td-reverse-sequential-h4.mq5:67-76`; `C:/QM/repo/framework/EAs/QM5_1567_demark-td-reverse-sequential-h4/QM5_1567_demark-td-reverse-sequential-h4.mq5:157-170` (SPEC absent)
- F4 `C:/QM/repo/framework/EAs/QM5_10123_don20-break/SPEC.md:11-13`
- F5 `C:/QM/repo/framework/EAs/QM5_10128_bb-breakout/SPEC.md:11-13`
- F6 `C:/QM/repo/framework/EAs/QM5_10142_rsi2-sma/SPEC.md:11-13`
- F7 `C:/QM/repo/framework/EAs/QM5_10145_tsm-meanret/SPEC.md:11-13`
- F8 `C:/QM/repo/framework/EAs/QM5_10183_carver-multi-sig/QM5_10183_carver-multi-sig.mq5:85-99`; `C:/QM/repo/framework/EAs/QM5_10183_carver-multi-sig/QM5_10183_carver-multi-sig.mq5:169-203`
- F9 `C:/QM/repo/framework/EAs/QM5_10403_et-turtle20x/SPEC.md:11-13`
- F10 `C:/QM/repo/framework/EAs/QM5_10513_mql5-ichimoku/SPEC.md:11-13`
- F11 `C:/QM/repo/framework/EAs/QM5_10692_tv-ls-ms/SPEC.md:11-13`
- F12 `C:/QM/repo/framework/EAs/QM5_10706_tv-mon-ls/SPEC.md:11-27`
- F13 `C:/QM/repo/framework/EAs/QM5_10911_grimes-complex-pb/SPEC.md:11-13`
- F14 `C:/QM/repo/framework/EAs/QM5_10919_grimes-overshoot/SPEC.md:11-13`
- F15 `C:/QM/repo/framework/EAs/QM5_10938_grimes-accept-high/SPEC.md:11-13`
- F16 `C:/QM/repo/framework/EAs/QM5_10939_grimes-context-pb/SPEC.md:11-13`
- F17 `C:/QM/repo/framework/EAs/QM5_11132_tm-cum-rsi2/SPEC.md:11-28`
- F18 `C:/QM/repo/framework/EAs/QM5_11165_weiss-rsi-ma/SPEC.md:11-28`
- F19 `C:/QM/repo/framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/SPEC.md:11-13`
- F20 `C:/QM/repo/framework/EAs/QM5_11422_williams-18ma-outside-bar-entry-d1/SPEC.md:11-13`
- F21 `C:/QM/repo/framework/EAs/QM5_11708_anon-market-squeeze-d1/SPEC.md:11-13`
- F22 `C:/QM/repo/framework/EAs/QM5_12567_cum-rsi2-commodity/SPEC.md:24-35`
- F23 `C:/QM/repo/framework/EAs/QM5_12778_edgelab-audusd-eurjpy-cointegration/SPEC.md:11-20`
- F24 `C:/QM/repo/framework/EAs/QM5_12969_usdjpy-gotobi-nakane-fix/SPEC.md:11-15`; `C:/QM/repo/framework/EAs/QM5_12969_usdjpy-gotobi-nakane-fix/SPEC.md:25-29`
- F25 `C:/QM/repo/framework/EAs/QM5_12989_grimes-nested-pb-v2/SPEC.md:11-13`
- F26 `C:/QM/repo/framework/EAs/QM5_13013_grimes-trendday-v2/SPEC.md:11-13`
- F27 `C:/QM/repo/framework/EAs/QM5_13036_balke-go-long-regime/QM5_13036_balke-go-long-regime.mq5:3`; `C:/QM/repo/framework/EAs/QM5_13036_balke-go-long-regime/QM5_13036_balke-go-long-regime.mq5:152-215`
- F28 `C:/QM/repo/framework/EAs/QM5_13117_eurgbp-audjpy/SPEC.md:9-20`; `:26-32`
- F29 `C:/QM/repo/framework/EAs/QM5_13128_pre-fomc-drift-ndx/SPEC.md:11-20`
- F30 `C:/QM/repo/framework/EAs/QM5_13213_balke-gmt3-range-breakout/SPEC.md:12-28`
- F31 `C:/QM/repo/framework/EAs/QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.mq5:3`; `C:/QM/repo/framework/EAs/QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.mq5:76-104` (SPEC absent)
- F32 `C:/QM/repo/framework/EAs/QM5_20048_wti-preholiday/SPEC.md:5-20`

## 9. Limitations

- The immutable backup is a point-in-time source and deliberately excludes any later
  live-database changes.
- The roster is a dated portfolio-analysis directory, not a deployment manifest.
- C1 uses full-period daily returns and fixed-risk series; it does not implement the
  regime split, capped inverse-vol portfolio recomputation, delta Sharpe, delta MaxDD,
  delta worst-day, bootstrap, or ops-cost tests required for an admission recommendation.
- PF/trades/DD are pipeline evidence only because they are read from `ea_metrics` joined
  to completed Q10 PASS work items. No new pipeline verdict is inferred.
- Missing SPEC files for QM5_1567 and QM5_13301 should be repaired as documentation work
  through the deterministic router; this report does not create untracked work.
