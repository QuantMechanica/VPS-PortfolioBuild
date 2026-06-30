# DXZ / FTMO Book Sizing at the Real 0.75 %/Trade Basis — 2026-06-30

**Status:** EVIDENCE / DECISION INPUT
**Author:** Claude
**Trigger:** OWNER asked whether we should scale up the DarwinexZero account, and corrected
the risk basis ("we run DWX at 0.75 % per trade"). That correction flipped the conclusion.

---

## TL;DR

- The **live DXZ book = 13 sleeves, each running INDEPENDENTLY at a flat `RISK_PERCENT=0.75`**
  (`T_Live\MT5_Base\MQL5\Presets\slot0..12`, `RISK_FIXED=0`). The deployed book is the **SUM**
  of the 13 sleeves, **not** the manifest's risk-parity *weighted average*.
- The portfolio manifest KPI (`manifest_d2c` MaxDD **0.51 %**) is a **weighted-average analysis
  artifact** and does **not** describe the deployment. The real deployed book is far more
  active: **~15.3 %/yr, 17.4 % 8-yr MaxDD, 3.26 % monthly VaR**.
- **DXZ: do NOT scale up.** At 3.26 % raw monthly VaR we are already at 50 % of DXZ's 6.5 %
  target; DXZ's own normalization (~2×) is **well within the 9.75× D-Leverage cap**, so the
  Darwin **already fills the VaR target** and is rated at **~30 %/yr** while our raw account
  carries only 17 % DD. Raising risk to 1.5 %/trade would push raw DD to ~35 % for the **same**
  Darwin rating → pure added risk, no reward. **0.75 % is well chosen.**
- **FTMO: the smooth swing book is a mediocre sprint vehicle** — ~36 % MC pass at 0.75 %/trade
  (optimistic; intraday floating DD not modeled → real ~25–30 %), and **no concentrated
  sub-portfolio from these 13 sleeves beats it** while staying breach-safe. A strong FTMO
  sprinter needs the **higher-frequency intraday edges** (the harvest initiative), not yet in
  the book.

---

## The correction (why earlier numbers were wrong)

An earlier pass used the manifest's risk-parity **weights** (which sum to 1), i.e. a
weighted-average book that splits one account across the sleeves → artificially smooth
(MaxDD 0.51 %, ~0.8 %/yr). That is not how the book trades. The live setfiles run **each**
sleeve at 0.75 % of the **full** equity, so the book is the **sum** of 13 independent sleeves.

### Risk basis (evidence)
- Backtest streams: `RISK_FIXED = $1000` on `initial_deposit 100000` = **1.0 %/trade**
  (`framework/registry/tester_defaults.json`, `fixed_risk.amount`).
- Live: **0.75 %/trade** flat across all 13 slots
  (`T_Live\MT5_Base\MQL5\Presets\slot*.set`, all `RISK_PERCENT=0.7500 RISK_FIXED=0`).
- Conversion: scale each stream by `0.75 / 1.0 = 0.75`, then **sum** all 13.
- Note: SP500 (slot7, 11132) realizes losses ~$2700 ≈ 2.7× nominal risk (overnight gap risk);
  this is already inside the streams.

---

## Real live book (13 sleeves, summed, 0.75 %/trade, net-of-cost, 8.2 yr)

| Metric | Value |
| --- | --- |
| Return | **~15.3 %/yr** ($124,966 on 100k) |
| MaxDD (8 yr) | **17.4 %** |
| Monthly VaR (95 %) | **3.26 %** |
| MaxDD / monthly VaR | 5.3× |

The 13 sleeves: 10440 NDX, 10513 XAU, 10692 NDX, 10715 USDJPY, 10911 GDAXI, 10939 GBPUSD,
10940 XAU, 11132 SP500, 11165 AUDCAD, 11421 AUDUSD, 11421 EURUSD, 12567 XAU, 12567 XNGUSD.

---

## DXZ DarwinIA — do not scale

DXZ normalizes every track to a target VaR (~6.5 % monthly) and rates it there (≈89 % return /
11 % DD weighted). The normalization multiplier is bounded by the **D-Leverage cap** (9.75× for
>60 min holds, 13× / 16× for shorter).

- Raw monthly VaR **3.26 %** → DXZ needs only **2.0×** to reach 6.5 % → **far below the 9.75× cap**.
- ⇒ the Darwin **already fills** the VaR target → rated at **~30 %/yr** (= raw 15 %/yr × 2),
  while our raw account only swings 17 % DD. **DXZ applies the leverage for us.**
