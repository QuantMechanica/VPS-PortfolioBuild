# Signature Panel v2 information architecture

- Router task: `203f9d3c-998c-48fd-a8d7-a9f8b931e90b`
- Date: `2026-09-07`
- State: `REVIEW`
- Scope: specification and source inventory only; no MQL5 source, binary, terminal, preset, or trading state changed by this task
- OWNER observation: the QM5_11421 canary displays two overlapping panels and the new panel omits decision-critical information

## Decision

Signature Panel v2 is the single EA-owned on-chart surface. When `qm_show_chart_panel=true`, the legacy `QM_ChartUI` surface must be suppressed before either renderer creates objects. The panel is a read-only view over the EA/framework's existing decisions and telemetry; it must never independently decide whether trading is allowed.

The first screen answers, in order: **may this EA trade now; if not, why; what risk room remains; what exposure exists; what happens next; is the data healthy?** Identity and product metadata remain visible but do not displace those answers.

## Current on-chart output inventory

A repository scan of non-obsolete `framework/EAs/**/*.mq5` found 3,996 source files containing `QM_ChartUI_Refresh(...)`, no direct `Comment(...)` call, and no direct `ObjectCreate(...)` call. The renderers and their lifecycle entry points are centralized as follows.

| Surface | Current content | Source locations | Ownership / issue |
|---|---|---|---|
| Legacy framework `QM_ChartUI` | Header/clock; risk placeholder and cap; open P/L; today's P/L and trade count; magic/open count; approximate news state; approximate kill-switch state; terminal AutoTrading, news/calendar status; last framework event | `framework/include/QM/QM_ChartUI.mqh:31` object namespace; `:52` rectangles; `:80` labels; `:236` header; `:256` compact line; `:273` tiles; `:339` status/last event; `:355` init; `:385` refresh; `:419` shutdown | Automatically included by `QM_Common`; several values are placeholders or inferred rather than authoritative. This is the overlapping legacy panel. |
| Framework lifecycle | Includes and starts the legacy surface for every EA, refreshes it on the framework timer, and destroys it at shutdown | `framework/include/QM/QM_Common.mqh:24`, `:334`, `:988`, `:1867` | This implicit ownership is why an EA-specific panel does not replace it automatically. |
| Signature `QM_ChartPanel` v1 | EA identity/slug, symbol/TF/magic, coarse news/Friday/governor/environment state, risk mode/value, notional exposure, heartbeat/time/build | `framework/include/QM/QM_ChartPanel.mqh:70` class; `:86` rectangle creation; `:112` label creation; `:176` initialization; `:219` refresh; `:244` shutdown | Read-only and timer-driven, but incomplete. Its `QM_SIG_*` objects overlap the legacy `QM5_UI_*` objects. |
| QM5_11421 canary wiring | Enables v1 by default, converts framework globals to a seven-field snapshot, initializes after framework init, refreshes after the framework timer, shuts down before framework shutdown | `framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5:51`, `:83`, `:85`, `:304`, `:329`, `:346`, `:408` | `QM_FrameworkInit` already creates `QM_ChartUI`; line 329 then creates `QM_ChartPanel`, causing the reported double panel. |
| Account monitor panel | Equity, balance, daily P/L/trades, open positions, last export, writer status | `framework/monitor/QM_AccountMonitor.mq5:63`, `:125`, `:140`, `:151`, `:807`, `:834` | Separate account-level program using `CAppDialog`; useful information hierarchy, not an EA overlay to suppress. |
| Account-monitor light chart theme | White/light chart colours applied at monitor init | `framework/include/QM/QM_ChartTheme.mqh:74`; `framework/monitor/QM_AccountMonitor.mq5:843` | Existing light implementation is precedent, but v2 needs snapshot/restore and common tokens shared with the panel. |
| Kill-switch overlay | No separate chart objects or `Comment`; state exists as framework globals/log events/files | `framework/include/QM/QM_KillSwitch.mqh:17`, `:445`, `:597`, `:602`, `:622` | Render the authoritative `g_qm_ks_halted` and reason in v2; do not infer a halt from P/L. |
| News overlay | No separate chart objects or `Comment`; the filter exposes loaded/available/cache/source state and performs native-calendar checks | `framework/include/QM/QM_NewsFilter.mqh:104`, `:112`, `:129`, `:843`, `:1253` | V2 needs a read-only next-event descriptor/countdown API. Current event records contain time/currency/impact but no display name. Never invent an event name. |
| FTMO governor overlay | No current panel; state is published through account-scoped terminal globals and halt files | `framework/EAs/QM5_13206_ftmo-account-governor/QM5_13206_ftmo-account-governor.mq5:353`, `:649`, `:698`, `:757` | Requires a separate account-level v2 view; never present one sleeve's magic as account scope. |

