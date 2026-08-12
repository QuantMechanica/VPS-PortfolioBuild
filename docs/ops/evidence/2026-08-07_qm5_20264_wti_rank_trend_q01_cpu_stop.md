# QM5_20264 WTI Pairwise Rank Trend Q01 And CPU Stop

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20264_wti-rank-trend` is built and Q01 is `PASS`. Q02 is
`NOT_ENQUEUED_CPU_CEILING`: the final path-anchored capacity sample found
seven T1-T10 factory terminals executing against the paced ceiling of seven.
No Q02 work item was created, and no dispatch command, smoke test, manual
backtest, or downstream phase was run.

## Edge And Non-Duplicate Boundary

At the first WTI D1 bar of a genuine new broker month, the EA reconstructs
thirteen consecutive completed `XTIUSD.DWX` month-end closes, oldest to
newest. It compares all 78 older/newer endpoint pairs and computes the
no-tie Mann-Kendall score:

```text
S = sum(sign(P_j - P_i)) for all 0 <= i < j <= 12
tau = S / 78
```

It buys when `S >= 28`, sells when `S <= -28`, and consumes the month flat
when the score is weaker or the state is tied, malformed, nonconsecutive, or
unavailable. The fixed boundary corresponds to a continuity-corrected no-tie
normal score of approximately 1.647 for thirteen observations; it was fixed
before any QM result. One position receives a frozen `3.5*ATR(20,D1)` hard
stop and no take-profit. The package renews at the next broker month, with a
forty-calendar-day stale guard and a persisted no-retry monthly attempt.

The deterministic pre-allocation checker scanned 4,321 EA-registry rows and
438 intake cards, found no exact slug or strategy-ID collision, and returned
only expected WTI/XNG trend-source neighbors for manual review. A content scan
found no existing WTI card using Mann-Kendall, Kendall tau, or an equivalent
all-pairs concordant-minus-discordant path score. The closest WTI systems use
an endpoint return, adjacent return signs, cumulative-return votes, OLS slope
plus `R^2`, moving averages, channels, variance ratios, or calendar state.
None discards return magnitude while comparing all 78 chronological endpoint
pairs. The endpoints, no-tie rule, integer score, fixed `abs(S) >= 28` gate,
consumed attempt, and monthly renewal are jointly load-bearing.

Direct WTI provides a new energy carrier relative to the certified XAU,
SP500, NDX, and XNG book. Profitability, neutrality, and decorrelation are not
claimed; Q02 owns density and economics, and Q09 alone may measure realized
book overlap if every preceding gate passes.

## Source And G0 Record

The tier-A source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed complete-paper review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its retrieval receipt binds
the 23-page author-hosted PDF at SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The bounded WTI extraction is
`strategy-seeds/sources/MOP-WTI-RANKTREND-2026/source.md`.

The paper explicitly includes WTI and supports monthly own-price continuation
through twelve lags. It does not use this rank statistic or score boundary.
The ordinal path rule, CFD endpoint reconstruction, fixed risk, ATR stop,
spread cap, attempt ledger, and lifecycle controls are transparent QM
hypotheses. No source efficacy, density, CFD-equivalence, cost, or correlation
result transfers.

G0 authorization is
`decisions/2026-08-07_qm5_20264_wti_rank_trend_g0.md`. The deterministic
artifact/registry commit is `925666147`; the source, card, EA, SPEC, and build
card commit is `bda7d2cc4`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20264` / `wti-rank-trend`.
- Strategy ID: `MOP-TSMOM-2012_XTI_MK12_S16`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202640000`.
- EA-registry SHA-256:
  `E6C184EFDE09D292362B6B179AA9D2BB0BA94EB7673ABD1CA37F722D15652615`.
- Magic-registry SHA-256:
  `83C6FD4AB442E271B468D5721C3C22B3A70B55C89C038CCFD25DC30487000291`.
- Generated resolver SHA-256:
  `917B7AF26C48EA7A05AC1F4C0987A3D0A3CF7E1C9B879844360C7A20B5D47DF1`;
  the generator kept 15,556 rows, dropped zero, and contains magic
  `202640000`.
- Card schema/ML lint: PASS on intake, canonical, and build copies; no missing
  sections or forbidden hits.
- Build prerequisite guard: PASS for EA registry, magic row, and EA directory.
- SPEC validation: PASS, one target and zero failures.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Strict target-scoped build gate:
  `D:/QM/reports/framework/21/build_check_20260807_114805.json` (`PASS`, strict,
  zero failures and zero warnings).
- The gate's compiler invocation:
  `D:/QM/reports/compile/20260807_114805/summary.csv` (`PASS`, zero errors and
  zero warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260807_114805/QM5_20264_wti-rank-trend.compile.log`.
