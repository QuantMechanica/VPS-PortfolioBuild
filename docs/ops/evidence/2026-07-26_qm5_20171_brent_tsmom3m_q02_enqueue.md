# QM5_20171 Brent three-month momentum Q02 handoff

- EA: `QM5_20171_brent-tsmom3m`
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_20171_brent-tsmom3m_card.md`
- Card gate: `g0_status: APPROVED`
- Diversity carrier: `XBRUSD.DWX` D1 (Brent crude)
- Structural edge: monthly three-month time-series momentum, sourced to
  Moskowitz, Ooi and Pedersen (2012), *Journal of Financial Economics*
- Expected cadence: 12 monthly packages/year; Q02 floor remains 5/year

## Deterministic preflight

- EA registry: `20171,brent-tsmom3m,...,active`
- Magic registry: `(20171, slot 0, XBRUSD.DWX, 201710000, active)`
- Approved-card slug, EA directory slug, EA registry slug, and compiled expert match.
- Backtest setfile retains `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Build check (compile skipped because the committed EX5 was already current):
  `PASS`, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260726_150359.json`
- MQ5 SHA256:
  `822f10c49bd080e7bfbed9d3e61ea4f0d1767beaf40bf29da200bffaf4f20bf5`
- EX5 SHA256:
  `f13e3e3ee5ccebfd96ab1e9bf9ae51af88254089c60b1dd7754f57ed9502a7cd`
- Setfile SHA256:
  `2d7cecea8ae59cb0ef1ee07bf37e65fb2eec3a56f6fb82c28aefd24c0fc0e17e`

## Farm coordination and handoff

- Claim task: `233cf3f4-22b3-4f6a-9b54-a1747d27882e`
- Claim key:
  `manual:codex:agents/board-advisor:QM5_20171:q02-build-handoff`
- Pre-enqueue DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20171_q02_enqueue_20260726T150456Z.sqlite`
- Q02 work item: `77c48a06-5b6e-4a91-8a90-317214ca254b`
- State at handoff: `pending`
- Bound test window: 2018-07-02 through 2022-12-31

Seven path-anchored T1-T10 tester processes were active, so no smoke test,
manual dispatch, pump, or other backtest launch was performed. The work item is
left for normal factory scheduling.

No T_Live file or process, AutoTrading setting, portfolio gate, portfolio
manifest, deploy manifest, or live setfile was touched.