Test-only `Comment(...)` calls exist in `framework/tests/mql5/QM_PropFirm_compile_probe.mq5:24` and `:39`; they are not production EA chart output. No strategy-specific production label, news object, or kill-switch object was found outside the centralized surfaces above.

### Single-source rule

The implementation contract is explicit:

1. Add a framework-level presentation switch/function that can suppress `QM_ChartUI` creation, refresh, timer arming, and shutdown without changing its default for the rest of the fleet.
2. QM5_11421 sets that suppression before `QM_FrameworkInit` when `qm_show_chart_panel=true`.
3. If v2 initialization fails, fail presentation closed: leave the legacy panel suppressed for that session and log one clear error. Do not create both surfaces as fallback.
4. If `qm_show_chart_panel=false`, the legacy framework panel may retain its existing behavior until fleet migration is separately authorized.
5. Object census acceptance for the enabled canary: zero `QM5_UI_11421_*` objects and exactly one `QM_SIG_11421_<magic>_*` namespace. Disable/deinit must remove every `QM_SIG_*` object owned by the instance.

## Ranked information architecture

Rank is global display priority. Fields marked **required** must never be silently blank: unavailable data renders `N/A` plus a short reason.

### STATE

1. **Trading allowed: YES/NO and concrete reason — required.** This is the primary line. The value is supplied by the EA after composing terminal permission, execution contract, kill switch, account governor, news, Friday-flat, spread, session, and strategy readiness. Show the first blocking reason and a compact secondary-reason count; do not recompute precedence in the panel.
2. **News blackout — required.** Show `OPEN`, `BLOCK`, `STALE`, or `UNAVAILABLE`; while blocked show next/current event name, currency, impact and countdown to release. If the current native interface cannot supply a name, show `HIGH USD event (name unavailable)` rather than fabricating one. Include `LIVE MT5` versus `TESTER FILE` source.
3. **FTMO/account governor — required when bound.** Show `ALLOW`, `ENTRY LOCK`, `FLATTEN`, `HALT`, or `UNBOUND`, the exact governor reason, and the age of its published heartbeat.
4. **Kill switch — required.** Show `ARMED` or `HALTED: <g_qm_ks_halt_reason>` from the real kill-switch state, never an inferred threshold.
5. **Friday flat.** Show time remaining to the configured broker-time flatten boundary, or `OFF`.
6. **Spread filter.** Show current spread, cap, units, and `PASS/BLOCK`; for intentionally fail-open zero modeled spread, say `PASS (modelled zero)`.
7. **Session filter.** Show named session and `OPEN/CLOSED/N/A`; `N/A` is required when the strategy has no common session contract.

### RISK

8. **Daily-loss and max-drawdown room — required.** Show distance to the active daily and total floors in both account money and percentage. For a sleeve without a governor binding, show internal kill-switch distance and label its scope `EA`, not `ACCOUNT`.
9. **Risk mode and next-trade risk — required.** Show `RISK_FIXED` or `RISK_PERCENT`, configured amount/percent, effective amount after portfolio weight/governor scale, and applicable per-trade cap.
10. **Current exposure — required.** Show open risk-to-SL in money and percent where all positions have usable SL; otherwise show `UNPRICED/N positions without SL`. Gross notional may be secondary but must not be labeled risk.
11. **Today's realized P/L.** Money, percent of the correct day anchor, and closed-trade count, scoped to this magic.
12. **Account balance/equity.** Both values and floating delta; avoid showing equity alone because the loss-room figures need context.

### POSITION

