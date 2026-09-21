# BR1 — US cash-open first accepted OR retest with peer confirmation

Programme: `FTMO_BR_NNFX_20260921`

Router task: `a42aa6f7-e8b8-4ccf-b9df-833080d94b89`

Packet: `BR1`, priority 79

Disposition: `UNKNOWN_PENDING_ACCEPTED_HARNESS_V2`

## Decision

The six-cell BR1 specification, semantic deduplication, current input snapshot, and the existing
F2 prescreen are reconciled here. The governed BR1 verdict remains **UNKNOWN**. Dependency
`7088da77-9e03-45cf-a568-581863f03ef1` is still IN_PROGRESS, so the required accepted v2
harness and trade-by-trade MT5 golden test do not yet exist. The existing run used the older F2
conservative closed-bar engine and was committed after the outcomes without a pre-run input
hash seal. It therefore cannot satisfy the packet's acceptance contract or be relabeled as a
v2 prescreen.

For context only, all six F2 cells were deeply negative and were labeled `CLEAR_REJECT` by
that engine. None passed selection, none survived validation, and peer confirmation did not
change the sign. Those observations justify **no promotion and no follow-on task**, but they
do not authorize a final v2 verdict. No Strategy Card, EA, registry/factory row, Q-gate row,
incumbent weight, live/demo configuration, or terminal state was created or changed.

Counts:

