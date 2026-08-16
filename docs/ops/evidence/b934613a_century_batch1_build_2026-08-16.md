# Century Suite build programme — batch 1

- Router task: `b934613a-ae5d-4590-bd9d-c5ad4ab54801`
- Worklist: `artifacts/century_clean_buildable.json` (77 rows)
- Batch result: **5/77 built; submitted for code review**
- Canonical branch: `agents/board-advisor`
- Build commit: `05e8ef8b90a5b26bbf90155786aa37902df4fe89`
- Pipeline status: **no pipeline verdict; Q02 not enqueued pending an `ea_review` approval predecessor**

## Authority and scope

This was the first five-row batch selected in worklist order by the deterministic
router. Each runtime card under
`D:/QM/strategy_farm/artifacts/cards_approved/` has `g0_status: APPROVED`, and
each EA ID/slug pair already existed in `framework/registry/ea_id_registry.csv`.
The exact card, registry, directory, and source slugs match.

The build used the corrected `qm-build-ea-from-card` contract. No slug was
shortened. No terminal was started manually, no backtest or pipeline phase was
run, and neither T_Live nor AutoTrading was enabled.

## Batch inventory and compile result

| EA | Hosts / timeframe | Magic slots | Strict compile | Full build check | EX5 SHA-256 |
|---|---|---|---|---|---|
| `QM5_30002_zigzag-gold-breakout-happy-gold` | XAUUSD.DWX / M15 | 0 = 300020000 | PASS, 0/0 | PASS, 0 failures / 0 warnings | `65d07b38aa4bfc44e1c72015ec791a168688f64cbc235042f2e4a6c3f4964302` |
| `QM5_30003_multisystem-gold-scalper-forex-gold-investor` | XAUUSD.DWX / M15 | 0 = 300030000 | PASS, 0/0 | PASS, 0 failures / 0 warnings | `c812487d4e785905935a858034524ab158a196fc1a752d70556b3a0e5840ea44` |
| `QM5_30008_rollover-hour-multifilter-forex-fury` | EURUSD, GBPUSD, USDCHF.DWX / M15 | 0–2 = 300080000–2 | PASS, 0/0 | PASS, 0 failures / 0 warnings | `7a7148c5435b470fd9bd9d42037a9bc6d152e78b7313352e4c84dd664ba60d4d` |
| `QM5_31002_us-indices-opening-range-breakout` | WS30, NDX.DWX / M5 | 0–1 = 310020000–1 | PASS, 0/0 | PASS, 0 failures / 0 warnings | `8585f760987a9253f615f0eed8a55da619be61dee7d328519358fe753221929a` |
| `QM5_31003_london-open-currency-strength-dispersion` | GBPJPY, EURUSD, AUDUSD.DWX / M15 | 0–2 = 310030000–2 | PASS, 0/0 | PASS, 0 failures / 0 warnings | `d7431b2e6082ae38a5b7014b894e1e5ca297d52d94a306ec6f698c5e8aa86a24` |

Compile and build-check evidence:

| EA | Compile summary | Build-check report |
|---|---|---|
| QM5_30002 | `D:/QM/reports/compile/20260816_210051/summary.csv` | `D:/QM/reports/framework/21/build_check_20260816_210051.json` |
| QM5_30003 | `D:/QM/reports/compile/20260816_210205/summary.csv` | `D:/QM/reports/framework/21/build_check_20260816_210205.json` |
| QM5_30008 | `D:/QM/reports/compile/20260816_210247/summary.csv` | `D:/QM/reports/framework/21/build_check_20260816_210246.json` |
| QM5_31002 | `D:/QM/reports/compile/20260816_210327/summary.csv` | `D:/QM/reports/framework/21/build_check_20260816_210327.json` |
| QM5_31003 | `D:/QM/reports/compile/20260816_210402/summary.csv` | `D:/QM/reports/framework/21/build_check_20260816_210401.json` |

## Registry and resolver evidence

The governed sequence was directory creation, allocation, resolver regeneration,
drop check, source build, and compile.

- Added ten unique active rows to `framework/registry/magic_numbers.csv`.
- Every source assigns `req.symbol_slot = qm_magic_slot_offset`; the host-order
  setfile slot therefore resolves to the corresponding registry row.
- Resolver regeneration retained `16090` rows, dropped `0`, and bound registry
  SHA-256 `1A690E8F08FE24A4144B92D26CBEC1DCBFF1ABB4DE34BC198D549BB4C78246B7`.
- A post-build dry run returned the same `16090 rows kept, 0 dropped` result.
- The global registry validator remains non-clean from pre-existing fleet debt:
  1,454 issues and 1,273 warnings across 4,519 EA rows / 16,121 magic rows.
  Filtering that output for `30002|30003|30008|31002|31003` returned zero issues.
  Unrelated registry debt was not repaired by this task.

