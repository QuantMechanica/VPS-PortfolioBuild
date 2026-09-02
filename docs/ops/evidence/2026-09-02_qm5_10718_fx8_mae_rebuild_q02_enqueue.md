# QM5_10718 FX8 basket MAE rebuild and fresh Q02 enqueue

Date: 2026-09-02 UTC

Branch: `agents/board-advisor`

Outcome: the approved D1 market-neutral FX8 carry sleeve was rebuilt under a
source-specific governed compile authority and one artifact-bound logical
basket Q02 row was enqueued. No economic verdict is asserted by this receipt.

## Non-duplicate selection

The controlling scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its strict v3 scan
tested all 66 FX relationships and found only the already-built
`QM5_12532` AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY survivors. The durable
frontier closure in
`docs/research/FX_COINTEGRATION_QM5_20240_Q04_RETIREMENT_20260831T233713Z.md`
records 123 approved cointegration identities, 123 EA directories, and no
unbuilt identity. It also records both preferred anchors beyond Q02 with no
current ONINIT or NO_HISTORY blocker. Creating another scan-derived card or EA
would therefore be duplicate work.

The mission's fallback clause was used for existing approved forex sleeve
`QM5_10718_edgelab-regime-filtered-carry`. Its approved G0 card is a structural,
learned-model-free, weekly-rebalanced D1 cross-sectional carry basket backed by
Lustig, Roussanov, and Verdelhan (RFS 2011) and Menkhoff et al. (JF 2012). It
holds the two highest-carry currencies against the two lowest-carry currencies
and is flat outside its realized-volatility regime.

## Build repair and governed receipt

The current strict build check found only `EA_Q08_MAE_HOOK_MISSING`. The source
repair adds `QM_FrameworkTrackOpenPositionMae()` as the first statement of
`OnTick`; it does not change signal, ranking, sizing, rebalance, exit, or regime
mechanics.

The append-only compile authority is bound to:

- EA label `QM5_10718_edgelab-regime-filtered-carry`;
- legacy logical-basket Q02 predecessor
  `92ba2ca6-1147-4432-af19-929a45993f4a`;
- repaired MQ5 SHA-256
  `92fa06a272aa4805e31c6caac4f1ad9feeaf91fec18c349a616bf2cae00f8f00`;
- the predecessor's exact FX8 logical symbol, host, timeframe, manifest, and
  28-member basket identity.

It grants no backtest, gate-verdict, portfolio-admission, or live-use
authority. The contract and tests were committed as `9c1e5a729f`.

Governed COMPILE_EA work item
`0ce7af66-266c-4117-8952-6d3f9b2611ee` completed `done/COMPILE_OK` on T6:

- compiler: PASS, 0 errors, 0 warnings;
- strict build check: PASS, 0 failures, 2 DWX swap-signal advisories;
- EX5 SHA-256:
  `10358a8dd852cd495265fc4099dfb7d9fecc711a047d98a4ff5eafbba51a91cc`;
- compile evidence:
  `D:/QM/reports/work_items/0ce7af66-266c-4117-8952-6d3f9b2611ee/QM5_10718/COMPILE_EA/compile_evidence.json`.

The EA package and 29 fixed-risk backtest presets were committed as
`ba5a522e20`. All 29 declare a positive `RISK_FIXED` and
`RISK_PERCENT=0`; the logical basket preset uses `RISK_FIXED=500`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Fresh logical-basket Q02

Fresh-Q02 seed `31f12573-d903-4386-a857-cad2b445d63a` was inserted pending for
logical symbol `QM5_10718_FX8_BASKET_D1`, hosted on `EURUSD.DWX` D1 over
2018-07-02 through 2024-12-31. Its immutable execution bindings are:

- MQ5 SHA-256:
  `92fa06a272aa4805e31c6caac4f1ad9feeaf91fec18c349a616bf2cae00f8f00`;
- EX5 SHA-256:
  `10358a8dd852cd495265fc4099dfb7d9fecc711a047d98a4ff5eafbba51a91cc`;
- logical setfile SHA-256:
  `cbc4602cc7685d7db68e9e17603916e4b66706ba9566248bf975c2a4782bd680`;
- active custom-history archive admission for all 28 basket members;
- 450-minute multisymbol timeout.

The guarded seed transaction atomically marked ten stale pending per-pair Q02
siblings `SUPERSEDED_BY_LOGICAL_BASKET`. No active sibling or duplicate logical
row existed.

Immediately before enqueue, five whole-host CPU samples were 72%, 70%, 79%,
81%, and 84% (maximum 84%, below the 97% stop ceiling). The only active farm
work was a non-basket XAGUSD OPT_CENSUS row on T3.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface was changed.
- No T_Live manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact was touched.
- No historical result was overwritten; the legacy Q02 PASS and all stale
  sibling rows remain preserved with append-only lineage.
- Unrelated staged, unstaged, and untracked shared-worktree changes were
  excluded from the commits.
