# QM5_13060 Q02 conversion-history repair and requeue

## Selection and claim

- Branch: `agents/board-advisor`.
- Farm coordination task:
  `4b4624c4-a32d-4542-ba89-72d04543b0ba`.
- EA: `QM5_13060_xti-eurcad-rspr`.
- Logical sleeve: D1 market-neutral WTI/EURCAD return-spread reversion.
- Failed Q02 row:
  `af535c27-7f87-4f14-8885-dcbfe477f007`.
- Failed evidence:
  `D:/QM/reports/work_items/af535c27-7f87-4f14-8885-dcbfe477f007/QM5_13060/20260724_154010/summary.json`.

The approved-build backlog had no unclaimed registry-complete forex, crypto,
rates, or new-energy card that passed the prebuild contract. This diverse
energy/FX basket was therefore selected under the mission's Q02-Q03
infrastructure-recovery priority. The claim and collision checks were recorded
atomically in the farm DB before repository changes.

## Diagnosis

The Q02 summary classified all three attempts as `BARS_ZERO` and
`INCOMPLETE_RUNS`, but the EA did not fail initialization:

- Source and deployed EX5 hashes matched and remained stable during the run.
- Both traded histories synchronized.
- The captured EA log contains 99 events and records a valid two-leg package:
  `BASKET_ORDER_ACCEPTED` for `EURCAD.DWX`, followed by `ENTRY_ACCEPTED` for
  `XTIUSD.DWX`.
- The T9 tester agent then requested `USDCAD.DWX` and `EURUSD.DWX` to value the
  EURCAD leg in the USD tester account.
- `USDCAD.DWX` synchronized, but `EURUSD.DWX` failed with
  `history synchronization error [Not found]`. The T9 controller recorded the
  corresponding `file opening or reading error [32]` sharing violation and
  discarded the completed pass as `some error after pass finished`.
- The discarded pass left a blank 0-bar report (`M0`, 1970 dates, empty expert
  and symbol), which explains the surface `BARS_ZERO` verdict.

The EA manifest and `OnInit` warmup named only the two traded legs. Conversion
history was therefore first pulled at package entry, inside the known shared
history-store lock window.

## Repair

- Added `USDCAD.DWX` and `EURUSD.DWX` to the basket manifest as history-only
  USD-account valuation dependencies.
- Declared the USD tester currency and deposit explicitly in the manifest.
- Warmed the two conversion routes with `XTIUSD.DWX` and `EURCAD.DWX` during
  `OnInit`, before any package can open.
- Preserved `XTIUSD.DWX` and `EURCAD.DWX` as the only traded legs. Registry
  slots and magic numbers are unchanged.
- Preserved the logical D1 strategy, thresholds, low-frequency cadence, and
  `RISK_FIXED=1000` / `RISK_PERCENT=0` backtest contract.

## Validation

- Conversion-manifest regression suite: `21 passed`.
- Symbol scope: `BASKET_OK`, zero violations; manifest scope is
  `XTIUSD.DWX`, `EURCAD.DWX`, `USDCAD.DWX`, and `EURUSD.DWX`.
- SPEC validation: PASS.
- Strict compile: PASS, zero errors and zero warnings.
- Compile log:
  `framework/build/compile/20260724_162821/QM5_13060_xti-eurcad-rspr.compile.log`.
- Build check: PASS, zero failures and zero warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260724_162843.json`.
- MQ5 SHA-256:
  `4f1d15c8c32a92aaa437a2b5e79d87e9789cc79a8c8c96024c30904bd456ae2b`.
- EX5 SHA-256:
  `4897eb78af2807b47a296536ebb5ccecd1ab1959943f832c8b33b3f5fc9e53b9`.
- Setfile SHA-256:
  `a11399907b46c6778059b2399e95d97bd9decaf586dfe9b242d2c7911491eb4b`.

No manual MT5 run was launched; Q02 CPU remains owned by the paced fleet.

## Queue handoff

- Pre-write online DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13060_conversion_requeue_20260724T163005Z.sqlite`
  (`PRAGMA integrity_check=ok`).
- The claimed Q02 row is reopened in place as pending with attempt count zero;
  no duplicate row is inserted.
- Runtime fields and the stale verdict/evidence binding are cleared.
- Expected MQ5, EX5, and setfile hashes are rebound to this repair.
- The four-symbol history scope is persisted while
  `traded_symbols=[XTIUSD.DWX, EURCAD.DWX]` remains explicit.
- T9 is excluded for the retry because it produced the observed sharing
  violation. Normal terminal-history eligibility checks still apply.

No portfolio gate, portfolio manifest, deploy manifest, `T_Live` path,
AutoTrading state, or live configuration was touched.
