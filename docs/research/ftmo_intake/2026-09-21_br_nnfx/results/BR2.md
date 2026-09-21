# BR2 — London handoff range break and bounded retest

Programme: `FTMO_BR_NNFX_20260921`

Router task: `2eba7ef7-ba70-4d0e-b9f2-94c5ea54efa2`

Packet: `BR2`, priority 78

Disposition: `UNKNOWN_PENDING_ACCEPTED_HARNESS_V2`

## Decision

The six-cell BR2 specification, semantic deduplication, current input snapshot, existing F2
prescreen, and joint-USD exposure are reconciled here. The governed BR2 verdict remains
**UNKNOWN**. Dependency `7088da77-9e03-45cf-a568-581863f03ef1` is still IN_PROGRESS, so the
required accepted v2 placement/fill harness and trade-by-trade MT5 golden test do not yet
exist. The existing run used the older F2 conservative closed-bar engine and was committed
after outcomes without a pre-run input hash seal. It cannot satisfy this packet's acceptance
contract or be relabeled as a v2 prescreen.

For context only, none of the six F2 cells passed selection and none survived validation.
Three were labeled `CLEAR_REJECT` and three `UNKNOWN` by that engine. All six selection
samples missed both the 300-trade minimum and the 0.40-trades/business-day density floor;
selection expectancy was negative in every cell. The positive 18-trade EURUSD compressed
validation result is post-selection noise, not a survivor. These observations justify **no
promotion and no follow-on task**, but they do not authorize a final v2 verdict.

No Strategy Card, EA, registry/factory row, Q-gate row, incumbent weight, live/demo
configuration, or terminal state was created or changed.

Counts:

- Exact duplicates closed: **0**.
- Semantic neighbours explicitly compared: **8** (seven existing EA specifications and
  approved task `2caa90f8-fb99-4545-b650-668feeb453a8`).
- Frozen BR2 cells: **6** (3 symbols x compressed/unfiltered arms).
- Existing F2 selection passes: **0 / 6**.
- Existing F2 validation survivors: **0 / 6**.
- Governed survivors: **0 / 6**.
- Acceptance gaps retained: **3** (accepted v2/golden harness, pre-outcome input seal, and
  news-calendar time correction/audit).

## Frozen specification

The governing source is `PLAN.md`; nothing here changes its mechanics.

- Symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX` on M5.
- Range: 00:00–07:00 `Europe/London`, built only from completed M5 bars and then frozen.
- Entry window: 08:00–10:30 London; all positions flat at 12:00 London.
- Breakout: first close beyond the frozen range by 0.10 x ATR(14), with the prior close still
  inside. ATR is frozen at breakout.
- Retest: a later M5 bar, within six bars, touches from -0.25 to +0.10 ATR around the broken
  level and closes back in the breakout direction. A wrong-side close beyond 0.25 ATR cancels.
- Entry: next available M5 open; cancel if more than 0.50 ATR past the retest close or already
  through the stop. Only the first breakout is eligible; no same-day re-arm.
- Stop: retest extreme plus/minus 0.10 ATR, widened to at least 0.50 ATR; skip above 1.50 ATR.
- Target: 1.5R from actual fill. First completed close back through the broken level exits at
  the next open.
- `retest_compressed`: current overnight range is no greater than the median of the preceding
  20 complete, identically defined London ranges. The current day is excluded.
- `retest_any`: identical control with only the compression predicate removed.
- One entry per symbol/day; `PRE30_POST30` high-impact relevant-currency news blackout; causal
  London timezone conversion; fixed 1,000 USD prescreen risk, never a live sizing instruction.
- Selection: 2018-07-02..2022-12-31. Reused validation: 2023-01-01..2025-12-31.
- Six cells are the complete BR2 grid; no parameter, arm, or symbol search is permitted after
  reading outcomes.

Selection requires at least 300 trades, E[R] >= 0.08, PF >= 1.15, worst-year DD <= 20R,
density >= 0.40 trades/business-day, and the family Bonferroni bar 0.00313. Validation requires
E[R] > 0, PF >= 1.05, worst-year DD <= 25R, and R/business-day at least half of selection.

## Semantic deduplication

| Neighbour | Existing mechanic | Specific BR2 difference | Disposition |
|---|---|---|---|
| `QM5_9987` | M15 session break, return inside, then boundary retest; reversal entry | BR2 is M5 continuation after an accepted break of a causally DST-resolved 00:00–07:00 London range, with compression/control arms | Semantic neighbour, not exact duplicate; all three relevant-symbol Q02 results are FAIL; spec SHA-256 `234ce3b7952d67cbac08fd032cbfc620621c6f51c2dbca421c700c321f603bdd` |
| `QM5_9725` | M5 counter-trendline retest with EMA8/SMA200/RSI filters | No frozen session range, London handoff, or compression pair in the existing rule | Semantic neighbour, not duplicate; EURUSD/GBPUSD Q02 FAIL and NDX Q04 FAIL; spec SHA-256 `18e2d8a73a30d3c4a8c10f8e093159d9bcf2a2b3b7c6334d2211ca8ccf41768e` |
| `QM5_13213` | H1 OCO breakout of 03:00–06:00 GMT+3, opposite-range stop, no retest, flat 18:00 | BR2 requires a later bounded M5 retest and causal London range/compression; only USDJPY overlaps | Incumbent/semantic neighbour, not duplicate; spec SHA-256 `dfe0730c8f3f43844b400a011faa6489479eecb11d133a515c3a548ed3ebc436` |
| `QM5_10710` | M15 Asian range (20:00–08:00 exchange/broker), later boundary-retest continuation, 3R, 48-bar cap | BR2 uses exact London DST, M5 six-bar state machine, causal compression/control pair, 1.5R, no re-arm, and noon flat | Closest mechanic, but materially different experiment; EURUSD Q02 FAIL, USDJPY Q04 FAIL; spec SHA-256 `27cfcadca01afe4f5b92a0f6f6c62d93ba30fa439717bf832acaf12532777bfd` |
| `QM5_10715` | M15 Asian-box OCO stop breakout | Immediate stop-entry breakout with no retest/compression is not BR2 | Semantic neighbour, not duplicate; downstream USDJPY evidence includes Q08 failure; spec SHA-256 `69f3640729f704c3278ed3ac39490aecb7d7a362460a61a613f4608585f7c205` |
| `QM5_10707` | M15 Asian-range sweep/reclaim mean reversion | Trades the opposite mechanism/sign and has no compression pair | Semantic neighbour, not duplicate; EURUSD/GBPUSD/USDJPY Q02 FAIL; spec SHA-256 `4a132ee62457ea3c3d498bc379c449150f327aa7d890314c5ac04b398c703117` |
| `QM5_10092` | M5 Asian-range wick sweep and reversal | Reversal after a sweep is not BR2's accepted-break continuation and bounded retest | Semantic neighbour, not duplicate; existing Q02 failures remain inherited context |
| Approved `2caa90f8-fb99-4545-b650-668feeb453a8`, H-AG10 | EURUSD New York-session EMA pullback, 10:15–12:30 ET | Different anchor, state machine, and session; not a frozen London-range handoff | Separate experiment; approved artifact SHA-256 `b290921c7c80efec33cc26f472b4451d9d45b9ae42db88851f3209dff3e56a37` |

The exact-difference conclusion is bounded to the current registry, code/specs, work-item
inventory, Track-B programme, and approved `2caa90f8` artifact. It is not a claim that every
external strategy ever published was searched.

## Existing F2 result — non-acceptance context only

Source result: `velocity_family_f3_break_retest_0921.json`, commit `dcebcd2245`. The engine
identifies itself as `velocity_family_f2_cash_session_0921.py (conservative closed-bar fills)`.
It is **not** the accepted v2/golden-tested harness required by this packet.

| Cell | F2 state | SEL n | SEL E[R] | SEL PF | worst-year DD R | trades/bd | median cost R | VAL n | VAL E[R] | VAL PF |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| EURUSD any | CLEAR_REJECT | 68 | -0.0948 | 0.849 | 8.42 | 0.0579 | 0.0864 | 34 | 0.0115 | 1.020 |
| EURUSD compressed | UNKNOWN | 36 | -0.1007 | 0.841 | 4.78 | 0.0306 | 0.0912 | 18 | 0.2052 | 1.429 |
| GBPUSD any | CLEAR_REJECT | 127 | -0.4602 | 0.435 | 22.13 | 0.1081 | 0.0790 | 50 | -0.3423 | 0.544 |
| GBPUSD compressed | CLEAR_REJECT | 67 | -0.5523 | 0.361 | 15.66 | 0.0570 | 0.0794 | 23 | -0.3982 | 0.495 |
| USDJPY any | UNKNOWN | 38 | -0.3205 | 0.571 | 13.12 | 0.0323 | 0.0843 | 65 | -0.1990 | 0.705 |
| USDJPY compressed | UNKNOWN | 16 | -0.1628 | 0.760 | 3.93 | 0.0136 | 0.0844 | 36 | -0.3606 | 0.529 |

The principal state-machine counts further explain the sparse samples:

| Cell | invalidated | retest expired | stop too tight | not compressed |
|---|---:|---:|---:|---:|
| EURUSD any | 580 | 434 | 172 | n/a |
| EURUSD compressed | 336 | 251 | 124 | 888 |
| GBPUSD any | 554 | 464 | 168 | n/a |
| GBPUSD compressed | 306 | 284 | 97 | 891 |
| USDJPY any | 406 | 339 | 141 | n/a |
| USDJPY compressed | 249 | 187 | 96 | 886 |

Every selection expectancy was negative. Compression reduced already-thin opportunity counts
without changing that sign. EURUSD compressed's positive validation expectancy is based on
only 18 trades after a failed selection cell; it is neither a pass nor a basis for a new arm.
The figures are historical diagnostic outputs only. They are not MT5 Every-Real-Tick proof,
not `ECONOMICALLY_VALIDATED`, and not accepted v2 states. A future valid rerun may emit only
`CLEAR_REJECT`, `WORTH_MT5_TEST`, or `UNKNOWN`; only a `WORTH_MT5_TEST` survivor may proceed to
independent critique and governed MT5 canary.

## Joint USD exposure

All three candidate symbols carry USD factor exposure, even though their quote conventions
differ:

| Candidate trade | USD factor sign when long | USD factor sign when short | Concurrent prescreen cap |
|---|---|---|---:|
| EURUSD | short USD | long USD | 1R = 1,000 USD |
| GBPUSD | short USD | long USD | 1R = 1,000 USD |
| USDJPY | long USD | short USD | 1R = 1,000 USD |

With one trade per symbol/day, BR2 can carry **3R / 3,000 USD gross candidate risk**
concurrently in this research normalization. Same-direction pair signals do not imply the same
USD factor direction: long EURUSD + long GBPUSD + short USDJPY is three short-USD legs, while
long EURUSD + long GBPUSD + long USDJPY is two short-USD legs against one long-USD leg. Gross
risk remains 3R in both examples; net USD sensitivity cannot be reduced to risk dollars
without causal position sizes and USD notionals.

The time window can overlap an open `QM5_13213` USDJPY position, and the current book also has
GBPUSD/USDCAD USD-factor sleeves. No empirical calendar-aligned correlation or joint drawdown
was produced by the old F2 JSON, so independence is **UNKNOWN**, not assumed. The 1,000 USD
prescreen normalization is not a proposed portfolio allocation and must not be added directly
to incumbent percentage-risk budgets. If any cell becomes a valid v2 survivor, its critique
must bind a proposed fixed risk, reconstruct simultaneous open equity against `QM5_13213` and
the USD sleeves, report gross/net USD notional by timestamp, and test <=5% daily and <=10%
total FTMO drawdown constraints before any portfolio admission.

## Input, cost, and code bindings

The F2 output did not embed pre-run HCC hashes. The hashes below bind the files visible at this
review and prepare a deterministic future rerun; they do **not** retroactively prove that the
same bytes produced commit `dcebcd2245`. The manifest digest is SHA-256 over the 24 following
UTF-8 lines, in displayed order, each terminated by LF:
`symbol,year,bytes,sha256,path`.

`BR2_CURRENT_HCC_MANIFEST_SHA256 = 5d669d859b39dc91fd00ba6bee0d84cec6574a9e4c7907f7ab28533d6cba06b5`

```text
EURUSD.DWX,2018,22287924,d70cb41f0a6aa756b0e13258908563c294504b24a34d3c712b8df56f9cc895b6,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2018.hcc
EURUSD.DWX,2019,22231824,f0aa5d4e6eec1d91eb27cee31796eaa7571338b4784a5d07a69c77a033d8073b,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2019.hcc
EURUSD.DWX,2020,22325013,b1751920c5cf45502bce5a1324f13dc1e60f94f4d13c1fc24b05c738ff92a876,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2020.hcc
EURUSD.DWX,2021,22180884,a7666e219f12aa238a7e212741e4e7f138db527df4f61e99eaa1154499792411,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2021.hcc
EURUSD.DWX,2022,22249104,d750af3ea9d20552453d4d8a9724b139c98fab9babc5e285f6ff03b8d9834eb5,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2022.hcc
EURUSD.DWX,2023,21812577,5e26c6f672aa1531312dac9becc6e93d9577287062e43805c7b662c95c6a5c3b,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2023.hcc
EURUSD.DWX,2024,22288473,5ff6126b9ed5e12e6a9f0dcbf2ab7ffbcfe3b2c6c7e80d4db261c026e0425be0,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2024.hcc
EURUSD.DWX,2025,20571204,c5c806d345d65e1b1c8cbc4230b0e00a7a85f4b46f208b907b07f40a1c462ae4,D:/QM/mt5/T2/Bases/Custom/history/EURUSD.DWX/2025.hcc
GBPUSD.DWX,2018,22314204,dbe90a49e66bd59bae0e7cc5aef9bbbbab7cf86d72399f659aec5dae0a15f67e,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2018.hcc
GBPUSD.DWX,2019,22280544,24ff51ad8ffaaf8c56b0773f7935cf9dfa33d840e1f5c33c1460c0eb059466d0,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2019.hcc
GBPUSD.DWX,2020,22330713,b77d9d213dcc217eda1ac185def537619bc144d8d8ac26a268893fd7dae112dd,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2020.hcc
GBPUSD.DWX,2021,22169304,f03910e21866a660450602ea6b87070e544246a8205769ccc70bacaf13cb37b7,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2021.hcc
GBPUSD.DWX,2022,22165284,f6e8db790bdaf282f90708a029dd524094176a7b91f8632d5eaf569b3bcef39b,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2022.hcc
GBPUSD.DWX,2023,21853557,80180c516253ea52ab0c95a0381a71282254b903b4d54ced4a512345114bad76,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2023.hcc
GBPUSD.DWX,2024,22322604,8b4d14fefdb7fdf93574ce589f808df54747cc7e0a2f57fc19ca2bac64afb574,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2024.hcc
GBPUSD.DWX,2025,20656842,a076b99cda7f07ec2140664f134c5514ec95737b566dc0bd30ed055d00d0c181,D:/QM/mt5/T2/Bases/Custom/history/GBPUSD.DWX/2025.hcc
USDJPY.DWX,2018,22308504,f344d81fc87b702df12e55518cfd543879d1f47ed4d5ad35d5110c1ad68bbdab,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2018.hcc
USDJPY.DWX,2019,22247775,2bd22d821022a82accd5e4b7b752a30a40e4ee3c2f4bdea14527fd008c9655af,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2019.hcc
USDJPY.DWX,2020,22318584,1d3a766e8ddca4bbad8e4102a936de68aff62fd840ae93926f222aee6c824a0e,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2020.hcc
USDJPY.DWX,2021,22272444,cde04ee4d1a8895bf06b6e39e7d807df145308b6380b17b2a2061245d186ad37,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2021.hcc
USDJPY.DWX,2022,22250004,65088758b20a71ec640b5f2d29ee5f10d1ee52435a816e82327bba3bbe000a2a,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2022.hcc
USDJPY.DWX,2023,21854757,dc5c19bd7bf1dde208b988b20f09a72ec62ca4fe875cb3d7b29a28303ce9d56a,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2023.hcc
USDJPY.DWX,2024,22256124,5bc2ebded2722bd559e674fe237ad2c15a0420ef8839d6674d138c0630fc1a39,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2024.hcc
USDJPY.DWX,2025,20681142,9a085d00e7abd50f909e75f11da0f0d324d5d034c787af1f4a3e755c988e8c4d,D:/QM/mt5/T2/Bases/Custom/history/USDJPY.DWX/2025.hcc
```

The three BR2 cost-prior lines are also hashed exactly as displayed, UTF-8/LF:

```text
EURUSD.DWX,0.0001,0.00005,0.00001,prior: 1.0 pip RT
GBPUSD.DWX,0.00012,0.00006,0.00001,prior: 1.2 pip RT
USDJPY.DWX,0.01,0.005,0.001,prior: 1.0 pip RT
```

`BR2_F2_COST_MANIFEST_SHA256 = e75ddd1d1d6ac7669e1728b75fcb510d53364a94efac56a50cf8822e09848877`

These are priors, not measured per-trade FTMO fills. Venue task
`73434cab-cf1c-4c17-8a11-9ca52c11d99e` is APPROVED with
`ABSTAIN_NO_ELIGIBLE_VENUE_DELTA`; it does not convert these priors into measured venue truth.

| Bound artifact | SHA-256 |
|---|---|
| Frozen `PLAN.md` | `e42d8770df11fcbbca9e5560a1280c352145b09d7cd1e2b30135d4bff1a9b57b` |
| Inventory | `76723f335a9b55c5a11fe4328c179048552e53321dfefa8d1e4ac94bca4fb226` |
| Sources manifest | `9ed8295104853d2f4490089b1f4b7b2ebfc8da6e06fa8ad7978dd17b782354ba` |
| OWNER decision | `d9f785f6098ed90a0a0dfb9a6a6c1096dca38b031e807c66faaa63b31139d7e8` |
| F2 result JSON | `cf033bd761b431e033fbc24bfea67067e63d52d7e5a9e501cf8bb5c6dcb5294b` |
| F1 shared module | `3f459b170c64ba69a9b6147d2e123173f197a81c8970b09ecb7916b5884f826d` |
| F2 shared module | `814b6f20b8bb366e0047bd0f2bea156f41dbf13a219c6ae92f7649c78eff47e8` |
| BR1/2/3 runner | `5c4ebc9f49776568c683d961724d1b73132fc8a0c949097efe1b266c173754e9` |
| HCC reader | `85a486767fafe0dfe4a3e1b4b177b2ca2f6939d3271a0a7abd4b1f8be1e14145` |
| News archive consumed by F2 | `dc96c059f64f609f71a911f2f4d01f00f56b2a7c335a13238258490f34f736ee` |
| Track-B programme | `ab22cb01ed3240fe2a6198294004ea18d9e5ecdeaf9e9e75b8f1350fe41b1228` |
| `FTMO_BOOK_CURRENT.md` | `60a0d4a14a959944054acee487fc4bac74543e6014b3050b368dc04fd1e82828` |
| FTMO KPI artifact | `7915f016a7b6c713edf63c479ce31fa5af6b5e9e4ce4011d7d2c5b703351c1b5` |
| Approved `2caa90f8` artifact | `b290921c7c80efec33cc26f472b4451d9d45b9ae42db88851f3209dff3e56a37` |

## Unresolved acceptance chain

1. Task `7088da77-9e03-45cf-a568-581863f03ef1` must reach accepted REVIEW with the v2
   placement/fill module and trade-by-trade MT5 golden evidence. Aggregate PF similarity is
   insufficient.
2. Task `a36a5983-8cfc-4528-8277-8b5d21787f82` must bind a versioned correction proposal for
   the sealed news archive. The current F2 run consumed hash `dc96...`, whose one-hour-offset
   allegation is still under audit; its blackout decisions cannot be silently rewritten.
3. Before any rerun, the exact v2 code, all HCC inputs, corrected sealed news manifest, cost
   inputs, six-cell grid, and SEL/VAL boundaries must be written into the output. The current
   post-hoc HCC manifest is preparation, not a substitute for that pre-outcome seal.
4. Only after those conditions may the fixed six cells be rerun. Failed cells and comparisons
   remain in the ledger. A survivor must first be `WORTH_MT5_TEST`, then undergo independent
   critique, joint USD/open-equity analysis, and governed Every-Real-Tick canary before any
   economic claim.

Until then, `UNKNOWN_PENDING_ACCEPTED_HARNESS_V2` is the only governed BR2 disposition. The
old F2 result is retained without overwrite, and no untracked follow-on work is invented.
