# QM5_20265 XAU/XAG Failed-Break Reversion Q01 And Q02 Handoff

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20265_xauxag-fail-rv` is built and Q01 is `PASS`. Q02 handoff status:
`WORK_ITEM_PENDING_FINAL_READBACK`.

No manual backtest, smoke test, dispatch tick, or downstream pipeline phase was
run by this task.

## Edge And Non-Duplicate Boundary

At each new `XAUUSD.DWX` D1 host bar, the EA aligns exactly sixty-two
completed XAU/XAG closes by timestamp and forms
`r = ln(XAU) - ln(XAG)`. Completed shifts 3 through 62 define a frozen
sixty-observation pre-event range. Shift 2 must close strictly outside that
range and the separate shift-1 bar must close strictly back inside it. The EA
fades an upside failure by selling XAU and buying XAG, and fades a downside
failure with the inverse package.

The package exits through the arithmetic mean of the newest twenty
synchronized completed ratios, after thirty calendar days, or on invalid
package/state. Each leg has a frozen `3.5*ATR(20,D1)` hard stop. One aggregate
`RISK_FIXED=1000` budget is split equally after per-leg stop-risk
normalization. The completed decision bar is consumed before execution gates
and persisted in a terminal Global Variable, so a failed or rejected package
cannot be retried after restart.

The deterministic pre-allocation checker scanned 4,322 EA-registry rows and
439 intake cards and returned `CLEAN`. Manual content review distinguished the
candidate from continuation-channel, z-score, return-spread, rolling OLS,
conditional-quantile, C-MTAR, and median/MAD XAU/XAG systems. In particular,
`QM5_12724_cme-xauxag-brk` follows a current 120-day breakout, while this
mechanic freezes the channel before two ordered event bars and trades opposite
the failed break.

The logical basket is a new relative-value carrier for the certified
XAU/SP500/NDX/XNG book. Market, factor, portfolio, and dollar neutrality are
not claimed. Q02 owns density and economics; Q09 alone may establish realized
decorrelation if every preceding gate passes.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-FAIL-2026/source.md`. It uses two
already approved complete repository packets: the Schweikert (2018) and Yaya,
Vo, and Olayinka (2021) peer-reviewed DOI lineage for a state-dependent
gold/silver relationship, and the governed CME Gold & Silver Ratio Spread
packet for an intermarket relative-value carrier. The channel-failure rule,
parameters, CFD mapping, risk, stops, and lifecycle are transparent QM
hypotheses; no source efficacy or futures-to-CFD equivalence transfers.

The public-source router classified a newly encountered official paper URL as
`DEFERRED:SOURCE_POLICY`. No content from that deferred retrieval was used.
G0 authorization is
`decisions/2026-08-07_qm5_20265_xauxag_fail_rv_g0.md`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20265` / `xauxag-fail-rv`.
- Strategy ID: `SCHWEIKERT-CME-XAUXAG-FAILRV-2026_S02`.
- Logical symbol: `QM5_20265_XAU_XAG_FAILRV_D1`, hosted on
  `XAUUSD.DWX` D1.
- Basket slots/magics: `XAUUSD.DWX` / 0 / `202650000` and
  `XAGUSD.DWX` / 1 / `202650001`.
- EA-registry SHA-256:
  `4ECB00008DDF401CB466D3E01E9E950CDB2C8470A876EFD89E0BBAA7FB7C7395`.
- Magic-registry SHA-256:
  `7629C1C115F7C6FAA60B5BC10D82A347AEE829151C73218B5935E0C5FE642549`.
- Generated resolver SHA-256:
  `D0A64FB6EB0EADE438E96C071F43A40FA31606E350DE083776A430C941C558C2`;
  it contains both allocated magics.
- Card schema/ML lint: PASS on intake, canonical, and build copies; no missing
  sections or forbidden hits.
- Build prerequisite guard: PASS for EA registry, both magic rows, and EA
  directory.
- SPEC validation: PASS, one target and zero failures.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `BASKET_OK`, zero violations, manifest symbols
  exactly XAU and XAG.
- Strict target-scoped build gate:
  `D:/QM/reports/framework/21/build_check_20260807_123827.json` (`PASS`, strict,
  zero failures and zero warnings).
- Final direct strict compile:
  `D:/QM/reports/compile/20260807_124703/summary.csv` (`PASS`, zero errors and
  zero warnings).
- Final compile log:
  `C:/QM/repo/framework/build/compile/20260807_124703/QM5_20265_xauxag-fail-rv.compile.log`.
- Setfile contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, D1, `2018.07.02` through `2024.12.31`; generated
  header build hash
  `a3328ba66fd3751bd64eeb7e58690b76c4abf97439ff14b0a5d44196e245a242`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after final strict compilation:

| Artifact | SHA-256 |
|---|---|
| Source packet | `1A1D172C346BE12EDE84AACF9FD5B51574944DB2B0BCF71996825583569ACA1F` |
| MQ5 | `6A0BF82074795DCC1654921060A0449DFE223E2E24C1DBE69064C002CEF86CCF` |
| EX5 runtime artifact | `2013E91E3F1B17C4F705A603A07C8C7E1CC97CBFC8905F0A1B57AD125842EA63` |
| SPEC | `152296ACF502B0F6198B8AC40903C4D2347802254E815C18C7EF0CD34B995469` |
| Backtest set | `CCA32DD4EB97C84F6D308834C50303CFC4A7F026A43CFC07C5677D9607458876` |

## Paced Q02 Handoff

The target-scoped dry run selected exactly one never-tested
`QM5_20265` / `QM5_20265_XAU_XAG_FAILRV_D1` item, zero stranded retries, and
zero deferred promotions. Early apply-mode attempts made no mutation because
the canonical scheduled controller held the global factory mutation lock.
The lock was never bypassed, deleted, or altered.

Final binding capacity sample: `PENDING_FINAL_SAMPLE`.

Final apply/readback: `PENDING_FINAL_READBACK`.

## Commits

- `0969b901b` — durable OWNER G0 authorization.
- `51e1387cc` — source packet and approved/intake cards.
- `b9c53bf22` — EA registry reservation.
- `73b95c300` — deterministic basket magic allocation.
- `c8ca9e0a7` — V5 EA, EX5, SPEC, manifest, build card, setfile, and resolver.
- `8af8c3245` — Q01 PASS status after final strict compilation.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered by this task.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
- Unrelated pre-existing and concurrent working-tree edits were preserved and
  excluded from this task's commits.
