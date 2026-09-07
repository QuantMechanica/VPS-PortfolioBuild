# Strategy Console v4 - QM5_11421 FTMO demo canary

- Router task: bb036699-87e0-4172-b00a-de49a14ab6b7
- OWNER package intake: 9bd0bea521
- Implementation: Astra draft, independently reviewed by Codex
- Scope: presentation-only Strategy Console v4 for QM5_11421_ohlc-daily-squeeze-reversal-d1
- Delivery state: compiled and installed to the existing FTMO demo data directory; no terminal launch, restart, chart attach, or AutoTrading mutation

## Outcome

The V5 panel is now a thin composition boundary around a typed QM_ConsoleSnapshot, a data producer, and a pure renderer:

    Strategy / V5 framework state -> QM_ConsoleSnapshot -> CQMStrategyConsole

The renderer consumes only the immutable snapshot. It does not call strategy filters, trading APIs, or the governor. CQMConsoleData owns the cached account/history/exposure reads, including a hard 30-second minimum between deal-history scans. The EA supplies only gates and facts that participate in its real admission path. UI work is timer-driven, trade transactions only invalidate data, and a View click changes presentation state for the next timer render. Tester and optimization paths bypass the visualization block.

QM_ChartPanel.mqh remains as a thin compatibility adapter. The split is:

- QM_DesignTokens.mqh: cross-platform tokens.
- QM_ConsoleModel.mqh: typed modes, states, gates, lines, exposure, snapshot, and snapshot self-test.
- QM_ConsoleData.mqh: locale formatting, history cache, broker-aware exposure, and snapshot enrichment.
- QM_StrategyConsole.mqh: deterministic, update-in-place chart renderer.

One object namespace, QM_SIG_*, owns the console and overlays. Legacy QM_ChartUI is suppressed before console initialization, so the canary cannot intentionally render two panels.

## Package reconciliation

The package asks for one restrained Today/Week strip. The OWNER's Signature Panel v3 acceptance also requires trades, EA P/L, win rate, profit factor, max drawdown, and streaks. The resulting contract is:

- FULL: fixed hierarchy, real Filter Gate and Risk sections, LIVE only when exposure exists, Today/Week strip, and the cached v3 PERFORMANCE table.
- COMPACT: brand, module/title, primary state card, Today/Week strip, and footer.
- MINIMAL: brand, primary state, and next meaningful event.

The default numeric locale remains de-DE (100.000,00 and 0,31 %). Input qm_number_locale can switch to en-US (100,000.00 and 0.31 %) without affecting trading.

QM5_11421 currently uses the legacy DXZ execution contract, so no FTMO governor is bound. The canary therefore shows neither a decorative governor gate nor invented daily/max-loss room. A conditional read-only branch exists for a future actually-bound governor contract.

## Token mapping

The automated acceptance check compares every color below with quantmechanica-design-tokens.json.

| JSON token | MQL constant | Value |
|---|---|---|
| color.carbon | QM_COLOR_CARBON | #171A21 |
| color.ink | QM_COLOR_INK | #0F172A |
| color.quantGreen | QM_COLOR_QUANT_GREEN | #0A8A5B |
| color.quantGreenDark | QM_COLOR_QUANT_GREEN_DARK | #087247 |
| color.slate | QM_COLOR_SLATE | #677185 |
| color.muted | QM_COLOR_MUTED | #8B95A7 |
| color.cloud | QM_COLOR_CLOUD | #F5F7F9 |
| color.surface | QM_COLOR_SURFACE | #FFFFFF |
| color.border | QM_COLOR_BORDER | #DCE2E8 |
| color.borderStrong | QM_COLOR_BORDER_STRONG | #C8D0DA |
| color.signalBlue | QM_COLOR_SIGNAL_BLUE | #3B6CF6 |
| color.signalBlueSoft | QM_COLOR_SIGNAL_BLUE_SOFT | #EAF1FF |
| color.positive | QM_COLOR_POSITIVE | #0B7A53 |
| color.positiveSoft | QM_COLOR_POSITIVE_SOFT | #E8F6F0 |
| color.negative | QM_COLOR_NEGATIVE | #B8454D |
| color.negativeSoft | QM_COLOR_NEGATIVE_SOFT | #FCEBEC |
| color.warning | QM_COLOR_WARNING | #996515 |
| color.warningSoft | QM_COLOR_WARNING_SOFT | #FFF4D6 |
| color.disabled | QM_COLOR_DISABLED | #A1A9B7 |
| color.disabledSoft | QM_COLOR_DISABLED_SOFT | #EEF1F4 |
| color.candleUp | QM_COLOR_CANDLE_UP | #0E9F7A |
| color.candleDown | QM_COLOR_CANDLE_DOWN | #F0545E |
| color.rangeBorder | QM_COLOR_RANGE_BORDER | #6B8FD8 |
| color.rangeFill | QM_COLOR_RANGE_FILL | #EDF3FF |