## Focused conformance gates

- All five SPEC documents pass `validate_spec_doc.py`.
- `validate_build_guardrails.py` checked 15 source/set files and returned PASS
  with no findings at the hard ceiling `qm_news_stale_max_hours = 336`.
- Ten generated backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Full input-use audit found no unwired inputs: 18, 17, 18, 16, and 16 inputs
  respectively.
- Focused source scan found no martingale, grid, ML/runtime import, T_Live, or
  AutoTrading mechanics.
- All five `.ex5` files exist and are non-empty.

The post-compile setfile hashes are:

| Setfile | SHA-256 |
|---|---|
| `QM5_30002_zigzag-gold-breakout-happy-gold_XAUUSD.DWX_M15_backtest.set` | `98d259808c754f1812c349094ad5a5f3cb5d26aaa73c7e0bc1780dc7c40fa33b` |
| `QM5_30003_multisystem-gold-scalper-forex-gold-investor_XAUUSD.DWX_M15_backtest.set` | `08063cb0c78093d18d007f41d221d7827a2b6bfd42b5fa81a18a9b4ef21c73af` |
| `QM5_30008_rollover-hour-multifilter-forex-fury_EURUSD.DWX_M15_backtest.set` | `7ccf7612eee2a169d0b4fb3aba76ccdf88d65e90c4ec539e25c9cd3e8a6ad622` |
| `QM5_30008_rollover-hour-multifilter-forex-fury_GBPUSD.DWX_M15_backtest.set` | `1685fbd0a68b694a684c38e7f35bcc1306b2bb4452a17002e53afc77b9351040` |
| `QM5_30008_rollover-hour-multifilter-forex-fury_USDCHF.DWX_M15_backtest.set` | `d0ceb12e0eadf87861c5c6169520cde2f8e0b9cd2da3c44428f6151e1c96bfee` |
| `QM5_31002_us-indices-opening-range-breakout_NDX.DWX_M5_backtest.set` | `dec1929536c1871cac3cd571a7f9b1dc1764e513b8e5ab588e81f51ee94a920c` |
| `QM5_31002_us-indices-opening-range-breakout_WS30.DWX_M5_backtest.set` | `d05d4ad7e34a1b5794b3a9d9e6c75cf9ac74bad956ccc442bd632c1cc56b138e` |
| `QM5_31003_london-open-currency-strength-dispersion_AUDUSD.DWX_M15_backtest.set` | `2d1b342239cad27ad79a3bc32ddcaccb176bda2dff09e3a548a357f620310eef` |
| `QM5_31003_london-open-currency-strength-dispersion_EURUSD.DWX_M15_backtest.set` | `c9aa79aa1d3578680169d0d3d8861c084855a902717b428cc3d4f31ab8f4600f` |
| `QM5_31003_london-open-currency-strength-dispersion_GBPJPY.DWX_M15_backtest.set` | `caa5a146a3614e953e67e21c237988093bbf290faa3a66dda5067c6f1630f9ea` |

## Review focus

`QM5_30003` is the material review point. Its approved card names three modules
without closed-form constants. The implementation and SPEC explicitly expose
the literal deterministic choices: a 20-bar OLS residual channel at 1.5
standard deviations, a 00:00–06:00 UTC Asian range with a 06:00–12:00 breakout
window, and a 1.5 ATR(14) H4 surge that breaks the prior H4 extreme. Fixed
25/30-pip card distances are represented as 250/300 XAU points. The stop is
server-side because the V5 risk sizer requires an absolute protective stop;
this differs from the card's presentation-layer statement that stops are
hidden. Review must accept or reject those declared choices before pipeline
handoff.

For `QM5_31002` and `QM5_31003`, card risk intent is implemented through the
required V5 framework risk inputs rather than a duplicate strategy-level risk
percentage input.

## Q02 disposition

The routed method requested immediate Q02 enqueue. The public CLI attempt

`python tools/strategy_farm/farmctl.py enqueue-backtest --ea <EA> --phase Q02`

returned `enqueued: false` for each candidate because Q02 is not a cascade
phase. The guarded Q02 path requires an `ea_review` predecessor whose verdict
is `APPROVE_FOR_BACKTEST`. This batch has no such predecessor yet. No manual DB
write, synthetic review, or self-approval was used. The five builds therefore
remain review artifacts and must be enqueued only after the designated code
review creates the required predecessor.

## Disposition

Return router task `b934613a-ae5d-4590-bd9d-c5ad4ab54801` to REVIEW at
**5/77 built**. Build PASS is not a pipeline verdict and does not authorize
live use. A subsequent deterministic batch must start at worklist row 6 and
must re-check that both registry files are clean before mutation.
