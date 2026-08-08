# QM5_20267 XNG Pairwise Rank Trend — Q01 And CPU-Ceiling Stop

Date: 2026-08-08 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20267_xng-rank-trend` is a new low-frequency natural-gas trend sleeve.
Its source-bounded card, deterministic V5 implementation, strict compile, and
single `RISK_FIXED` XNG backtest setfile completed Q01 with `PASS`.

Q02 is `NOT_ENQUEUED_CPU_CEILING`. The non-mutating sweep selected exactly one
never-tested candidate, `QM5_20267 / XNGUSD.DWX`, but the immediate
path-anchored capacity sample found nine governed T1-T10 terminals against the
paced ceiling of seven. Apply mode was not run. Immediate readback returned
zero work items for `QM5_20267`; no manual backtest or dispatch was started.

## Edge And Non-Duplicate Boundary

On the first processed D1 bar of a genuine broker-month transition, the EA
reconstructs thirteen consecutive completed `XNGUSD.DWX` month-end closes,
oldest to newest. It compares all 78 older/newer endpoint pairs and computes
the no-tie Mann-Kendall score:

```text
S = sum(sign(P_j - P_i)) for all 0 <= i < j <= 12
tau = S / 78
```

It buys when `S >= 28`, sells when `S <= -28`, and consumes the month flat
when the score is weaker or the state is tied, malformed, nonconsecutive, or
unavailable. The boundary corresponds to a continuity-corrected no-tie normal
score of approximately 1.647 for thirteen observations; it was fixed before
any QM result. One position receives a frozen `3.5 * ATR(20,D1)` hard stop and
no take-profit. The package renews at the next broker month, with a forty-day
stale guard and a persisted no-retry monthly attempt.

The pre-allocation review found no `xng-rank-trend` slug,
`MOP-TSMOM-2012_XNG_MK12_S17` identity, or XNG Mann-Kendall/all-pairs rank
mechanic. The same-source `QM5_20264_wti-rank-trend` implementation is the
locked WTI template; this XNG carrier changes no statistic or threshold.

The nearest XNG systems are materially different:

- `QM5_20262_xng-lr-trend` uses log-price OLS slope and an `R^2` gate;
- `QM5_20259_xng-mom-vote` votes on cumulative-return horizons;
- `QM5_13116_xng-signmom` counts adjacent monthly-return signs;
- `QM5_12804_xng-tsmom12m-atr` uses one endpoint return and an ATR corridor;
- certified `QM5_12567_cum-rsi2-commodity` is a long-only daily RSI(2)
  pullback with a five-bar lifecycle.

The all-pairs ordinal path, monthly symmetric direction, and one-month hold are
therefore mechanically different from the incumbent XNG sleeve. Correlation
is not claimed: Q09 alone may establish realized portfolio overlap if the
candidate survives every earlier gate.

## Source And G0 Record

The tier-A source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed complete-paper record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its receipt binds the
23-page author-hosted PDF at SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The bounded XNG mechanization is
`strategy-seeds/sources/MOP-XNG-RANKTREND-2026/source.md`.

The paper includes natural gas in its commodity universe and supports the
monthly own-price continuation family. It does not use the rank statistic or
score boundary. The ordinal state, continuous-CFD endpoints, fixed risk, ATR
stop, spread cap, attempt ledger, and lifecycle controls are transparent QM
hypotheses. No source efficacy, XNG-specific alpha, density, CFD equivalence,
or diversification claim transfers.

G0 authorization is
`decisions/2026-08-08_qm5_20267_xng_rank_trend_g0.md`.

Committed lineage:

- `816fb4cfa509cd9843fe2a3e8e9b5ea265dfc849` — source packet, approved card,
  and G0 decision;
- `239028d9b02b5b8eff7642c34a3ec039f05906a2` — EA ID reservation;
- `174ce3369d2ade8aa90baa0f7b1bf042f262af44` — EA, executable, backtest set,
  magic row, and resolver.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20267` / `xng-rank-trend`.
- Strategy ID: `MOP-TSMOM-2012_XNG_MK12_S17`.
- Symbol/slot/magic: `XNGUSD.DWX` / 0 / `202670000`.
- Magic resolver regeneration: 15,560 rows kept, zero dropped.
- Magic registry SHA-256 and resolver-embedded registry SHA:
  `456609384AFF7157CBAD5C1BA669D11D1A5960E6B56DD5B319B36D1E31334AD1`.
