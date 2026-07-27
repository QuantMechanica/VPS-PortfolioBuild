# Joint FTMO Backtest-Only EA — BUILD (2026-07-27)

Branch `agents/board-advisor`. Author: Claude. Built per the design
(`2026-07-27_joint_backtest_ea_design.md`) as **corrected by** the binding
adversarial review (`2026-07-27_joint_backtest_ea_adversarial_review.md`). Where
the two conflict, the review wins (task instruction).

## 0. Verdict

**Built USDJPY-only** — the two gate-clean, intraday-flat USDJPY sleeves QM5_9936
(lead) + QM5_13213 (same-edge probe) on ONE simulated $100k account, one tester
run. The design's third sleeve (10848:XAUUSD) is **dropped**, per the review's
CRITICAL findings C1–C4: a per-tick-managed non-host foreign symbol driven off
the host's tick stream measures a *different* strategy (C1), is invisible to the
design's only fidelity control (C2), and biases the −5% daily read optimistically
(C4). Both USDJPY sleeves are host-symbol, so none of those failures arise and
singleton replay is a valid control.

- **ea_id** 20180 · **slug** `ftmo-joint-sim-backtest-only` · host **USDJPY.DWX** · H1
- magics `201800000` (slot 0 = 9936), `201800001` (slot 1 = 13213), both USDJPY.DWX
- **Compile: PASS, 0 errors, 0 warnings** (canonical `compile_one.ps1`; run tag
  `20260727_100733`; log `framework/build/compile/20260727_100733/…compile.log`).

## 1. What was built