13. **Open positions for this magic — required.** For each: symbol, BUY/SELL, lots, entry, SL, TP, floating P/L money and percent, and elapsed trade time. Netting accounts must label ticket/symbol scope correctly.
14. **Pending orders for this magic — required.** Type, lots, trigger price, SL/TP and expiry. Use `NONE` explicitly.
15. **Overflow summary.** Display at most three position/order detail lines, then `+N more`; totals remain accurate.

### NEXT

16. **Next decision point — required.** For bar-driven strategies show next bar time in broker time and countdown. For timer/event-driven strategies show the next declared evaluation boundary.
17. **Last signal result/reason — required.** Show `LONG/SHORT/NONE/BLOCKED` plus the EA-supplied mechanical reason code and timestamp. No natural-language interpretation by the panel.
18. **Last trade result.** Latest closed deal for this magic: exit time, P/L money/percent, and canonical exit reason when available.

### HEALTH

19. **Heartbeat and last-tick age — required.** Show framework heartbeat, seconds since last tick, and terminal connection `UP/DOWN`.
20. **Calendar health — required.** Source (`LIVE MT5 NATIVE` or bound tester file), age/last modification when meaningful, loaded row count/hash prefix for file data, and availability/cache state. A live native source must not display the historical file mtime as freshness.
21. **Build identity — required.** Short build/EX5 hash plus full value in the input/receipt, never a runtime guess.

### IDENTITY

22. **EA identity — required.** `QM5_<id>`, slug, `#property version`, build hash short.
23. **Chart identity — required.** Resolved symbol, timeframe, and logical magic.
24. **Environment/account — required.** `LIVE` or `DEMO` from the actual account trade mode/server, plus masked login (`****6732`). Never label all non-tester sessions `LIVE`.
25. **Market product line.** License type when exposed by `MQLInfoInteger(MQL_LICENSE_TYPE)`, product version, and `Support: MQL5 comments/messages`. No external URL, affiliate identifier, or upsell text.

## Data ownership contract

`CQMChartPanel` receives an immutable snapshot assembled by the EA/framework on the timer. The snapshot contains final strings/numbers and validity flags. It may enumerate positions, orders and history read-only for the bound magic, but it may not call trade methods, open files that affect policy, set globals, or derive an allow decision.

Authoritative producers:

- Framework/execution contract: final trading permission, first blocker, spread/session state, heartbeat, magic, risk mode and effective risk.
- `QM_NewsFilter`: calendar source/health and a new read-only event descriptor API. The display API shares the same symbol/currency/impact matching as the gate.
- `QM_KillSwitch`: halted state, exact reason, anchor, thresholds and distance calculations.
- FTMO governor globals: account-level entry lock, reason, risk scale, floor distances and heartbeat, read under the same even-generation snapshot protocol used by trading consumers.
- Terminal/account/history APIs: connection, account type, masked login, positions, orders, last deal and P/L.
- Strategy hook: next decision time and last mechanical signal reason code. Until a strategy supplies these fields, render `N/A (strategy hook absent)`.

## Density and clutter rule

The canary uses one fixed, non-interactive panel. No tabs, scrolling, click-to-trade controls, pop-ups, or collapsible state are permitted in v2. Critical information must not be hidden behind interaction.

- Maximum: 22 visible text rows at 100% DPI, including headers and footer.
- Always visible: trading permission/reason, news, governor/kill switch, loss/DD room, current exposure, heartbeat/calendar health, identity.
- Position/order details: maximum three lines total, followed by `+N more`.
- `NEXT` may use two rows; unavailable values collapse to one explicit `N/A` row.
- Do not show raw JSON, full hashes, filesystem paths, internal variable names, repeated timestamps, OHLC indicators, strategy parameters, or every historical deal.
- Use color only as a redundant state cue: every color has a text label. Red is reserved for a blocking/halt state, amber for degraded/near-limit, emerald for healthy/allowed, steel blue for identity.

## Compact text mockup

