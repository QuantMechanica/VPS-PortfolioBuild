# QM5_13121 Energy Trend-Momentum Q02 Enqueue Evidence

Date: 2026-07-10
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency commodity/energy sleeve:
`QM5_13121_energy-tfmom`. The EA trades a paired XTI/XNG package once per
broker month when the 12-completed-month relative winner is above its own
seven-month mean and the loser is below its mean. Fixed risk is split with
60-D1 inverse-volatility weights.

This is a new mechanic, not a renamed copy of an existing commodity EA. The
repository dedup helper returned `CLEAN` before atomic ID allocation.

## Source And Card Evidence

- Primary source: Clare, Seaton, Smith, and Thomas (2014), "Trend following,
  risk parity and momentum in commodity futures", *International Review of
  Financial Analysis* 31, 1-12, DOI
  https://doi.org/10.1016/j.irfa.2013.10.001.
- Full 12-page paper read end to end.
- Source packet: `strategy-seeds/sources/CLARE-TFMOM-2014/source.md`.
- Canonical card: `strategy-seeds/cards/energy-tfmom_card.md`.
- Approved fleet card: `artifacts/cards_approved/QM5_13121_energy-tfmom.md`.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.

## Non-Duplicate Evidence

- `QM5_12567_cum-rsi2-commodity`: RSI pullback; no overlap.
- `QM5_12733_xti-xng-xmom`: raw relative momentum without the two-sided
  seven-month trend requirement or source risk-parity weights.
- `QM5_12840_xti-xng-rspread`: z-score return-spread fade.
- `QM5_13089_xti-xng-carry`: broker-swap carry rank.
- `QM5_13113_energy-mom-ivol`: residual-volatility double sort.
- `QM5_13118_energy-skew-rank`: third-moment rank.
- `QM5_13120_energy-momrev`: 12/18-month opposite-rank gate rather than
  per-leg trend confirmation.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug energy-tfmom --strategy-id CLARE-TFMOM-2014_XTI_XNG_S01 --author "Clare Seaton Smith Thomas" --mechanic "monthly 12m cross-sectional energy momentum 7m trend agreement 60d inverse volatility"`

Verdict: `CLEAN`.

## Registry Evidence

- EA registry: `13121,energy-tfmom,CLARE-TFMOM-2014_XTI_XNG_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131210000`.
- Magic slot 1: `XNGUSD.DWX -> 131210001`.
- `QM_MagicResolver.mqh` regenerated from `magic_numbers.csv` and contains both
  new magic values.

The repository-wide `validate_registries.py` command remains red on hundreds
of pre-existing legacy rows and three pre-existing missing EA directories
(`1001`, `1015`, `1016`). It reported no `13121` defect. Scoped build and
magic checks for the new EA pass.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13121_energy-tfmom/QM5_13121_energy-tfmom.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13121_energy-tfmom/QM5_13121_energy-tfmom.ex5`.
- Compile result: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260710_174742/QM5_13121_energy-tfmom.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260710_174752.json`.
- SPEC validator: PASS.
- Build guardrails: PASS.
- Symbol scope: `BASKET_OK`.
- MQ5 SHA256:
  `25f6e48c0f932dcc54363e1662c522922a775b094716a849679c5d0cf266d82d`.
- EX5 SHA256:
  `0065168aca7a79ce997f776f5569c0b3bfe5f96eaefeffcd3d17d2023ee152f3`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13121_ENERGY_TFMOM_D1`.
- Host: `XTIUSD.DWX`, D1.
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13121_energy-tfmom/sets/QM5_13121_energy-tfmom_QM5_13121_ENERGY_TFMOM_D1_D1_backtest.set`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close disabled only for the source-aligned one-month holding period.
- Each leg has a frozen `ATR(20) * 3.5` hard stop plus orphan cleanup and a
  35-day stale-package guard.

## Q02 Queue Evidence

- Build task: `bd46e0c8-07c0-44cd-b9b4-408371ef636a` (`done`).
- Work item: `3dc3cec3-3691-4bdd-9f67-fa6b245be574`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13121_ENERGY_TFMOM_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Enqueued at: `2026-07-10T17:44:58+00:00`.
- Queue path: `record_build_result.auto_q02`.
- Basket manifest: two symbols, host `XTIUSD.DWX`, timeframe D1.

No manual smoke/backtest was started. The paced fleet will dispatch Q02; this
avoids adding load near the backtest CPU ceiling.

## Safety Boundary

- No T_Live path accessed or changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest created.
- No portfolio gate or portfolio admission file changed.
- No gate threshold changed.
