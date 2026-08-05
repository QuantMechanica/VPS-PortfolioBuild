# QM5_11091 diverse-FX Q02 ONINIT recovery — 2026-08-05

## Disposition

`REBUILT_Q02_PENDING_CPU_CEILING`: the approved low-frequency H1
stochastic-state sleeve was blocked entirely by Q02 infrastructure failures,
not by an economic verdict. Its source and binary have been refreshed against
the current V5 framework, its four backtest setfiles have been regenerated with
explicit strategy inputs and fixed-risk bindings, and one EURUSD canary has
been returned to Q02 through the canonical queue path.

- Branch: `agents/board-advisor`
- EA: `QM5_11091_stoch-mtf-state`
- Farm claim: `3baf0d7c-6b2e-4a4c-b755-a6fafcdda4ce`
- Q02 work item: `9de11611-a9fc-4bf7-baf2-1d8762c176a3`
- Queue state at handoff: `pending`, unclaimed, attempt 0
- Queue time: `2026-08-05T20:06:22+00:00`
- Manual dispatch: `false`

This record does not infer a Q02 pass, an economic result, certification, or
permission to advance beyond the governed scheduler.

## Priority and diversity rationale

The pre-claim backlog scan found no diversity-first approved card that was
also build-authorized under the mandatory registry and magic-allocation
preconditions. The only strict build-eligible backlog item was
`QM5_10367_et-gbs-breakout`, an all-index sleeve that would add to the existing
index concentration. Approved diverse cards without their deterministic
registry allocations were not eligible for build.

The next mission priority therefore applied. `QM5_11091` covers three major-FX
pairs plus XAU, has no Q02/Q03 economic verdict or downstream phase result, and
had no open work item or competing agent claim. Its approved card cites the
public EarnForex Stochastic Multi-Timeframe repository and estimates 24
trades/year/symbol. The mechanic is deterministic H1/H4/D1 stochastic-state
alignment with an ATR stop and time exit; it contains no ML or adaptive fit.

## Preserved failure evidence

The latest bound runs for the FX and metal legs are:

- EURUSD: `D:\QM\reports\work_items\002731e7-96ff-40e8-9bc2-f12112a2aadd\QM5_11091\20260728_114741\summary.json`
- XAUUSD: `D:\QM\reports\work_items\2c4658b1-07a3-48c2-886c-7bf51c0b0767\QM5_11091\20260728_144101\summary.json`

Both Model-4 reports classify the sole attempted run as invalid with
`ONINIT_FAILED`, `BARS_ZERO`, and `INCOMPLETE_RUNS`. Both also prove the old
source/deployed EX5 and setfile were identical and stable for the duration of
the run. There are zero usable bars and no economic observations to adjudicate.

The T7 terminal history log for the same day independently records repeated
`'XAUUSD.DWX' file opening or reading error [32]` messages. This corroborates a
terminal/history-store infrastructure boundary; it does not prove that the EA
strategy caused the failure. The old artifact contract nevertheless had two
avoidable sources of retry ambiguity: a pre-current-framework `OnTick` wiring
and generated setfiles whose `build_hash` was still `pending` and whose card
defaults were not materialized.

## Minimal repair

- Added the current framework's explicit first-call MAE sampling hook.
- Moved the central news check to the entry-only path so Friday close,
  position management, and exits remain active through news windows.
- Deterministically zero-initialized each `QM_EntryRequest` before strategy
  signal evaluation.
- Recompiled a fresh EX5 against the current V5 framework.
- Regenerated all four registered-symbol backtest setfiles through the standard
  generator, including exact EA/magic identity, current build seals, and every
  approved strategy input.
- Preserved `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` in every setfile.
- Added the exact approved Strategy Card copy under the EA's `docs` directory
  and recorded the infrastructure-only revision in `SPEC.md`.

Entry thresholds, multi-timeframe state rules, ATR stop, maximum hold, symbol
set, timeframe, and trade-frequency assumptions are unchanged.

## Verification

- Strategy-spec validation: `PASS` (1/1).
- Build guardrails: `PASS`, 5 files checked, zero findings.
- Full strict build check: `PASS`, zero failures and zero warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260805_200239.json`
  (`8d187eb0a9b189db078452886365a9ae775f2046387016452d0f1101075dca4e`).
- Final strict MetaEditor compile: `PASS`, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260805_200347\QM5_11091_stoch-mtf-state.compile.log`
  (`e913763bfd470f81574c023bccdd7c09356e3b5a0ea8cf91b89ff87864c0d74f`).
- Compile summary:
  `D:\QM\reports\compile\20260805_200347\summary.csv`
  (`73d17ad4a54e8b24f6f1843430e1ba65ec8e166878321fe5716072ca68ee6ea0`).

Bound artifact SHA-256 identities:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `b3ebdc8b9e60edd24df702968b2ab51986b072e6432f66ecfdf0b45cb4ae895` |
| EX5 | `5687bd25ba1cc915bb1080016dd0b55a5dff6fdc699950c3f48d73b39cb64eee` |
| SPEC | `572fc544e8ababef3724e755eecd94c502aa2792238c8f2e51f9f3c5354ee154` |
| Approved card copy | `7b12141f208cba38b767cc4d3c5bc2f7d5ecd555110d3c81537fdbb203450846` |
| EURUSD setfile | `d3b9489b0432236daa3353e4ce43316f9bb591bb5061656d137e0a6451b44acb` |
| GBPUSD setfile | `9b214cd9cb337f00764e18add9ebf7eb63076f2586bc65375bbb8a50f12e0855` |
| USDJPY setfile | `d59688803a01474022921d79220d70946eb4f08d2066584ede38ccd27c38b283` |
| XAUUSD setfile | `14b380aee9a7a9f9f461e6860a2497bcb4c7d0b24a7934d8d20903fa247b1b80` |

## Farm coordination and CPU boundary

- Pre-claim online backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11091_claim_20260805T195827Z.sqlite`.
- Pre-enqueue online backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11091_q02_requeue_20260805T200612Z.sqlite`.
- Both backups passed SQLite `quick_check`.
- A targeted canonical dry run selected exactly one EURUSD Q02 row. The apply
  invocation inserted that one canary; GBPUSD and USDJPY were excluded by the
  symbol filter and no duplicate cohort was enqueued.
- The infrastructure-attempt cap was raised only for this materially rebuilt
  artifact cohort; no economic result was bypassed.
- `farmctl mt5-slots` reported seven managed factory terminals running, exactly
  the configured backtest CPU ceiling.
- CPU-ceiling response: queue only, then stop. No smoke test, dispatch tick,
  terminal reservation, manual tester, or pipeline phase was launched.

No `T_Live` process or file, AutoTrading setting, portfolio gate, portfolio
admission, deploy/live manifest, registry, or live setfile was changed.
