# Q08 promotion-window and identity repair

Router task: `5de65240-a677-4b32-992b-62616ff44b42`

## Outcome

Q08 promotion now binds the queue seal, DSR cohort, and baseline runner to one
governed phase window. Promotions also carry typed current EX5, MQ5, setfile,
include-closure, build, and data-window identity; insertion fails closed when
the phase window or an authenticated build authority cannot be derived.

The two terminal INVALID rows named by the task were preserved. Append-only
successors were created with a `2017.01.01` through `2025.12.31` seal and the
current authenticated artifact identity:

| EA | Preserved INVALID | Append-only successor | DSR SHA-256 | Final pipeline verdict |
|---|---|---|---|---|
| QM5_41488 | `3e157d97-45fa-4f8a-8f55-60484ffdbea4` | `c11b2a55-ec79-4af8-a87c-8ed22d3f6ca7` | `9fcfe859183014ef96e8d15a51b5158fc40891da53643ade27839c048ba6c78e` | `FAIL_SOFT` |
| QM5_41489 | `f38417ed-c2a8-4ec9-919e-bc7223e9b8f1` | `63c9779d-3a67-4eb9-b3e7-2dff8565011a` | `b104232b996f468c0f684989a94a3a25ba33af1221d7bce4938a9fd956ec111f` | `FAIL_HARD` |

Both new DSR documents seal `2017-01-01` through `2025-12-31`. Both successor
aggregates have `n_invalid=0`; neither reproduced
`DSR_V2_TRADE_OUTSIDE_SEALED_CALENDAR`.

## Root cause and correction

`_promotion_payload_with_basket_context` legitimately propagated basket
metadata but also carried the Q02 canary aliases `from_date=2018.07.02` and
`to_date=2022.12.31` into later phases. The Q08 DSR producer preferred those
aliases while the Q08 runner independently executed the full phase history.
The resulting DSR documents therefore rejected trades outside the wrong seal
with `DSR_V2_TRADE_OUTSIDE_SEALED_CALENDAR`.

The correction:

- centralizes Q08 window resolution in `q08_window.py`, including the governed
  DWX late-history floor, and uses it in both queue promotion and the runner;
- overwrites all ambiguous inherited date/year aliases at Q08 promotion;
- prefers the phase `expected_*` window in DSR resolution as a defense in depth;
- authenticates the current binary/source/setfile/include closure through a
  verified four-part predecessor or governed compile evidence;
- writes typed identity and data-window columns on every Q08 insertion path;
- refuses insertion when either window or identity authority is unavailable;
- provides a journaled, compare-and-swap pending-row repair that never edits a
  terminal row, verdict, or evidence path.

Code commit: `dd631220ee` (`fix(q08): bind promoted rows to governed window`).

## Pending-row census and governed repair

The apply-time census found 47 unclaimed, unsuperseded promoted Q08 rows. None
had enough current authority for an in-place identity/window repair, so no row
was guessed or partially rebound:

| Refusal | Count |
|---|---:|
| predecessor setfile identity mismatch | 22 |
| current build compile provenance unavailable | 16 |
| compile include closure unbound | 7 |
| predecessor MQ5 identity mismatch | 1 |
| compile include closure not current | 1 |

Two rows without an existing hold received the typed item-scoped hold
`Q08_PROMOTION_BINDING_REFUSED`. The remaining 45 already had active governed
holds; those were preserved and journaled as hold conflicts rather than
overwritten. Thus all 47 refused rows remain non-claimable.

The repair journal is
`q08_promotion_repair_journal.json` (SHA-256
`bde3b367eac9c79645e72f3b57ce1c53ebd4d053d087c020b92e807484307079`).
It binds the governed backup
`D:\QM\strategy_farm\state\backups\farm_state_before_q08_promotion_repair_20260922T031737Z_2668abee.sqlite`
(SHA-256 `691d7a98f0f4c6cfbbd343b04f48c217b2f1efd9cae7a516397ad7f2442909bd`)
and attests zero terminal-row, verdict, or evidence-path edits.

