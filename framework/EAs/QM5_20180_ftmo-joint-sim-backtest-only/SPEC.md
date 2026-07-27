# QM5_20180 — FTMO Joint Sim (BACKTEST-ONLY)

**ea_id** 20180 · **slug** `ftmo-joint-sim-backtest-only` · **host** USDJPY.DWX · **TF** H1
· **registry status** `backtest-only` (non-pipeline)

A single measurement EA that trades the two gate-clean, intraday-flat USDJPY
sleeves on ONE simulated $100k account in ONE strategy-tester run, so the account
equity curve is REAL (not a proxy) and the two sleeves' realised correlation is a
direct read from co-timed trades.

| slot | sleeve | strategy | window (GMT+3) | evening |
|---|---|---|---|---|
| 0 | QM5_9936 | FF range breakout | range 01–06 | cancel 13, close 20 |
| 1 | QM5_13213 | Balke range breakout | range 03–06 | single flat 18 (cancel==close) |

magic = `ea_id*10000+slot` → `201800000` (slot 0), `201800001` (slot 1), both USDJPY.DWX.

## Scope decision (binding)
Built USDJPY-only per the adversarial review
(`docs/ops/evidence/2026-07-27_joint_backtest_ea_adversarial_review.md`), which
refuted the design's 3rd sleeve (10848:XAUUSD): a non-host per-tick-managed foreign
symbol driven off the host tick stream measures a different strategy (C1), is
invisible to singleton replay (C2), and biases the −5% daily read (C4). Both USDJPY
sleeves are host-symbol, so those failures do not arise and singleton replay is a
valid fidelity control.

## Backtest-only guarantees (structural)
`OnInit` refuses: init outside the Strategy Tester; `RISK_PERCENT>0`; any
`prop_phase != OFF`; non-zero stress. Ships **no** live/demo/ftmo set and no deploy
manifest. RISK_FIXED only.

## Fidelity mechanism
The sleeve logic is a COPY of the gated 9936/13213 algorithm
(`framework/include/QM/modules/QM_Mod_FtmoJointRangeBreakout_20180.mqh`) — the gated
EAs are left untouched (review H2). Sleeve 0 opens via the default QM_Entry path
(byte-identical to standalone 9936); sleeve 1 via the QM_Entry explicit-magic
overload. Proven by singleton replay (the `_replay_s0` / `_replay_s1` sets), not
asserted.

## Equity export (primary deliverable)
`QM_Mod_FtmoJointEquitySampler_20180.mqh` writes
`Common\Files\QM\q08_equity\20180_USDJPY_DWX.jsonl`: `EQUITY_BAR` per host H1 closed
bar and `EQUITY_LOW` on every new intraday low, each with a per-sleeve floating-P&L
breakdown. The FTMO −5% daily / −10% total / +10% / +5% predicates are exact reads
at any post-hoc leverage vector (RISK_FIXED linearity). RECORD, never ENFORCE.

## Sets
- `..._USDJPY.DWX_H1_backtest.set` — both sleeves (joint run).
- `..._USDJPY.DWX_H1_replay_s0.set` — sleeve 0 only (fidelity control vs 9936).
- `..._USDJPY.DWX_H1_replay_s1.set` — sleeve 1 only (fidelity control vs 13213).

Build/evidence: `docs/ops/evidence/2026-07-27_joint_backtest_ea_build.md`.
