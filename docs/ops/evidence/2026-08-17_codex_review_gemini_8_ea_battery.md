# Codex review: Gemini eight-EA battery repair

- Codex review task: `7ef88ada-0b69-41a8-985e-36857b21aa68`
- Gemini source task: `c162c123-6264-4028-9f19-84cbd81cff48`
- Source artifact: `docs/ops/evidence/2026-08-16_repair_8_eas_battery.md`
- Reviewed commit inferred from the artifact path history: `92e590b3b87279d09117dced86188da7b45d680e`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

## Findings

### 1. High: QM5_1630 consumes the cooldown before an entry succeeds

`Strategy_EntrySignal` writes `g_last_buy_entry_time` and `g_last_sell_entry_time` when it returns a request (`QM5_1630...mq5:527` and `:558`). The order is not attempted until `OnTick`, where `QM_TM_OpenPosition` is called at line 793 and its success is checked afterwards.

Therefore any rejected or otherwise unsuccessful open consumes the full 18-H4-bar same-direction cooldown even though no entry occurred. The approved card says “no re-entry ... within 18 H4 bars”; a failed request is not an entry. This can suppress roughly three days of otherwise valid signals and contaminate trade-frequency/performance evidence.

Required correction: update the direction-specific cooldown timestamp only inside the successful `QM_TM_OpenPosition` branch. Add a regression that forces one open failure and proves the next valid same-direction signal is not cooldown-blocked, while a successful open is blocked for the configured number of bars.

### 2. Medium: QM5_11897 only partially wires `strategy_timeframe`

The patch adds a parser supporting M1, M5, M15, M30, H1, H4, and D1 (`QM5_11897...mq5:56-65`) and applies the selected timeframe to indicator/bar reads. Two card rules remain hard-coded in H1-sized seconds:

- pending-order expiry uses `... * 3600` at lines 193 and 273;
- the 120-bar hard timeout uses `120 * 3600` at line 426.

Thus selecting H4 or D1 changes the signal bars but still expires/closes on an H1 clock. All current canonical setfiles select H1, so this does not alter the present baseline, but the artifact's claim that the input is “fully wired” is false and any parameter variation is internally inconsistent.

Required correction: either enforce the approved H1-only contract and reject other values, or derive these durations from `PeriodSeconds(GetStrategyTimeframe())`. Add static/runtime coverage for the chosen contract.

### 3. Evidence binding is insufficient for binary acceptance

The Gemini artifact states compile/build/guardrail results but does not record the commit hash, source hashes, EX5 hashes, report paths, or compiler log paths. The reviewed commit had to be inferred from Git history. That is not enough to authenticate the eight committed binaries for a pipeline handoff.

Codex independently verified the current source tree, but that does not retroactively bind the original binary evidence. In addition, `QM5_11897` source was subsequently changed by the separate stop-normalization review commit `3d853ab6b`, so its current repository EX5 is intentionally no longer a current-source build.

Required correction: after the code findings are fixed, produce strict compile evidence that binds each source closure and `.ex5` to the repair commit, with durable log/report paths and hashes.

## Independent checks

The following read-only/static checks were run for all eight EA labels:

- `framework/scripts/build_check.ps1 -EALabel <label> -SkipCompile`: exit 0 for 8/8.
- `validate_build_guardrails.py <eight EA directories>`: PASS for 8/8, with `qm_news_stale_max_hours` ceiling 336.
- Isolated serial DEV1 MetaEditor compilation of a repository-matching source copy: 0 errors / 0 warnings for 8/8. Logs are under `D:\QM\reports\compile\gemini_8_ea_codex_review_20260817\`.

The three host-slot changes (`QM5_10648`, `QM5_10649`, `QM5_10973`) correctly use `qm_magic_slot_offset`. The `QM5_1355` WVF/ATR/EMA parameter substitutions and `QM5_2076` bounded volume/stddev windows are consistent with their current setfile defaults. Removing the obsolete QM5_9501 W1 setfile is consistent with the previously authorized D1-native W1 rescale. These points do not override the findings above.

No source, binary, setfile, registry, resolver, work item, or pipeline state was changed by this review.