- Raising raw risk to 1.5 %/trade (to "fill" the VaR ourselves) yields the **same** Darwin
  rating but ~35 % raw DD. No upside. **Leave 0.75 %.**

(The earlier "scale up to capture ~half the lost return" advice was an artifact of the wrong,
weighted-average VaR of 0.29 %. At the real 3.26 % VaR, the cap is not binding.)

---

## FTMO 2-step — book is a weak sprinter

MC (block-bootstrap, closed-PnL daily approximation; **intraday floating DD invisible → breach
is a lower bound, pass an upper bound**):

| risk %/trade | ~8yr MaxDD | ~ret/yr | pass % | dailyBreach % | maxLossBreach % | days(p50) |
| --- | --- | --- | --- | --- | --- | --- |
| **0.75 (live)** | 17.4 | 15.2 | **35.8** | 0.0 | 3.2 | 63 |
| 1.12 | 26.1 | 22.9 | 51.0 | 6.0 | 12.0 | 44 |
| 1.50 | 34.8 | 30.5 | 56.0 | 15.5 | 18.8 | 35 |
| 2.25 | 52.2 | 45.7 | 39.2 | 41.2 | 19.5 | 20 |

- Best breach-safe (≤5 %) point = the **current 0.75 %/trade (~36 % pass)**. Higher risk lifts
  pass but immediately breaches FTMO's 5 % daily / 10 % static limits.
- The sprint optimizer over all 13 sleeves (singles + ≤3-combos, scales 5–22) found **no
  breach-compliant combo** beating the full book — every high-pass combo (e.g.
  USDJPY+SP500+AUDUSD) is `RISK_TOO_HIGH` (breach 20–38 %). These are **swing edges** without
  the trade frequency to sprint +10 % in 60 days safely.
- ⇒ A real FTMO vehicle needs **higher-frequency intraday edges**. Focus the harvest pipeline
  (intraday/breakout reservoir + new cards QM5_12815/12816) there.

---

## Methodology & caveats
- Streams = Q08 `TRADE_CLOSED` net-of-cost (commission basis `worst_case_dxz_ftmo`).
- Summation uses fixed $750 (0.75 % of static 100k) per trade; true fixed-fractional sizing
  shrinks positions in drawdown, so the 17.4 % MaxDD is a **mild over-estimate**.
- FTMO MC uses closed daily PnL (intraday floating DD not in artifacts) → pass is optimistic.
- DXZ VaR target 6.5 % monthly and D-Leverage caps per
  [[reference_commission_by_asset_class_2026-06-26]] / hot-VaR notes.

## Evidence files
- Tool: `tools/strategy_farm/portfolio/book_sizing.py` (reproduces every number above)
- FTMO sprint optimizer: `D:\QM\strategy_farm\artifacts\portfolio\ftmo_sprint_optimizer_2026-06-30.json`
- Risk basis: `framework/registry/tester_defaults.json`; live setfiles
  `T_Live\MT5_Base\MQL5\Presets\slot0..12_*.set`
- Book composition: `D:\QM\reports\portfolio\manifest_d2c_13sleeve_2026-06-28.json`

## Recommendation
1. **DXZ:** no change — keep 0.75 %/trade; the Darwin already fills the VaR target.
2. **FTMO:** prioritize the **intraday harvest pipeline** (higher-freq edges) so the book gains
   a genuine sprint vehicle; the current swing book passes only ~25–36 %/attempt.

## Action taken (2026-06-30) — intraday FTMO prioritization
The Q02 backtest queue (5467 pending) was **48 % swing (D1/H4), 29 % intraday**. The dispatch
orders by `priority_track` first (`terminal_worker.py::_priority_pending_query`). Set
`"priority_track": true` on the **1307** genuine intraday Q02-pending work_items
(M1 125 / M5 483 / M15 544 / M30 150 + 5 scalper/orb slug-only) so the FTMO-relevant
high-frequency edges drain ahead of the swing backlog.
- Tool (auditable, reversible): `tools/strategy_farm/prioritize_intraday_ftmo.py`
  (`--apply` / `--revert` / dry-run default).
- New cards in flight: **QM5_12815** (stat-mr, M15/H1) + **QM5_12816** (harmonic-cypher, H1/H4)
  queued as `build_ea` (pending). Re-run the tool after new intraday EAs build to capture them.
- Backtests are CPU-bound (~8 terminals); this changes dispatch ORDER, not throughput. The swing
  book is already deployed/working on DXZ, so biasing the next chunk to intraday is aligned.