- Generated resolver SHA-256:
  `16ECF3D6E2D9E246B0B117CE62B5A4D6A02FB140C1228F2D628E9E761340D048`.
- Card schema/ML lint: PASS on intake, approved, and build copies; copies were
  hash-identical after status binding.
- Build prerequisite guard: PASS for registry row, magic registry, and EA
  directory.
- SPEC validation: PASS, one target and zero failures.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Strict build report:
  `D:/QM/reports/framework/21/build_check_20260808_200406.json` (`PASS`, zero
  failures and zero warnings).
- Compiler summary:
  `D:/QM/reports/compile/20260808_200407/summary.csv` (`PASS`, zero errors and
  zero warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260808_200407/QM5_20267_xng-rank-trend.compile.log`.
- P1 binary-presence validation:
  `D:/QM/reports/pipeline/QM5_20267/P1/P1_QM5_20267_result.json` (`PASS`).
- EX5 size after final compile: 379,140 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; build hash
  `9fcefb4d42d4ce826af6802e2cba9412d5104bb08a4f6906dbadeac7401da12e`.

Artifact SHA-256 values after Q01/CPU-stop status binding:

| Artifact | SHA-256 |
|---|---|
| Source packet | `8ED81D262858C5C4013DD03A0B4D156AA1B536EEE9EABFF28AF52880E1C54E9C` |
| Intake/approved/build card | `645D25A68C0DC61630324F01AB7F14EAAD6708F7FB355397044249A22CCAC945` |
| EA registry (sample-time) | `67104F1148C1F5560BB7A6E29894C0512CCFCB616654654C4BE84D100657E6E8` |
| MQ5 | `3841AA025F86FA141F3A00C6465F32F178F1FDB3B9EFC3DE3DA35E8A676D6E87` |
| EX5 | `4AF7FFEDDAEE8755A89DE52F68EB7C44F587F1370A3249A05C9E7EA4822BEF1C` |
| SPEC | `8711C73CE6DBE28181026E46E74CAEFCAAC030E7EC92D67F84EE153DC08510D0` |
| Backtest set | `36B6CD4FBEE5BE4B59846A076E55114A57A702A05C39471E34C754693C3AC0D7` |

## Q02 Dry Run And CPU Stop

The rolling sweep receipt
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, generated at
`2026-08-08T20:07:45+00:00`, records `apply=false`, queue depth 1,169 below
the 7,000-row queue ceiling, and exactly one never-tested candidate:

| EA | Symbol | Setfile | Priority |
|---|---|---|---|
| `QM5_20267` | `XNGUSD.DWX` | `QM5_20267_xng-rank-trend_XNGUSD.DWX_D1_backtest.set` | `true` |

The immediate `farmctl mt5-slots` sample at
`2026-08-08T20:08:03+00:00` found nine executable paths rooted under
`D:/QM/mt5/T1..T10/terminal64.exe`:

| Terminal | PID | Observed purpose |
|---|---:|---|
| T1 | 8540 | governed Q09 live-news backfill |
| T2 | 21076 | reserved DXZ/FTMO spread-calibration bootstrap |
| T3 | 16760 | Q02 `QM5_11313 / EURUSD.DWX` |
| T5 | 10952 | Q02 `QM5_11411 / USDCAD.DWX` |
| T6 | 18156 | pipeline run `QM5_20266` |
| T7 | 8748 | Q02 `QM5_12538 / EURJPY.DWX` |
| T8 | 20084 | Q02 `QM5_12512 / GBPUSD.DWX` |
| T9 | 17492 | Q02 `QM5_20192` logical XAU/XAG basket |
| T10 | 12052 | Q02 `QM5_11411 / AUDUSD.DWX` |

The same read-only scan observed separate `C:/QM/mt5/T_Live` and FTMO
terminal processes. They explain the raw process count of eleven, were excluded
from the factory-capacity count, and were not accessed or changed.

Nine governed terminals exceed the mission's paced ceiling of seven. Per the
explicit stop condition, no apply-mode sweep, enqueue, dispatch, retry, terminal
reservation, process action, or manual backtest followed. Immediate
`farmctl work-items --ea QM5_20267` returned `count: 0`.

## Safety Boundary

- No Q02 work item was created and no test was launched by this mission.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, stress, or optimization setfile was created.
- AutoTrading, `T_Live`, the portfolio gate, deploy manifests, and the T_Live
  manifest were not touched.
- Unrelated pre-existing working-tree edits were preserved and excluded from
  all mission commits.