```text
| QM | QM5_11421  v5.0  BUILD 48fddf28       DEMO |
| EURUSD.DWX / D1   MAGIC 114210000   LOGIN ****6732 |
| TRADING  NO  | NEWS BLACKOUT: US CPI HIGH  00:18:42 |
| GOV ALLOW age 1s | KS ARMED | FRI FLAT 2d 04:31 |
| SPREAD PASS 0.2/2.5 pip | SESSION N/A |
| RISK FIXED $1000 -> EFFECTIVE $650 (GOV 0.65x) |
| ROOM DAILY $4,210 / 4.21% | TOTAL $9,340 / 9.34% |
| EXPOSURE SL $620 / 0.62% | BAL 101,240 | EQ 101,180 |
| TODAY +$240 / +0.24% (2 trades) |
| POS BUY 0.50 @1.17240 SL1.16000 TP1.19000 |
|     FLOAT -$60/-0.06% | OPEN 03:14:08 |
| ORD NONE |
| NEXT BAR 21:00:00 broker (00:42:13) |
| LAST SIGNAL BLOCKED: NEWS_BLACKOUT @20:15:00 |
| LAST TRADE +$310/+0.31% | EXIT STRATEGY @2026.09.06 |
| HEALTH HB OK | TICK 0.4s | CONNECTION UP |
| CAL LIVE MT5 NATIVE OK | event query age 1s |
| LICENSE FULL | Support: MQL5 comments/messages |
```

FTMO governor account-level variant:

```text
| QM | FTMO ACCOUNT GOVERNOR | POLICY FTMO_2S_P1_100K_V2 |
| ACCOUNT ****6732 / FTMO-Demo | 8 sleeves | HB 0.2s |
| ENTRY LOCK: NO | REASON ALLOW | DRY RUN OFF |
| DAILY ROOM $4,210 / 4.21% | TOTAL ROOM $9,340 / 9.34% |
| TARGET +$8,760 | DAYS 2/4 | RISK SCALE 0.65x |
| EXPOSURE 3 pos / 1 order | SL RISK $1,420 / 1.40% |
| FLATTEN NO | HALT LATCH NO | UNKNOWN MAGIC NONE |
| NEWS OPEN | FRI FLAT 2d 04:31 | CAL LIVE NATIVE OK |
| BAL 101,240 | EQ 101,180 | MIDNIGHT 100,900 |
```

The governor panel is explicitly `ACCOUNT` scope and must show policy ID, governed sleeve count, target/minimum-day progress, entry lock, flatten/halt latches, unknown exposure, effective floor distances, risk scale, and even-generation snapshot age. It must not reuse the per-magic position label.

## MQL5 Market readiness

Buyer-facing fields should answer what product/version is running, whether the license is Market/full/demo/free/time-limited, and where support is provided. Keep the line factual and English.

The current official [Market rules](https://www.mql5.com/en/market/rules) prohibit DLL calls, third-party links in the product, intrusive or advertising pop-ups, custom panels with external/affiliate links, sponsored chart labels, functional restrictions, profit promises, and presenting backtests as real results. The [official publication guide](https://www.mql5.com/en/articles/385) requires a compiled EX5, incremented `major.minor` version, English program/input/message text, bundled resources, and successful automatic Strategy Tester validation across varied conditions. Therefore v2 contains no URL, Telegram/support handle, broker affiliate, testimonial, profit claim, license restriction logic, or alert on initialization. `Support: MQL5 comments/messages` is text, not a link.

## Step-2 acceptance contract

- Light scheme from `AMENDMENT_LIGHT_SCHEME.md` is authoritative.
- `qm_show_chart_panel=true` produces exactly one on-chart information surface.
- Timer-driven refresh only; no panel work in `OnTick`; non-visual tester creates no objects and changes no chart properties.
- Chart scheme uses a separate opt-out, snapshots every modified chart property before applying, and restores that exact snapshot on deinit only if applied by this instance.
- Source scan/object census proves legacy suppression and complete v2 cleanup.
- QM5_11421 strategy entry/exit/sizing/news/Friday/kill-switch logic is byte-for-byte unchanged outside presentation wiring.
- Build is artifact-only; canonical `framework/EAs/*.ex5` files remain untouched.
- Any demo install is limited to the explicitly named FTMO demo folder with pre-install backup and receipt. No terminal launch, chart attachment, AutoTrading change, or live install.