Brand strings, typography weights, all 4/8/12/16/24/32/48/64/96/128 spacing values, radii, layout limits, breakpoints, and status foreground/background aliases are also mirrored value for value.

Documented native deviations:

- MT5 chart objects do not support CSS corner radii, so native objects are square while radius tokens remain available for cross-platform parity.
- MT5 uses Segoe UI / Segoe UI Semibold because Inter is not guaranteed on the terminal host; the web font stack remains in the token header.
- Object text uses ASCII (c) instead of a copyright glyph under the ASCII-only chart-copy contract.
- The native console is 544 px wide to keep two gate columns legible; spacing rhythm, hierarchy, palette, and one-pixel separators remain package-aligned.

## Real gate inventory

| Gate | Snapshot source | Trading-path proof | Current behavior |
|---|---|---|---|
| Execution | Terminal/MQL/account expert permissions and g_qm_runtime_execution_state | V5 runtime execution contract gates order admission; display only reads state | PASS or BLOCK |
| News | g_qm_news_* loaded/available/cache verdict and wall-clock age | OnTick calls QM_NewsAllowsTrade2; display uses the same 60-second quote-cache lifetime | OFF, WAIT, PASS, BLOCK, ERROR, or STALE |
| Kill switch | g_qm_ks_halted | OnTick calls QM_KillSwitchCheck | PASS or BLOCK |
| Friday | qm_friday_close_enabled and broker weekday/hour | OnTick calls QM_FrameworkHandleFridayClose | OFF, PASS, or BLOCK |
| Spread | Live bid/ask and strategy_spread_cap_pips | OnTick calls Strategy_NoTradeFilter with the same fail-open predicate | OFF, WARN, PASS, or BLOCK |
| Capacity | Magic-scoped positions and actionable pending orders populated by CQMConsoleData | Strategy_EntrySignal refuses another setup when either exists | PASS or BLOCK |
| Squeeze | No speculative display recomputation; next D1 close is the meaningful event | Strategy_EntrySignal is sole authority for the pattern calculation | WAIT |
| Governor | Added only when QM_RuntimeExecutionGovernorRequired() is true | Immutable runtime contract plus QM_FTMO_ReadGovernorScale | Absent for this legacy-contract canary |

There is no decorative session row: this D1 strategy has no independent session/time-window admission rule. OFF remains distinct from N/A and PASS.

## Risk provenance

- Next trade: configured V5 fixed/percent risk, portfolio weight, and existing per-trade cap; a governor scale applies only when the real runtime contract requires it.
- Open exposure: magic-scoped positions priced to their actual SL with OrderCalcProfit, respecting symbol contract and account currency. Missing/unpriceable SLs are reported, not guessed.
- Stop basis: the strategy's actual previous-range multiplier and pip cap.
- LIVE: emitted only for an open position or actionable pending order; direct entry/SL/TP labels and trade markers are exposure-dependent.

## Text acceptance mockups

Values are illustrative but follow the renderer hierarchy and formatter grammar.

### FULL

    QuantMechanica                                                View
    STRATEGY CONSOLE
    OHLC Daily Squeeze Reversal | D1

    WAITING FOR SETUP                         DEMO | EURUSD.DWX
    Squeeze evaluated on the next D1 bar
    Next D1 evaluation in 04:17 | 2026-09-08 00:00 BT

    FILTER GATE
    Execution - Permission open   PASS    News - Native MT5 clear       PASS
    Kill switch - Armed           PASS    Friday - Before close         PASS
    Spread - 0,6 pip              PASS    Capacity - One slot free      PASS
    Squeeze - On D1 close         WAIT

    RISK
    Next trade                                      0,31 % | EUR 312,50
    Open exposure                                     0,00 % | EUR 0,00
    Stop basis                              Prior range x 1,50 | cap 80,0 pip

    Today  EUR +84,20 | 1 trade              Week  EUR +412,70 | 4 trades

    PERFORMANCE | THIS EA
    Trades today / attach / all                                    1 / 7 / 124
    Wins / losses | win rate                                  83 / 41 | 66,94 %
    Net P/L | attach equity                              EUR +12.345,67 | +3,09 %
    Gross profit / loss                              EUR +18.450,00 / EUR -6.104,33
    Profit factor / expectancy                                  3,02 / EUR +99,56
    Average win / loss                                   EUR +222,29 / EUR -148,89
    Max drawdown | attach equity                           EUR 2.100,00 | 0,53 %
    Streaks now / longest                                         W3 L0 / W8 L4
    Best / worst                                         EUR +780,00 / EUR -310,00
    Last closed trade                              EUR +145,20 | 2026-09-07 18:00 BT
    Account balance / equity                       EUR 100.412,70 / EUR 100.412,70

    (c) QuantMechanica                                            v5.0