## Rerun bindings

| Binding | QM5_41488 | QM5_41489 |
|---|---|---|
| EX5 | `3c2cac2fe817fb60fbef394ba4b1ee46a39423c563c46797fd99262593b4eb08` | `e582501f16fb9820bb4ec53ca18a880a0ee044b16f3ce3637fa8ee1c031da842` |
| MQ5 | `e8ff5415daf04c74c46421c50b177a43797dd68b2055cd7b4cfaf7d432b63e63` | `25fd30a52a8f2a56a614b132616b6e20b46957db95e28ff46a1367cbe7f027fa` |
| Setfile | `9e8efb17798a3ea20f5e2255507abada381f04e4a73c67830c51928ebe5ca504` | `f709fc0f9773b389069ba5769cbb10a5757b0d6b51c8c111ca34d96279014341` |
| Include closure | `7a3a71ea665415b7822c7f2995a0199b530dc3e2508b9180d2c0e6f47af23861` | `7a3a71ea665415b7822c7f2995a0199b530dc3e2508b9180d2c0e6f47af23861` |
| Compile work item | `c9b81f7e-2723-4161-878a-8badaeded7fb` | `3056a976-b5ec-43da-b5be-b73bbe750402` |
| Typed window | `2017.01.01` – `2025.12.31` | `2017.01.01` – `2025.12.31` |

Both setfiles were rechecked before enqueue with `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

## Verification

- `26 passed`: focused Q08 window, promotion, DSR, repair, and admission tests.
- `112 passed, 13 subtests passed`: Q08 cascade, stream rerun, DSR, admission,
  and expanded-news adjacency suite.
- Broader pump/cascade regression run: `247 passed, 25 subtests passed`; its
  sole failure was the pre-existing V4 readiness scan finding three unrelated
  Q09 literals in `q09_news_runner.py` and `terminal_worker.py`.
- Python bytecode compilation and `git diff --check` passed for all changed
  files.
- Cycle-start farm health was already `FAIL` (`14 FAIL`, `57 OK`, `15 WARN`),
  including unrelated Q08 invalid-rate/claim-starvation and dispatcher checks.
- Pre-review final farm health remained `FAIL` (`14 FAIL`, `58 OK`, `16 WARN`)
  because of the existing global backlog/monitor conditions. The Q08
  head-of-line claim-starvation check was `OK` (`7/10` terminals idle with 43
  unblocked pending rows), both task reruns were terminal, and there were no
  active rows beyond timeout. The trailing Q08 INVALID rate remained 26.8%
  because the append-only repair correctly preserves the two historical
  INVALID rows.

No terminal was started manually, no active backtest was interrupted, and
AutoTrading/T_Live were not enabled.

## Final successor verdicts

Pipeline verdicts are reported exactly from the two successor aggregates:

- QM5_41488: `FAIL_SOFT`, 82 trades. Q08.2 DSR passed with
  `DSR_V2_COMPUTED` (`p=0.0218533779`); the economic failures were seasonal
  robustness (Q08.4) and PBO (Q08.7). Evidence:
  `D:\QM\reports\work_items\c11b2a55-ec79-4af8-a87c-8ed22d3f6ca7\QM5_41488\Q08\XTIUSD_DWX\aggregate.json`.
- QM5_41489: `FAIL_HARD`, 432 trades. Q08.2 produced a valid DSR calculation
  (`DSR_V2_COMPUTED`, `p=0.1283027298`) and failed economically/statistically,
  not because of a calendar seal. Q08.4 seasonal and Q08.6 chopping-block also
  failed. Evidence:
  `D:\QM\reports\work_items\63c9779d-3a67-4eb9-b3e7-2dff8565011a\QM5_41489\Q08\XTIUSD_DWX\aggregate.json`.
