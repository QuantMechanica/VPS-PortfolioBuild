# QM5_20180 sleeve-0 fidelity diagnosis

Date: 2026-07-27  
Router task: `e93d0ad2-1450-43a4-af16-fd8e3a0ca72c`  
Verdict: **the 0.914741 result is not a valid signal-logic fidelity test**

## Plain answer

A gated sleeve can be reproduced outside its original EA only when the control
replays the same executable framework vintage and the same market-data image.
That condition was not met here. The gated reference came from a July 14
`QM5_9936` binary, while `QM5_20180` was compiled on July 27 from the then-current
framework and a copied/reentrant strategy implementation. The reported comparison
therefore measures two different executable programs, not merely the effect of
moving one sleeve into a shared module.

This does **not** establish that extraction into a shared module is impossible.
It establishes that the present run cannot answer that question. A valid control
must compile standalone 9936 and singleton 20180 from one pinned source/framework
commit and run both against one pinned terminal/tick-store image. Until that
control reaches 1.0, the shared-module plan is not admitted.

No new backtest was run. The existing streams, summaries, sources and tick-store
manifests were sufficient to diagnose the invalid control.

## 1. What the comparator actually measures

`tools/strategy_farm/compare_joint_replay.py:46-48` pairs records by the exact
tuple `(entry_time, close_time)`. It then requires net P/L within $0.005 and
volume within 0.005 lots (`:58-63`, `:80-83`). Its denominator is the larger
stream length (`:96-97`). It does not compare entry price, exit price, side, SL
path or signal state.

The comparator is internally consistent for its documented byte-fidelity gate,
but its `unmatched_*` labels are not equivalent to “different signals.” One
changed close timestamp makes the same entry appear once as unmatched joint and
once as unmatched gated.

An independent read-only reconciliation of:

- `D:/QM/reports/joint_20180/harvest/20180_s0.jsonl`
- `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`

produced:

| category | count |
|---|---:|
| exact entry, close, net and volume | 1,148 |
| same entry and volume, different close | 77 |
| same entry and close, different net | 1 |
| joint-only entry times | 29 |
| gated-only entry times | 26 |

Thus 77 of the comparator's 107 joint / 104 gated unmatched records are paired
entries with different exits, not missing entry signals. All 77 retain identical
volume. Twenty-five close exactly 3,600 seconds later in the joint run; four
close 7,200 seconds later; three are 3,599 seconds later and three are 3,601
seconds later. That H1 clustering points at management/execution-path drift,
not wholesale signal divergence.

The first difference is a gated-only entry at epoch `1509430212`
(2017-10-31T06:10:12Z). The first shared entry with a different close is epoch
`1510651994` (2017-11-14T09:33:14Z): joint close `1510670955`, gated close
`1510665762`, a 5,193-second delta. Differences then occur across every year
through 2025; there is no single late start-date boundary.

## 2. The control used different executable programs

The gated baseline summary identifies:

- canonical backtest set:
  `...Q08/_baseline/.../20260727_035506/summary.json:27`;
- executable SHA-256
  `a1de7a7be28a40b592400c1fa3631d1fbd3f7e45c03f4b1763b99acd44e868ca`,
  last written 2026-07-14 (`:39-56`);
- source SHA-256
  `aac82a7c08255372b63deef8060317c44f8e3cd4b2f8b364ba46896d0d7e364e`,
  last written 2026-06-11 (`:58-64`);
- T10 and 1,252 trades (`:96`, `:146`).

The singleton summary identifies:

- replay set at `...20260727_122752/summary.json:27`;
- executable SHA-256
  `c29da61f2aeb348d35a0dbbdc5b889c172df3332be1d51523c16e98de721e946`,
  last written 2026-07-27 (`:39-56`);
- joint source SHA-256
  `f46d54c6e9bfe779aac82a77b45555d563727c7addda6a19d12e20e72fc1fc21`
  (`:58-64`);
- T9 and 1,255 trades (`:96`, `:157`).

This is the named mechanism: **execution-identity drift**. A copied strategy
compiled against the July 27 framework was compared with an older standalone
binary compiled against the July 14 framework. The build statement
“byte-identical because it uses the default entry path” cannot bridge different
compiled programs. The 77 equal-entry/equal-volume but H1-shifted exits are the
observed behavioural consequence.

The terminal tick-store manifests do not support blaming history first. Recursive
T9/T10 `USDJPY.DWX` tick-cache inventories had the same relative file names,
sizes and timestamps for the tested history. This is not a byte hash of the
approximately 958 MB store, so byte identity remains unproven, but there was no
manifest-level difference.

## 3. Eliminations

### Comparator

The comparator did not fabricate the 0.914741 number. Re-running its documented
logic against the two durable streams reproduces 1,148 exact matches. Its
presentation does, however, conceal that 77 pairs share the entry and volume and
differ only at exit. The comparator should retain its strict gate but add
diagnostic categories; the gate threshold must not be relaxed.

### `qm_risk_cap_pct`

This is a no-op for the tested fixed-risk configuration:

- `QM_Common.mqh:173` selects `QM_RISK_MODE_FIXED` when `RISK_FIXED > 0`;
- `:180-182` configures that fixed mode and sets the default cap percentage to
  1.0;
- `QM_FrameworkSetRiskCapPct(1.0)` at `:315-327` writes the same one-percent
  percentage cap;
- both replay sets carry `RISK_FIXED=1000`, `RISK_PERCENT=0`.

The explicit `qm_risk_cap_pct=1.0` in the joint set therefore does not change
fixed-money sizing. The stream confirms this operationally: all 77 same-entry
different-exit pairs have exactly the same volume.

### Starting balance and costs

Both tester INIs specify deposit 100,000 USD and leverage 100. Both run summaries
record the same injected/restored canonical commission-group SHA-256
`25314333af81faf48e2afe2db5d52beea640cc74ec33a85a46b7c43aadb921dd`.
The 1,148 exact trades, including net and volume, independently refute a global
starting-balance or commission mismatch.

### Parameter binding

The durable gated stream is the Q08 baseline run
`20260727_035506`, whose tester INI names the canonical
`...USDJPY.DWX_H1_backtest.set`. A different document cited the later
`20260727_051717` neighborhood run, which used a 2.25 max-range perturbation;
that citation is wrong for stream provenance. The harvested stream mtime and
baseline summary timestamp both end at 04:15:56Z, before the neighborhood runs.
The diagnosed mismatch is therefore not the 2.25 perturbation.

## 4. Fix and admission test

The fix is to repair the control, not tune the strategy:

1. Pin one repository commit, compiler/terminal build, set hashes, commission
   group and one terminal tick-store image.
2. Compile standalone 9936 and singleton 20180 from that same framework state.
3. Run both canonical fixed-risk configurations on the same reserved terminal,
   sequentially, harvesting each stream before the next run truncates it.
4. Extend the comparator report with the five categories in section 1 while
   retaining the exact `match_rate == 1.0` admission rule.
5. If the pinned same-build control still fails, use the first differing entry
   and first shared-entry/different-close pair to trace order placement, SL
   modification and close events. Only then is a copied-module implementation
   defect established.

No threshold, strategy parameter, gate or historical stream should be altered.
The existing 20180 joint instrument remains **not admitted**. The broad claim
“a gated sleeve cannot be reproduced outside its own EA” is **NOT ESTABLISHED**;
the narrower claim “this cross-vintage replay reproduces it” is refuted.