- Exact duplicates closed: **0**.
- Semantic neighbours explicitly compared: **7** (four existing EA specifications, Track-B
  H-B2/H-B4, and approved task `2caa90f8`'s H-AG1).
- Frozen BR1 cells: **6** (3 symbols x peer/no-peer arms).
- Existing F2 selection passes: **0 / 6**.
- Existing F2 validation survivors: **0 / 6**.
- Acceptance gaps retained: **3** (accepted v2/golden harness, pre-outcome input seal, and
  news-calendar time correction/audit).

## Frozen specification

The governing source is `PLAN.md`; nothing here changes its mechanics.

- Symbols: `NDX.DWX`, `SP500.DWX`, `WS30.DWX`.
- Opening range: 09:30–09:45 `America/New_York`, built only from completed M5 bars.
- Breakout: first close beyond the range by 0.10 x ATR(14), with the prior close not beyond
  that boundary. ATR is frozen at breakout.
- Retest: a later M5 bar, within six bars, touches from -0.25 to +0.10 ATR around the broken
  level and closes back in the breakout direction. Wrong-side close beyond 0.25 ATR cancels.
- Entry: next available M5 open; cancel if more than 0.50 ATR past the retest close or already
  through the stop. No same-session re-arm.
- Stop: retest extreme plus/minus 0.10 ATR, widened to at least 0.50 ATR; skip above 1.50 ATR.
- Target: 1.5R from actual fill. First completed close back through the broken level exits at
  the next open. Flat at 15:45 New York.
- `retest_peer`: SP500 confirms NDX/WS30; NDX confirms SP500. The peer must have a completed
  close outside its own opening range in the same direction by the retest close.
- `retest_nopeer`: identical control with only peer confirmation removed.
- One entry per symbol/session/day; `PRE30_POST30` high-impact USD news blackout; causal New
  York timezone conversion; fixed 1,000 USD prescreen risk, never a live sizing instruction.
- Selection: 2018-07-02..2022-12-31. Reused validation: 2023-01-01..2025-12-31.
- Six cells are the complete BR1 grid; no parameter or symbol search is permitted after reading
  outcomes.

Selection requires at least 300 trades, E[R] >= 0.08, PF >= 1.15, worst-year DD <= 20R,
density >= 0.40 trades/business-day, and the family Bonferroni bar 0.00313. Validation requires
E[R] > 0, PF >= 1.05, worst-year DD <= 25R, and R/business-day at least half of selection.

## Semantic deduplication

| Neighbour | Existing mechanic | Specific BR1 difference | Disposition |
|---|---|---|---|
| `QM5_10181` | 09:30–09:45 M5 OR retest with H1 EMA bias, 70% strong body, 1.2 ATR impulse, structural pivot, 2.5R; primarily XAU | BR1 removes H1/impulse filters, uses the bounded 0.10/0.25 ATR state machine and paired cross-index confirmation on three US indices | Semantic neighbour, not exact duplicate; existing Q02 FAIL remains binding |
| `QM5_10659` | 15-minute OR; breakout immediately places a limit retest at the boundary; six-bar order expiry | BR1 requires a later completed retest bar and next-open market fill; no pending limit; peer/no-peer causal pair | Closest parent, but execution state is materially different; existing Q02 FAIL remains binding |
| `QM5_10668` | M15 OR pullback to VWAP or boundary with EMA(9), chop filter, 1.5R | BR1 is M5 boundary-only and tests peer confirmation; no VWAP/EMA state | Semantic neighbour, not duplicate |
| `QM5_10724` | 30-minute M15 OR, later retest, opposite-OR stop, 20-bar timeout, breakeven rule | BR1 uses 15-minute M5 OR, six-bar timeout, ATR-bounded retest stop, and peer arm | Semantic neighbour, not duplicate |
| Track B `H-B2` | Two directional M15 post-open bars, body >=60%, enter bar 3 | Continuation impulse, not a boundary retest and no peer arm | Separate state machine; its thin-density evidence is inherited as context only |
| Track B `H-B4` | Trend qualifier then pullback to 20-bar M5 SMA, 2R | Mean pullback after 10:30, not a first OR retest and no peer arm | Separate state machine; existing negative result is not rerun |
| Approved `2caa90f8`, H-AG1 | NDX cash-open OR **fade** after rejection, with overnight-gap filter | BR1 trades accepted breakout continuation across three indices | Opposite economic direction; no duplicate task created |

The exact-difference conclusion is bounded to the current registry, code/specs, work-item
inventory, Track-B programme, and approved `2caa90f8` artifact. It is not a claim that every
external strategy ever published was searched.

## Existing F2 result — non-acceptance context only

Source result: `velocity_family_f3_break_retest_0921.json`, commit `dcebcd2245`. The engine
identifies itself as `velocity_family_f2_cash_session_0921.py (conservative closed-bar fills)`.
It is **not** the accepted v2/golden-tested harness required by this packet.

| Cell | F2 state | SEL n | SEL E[R] | SEL PF | worst-year DD R | trades/bd | median cost R | VAL n | VAL E[R] | VAL PF |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| NDX no-peer | CLEAR_REJECT | 210 | -0.6157 | 0.341 | 50.61 | 0.1787 | 0.3507 | 140 | -0.3128 | 0.588 |
| NDX peer | CLEAR_REJECT | 159 | -0.6448 | 0.319 | 36.90 | 0.1353 | 0.3295 | 103 | -0.2528 | 0.652 |
| SP500 no-peer | CLEAR_REJECT | 167 | -1.5763 | 0.059 | 73.07 | 0.1421 | 1.2215 | 140 | -1.2267 | 0.073 |
| SP500 peer | CLEAR_REJECT | 128 | -1.5334 | 0.065 | 47.23 | 0.1089 | 1.1358 | 115 | -1.1484 | 0.084 |
| WS30 no-peer | CLEAR_REJECT | 195 | -2.2229 | 0.027 | 120.61 | 0.1660 | 1.7816 | 152 | -1.5759 | 0.057 |
| WS30 peer | CLEAR_REJECT | 152 | -1.9804 | 0.038 | 83.29 | 0.1294 | 1.5845 | 102 | -1.3771 | 0.075 |

The retest state machine was invalidated on 702–762 sessions and expired on 612–621 sessions
per symbol. Peer confirmation removed another 103–127 opportunities. Every cell missed the
0.40 density floor, every selection expectancy was negative, and the peer controls did not
alter the sign. Index cost priors consumed a median 0.33–1.78R per trade, consistent with the
small M5 structural stops being cost-dominated.

These figures are historical diagnostic outputs only. They are not MT5 Every-Real-Tick proof,
not `ECONOMICALLY_VALIDATED`, and not accepted v2 states. A future valid rerun may emit only
`CLEAR_REJECT`, `WORTH_MT5_TEST`, or `UNKNOWN`; only a `WORTH_MT5_TEST` survivor may proceed to
independent critique and governed MT5 canary.

## Input, cost, and code bindings

The F2 output did not embed pre-run HCC hashes. The hashes below bind the files visible at this
review and prepare a deterministic future rerun; they do **not** retroactively prove that the
same bytes produced commit `dcebcd2245`. The manifest digest is SHA-256 over the 24 following
UTF-8 lines, in displayed order, each terminated by LF:
`symbol,year,bytes,sha256,path`.

`BR1_CURRENT_HCC_MANIFEST_SHA256 = c89278066572b53b9c09c884ebbaf5ec9f17680aabd30b802e3e921bd83636f1`

```text
NDX.DWX,2018,10346034,a07af7bb494f0676a6b2686ae3a272967114340b2027f92f228941518cd81445,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2018.hcc
NDX.DWX,2019,20583666,0242f18c0eb57810fd4c19f35837aa803dc7fdcb1516455c802aaf194f539b26,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2019.hcc
NDX.DWX,2020,20527575,ee07237f074e8e3ff3289b6e5654fbb8542d210d5ae4ab313e310a7a86d6d16b,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2020.hcc
NDX.DWX,2021,20698515,17d585eacc9a935ac91dd72a04d0f02d678802bef4ad0b39173201a7d3c5ab0e,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2021.hcc
NDX.DWX,2022,20630226,1c9fb7975f06e7306b35970f34e097840ccf9255f6048d35ef4dbbed108a1126,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2022.hcc
NDX.DWX,2023,20516637,6e15765b0fbfbe80714a3df7ecaae2d510a4a25a0a7cd8569b35c956ca2781f2,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2023.hcc
NDX.DWX,2024,20600295,5f519e15107a75ff57c68afb9478a5172007a26346982d688d24d4d1d04561af,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2024.hcc
NDX.DWX,2025,20497086,4d0cd4e3cba5e7e3bd262daa0572e08a30436a9c5e6201ff0600e66824c0fce5,D:/QM/mt5/T2/Bases/Custom/history/NDX.DWX/2025.hcc
SP500.DWX,2018,9674754,76c524b42af188ebee41a6a67027d3e664eb8c02dae1723f8c88a68546969bda,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2018.hcc
SP500.DWX,2019,19645557,f58e0f90423a6c15216985f5dc9a34dfa6e9f877957f6c53d26f0c7f105344fd,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2019.hcc
SP500.DWX,2020,20769855,09a0c3a5385b8abdf6339806e115e8d876fe5685613f39156d7e257958396fd5,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2020.hcc
SP500.DWX,2021,21205275,0c4aeb914970c59723bd2e8350cbe3bb360e67685a133333ace0bed444150fb8,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2021.hcc
SP500.DWX,2022,21273606,52777bba1eb541c9f7c8488ebe6c7360bfcb208e81ada3c34812ea546e765d3f,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2022.hcc
SP500.DWX,2023,20549259,bf001b7af6fe74ba1b7e586ae03a22a0888b6351a42ae4684ac142425e71531b,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2023.hcc
SP500.DWX,2024,20870835,9d8680dde4fc4d82b922f4fd09bc94687adc002c45a97c163feb1024381afacf,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2024.hcc
SP500.DWX,2025,20921928,8f81a241a06c64850ad4258834a9a9c5a0fa11c2465c6015e8ccc2316cb6ab77,D:/QM/mt5/T2/Bases/Custom/history/SP500.DWX/2025.hcc
WS30.DWX,2018,10460625,13314703d852e0f90dd3e279e5f3bc81489913304c59c01764b53f3099570237,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2018.hcc
WS30.DWX,2019,20858997,0ee6f8fc721de8176a61a2e2ac8c59a09991c12cd3684a462092d8df47ec57e4,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2019.hcc
WS30.DWX,2020,21023055,08b70450975254dceb67d297e8aae8ec30b23284ef15db60af493c62af8f8c65,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2020.hcc
WS30.DWX,2021,21295155,8bb2962a161d3184a621e7e73b97168fbae1ccd7e23f97077a57f9c44335ba15,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2021.hcc
WS30.DWX,2022,21269046,ca927c8cc8e0ad83a5e2d17fabacfa4e2e8beaaf7a980325d307d31be40dc67a,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2022.hcc
WS30.DWX,2023,20820459,3d78354eeeaaf35f764fc1922469404d0e6a13eac122d4be066e7a14dd903e3b,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2023.hcc
WS30.DWX,2024,21248415,86e6b0837437984a67dcd4ae5d6e93fe2c29d6af967408fccb29dc0b5c3f9af3,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2024.hcc
WS30.DWX,2025,20991468,d42eeb198fd33b950e846226c1e21d955ec16ee77c444f08f759dee535a8d149,D:/QM/mt5/T2/Bases/Custom/history/WS30.DWX/2025.hcc
```

The three BR1 cost-prior lines are also hashed exactly as displayed, UTF-8/LF:

```text
NDX.DWX,1.0,0.5,0.01,prior: FTMO US100 ~0.5-1.0 pt spread
SP500.DWX,0.4,0.2,0.01,prior: FTMO US500 ~0.3-0.5 pt
WS30.DWX,2.0,1.0,0.01,prior: FTMO US30 ~1.5-2.5 pt
```

`BR1_F2_COST_MANIFEST_SHA256 = 86206120822ae6d6c88e7cfb5333abbbf13499e85cc405e08c23ec3ec599dfbe`

These are priors, not measured per-trade FTMO fills. Venue task
`73434cab-cf1c-4c17-8a11-9ca52c11d99e` is REVIEW with
`ABSTAIN_NO_ELIGIBLE_VENUE_DELTA`; it does not convert these priors into measured venue truth.

| Bound artifact | SHA-256 |
|---|---|
| Frozen `PLAN.md` | `e42d8770df11fcbbca9e5560a1280c352145b09d7cd1e2b30135d4bff1a9b57b` |
| Inventory | `76723f335a9b55c5a11fe4328c179048552e53321dfefa8d1e4ac94bca4fb226` |
| F2 result JSON | `cf033bd761b431e033fbc24bfea67067e63d52d7e5a9e501cf8bb5c6dcb5294b` |
| F1 shared module | `3f459b170c64ba69a9b6147d2e123173f197a81c8970b09ecb7916b5884f826d` |
| F2 shared module | `814b6f20b8bb366e0047bd0f2bea156f41dbf13a219c6ae92f7649c78eff47e8` |
| BR1/2/3 runner | `5c4ebc9f49776568c683d961724d1b73132fc8a0c949097efe1b266c173754e9` |
| HCC reader | `85a486767fafe0dfe4a3e1b4b177b2ca2f6939d3271a0a7abd4b1f8be1e14145` |
| News archive consumed by F2 | `dc96c059f64f609f71a911f2f4d01f00f56b2a7c335a13238258490f34f736ee` |
| Track-B programme | `ab22cb01ed3240fe2a6198294004ea18d9e5ecdeaf9e9e75b8f1350fe41b1228` |
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
   critique and governed Every-Real-Tick canary before any economic claim.

Until then, `UNKNOWN_PENDING_ACCEPTED_HARNESS_V2` is the only governed BR1 disposition. The
F2 negative result is retained without overwrite, and no untracked follow-on work is invented.
