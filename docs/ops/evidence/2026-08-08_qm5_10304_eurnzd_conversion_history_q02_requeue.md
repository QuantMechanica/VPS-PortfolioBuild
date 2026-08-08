# QM5_10304 EURNZD Q02 Conversion-History Recovery

Date: 2026-08-08
Branch: `agents/board-advisor`
EA: `QM5_10304_narang-revert`
Lane: `EURNZD.DWX`, H4, Q02

## Selection and farm claim

The approved build backlog had no truly unbuilt forex, crypto, rates, diverse
energy, or market-neutral card that simultaneously had its required active
magic allocation and a validated DWX lane. The next mission priority was a
diverse instrument blocked at Q02 by infrastructure.

`QM5_10304` is an approved, structural H4 mean-reversion EA on a non-major FX
cross. It has no Q02 PASS and its latest EURNZD work item was terminal
`INFRA_FAIL`, with no pending or active duplicate when claimed.

- Farm claim: `b7271dd4-5743-475a-8a91-de69f1a1b597`
- Claim key: `QM5_10304|EURNZD.DWX|Q02|fx_conversion_history_warmup`
- Owner/state: `codex:agents/board-advisor` / `IN_PROGRESS`
- Source failure: `7d1b17ef-64ec-44e3-a9dd-be7db5fe010b`
- Pre-mutation DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10304_eurnzd_conversion_recovery_20260808_090927Z.sqlite`

## Diagnosis

The source row exhausted three cold-cache attempts and closed
`failed/INFRA_FAIL` with `cold_cache_retries_exhausted:BARS_ZERO`. Its summary
reported `BARS_ZERO` and `INCOMPLETE_RUNS`:

`D:\QM\reports\work_items\7d1b17ef-64ec-44e3-a9dd-be7db5fe010b\QM5_10304\20260807_223600\summary.json`

The T5 MetaTester agent log proves the EA did initialize and process real
EURNZD ticks. It then:

1. synchronized `NZDUSD.DWX`, the EURNZD quote-to-USD route;
2. reached EURNZD trade attempts;
3. first requested `EURUSD.DWX` at the 2019-09-06 entry;
4. emitted `history synchronization error [Not found]` and repeated
   `no prices for symbol EURUSD.DWX`;
5. ended the QM5_10304 test thread immediately after that deal.

The relevant agent evidence is in lines 553-604 of:

`D:\QM\mt5\T5\Tester\Agent-127.0.0.1-3004\logs\20260808.log`

This matches the framework fixed-risk implementation. For a DWX FX cross,
`QM_RiskSizerReadDwxFxSnapshot()` obtains the quote-to-account rate for tick
value and the base-to-account rate for margin. With a USD tester account,
EURNZD therefore needs both `NZDUSD.DWX` and `EURUSD.DWX`. Before this repair,
those symbols were selected only when the first trade was sized, too late for
MetaTester to establish a stable foreign-history context.

## Repair

`Strategy_WarmupDwxRiskConversions()` now resolves the same deterministic
direct/inverse conversion routes as `QM_RiskSizer` and pre-loads 300 H4 bars
once during `OnInit`.

The scope is deliberately narrow:

- tester mode only;
- fixed-risk mode only;
- six-character fiat `.DWX` pairs only;
- at most the base/account and quote/account conversion routes;
- no signal input, order route, magic slot, strategy parameter, or risk amount
  changed.

The conversion histories are data-only dependencies. The EA does not call
`QM_SymbolGuardInit()` for them, so the framework stays in single-symbol mode
and position ownership / Friday-close behavior remain scoped to the chart
instance. `SPEC.md` revision v1.1 records this boundary.

The standard strict build refreshed the shared EX5 and all 37 registered
backtest setfile build identities. Every backtest setfile remains
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Validation

- `validate_spec_doc.py`: PASS.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`.
- Strict `build_check.ps1`: PASS, 0 failures, 0 warnings.
- Strict compiler result inside build check: PASS, 0 errors, 0 warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260808_091447.json`
  (SHA-256 `ea5e37a17a086ffaa763f344aa6a096e58a1131b96d99c1cb3be8707bc55105a`).
- Compile log:
  `C:\QM\repo\framework\build\compile\20260808_091447\QM5_10304_narang-revert.compile.log`
  (SHA-256 `2054d7626c8b29521ca7b202ca476b529a3dcc3b970195202993527ccefe9841`).
- Repaired MQ5 SHA-256:
  `6518488bc3797a8e35ef2ff5c0e3dbbe4bd448d6536006a353aa51179e71cea1`.
- Repaired EX5 SHA-256:
  `715660cf09ba765379b31e53b6af2955600900cc5033bd2b09aa8bc6d9294f60`.
- EURNZD setfile SHA-256:
  `a6a325fa7983ab32d81abfacc7e8b0c6a27b6709f5e4c6efba68120ce93546da`.
- The paced pump auto-committed the rebuilt EX5 and 37 generated setfile
  identities in `8d985b02d` (`build: pump auto-commit 38 factory artifact
  path(s)`).
- Farm DB `PRAGMA quick_check`: `ok` after enqueue.

## Append-only Q02 handoff

The recent bound row `7d1b17ef-64ec-44e3-a9dd-be7db5fe010b` was not mutated.
The ordinary exact-row rerun path correctly refused because that historical
evidence is sealed to the old MQ5/EX5/setfile hashes. No row was inserted by
the refused calls.

The guarded current-build requalification path used terminal pre-binding row
`7daf6231-8258-4c08-8c45-9c0cda639cd5` to preserve the EURNZD/H4 execution
identity and appended exactly one fresh Q02 row:

- Work item: `d5741a13-a178-4bfe-aad9-78737b7b4fa6`
- Symbol/period: `EURNZD.DWX` / H4
- Risk: fixed 1000, percent 0
- Expected MQ5: `6518488bc3797a8e35ef2ff5c0e3dbbe4bd448d6536006a353aa51179e71cea1`
- Expected EX5: `715660cf09ba765379b31e53b6af2955600900cc5033bd2b09aa8bc6d9294f60`
- Expected setfile: `a6a325fa7983ab32d81abfacc7e8b0c6a27b6709f5e4c6efba68120ce93546da`
- Initial enqueue state: `pending`, unclaimed
- Normal paced-farm state at evidence capture: `active`, claimed by `T10`; the
  binary was restaged and verified against the expected hash.

The first T10 agent run supplied immediate runtime confirmation of the repair.
Lines 4729-4746 of
`D:\QM\mt5\T10\Tester\Agent-127.0.0.1-3002\logs\20260808.log` show
`NZDUSD.DWX` and `EURUSD.DWX` both selected and fully synchronized during
initialization, before EURNZD tick generation continued. This is the dependency
ordering that was absent in the failed T5 evidence; the Q02 economic verdict
was still pending at capture.

No manual smoke, `dispatch-tick`, or terminal launch was performed. The normal
paced scheduler claimed the row. Before enqueue, four `terminal64.exe`
processes were running and CPU load was 2%; after the normal claim, six were
running and CPU load was 30% on 16 logical processors. The configured backtest
CPU ceiling was not reached.

No `T_Live` file or process, AutoTrading setting, portfolio gate, deploy
manifest, or live configuration was touched.