- EX5 size: 379,116 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; generated header build hash
  `66435551e6cacd6e82e118e678219d092f0959c94eb135fff5a8b501f7da296d`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after the Q01/capacity-stop status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `A5AE6AC763357307C55141495985BFDD8359642454B52A83D6FEAE151DAD2EEC` |
| Intake/canonical/build card | `B8720F03AECEB18DC0B36486CA5F54BF9521FE4D32E438CF5E3B7D2B078E626C` |
| MQ5 | `D9818FF297E01688D1F0098B6350A9BC202941E5D423BBD4A0DA8071DB5815E8` |
| EX5 | `D6C3308F167E90084863C1A455F3A9D5628DE6AC487D89394914BF0E37452EEA` |
| SPEC | `9E3EE04DE4353D0E364C1D52D20074601A7DDD96D55456BE7154E194E6401F66` |
| Backtest set | `BAF93F576227B203833522E49BEA06C3039301B512F370114BF12204A1A480D5` |

## Q02 Capacity Stop

The initial target-scoped dry run selected exactly one never-tested
`QM5_20264` / `XTIUSD.DWX` item, zero stranded retries, and zero deferred
promotions. A capacity sample at `2026-08-07T11:52:43+00:00` found five
governed factory terminals against the ceiling of seven. Bounded idempotent
apply attempts made no mutation because the active factory owner held the
global mutation lock. Readback remained count zero for `QM5_20264`.

Before any further apply attempt, `farmctl mt5-slots` sampled the governed
processes again at `2026-08-07T12:01:25+00:00` and found the binding 7/7 load:

| Terminal | PID | Observed phase/state |
|---|---:|---|
| T4 | 6968 | Q02, `QM5_12538` / `GBPJPY.DWX` |
| T5 | 18172 | governed Q09 live-news backfill, `QM5_10939` |
| T6 | 5504 | Q02, `QM5_10304` / `EURNZD.DWX` |
| T7 | 2096 | Q02, `QM5_9507` / `USDJPY.DWX` |
| T8 | 18376 | Q07, `QM5_11177` / `XAUUSD.DWX` |
| T9 | 13488 | Q09_NEWS, `QM5_11422` / `USDCAD.DWX` |
| T10 | 11516 | Q02, `QM5_20206` / logical XAU-XAG basket |

Only executing terminal processes rooted under
`D:/QM/mt5/T1..T10/terminal64.exe` count. The read-only command also observed
the separate `C:/QM/mt5/T_Live` and FTMO processes; those two explain its raw
`terminal64_running_count` of nine, are excluded from the paced count, and
were not accessed or changed.

Per the mission's CPU-stop condition, no further enqueue attempt was made
after the binding sample. No Q02 work-item ID exists from this task. A later
paced operator may take a fresh immediate capacity sample and, only below the
seven-terminal ceiling, use the target-scoped sweep workflow for `QM5_20264`
and `XTIUSD.DWX`. This is a ready-but-capacity-blocked handoff, not a Q02
screening verdict.

## Safety Boundary

- No successful apply-mode enqueue, dispatch tick, manual backtest, smoke
  test, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
- The unrelated pre-existing `QM5_11390` working-tree edits were preserved and
  excluded from this mission's commits.
