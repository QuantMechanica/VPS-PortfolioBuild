# QM5_20230 WTI Seasonal Gap Build And Q02 CPU-Ceiling Stop

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency direct-energy candidate was researched,
approved, allocated, built, committed, and strictly validated:

- EA: `QM5_20230_wti-seas-gap`.
- Carrier: exact `XTIUSD.DWX`, D1, slot 0, magic `202300000`.
- Mechanic: at a genuine Friday-to-Monday boundary, compute the Chan-style
  prior-Friday range break with `0.10` times the sample volatility of exactly
  90 completed arithmetic D1 returns. Buy a strict upside break only in
  November-May; sell a strict downside break only in June-October. Reject an
  in-band or season-opposing open after consuming the Monday attempt.
- Lifecycle: first-following-D1 exit, two-calendar-day stale repair, frozen
  `3.0 * ATR(20,D1)` hard stop, no target, and Friday hour-21 fail-safe.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Planning cadence: 4-10 completed packages/year; Q02 must retire below five
  per year on average.

The Q02 dry run selected exactly one never-tested priority item and no
stranded/recovery item. Q02 was **not enqueued** because the active factory
terminal count exceeded the binding backtest CPU ceiling. No Q02 result,
profitability, decorrelation, certification, or portfolio-admission claim is
made.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-CHAN-WTI-SEASGAP-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply positive November-May and
  negative June-October WTI physical-season directions.
- Ernest P. Chan (2013), *Algorithmic Trading*, Chapter 7 Example 7.1,
  supplies the prior-session high/low opening-gap continuation rule, `0.10`
  multiplier, lagged 90-return volatility sample, and short lifecycle. His
  source carriers are not WTI.
- Hoelscher, Mbanga, and Nelson (2017), *Journal of Finance Issues* 16(1),
  47-68, DOI `10.58886/jfi.v16i1.2264`, supply peer-reviewed WTI weekend
  context but do not test this interaction.

No source performance, CFD basis, trade-frequency, or portfolio-correlation
claim transfers. The WTI carrier, fixed physical-season map, genuine weekend
sequence, prior-range break, lagged-volatility buffer, agreement-only
direction, and next-D1 lifecycle are jointly load-bearing.

The deterministic pre-allocation checker found no exact slug or strategy-ID
identity. Manual review separates the candidate from the all-season
`QM5_20217_wti-wkend-mom` parent, monthly seasonal systems, year-round weekday
systems, WTI gap-fill systems, and `QM5_12567`'s two-day oscillator pullback.

## Allocation And Commits

- Approved source packet and durable G0 decision: `fd55cba51`.
- Canonical card and EA-ID allocation: `d8442003b`.
- Magic slot allocation: `c524321dd`.
- Regenerated 15,505-row resolver: `4cd6637b1` (paced artifact pump).
- EA source/binary, SPEC, approved/build card copies, Q01 state, and fixed-risk
  setfile: `dd90af850`.

The registry rows are `20230,wti-seas-gap` and `XTIUSD.DWX`, slot 0, magic
`202300000`.

## Q01 Evidence

- Canonical card schema lint: PASS; no missing sections or ML hits.
- Seven-section SPEC validator: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_193626/QM5_20230_wti-seas-gap.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260805_193626/summary.csv`.
- Strict V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260805_193626.json`.
- P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_20230/P1/P1_QM5_20230_result.json`.
- EX5 size: 374,182 bytes.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Source packet | `19EFA0EA5DD64A3D288778C6C864B9FB013253C5183BEFCA23351669BD6D1018` |
| G0 decision | `1B2C301C97D931AA5E08FE2D867C2FE02AD2F143368373988C82522E9AA67CBF` |
| Canonical/approved/build card | `8C0FF289DB06F62D02933613FCA7D921D8FDE2951914D182AF9AD681C958637F` |
| MQ5 | `867227539D21DF413246DB21180AB731C20EF6FA364BD47A5FF6136138E11E63` |
| EX5 | `CE7248A517CA2B4244D7566BE11A541CA9C6A32FBE89EBE06823475A7FE7BA60` |
| SPEC | `BB2A5BF7F87B8F8B4BF8CE7AC28322628E088F61CB4442886BD85E82D71A13C2` |
| Backtest set | `43A5E669E7484FDFB87CA8BF4AA952CA9852288AB633086E083B9AAB2FCB6597` |

## Q02 Dry Run And CPU-Ceiling Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20230 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one `never_tested` item, zero skipped rows, zero
stranded rows, and one priority-track item. The queue itself had 1,518
pending items against its separate 7,000-row ceiling. Machine evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, scoped to
`QM5_20230 / XTIUSD.DWX` with `apply=false`.

At `2026-08-05T19:41:19.0451685Z`, a read-only process scan anchored exactly
to `D:\QM\mt5\T1..T10\terminal64.exe` and excluding `T_Live` found ten active
factory terminals: T1, T2, T3, T4, T5, T6, T7, T8, T9, and T10. The binding
backtest CPU ceiling is seven. The mission requires an immediate stop at that
ceiling, so no apply command, queue write, terminal action, or backtest launch
followed.

The subsequent read-only command
`python tools/strategy_farm/farmctl.py work-items --ea QM5_20230` returned
`count: 0`, confirming that no Q02 work item exists.

## Safety Boundary

- No Q02 apply or manual backtest was run.
- No live, demo, or shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- No terminal was started, stopped, reserved, reaped, or altered.
- The portfolio gate and T_Live manifest were not touched.
- Existing unrelated working-tree changes were preserved and excluded from
  every task commit.