No LIVE section appears in that flat-state example. When exposure exists, LIVE is inserted between RISK and the Today/Week strip and contains only real tickets.

### COMPACT

    QuantMechanica                                                View
    STRATEGY CONSOLE
    OHLC Daily Squeeze Reversal | D1

    WAITING FOR SETUP                         DEMO | EURUSD.DWX
    Squeeze evaluated on the next D1 bar
    Next D1 evaluation in 04:17 | 2026-09-08 00:00 BT

    Today  EUR +84,20 | 1 trade              Week  EUR +412,70 | 4 trades
    (c) QuantMechanica                                            v5.0

### MINIMAL

    QuantMechanica                                                View
    WAITING FOR SETUP
    Next D1 evaluation in 04:17 | 2026-09-08 00:00 BT

No license hash, login number, support copy, debug mode, or heartbeat block is rendered in any mode.

## Verification

- Focused Python tests: 8 passed in test_chart_panel_acceptance.py and test_qm5_11421_chart_panel_integration.py.
- Static acceptance: PASS, 21/21 checks including typed snapshots, renderer purity, timer-only behavior, tester/optimization bypass, deterministic namespace, update-in-place, one redraw, modes, dynamic LIVE, both formatter families, 30-second history floor, broker-aware risk, all token colors, and scheme restoration.
- Header/native compile probe: 0 errors, 0 warnings; EX5 SHA-256 b349448b42371a9177d06d8b3d634684996b52d6ae69054f6a2d90e499b92a6e.
- Final canary/native compile: 0 errors, 0 warnings; 3823 ms, X64 Regular; artifact source hash equals the canonical working source hash.
- Build guardrails: final artifact source PASS (1 file), installed preset source PASS (1 file), and complete QM5_11421 directory PASS (30 files), max_news_stale_hours=336, no findings.
- Trading-code equivalence: the focused integration test extracts Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ExitSignal, and the OnTick trading body and proves byte-for-byte equality with baseline commit db44a0983a.
- git diff --check: PASS. Target files are committed with LF blobs.

The self-test functions compile and are wired into QM_ChartPanel_compile_probe.mq5::OnInit. MetaEditor compilation does not execute OnInit. Because this run did not launch or attach a terminal, no runtime QM_CONSOLE_SELF_TESTS PASS journal line is claimed. The object counts below are source-derived expectations, not a live-chart census. Runtime screenshot, census, and View-cycle observation remain CEO/OWNER reattach checks.

Machine-readable details are in verification_receipt.json, object_census.json, and install_receipt.json.

## FTMO demo install

Only these final artifacts were copied into data directory 81A933A9AFC5DE3C23B15CAB19C63850:

- MQL5/Experts/QM_FTMO/QM5_11421_ohlc-daily-squeeze-reversal-d1.ex5
- MQL5/Presets/QM5_11421_EURUSD_D1_live_trial.set

The running FTMO terminal remained PID 21056. It was not started, stopped, restarted, or asked to attach the EA. common.ini stayed byte-identical, so the pre-existing AutoTrading setting was not changed. No T_Live or T1-T10 path was touched. The repository framework EX5 stayed byte-identical at SHA-256 9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b.

The live-trial preset retains its existing percent-risk demo contract (RISK_FIXED=0, RISK_PERCENT=0.3125). The fixed-risk requirement applies to backtest sets; every backtest set in the canary directory passes RISK_FIXED > 0 and RISK_PERCENT = 0.

## OWNER reattach instruction

1. On the existing FTMO demo EURUSD.DWX D1 chart, remove and reattach Experts/QM_FTMO/QM5_11421_ohlc-daily-squeeze-reversal-d1 without launching another terminal.
2. Load MQL5/Presets/QM5_11421_EURUSD_D1_live_trial.set; confirm FULL, 100%, de-DE, build 5be08463, exactly one QM_SIG_* console, no legacy overlap, and View cycles FULL -> COMPACT -> MINIMAL -> FULL on timer refresh.
3. Leave AutoTrading exactly as found; capture the three-mode screenshots and live QM_SIG_* object census for final CEO acceptance.

## Review boundary

This artifact is deliberately left in REVIEW. Native compilation, static/focused verification, hashes, install integrity, and trading-path equivalence are complete. Live visual acceptance and runtime self-test execution are not inferred from compilation.
