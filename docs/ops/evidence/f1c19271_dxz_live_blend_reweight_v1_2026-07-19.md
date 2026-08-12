# Live-Blend-Reweighting v1 — deterministic HOLD evidence

Date: 2026-07-19

Router task: `f1c19271-dbff-4694-a302-327605a59616`

Book: OWNER-deployed DXZ Sunday Final-24

Verdict: **HOLD scaffold — blend rule failed OOS; no live export; no weights proposed**

## Outcome

The offline extraction/reweight scaffold is implemented in
`tools/strategy_farm/portfolio/dxz_live_blend_reweight.py`. It cannot connect to
MT5, start a terminal, edit presets, apply weights, change `TOTAL_RISK`, or touch
AutoTrading. It accepts only a frozen account-history export plus provenance
metadata and produces an OWNER-review package. This is a fail-closed evidence
consumer, not an operational unattended monthly reweighter: the approved deal
export producer does not yet exist.

The predeclared variance blend did **not** pass the required held-out validation
on the sealed Final-24 stream basis:

| metric | capped inverse-vol baseline | live-blend rule |
|---|---:|---:|
| log-volatility RMSE | 0.9318575366 | 0.9643795035 |
| decisive fold wins | 50 / 78 | 28 / 78 |
| relative RMSE | 1.000000 | 1.0349001490 |

The blend was 3.49% worse on the predeclared loss and won 35.90% of folds. The
result is `FAIL`, so the generated OWNER template contains an empty
`proposed_weights` array and `analysis_weights_withheld=true`. Candidate weights
and deltas are also blanked in `sleeve_diagnostics.csv`; only the already
deployed baseline weights remain visible in the frozen manifest. Parameters were
not retuned after observing the failure.

No authoritative T_Live deal-history export was present in the mounted stores.
EA JSONL `EQUITY_SNAPSHOT` rows are account-wide, `TM_CLOSE` lacks realised cash
components, journals lack Magic/cost attribution, and native `deals_*.dat` is a
proprietary cache. None was treated as per-sleeve PnL. The evidence run is
therefore template-only with zero observed Final-24 sessions and these holds:

- `LIVE_DEAL_EXPORT_REQUIRED`
- `LIVE_WINDOW_IMMATURE_0_OF_21_MINIMUM_SESSIONS`
- `NO_SLEEVE_HAS_MINIMUM_LIVE_EVIDENCE`
- `BLEND_RULE_OOS_FAILED`

The Final-24 evidence clock starts with the first full session on 2026-07-20.
With the fixed 21-session minimum, 2026-08-16 remains immature; the earliest
calendar date that can reach the session gate is 2026-08-17. OOS PASS and valid
live evidence would still be required.

## Implemented contract

- Inputs are bound to the 24-sleeve manifest, final OWNER decision, deployed
  staging-report manifest SHA, active Magic registry, canonical commission
  registry, generator/dependency source hashes, and all 24 sealed stream
  hashes/trade counts. The sealed baseline fingerprint is pinned in code.
- Backtest PnL uses the same `portfolio_common.load_streams` net-of-cost path as
  the deployed book construction. All 24 manifest trade counts must match.
- Live realised cashflow is `profit + swap + commission + fee`, attributed from
  opening Magic through `position_id`; Magic-zero broker closes inherit the
  opening owner. Unknown/conflicting ownership, missing opening risk, duplicate
  deals, and `INOUT` rows fail closed.
- A real run requires an immutable deal export, metadata sidecar for account
  `4000090541` / server `Darwinex-Live`, a contemporaneous risk schedule, and the
  pinned baseline `input_sha256.csv` from this package.
- The v1 risk schedule is restricted to one 2026-07-20 regime per Final-24 Magic,
  exactly matching the deployed manifest and preserving `TOTAL_RISK=9.75`.
- Evidence eligibility counts closed positions, not IN/OUT deal rows. The fixed
  monthly minimum is 21 sessions; blend alpha is `min(n_sessions / 42, 1)` and
  saturates at 42. The hard sleeve cap is exactly 1.0 and total risk remains
  exactly 9.75.
- Live manifests require `RISK_FIXED=0`, while every referenced backtest set is
  checked for `RISK_FIXED>0` and `RISK_PERCENT=0`.
