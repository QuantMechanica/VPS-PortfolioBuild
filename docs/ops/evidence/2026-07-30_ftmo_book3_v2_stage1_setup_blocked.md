# FTMO Book 3 V2 — Stage 1 fail-closed closeout

**Observed:** 2026-07-30
**Authoritative source commit:** `40573cd720d524ffe3035930da9337a7328086b8`
**Measurement contract:** `FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET`
**Evidence vintage:** `FTMO_BOOK3_20260729_V2`

## Verdict

Stage 0 passed its exact full-lifecycle comparison. Stage 1 is
`SETUP_BLOCKED`, and the V2 ladder stops before R2/J2. The result is not
adjudicated away and the comparison gate is not weakened.

The immediate publication failure was an open XAU position at the joint EA's
`OnDeinit`. MT5 closed that position as `end of test` only after the EA's final
producer snapshot. More importantly, an independent reconstruction from the
native MT5 reports proves that the divergence is corpus-wide rather than a
single boundary-row issue. A boundary exclusion or an end-flat patch therefore
cannot turn Stage 1 into a valid PASS.

## Bound controller and run evidence

- Compile root:
  `D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02`
- Compile manifest SHA-256:
  `85a6dcf66ea98fe1cfb4b797a9168908cfdc8a46a0b0875ebcc4331e7195858c`
- Execution-input artifact bundle SHA-256:
  `7be1ed7f5cce1e7aa5aeccccf8f7c627f66e707c909bb3bf9b5cc59df4869cf4`
- Prepare plan SHA-256:
  `8b759abaea903f10fbd25cab5b04858abbd022a808fd5064d5f733da916f613e`
- R0 runner receipt SHA-256:
  `4c8a19073504728c4531ef9139a08badfd77308f18729c8d27a10ba48a28e768`
- J0 runner receipt SHA-256:
  `44d7e861d8e50d8aa852c26abf29f42c579e215028a34c6e25175331b28cdf74`
- Stage-0 PASS receipt SHA-256:
  `00a7fb68582d91a0efb93d711b6a413fd108a24d341f0669815a14dc0725f1a7`
- R1 runner receipt SHA-256:
  `caadc31ea7e4603b000af3206868279c68d49c960fa7b4c14667bb0cfb42b3cf`
- J1 runner receipt SHA-256:
  `bbe6a50c1772a4d7e27166af0d0ebf381f46a34d80e66891055739cd537fd82d`
- Stage-1 `SETUP_BLOCKED` receipt:
  `D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02\runtime\fidelity_stage1_40573cd720d5_receipt.json`
- Stage-1 receipt SHA-256:
  `b3fa3b23f973e22925bab1a6c035bcbddefee3faf84021eec3d50c2a06e3bc43`

## Stage 0

R0 and J0 each produced 1,143 complete USDJPY lifecycles. The exact matcher
reported 1,143/1,143 matches with zero unmatched rows under the full lifecycle
money/volume/price contract. Stage 0 is PASS.

## Stage 1 — immediate producer boundary

The J1 MT5 run itself completed successfully and its native report contains
1,449 total basket lifecycles. The governed runner receipt is nevertheless not
successful because the joint Q08 trade stream was not freshly published.

The joint producer reported XAU position `4230` still open during `OnDeinit`:

- magic: `201810001`
- entry deal: `#2896`
- side/volume: BUY `0.04`
- entry: `4338.04` at `2025-12-30 01:01:01` broker wall time
- producer-snapshot exits: `0`

After the EA producer stopped, MT5 generated one automatic `end of test` SELL
deal (`#2899`, `0.04`, `4338.21`, `2025-12-30 23:59:58`). The atomic stream
harvest therefore refused the stale pre-run Q08 trade file. This is a correct
fail-closed publication outcome.

## Stage 1 — corpus-wide standalone/joint divergence

The stronger finding comes from the two native MT5 reports themselves:

| Measure | R1 standalone XAU | J1 joint XAU |
|---|---:|---:|
| Complete lifecycles | 291 | 306 |
| Deals | 582 | 612 |
| Native net | USD 16,062.47 | USD 15,601.84 |
| Extra joint entries | — | 15 |

Additional comparison facts:

- Strict multiset intersection over entry/close time, side, entry/exit price,
  volume, profit, swap, commission, fee, and net: **0**.
- All 291 standalone entries have a unique joint entry in the same minute, but
  the joint entry is consistently one second later.
- Unique entry-minute/close-minute/side pairing yields 275 pairs; 16 standalone
  and 31 joint rows remain unmatched.
- Of those 275 paired rows, only 20 are economically identical. Entry price
  matches 69 times, exit price 70 times, and profit/net 24 times. Volume matches
  on all 275 pairs.
- The first economically different lifecycle already appears in 2018. A later
  2020 lifecycle also has a materially different holding period, so the issue
  is not confined to sub-second timestamp formatting.

The current timer-driven cross-symbol EA is therefore not a faithful native
execution oracle for the XAU sleeve. The `OnTimer` scheduling model changes the
strategy's event cadence and trade path.

## Consequence and next contract

1. R2 and J2 remain pending and held under V2. They are not dispatched after a
   non-PASS Stage 1.
2. No boundary row is deleted or excluded post hoc.
3. No tolerance, matcher, money basis, or gate threshold is relaxed.
4. A fresh R2 MT5 result, if needed for portfolio research, must run under a
   separately preregistered standalone diagnostic contract with its own
   content-addressed identity and explicit `no_ladder_progression` boundary.
5. The production book evaluation uses native standalone MT5 streams as the
   strategy-fidelity source. A common-account M15/MAE reconstruction is
   research evidence only until a synchronized event- or tick-complete equity
   path closes the FTMO money gate.
6. A true cross-symbol single-EA replacement is a separate union-clock R&D
   project and must earn fresh standalone parity before any admission claim.

## Safety state

- Factory remained OFF; observed OFF-flag SHA-256:
  `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`.
- T10 was the only governed test terminal used.
- T5 and T_Live were outside the run scope. T_Live was not restarted and
  AutoTrading was not touched.
- No Factory restart, deployment, paid-Challenge purchase, or live-trading
  authorization follows from this closeout.
