# QM5_38006 Gemini build — mandatory Codex review

- Review task: `69866933-85eb-43d3-9233-c455961b7b07`
- Gemini source task: `8eb1627c-03bb-4f59-ab0a-b6c46c8a63ab`
- EA: `QM5_38006_codetrading-doji-hammer-pivot-rejection`
- Reviewed at: `2026-08-30T11:18:05Z`
- Disposition: **CHANGES_REQUIRED — remain in REVIEW**
- Pipeline verdict: **none** (this is a code-review artifact, not pipeline evidence)

## Reviewed identity and compile provenance

The reviewed files still match the Gemini build-identity artifact at
`docs/ops/evidence/8eb1627c_qm5_38006_build_identity.json`:

- MQ5 SHA-256: `7031db1a2fef63e99394dc224e96c234676d33b8130f3cddcd1c79402b8d5831`
- EX5 SHA-256: `dc90fac248aa873859bb374979d336c60e7c9474b99a3570ac3e3d7f6300624b`
- Governed `COMPILE_EA` work item: `2e0c4df5-9c1c-4498-bdb5-b49d0b785c68`
- Claimed compiler terminal: T8
- Compile result: PASS, 0 errors, 0 warnings
- Strict build check: PASS, 0 failures, 0 warnings
- Compile evidence: `D:/QM/reports/work_items/2e0c4df5-9c1c-4498-bdb5-b49d0b785c68/QM5_38006/COMPILE_EA/compile_evidence.json`

The three registered H1 set files align with active slots for EURUSD.DWX,
GBPUSD.DWX, and USDJPY.DWX. Each uses `RISK_FIXED=1000` and
`RISK_PERCENT=0`. News staleness remains fail-closed at the allowed maximum of
336 hours.

## Focused verification

- `python -m pytest tools/strategy_farm/tests/test_qm5_38006_rework_static.py -q`: **9 passed**
- `validate_build_guardrails.py` over the MQ5 and all three set files: **PASS**, no findings
- `build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_38006_codetrading-doji-hammer-pivot-rejection`: **PASS**, no failures or warnings
- Mechanical build-review prescreen: **PASS**, no problems
- EA registry row, three magic rows, symbol slots, card mirror, current MQ5 hash, and current EX5 hash: **consistent**

These automated passes do not establish strategy-card conformance for the
drawdown control below.

## Findings

### P1 — the authorized 5% total-drawdown stop is not enforced in tester mode

The approved card requires a **5.0% maximum total drawdown stop measured from
initial equity** (`strategy-seeds/cards/approved/QM5_38006_codetrading-doji-hammer-pivot-rejection.md`, section 4.2, line 113).

The EA declares `strategy_total_dd_halt_pct=5.0` and passes it as the fourth
argument to `QM_KillSwitchInit`
(`framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection/QM5_38006_codetrading-doji-hammer-pivot-rejection.mq5`, lines 50-52 and 357-361).
That fourth argument is `portfolio_dd_halt_pct`, not a local
initial-equity-drawdown calculation (`framework/include/QM/QM_KillSwitch.mqh`,
lines 469-496).

`QM_KillSwitchCheck` evaluates that threshold only through the external
`portfolio_dd.signal` channel, and the entire operator-signal block is skipped
when `MQL_TESTER` is true (`QM_KillSwitch.mqh`, lines 661-698). The remaining
local equity calculation is only the broker-day daily-loss check (lines
700-714). The EA contains no independent initial-equity total-drawdown check.

Consequently, a strategy-tester run can continue beyond the card-authorized 5%
total-drawdown boundary. Its results would not exercise the authorized risk
contract, even though the input name and static validators make the control
appear present. This blocks code acceptance and any Q02 submission.

Required repair: implement or invoke an approved framework control that records
the initial-equity baseline and halts/flattens at the configured total-drawdown
threshold in tester as well as the intended deployment context. Add a focused
test proving the tester path trips at 5.0%.

### P2 — the 2% realized-loss entry halt fails open if history selection fails

`StrategyDailyRealizedLossHalt` treats the numeric result of
`QM_ChartUITodayPnL(0, ...)` as authoritative (EA lines 170-178). The framework
helper returns `0.0` when `HistorySelect` fails and exposes no success flag
(`framework/include/QM/QM_ChartUI.mqh`, lines 169-182). In that failure case the
EA interprets unavailable history as zero realized loss and permits new entries,
contrary to the card's 2.0% daily realized-loss circuit breaker.

Required repair: make unavailable deal history produce a fail-closed entry halt
with a diagnostic event, while retaining the separate 2.5% equity hard stop.

## Re-review gate

Do not promote this Gemini build to PIPELINE. After the two findings are
repaired, regenerate the EX5 and set-file identity through governed
`COMPILE_EA`, rerun the focused static and guardrail checks, and obtain a new
mandatory Codex review. Do not weaken the 336-hour news-staleness ceiling or the
fixed-risk set-file contract. No live terminal or AutoTrading action was taken
during this review.