| path | role |
|---|---|
| `framework/EAs/QM5_20180_ftmo-joint-sim-backtest-only/QM5_20180_ftmo-joint-sim-backtest-only.mq5` | the joint EA |
| `framework/include/QM/modules/QM_Mod_FtmoJointRangeBreakout_20180.mqh` | COPIED, per-sleeve range-breakout logic (9936/13213) |
| `framework/include/QM/modules/QM_Mod_FtmoJointEquitySampler_20180.mqh` | per-bar + intraday-low account-equity export |
| `…/sets/…_USDJPY.DWX_H1_backtest.set` | joint run (both sleeves) |
| `…/sets/…_USDJPY.DWX_H1_replay_s0.set` | fidelity control: sleeve 0 only |
| `…/sets/…_USDJPY.DWX_H1_replay_s1.set` | fidelity control: sleeve 1 only |
| `framework/registry/ea_id_registry.csv` (row 20180, status `backtest-only`) | registry |
| `framework/registry/magic_numbers.csv` (2 rows, status `active`) | magics |
| `framework/include/QM/QM_MagicResolver.mqh` (regenerated, 15208→15210 rows) | resolver |
| `tools/strategy_farm/compare_joint_replay.py` | fidelity diff (requirement #3) |

**Architecture (deviation from the design, following the review).** The design
routed every leg through `QM_BasketOpenPosition` for "one code path" and to serve
the non-host XAUUSD sleeve. With XAUUSD dropped, both sleeves are host-symbol, so
entries use the **`QM_Entry` explicit-magic overload** (`QM_TradeManagement.mqh:276`,
`QM_Entry.mqh:225-237`) instead: sleeve 0 opens through the DEFAULT path
(`explicit_magic=0`) — **byte-identical to standalone 9936** — and sleeve 1
through the explicit-magic path. This is strictly *higher* fidelity than the
basket path (it removes the design §3.2 divergence-1/2 risks entirely: same
sizing, same news gate, same code) and needs **no basket mode, no history warmup,
no basket manifest** (design §8.2/§8.3 hazards do not arise for a single-symbol
run). Ownership of slot-1's magic in the Q08 stream is secured by `QM_MagicFor`
(`QM_Common.mqh:340-377`, binds slot→`_Symbol` in `g_qm_fw_magic_contexts` and
registers it with the kill-switch, which the explicit-magic path requires).

## 2. Fidelity mechanism (requirement #3, part 1) — implemented

The sleeve logic is a **COPY** of the gated 9936/13213 algorithm into a private
20180-namespaced module; the gated EAs are **not** touched (review H2). Verified
by reading both gated sources in full (`QM5_9936….mq5:197-416`,
`QM5_13213….mq5:198-420`): the two are line-for-line identical **except** the
window/cancel/close hours. The module reproduces both by parameterising
`(range_start_hr, range_end_hr, cancel_hr, close_hr, atr_period, min/max_range_atr_mult,
trail_trigger_r, range_scan_bars, magic, explicit_magic, slot, reason_prefix)`
per sleeve. Correspondence (module fn → gated source):

| module (`QM_Mod_FtmoJointRangeBreakout_20180.mqh`) | 9936 | 13213 |
|---|---|---|
| `QM_FJ_RB_Gmt3DayKey/Hour` | :100-116 | :101-117 |
| `QM_FJ_RB_BuildRangeForToday` | :197-224 | :198-225 |
| `QM_FJ_RB_TryEntry` (both stop legs) | :267-317 + caller :546-551 | :267-318 + caller :517-522 |
| `QM_FJ_RB_ManageOpenPosition` (cancel-at-hr, cancel-opposite, +1R 2-bar trail) | :321-383 | :322-386 |
| `QM_FJ_RB_ExitSignal` (close-hr or opposite touch) | :387-416 | :390-420 |

A normalized structural diff of the trailing-stop core (the strategy's primary
risk control) against 9936 shows only the injected `p`/`st` parameters and
cosmetic line-wraps — no arithmetic change.

**Review M2 (13213 cancel/close) is handled correctly.** 13213 uses ONE evening
hour for **both** the pending-cancel (`13213….mq5:330`) and the session close
(`:396`), whereas 9936 uses two (cancel=13 `:327`, close=20 `:392`). The design's
"bind the rest to 9936's defaults" recipe would have wrongly set 13213's cancel
hour to 13. The joint EA binds sleeve 1 to `s1_cancel_hr=18`, `s1_close_hr=18`
(the set file and inputs make this explicit).

**The four §3.2 divergence points** between the QM_Entry and basket paths do not
apply, because BOTH sleeves use the QM_Entry path on the host symbol:
1. **Sizing** — identical `QM_LotsForRiskAtEntry`; RISK_FIXED=1000 with the
   frozen $1000 cap (1% of the $100k deposit, `QM_Common.mqh:179`,
   `QM_RiskSizer.mqh:99-116`) → not clamped, exact.
2. **News** — one `QM_NewsAllowsTrade2(_Symbol,…PRE30_POST30,DXZ)` gate serves
   both sleeves (both USDJPY), identical to each gated source's gate.
3. **Friday close** — `QM_FrameworkHandleFridayClose` closes all owned positions
   per (symbol,magic) (`QM_Common.mqh:646`); both magics are owned via
   `QM_MagicFor`, so each sleeve is Friday-closed exactly as standalone.
4. **Stop fills** — deterministic price-crossing events under Model 4; both paths
   use `type_time=GTC`.

## 3. Fidelity PROOF (requirement #3, part 2) — empirical match rate NOT ESTABLISHED

**Tooling built and validated.** `tools/strategy_farm/compare_joint_replay.py`
diffs a joint-singleton Q08 stream against a gated sleeve stream on the
re-magick-invariant identity `(entry_time, close_time, net, volume)` and reports
the match rate. Self-test on the gated streams:

- 9936 vs 9936 → `match_rate 1.0` (1252/1252) — sanity pass.
- 9936 vs 13213 → `match_rate 0.169` (269/1252 coincidental) — see below.

**Empirical singleton-replay match rate: NOT ESTABLISHED (controlled run pending).**
It was **not** run in this session, for concrete, evidence-based reasons:
1. A bit-for-bit compare against the *gated* streams needs the factory
   phase-runner's exact `.DWX` commission config. A real work-item `tester.ini`
   (`…/QM5_12814/…/tester.ini`) carries **no** commission/groups line, so
   commission is baked into the imported custom symbol; a hand-rolled ad-hoc run
   with a different symbol/commission would yield a **false mismatch** — a
   fabricated finding, which the task forbids ("a low match rate is a finding to
   report, not something to tune away" — and, by symmetry, a misconfigured
   mismatch must not be reported as one).
2. The methodologically clean "cost-cancels-out" alternative (run standalone
   9936/13213 too, same sandbox) would write `9936_/13213_USDJPY_DWX.jsonl` into
   the **machine-wide shared** `Common\Files\QM\q08_trades` (FILE_COMMON,
   `QM_Common.mqh:968`) that the **actively-running factory** reads — disrupting
   it (5 terminals were busy at build time). Constraint: do not disrupt factory
   backtests.
3. Only the new `20180_USDJPY_DWX.jsonl` file is conflict-free, but comparing it
   to the existing gated streams reintroduces the commission-config uncertainty
   of (1).

**Ready-to-run protocol** (execute on a quiet fleet window, or via the factory
phase-runner which already handles Common-stream compare-and-swap). For each
sleeve S ∈ {s0→9936, s1→13213}: run the joint EA with the `_replay_S.set` on
USDJPY.DWX H1, Model 4, Deposit 100000 USD, Leverage 100, over the gated window
(2017.10 → 2025.12), harvest `Common\Files\QM\q08_trades\20180_USDJPY_DWX.jsonl`,
then:
```
python tools/strategy_farm/compare_joint_replay.py \
  --joint <harvested 20180_USDJPY_DWX.jsonl> \
  --gated D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/<9936|13213>_USDJPY_DWX.jsonl
```
Admission gate (design §3.3): a sleeve is admitted to the joint run only if it
replays `match_rate = 1.0` (net to the cent, volume to the step). A low rate is a
finding, not something to tune away.

**Static fidelity confidence is high** (line-for-line copy + identical QM_Entry
code path + enumerated §3.2 non-divergences), but the empirical bit-for-bit
confirmation is explicitly OPEN.

## 4. Equity export (requirement #4) — primary deliverable, implemented

`QM_Mod_FtmoJointEquitySampler_20180.mqh` writes host-keyed
`Common\Files\QM\q08_equity\20180_USDJPY_DWX.jsonl`, mirroring the Q08 stream's
file conventions (FILE_COMMON, persistent handle truncated once, buffered append
flushed at ~32 KB + shutdown, `QM_Common.mqh:952-979`). Two row types:
- `EQUITY_BAR` — one per host H1 closed bar; `equity`, `balance`, `fl_total`, and
  a per-sleeve floating-P&L breakdown `fl:[{magic,f}…]`.
- `EQUITY_LOW` — every new intraday (per-broker-day) low of `ACCOUNT_EQUITY`, plus
  a day-rollover anchor.

From this the FTMO predicates are exact reads at any post-hoc leverage vector `k`
(RISK_FIXED linearity, design §6; `QM_RiskSizer.mqh:99-116`): −5% daily from
`EQUITY_LOW`, −10% total from the running min, +10%/+5% first-passage from the
balance path, all re-levered via `equity_k(t)=balance_k(t)+Σ_s k_s·floating_s(t)`.
**RECORD, not ENFORCE** (`prop_phase=OFF`): enforcing would truncate the very path
being measured (design §7). Review **C4 does NOT apply** — USDJPY-only means every
tick is a host tick, so the account-equity low (which includes both sleeves'
floating USDJPY P&L) is sampled at full tick resolution, no cross-symbol
under-sampling.

## 5. Every confirmed review finding — addressed or N/A

| # | finding | disposition |
|---|---|---|
| **C1** | non-host per-tick management (10848) is unfaithful | **removed** — XAUUSD sleeve dropped; both sleeves host-symbol |
| **C2** | replay can't see C1 | **removed** — no non-host sleeve; USDJPY replay is a valid control |
| **C3** | no host makes all faithful; chosen host worst | **removed** — only USDJPY sleeves; both host-symbol |
| **C4** | equity export under-samples the intraday low | **does not apply** — USDJPY-only ⇒ every tick is a host tick (§4) |
| **H1** | correlation contaminated + 9936↔13213 tautology | **acknowledged, not overclaimed** — cross-asset correlation not produced (no XAUUSD); the 9936↔13213 number is reported as descriptive near-collinearity, NOT independent-alpha evidence. The gated streams already share **269 bit-identical trades** (compare tool), direct evidence of the tautology H1 named. |
| **H2** | next step recompiles gated 9936/13213 | **avoided** — logic COPIED into a private module; gated EAs untouched |
| **M1** | "do not re-implement" contradicts the mechanism | for the USDJPY sleeves the copy is a faithful transcription covered by replay; the XAUUSD re-implementation M1 warned about is gone |
| **M2** | 13213 cancel/close recipe defective | **fixed** — independent `cancel_hr`/`close_hr`; sleeve 1 = 18/18 (§2) |
| **M3** | per-tick equity sampler cost not budgeted | **mitigated** — the O(PositionsTotal) scan runs only on emit (new bar / new low), not unconditionally every tick; per-tick path is one `ACCOUNT_EQUITY` read + compare |
| **M4** | registering as active basket EA makes it pipeline-routable | **mitigated three ways** — (a) NOT registered in `multisymbol_eas.txt`, NO basket manifest (single-symbol run); (b) ea_id_registry status = `backtest-only` (not `active`); (c) structural OnInit guard refuses live/percent/enforcing configs |
| **L1** | §8.1 tick-timing claim contradictory | moot — instrument runs at stress 0 only (guarded in OnInit) |
| **L2** | backtest-only is set-file, not compile-time | **hardened** — OnInit refuses `!MQL_TESTER`, `RISK_PERCENT>0`, `prop_phase!=OFF`, `stress!=0`; ships no live/demo set, no deploy manifest |

**Survivals** (review "What SURVIVES") are all used: magic/registry model (1);
basket-mode trade capture — here replaced by the simpler, equivalent `QM_MagicFor`
context ownership on the host symbol (2); RISK_FIXED linearity (3); FILE_COMMON
determinism (4); history/cost baseline — USDJPY.DWX full coverage, no re-import
(5); record-not-enforce (6); and the USDJPY-only instrument itself (7).

## 6. Set file — derived from the gated sets (requirement #6), with diff

`…_H1_backtest.set` carries RISK_FIXED=1000 / RISK_PERCENT=0 / PORTFOLIO_WEIGHT=1
verbatim from both gated `_backtest.set` files, and re-namespaces their strategy
params `s0_*` (from 9936) / `s1_*` (from 13213). Diff vs the two sources:

- **s0_\*** ≡ 9936 `_backtest.set` values: range 1–6, cancel 13, close 20, atr 14,
  mult 0.4/2.5, trail 1.0, scan 36. (renamed only)
- **s1_\*** ≡ 13213 `_backtest.set` values: range 3–6, **cancel 18, close 18**
  (13213 sets `strategy_exit_hour=18`; the rest inherit 13213's input defaults,
  identical to 9936's — atr 14, mult 0.4/2.5, trail 1.0, scan 36).
- **News**: both source sets set NO news inputs (they use the EA defaults
  PRE30_POST30 + DXZ). The joint EA carries the identical input defaults; the set
  likewise does not override them — news is **preserved** exactly.
- **Added**: `s0_enabled/s1_enabled` (sleeve toggles for replay),
  `qm_risk_cap_pct=1.0` (framework default), `qm_stress_reject_probability=0.0`.
- **Not present**: any `RISK_PERCENT>0`, any `ftmo_*`/`prop_phase`/live/demo line —
  by design (backtest-only).

## 7. Order-of-operations followed (requirement #5)

dirs (EA dir created) → CSV rows (ea_id + 2 magic rows) →
`update_magic_resolver.py` (never hand-edited the `.mqh`) → verify (15210 rows;
201800000/201800001 present; `QM_MagicRegistered` will resolve) → compile. Run
serially (single regen; magic-resolver race respected). **Note:** the build pump
auto-committed the registry+resolver+backtest.set into `fb399355d` before I could
— content verified correct — and the hand-authored source (.mq5, modules, SPEC,
replay sets, .ex5) was committed under the semantic label `e40e3b94d`.

## 8. Status / risks / next step

- **Status.** Build complete and compiled (0/0). Fidelity mechanism + equity
  export implemented. Comparison tooling built and self-validated. Committed
  (`e40e3b94d`; registry in `fb399355d`).
- **Risks / open.** (a) **Empirical singleton-replay match rate is NOT
  ESTABLISHED** — it needs one controlled run per sleeve on the proper harness
  (cost-config + shared-Common + factory-saturation reasons, §3); static
  confidence is high but not a substitute. (b) The joint 2-sleeve run (equity
  path + realised 9936↔13213 correlation) is likewise pending. (c) H1 stands:
  the 9936↔13213 correlation is near-collinear by construction (269 bit-identical
  gated trades already) and must not be read as independent-alpha evidence.
- **Next step.** On a quiet fleet window (or via the factory phase-runner, which
  protects the shared Common stream): run `_replay_s0`/`_replay_s1`, diff with
  `compare_joint_replay.py`, admit each sleeve only at match_rate 1.0, then run
  the 2-sleeve `backtest.set` and post-analyse `20180_USDJPY_DWX.jsonl`
  (equity) + `q08_trades/20180_USDJPY_DWX.jsonl` (per-sleeve realised P&L +
  correlation) at the chosen leverage vector.