- Outputs are analysis-only, composition-preserving, return-forecast-free, and
  OWNER approval remains mandatory. Cluster caps and automatic risk increases
  are outside v1.

## Durable artifacts

Canonical package:
`C:/QM/repo/docs/ops/evidence/f1c19271_dxz_live_blend_reweight_v1_20260719/`

- `oos_validation.json` and `oos_folds.csv` — held-out result and all 78 folds.
- `input_sha256.csv` — manifest/decision/staging/registry/tool plus 24 stream
  hashes and trade counts; this is the future live-run baseline pin.
- `invocation_config.json` and `frozen_inputs/` — exact task/commit invocation,
  source dependencies, registries, decision/staging inputs, and all 24 sealed
  Q08 streams.
- `deal_export_contract.json` — required offline export and metadata contract.
- `manifest_snapshot.json` — exact Final-24 input snapshot.
- `sleeve_diagnostics.csv` — backtest/live diagnostics; candidate weight and
  delta columns are empty while HOLD.
- `owner_review_template.json` and `total_risk_review_template.md` — empty,
  no-apply OWNER decision shells.
- `verify.json` — artifact hashes and guardrail invariants.
- `.gitattributes` — disables line-ending conversion inside the package so the
  recorded hashes remain byte-stable across Windows worktrees.

## Verification

```powershell
cd C:/QM/repo
python -m pytest tools/strategy_farm/tests/test_dxz_live_blend_reweight.py -q
python -m py_compile tools/strategy_farm/portfolio/dxz_live_blend_reweight.py tools/strategy_farm/tests/test_dxz_live_blend_reweight.py
```

Result: `22 passed`; bytecode compilation PASS. Generator commit:
`be6cb400d619dd25354a8987308e30f0f6358402`.

Template-only reproduction:

```powershell
python tools/strategy_farm/portfolio/dxz_live_blend_reweight.py `
  --task-id f1c19271-dbff-4694-a302-327605a59616 `
  --generator-commit be6cb400d619dd25354a8987308e30f0f6358402 `
  --manifest D:/QM/reports/portfolio/portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json `
  --decision-record C:/QM/repo/decisions/2026-07-19_t_live_dxz_sunday_final_book.md `
  --staging-report C:/QM/deploy/DXZ_FINAL_2026-07-19/staging_report.json `
  --backtest-bundle D:/QM/reports/portfolio/dxz_final_20260719 `
  --magic-registry C:/QM/repo/framework/registry/magic_numbers.csv `
  --live-start 2026-07-20 --as-of 2026-07-19 `
  --generated-at-utc 2026-07-19T15:37:22Z `
  --output-dir C:/QM/repo/docs/ops/evidence/f1c19271_dxz_live_blend_reweight_v1_20260719 `
  --template-only
```

The generator source matched Git blob `b3f302aea6f945526ed9d45ac8f385ec54fd5321`
before and after this run. `verify.json` records hashes for every artifact and
frozen input, including the generator and its Python dependencies. The output
directory is immutable/non-empty on rerun by design; use a new dated directory
for any later evidence cut.

## Review boundary and next evidence cut

This is not a pipeline verdict and does not authorize deployment. The current
blend rule is rejected unless a separately predeclared rule earns fresh OOS
evidence; the failed gate must not be weakened. A later TOTAL_RISK review also
needs an OWNER-mediated account-history export and book-level mark-to-market
equity evidence. Realised close cashflow alone understates open-position drawdown
and cannot support a risk increase.

Before this can become an operational monthly reweighter, a reviewed offline
deal exporter must produce the exact UTC window and account/server metadata; the
live normalization also needs entry-equity or equivalent signed sizing lineage.
Order setup timestamps and order-specific deployed risk are required for any
orders created before a weight change. Scenario matrices remain intentionally
absent while OOS is FAIL.

The roadmap addendum advances extraction v1 to 2026-07-24 and the advisory
TOTAL_RISK review toward 2026-07-26. Historical 13→15→23→24 data must not be pooled
under Final-24 weights; it requires a separately reviewed contemporaneous risk
schedule and composition-aware evidence cut.
