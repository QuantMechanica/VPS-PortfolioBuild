# Ownership fix and slot-2 build

Date: 2026-07-28  
Router task: `08e241e2-3b00-494e-bc35-aabc6aec0061`

## Result

The two build blockers are cleared. The two-sleeve rerun is staged and queued. The
three-sleeve run was **not** queued because the required OWNER confirmation of
slot 2 = 13108 is not recorded.

## 1. Targeted ownership registration

`QM_FrameworkRegisterMagicSymbol(ea_id, slot, symbol)` was added at
`framework/include/QM/QM_Common.mqh:379`. It registers exactly the opted-in
magic/symbol context and kill-switch magic without enabling basket mode.
`QM_FrameworkOwnsMagicSymbol` therefore admits q08 deals for that context through
its existing context loop.

The historical `QM_MagicFor(ea_id, slot)` default path at
`QM_Common.mqh:340-378` is unchanged byte-for-byte in the source diff: the only
diff in this area is the new function appended after it. A non-opting EA,
QM5_9936, compiled successfully with 0 errors and 0 warnings. This proves the
default source path is untouched; the new behavior requires an explicit call.

QM5_20181 opts in for satellite 10145 at
`QM5_20181_ftmo-joint-multisym-timer.mq5:314` and for disabled slot 2 at line
344. Basket mode remains false, so the runner framework context is unchanged.

## 2. Slot 2 = QM5_13108 built, disabled

The `s2_*` input group is at lines 144-155 and defaults `s2_enabled=false`.
`QM20181_Run13108` at line 541 carries the gated standalone mechanics:

- XTIUSD.DWX / D1, slot 2, its own magic and persistent closed-bar key;
- 30-day cumulative-return direction;
- five-day upper/lower partial moments against separate 252-observation nearest-
  rank 80th percentiles;
- the S2 four-region map;
- ATR(20) × 3 stop, maximum hold 8 days, spread ceiling 1500;
- fixed-risk sizing and once-per-closed-D1-bar management/entry.

No three-sleeve work item was created.

## 3. The 0.999125 mechanism

This is genuine joint-account coupling, not a tick-interleaving artifact.
The prior two-sleeve logger at
`D:/QM/reports/work_items/c0192be6-2490-4f3b-ae1e-48bf6922d9e6/QM5_20181/20260728_125300/raw/run_01/logger_sample.jsonl:3234`
records, at `2020-08-11 15:52:33`, `KS_DAILY_LOSS` with account equity
155,590.03 → 150,920.04 (`-3.001471%`) and `closed_positions=1`. That forced
close is the runner's shifted exit: entry time 1597138045, 4.12 lots, net
-713.84.

The satellite's floating P/L changes the shared account equity used by
`QM_KillSwitchCheck` (`QM_KillSwitch.mqh:700-715`). Removing or sleeve-isolating
that check would falsify the joint-account measurement and weaken a fail-closed
risk rail, so no such change was made. Consequently, the strict claim that a
runner in a shared account must equal its standalone stream is structurally
incompatible with the account-level daily-loss guard on this path.

## 4. Verification and governed rerun

- QM5_9936 non-opt-in compile: 0 errors, 0 warnings.
- QM5_20181 compile: 0 errors, 0 warnings.
- MQ5 SHA-256:
  `b07f2f95155ce63b6c64f78b917be62c94daf8ad57ae8b217b91ef5444af3b89`
- Immutable staged EX5:
  `D:/QM/strategy_farm/artifacts/ex5_staging/ownership_fix_step2_9936_10145/QM5_20181_ftmo-joint-multisym-timer.ex5`
- staged EX5 SHA-256:
  `806e53c1fe94bc2cbae3ddc8de66a3add985c7ef443e0a6ab9f226083778a7cb`
- set SHA-256:
  `7d2a061f27372c2fd489e2a58867e7b7208461f70581c95dd1a1ab94fd5d312d`
- governed Q02 work item:
  `f0a3c02e-c1b1-42ec-9675-b1e600d15f78`

The work item is pending, uses Model 4, the 2018-07-02 through 2025-12-31
window, the current two-sleeve set, `skip_terminals=["T5"]`, and the immutable
staged-EX5 before/after SHA contract. No terminal was launched manually.

Verdict: **BUILD PASS; RERUN QUEUED; RUNNER-INVARIANCE GATE EXPECTED TO FAIL
HONESTLY WHEN THE SHARED-ACCOUNT KILL SWITCH COUPLES SLEEVES.**
