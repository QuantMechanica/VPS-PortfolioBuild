# FTMO book rebuild status - 2026-07-10

## Ownership and terminal boundary

Codex owns the FTMO workstream. Claude is not a dependency and remains outside
this book. Codex may use T1-T5 only. T6-T10, T_Live, the FTMO terminal,
AutoTrading, live accounts, and Darwinex-Zero book artifacts are out of scope.

Factory state remains OFF with `codex_parallel=0`.

## Current book verdict

The installed Round25 preset book contains 12 sleeves and sums to
`RISK_FIXED=8999`. The combined gate result is `NO_GO`:

- Strict Q02-Q10 qualification: `0/12 CHALLENGE_READY`.
- Report reconciliation: `2/12 PASS` (`10848/XAUUSD`, `12990/GBPUSD`).
- Seven sleeves have a failing stream; three have no Q08 reconciliation input.
- No sleeve satisfies both contracts, so book-ready count is `0/12`.

Machine-readable evidence:

- `artifacts/ftmo_round25_qualification_2026-07-10.json`
- `artifacts/ftmo_round25_stream_reconciliation_2026-07-10.json`
- `artifacts/ftmo_round25_book_readiness_2026-07-10.json`

No scale change, density delta, or decorrelation delta may be applied to this
book. The earlier scale/pass probabilities are historical invalidated research.

## Root cause and repair boundary

Fifty-eight missing A/B exits are kill-switch closes whose close order uses magic
`0`; one additional exit is an MT5 tester-end liquidation after EA shutdown.
The exact shared-framework repair and fixtures are defined in:

- `docs/ops/evidence/FTMO_STREAM_GAP_ROOT_CAUSE_2026-07-10.md`
- `docs/ops/evidence/Q08_ROUND_TRIP_COMMISSION_HANDOFF_2026-07-10.md`
- `docs/ops/evidence/FTMO_JOINT_EQUITY_CAPTURE_SPEC_2026-07-10.md`

Framework includes are owned by CTO / Quality-Tech and are not modified by the
Development build lane.

## Codex implementation completed

- `ftmo_stream_reconciliation.py`: count/net/MAE reconciliation against MT5.
- `ftmo_qualification.py`: fail-closed Q02-Q10 binary-fresh inventory.
- `ftmo_book_readiness.py`: combined all-sleeves book gate.
- `ftmo_joint_equity.py`: exact FTMO 2-Step trace evaluator with Prague day
  anchors, daily and total equity floors, four trading days, flat-at-target,
  Phase-2 reset, synchronized sleeve-grid enforcement, and DST handling.

## Execution sequence after framework repair

1. Recompile only the selected FTMO candidates against the repaired framework.
2. Run locked model-4 baselines on idle T1-T5 with report/trace hashes.
3. Require exact report reconciliation before Q02 or portfolio analysis.
4. Run the full per-symbol Q02-Q10 cascade; no soft-fail rescue in the strict
   challenge lane.
5. Capture synchronized joint equity for survivors only.
6. Rebuild the book from strict survivors, then compare risk scales and Phase-1
   plus Verification timing.
7. Use a new Free Trial only after the combined book gate returns `READY`.

## Strategy supply

The only two APPROVED/ID-allocated cards not already built are Lien Perfect
Order and Lien Carry Trade. Both are multi-month D1 strategies with roughly
1-6 trades per year and fail the current extraction-schema lint. They are not
valid FTMO-speed build targets.

`QM5_13122_tokyo-fix-5m` was approved, built, and tested as the first new
high-density candidate. It compiled strict with no warnings, but valid
model-4 yearly reports pooled to 1,792 trades, PF 0.927, and -USD 7,796.79 at
the FTMO USDJPY commission basis. It is `Q02 FAIL` and retired without a
parameter rescue. Evidence:

- `docs/ops/evidence/FTMO_TOKYO_FIX_Q02_SCREEN_2026-07-10.md`
- `artifacts/ftmo_tokyo_fix_q02_screen_2026-07-10.json`

`QM5_13125_xau-usclose-ovnt` was the next structural candidate. Its native
2019-2025 model-4 reports pooled to 1,371 trades, PF 1.293 and USD 60,572.98,
but the custom symbol charged zero commission and zero swap. Re-costing every
round trip to the 2026-07-10 official FTMO XAU/USD commission and current long
swap reduced the result to PF 0.971 and USD -6,978.62. It is `Q02 FAIL` and
retired without Q04 or parameter rescue. Evidence:

- `docs/ops/evidence/FTMO_XAU_USCLOSE_OVERNIGHT_Q02_2026-07-10.md`
- `artifacts/ftmo_xau_usclose_overnight_q02_costed_2026-07-10.json`

`QM5_13127_et-open-atr-long` tested the source-faithful long-only repair of the
near-miss `10375` opening-breakout EA. The current binary was deterministic,
but 2022 returned PF 0.883 and USD -4,294.48; pooled 2021-2023 PF was only
1.144. Seven trades also crossed broker midnight while the custom report
charged zero swap. It is `Q02 FAIL`; 2024/2025 remained unopened. Evidence:

- `docs/ops/evidence/FTMO_ET_OPEN_ATR_LONG_Q02_2026-07-10.md`
- `artifacts/ftmo_13127_q02_preholdout_2026-07-10.json`

The proposed density delta was then requalified against current FTMO costs and
current binaries. None of its three additions is eligible for the strict FTMO
book:

- `10118/US100`: 716 native trades and PF 1.088 became PF 1.016 after the
  current `US100.cash` long/short swaps; the additional 5 bp stress was
  negative. Strict Q02 `FAIL`.
- `10546/XAU`: 1,762 native trades and PF 1.133 became PF 0.993 and
  USD -8,067 after current FTMO commission and direction-specific swaps.
  Strict Q02 `FAIL`.
- `10916/GER40`: fresh deterministic 2020-2025 reports passed deal-level Q02
  (466 trades, official-cost PF 1.240; 5 bp PF 1.210) and all 2023-2025
  walk-forward folds. Q05 then hard-failed at 15.1025% drawdown against the
  fixed 15.0% ceiling. It is a research reserve, not a promoted sleeve.

Evidence:

- `artifacts/ftmo_10118_ndx_cost_reconciliation_2026-07-10.json`
- `artifacts/ftmo_10546_xau_cost_reconciliation_2026-07-10.json`
- `artifacts/ftmo_10916_gdaxi_q02_current_binary_2026-07-10.json`
- `D:\QM\reports\ftmo_10916_q04_20260710\QM5_10916\Q04\GDAXI.DWX\aggregate.json`
- `D:\QM\reports\ftmo_10916_q05_20260710\QM5_10916\Q05\GDAXI_DWX\aggregate.json`

Therefore the earlier `10118 + 10916 + 10546` manifest delta is invalid for
deployment. It remains research history only and must not be used for sizing.
