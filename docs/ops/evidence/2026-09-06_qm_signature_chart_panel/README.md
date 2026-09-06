# QuantMechanica Signature Chart Panel - design and acceptance

Date: 2026-09-06  
Task: `e0db4991-21ac-466a-b9f6-0cf950c57914`  
State: REVIEW  
Scope: presentation component and governed wiring plan only; no EA inventory binary,
terminal, account, preset, `T_Live`, or AutoTrading change.

## Decision

`framework/include/QM/QM_ChartPanel.mqh` is the common presentation component for
future DXZ/FTMO EA rebuilds. It starts from the compact information hierarchy of
`QM_AccountMonitor` but uses a dark slate surface, steel-blue identity rail and emerald
healthy state. It is deliberately independent of trading logic.

The component is accepted for source-level integration and fresh governed rebuilds. It
is not authorization to replace any gate-bound EX5 or deploy a rebuilt EA.

## Visual specification

The panel is a 360 x 210 px upper-left card with a 5 px steel-blue rail. The header reads
`QM | QUANTMECHANICA`. It has four scan layers:

```text
+--------------------------------------------------+
| QM | QUANTMECHANICA                              |
| EA 11421 | ohlc-daily-squeeze-reversal-d1        |
| EURUSD / D1 | MAGIC 114210000                    |
|                                                  |
| GOVERNANCE                                       |
| NEWS OPEN | FRI OK | GOV ARMED | ENV LIVE        |
|                                                  |
| RISK / EXPOSURE                                  |
| RISK_PERCENT 0.3125 | OPEN 12500.00              |
|                                                  |
| HB OK | 2026.09.06 20:10:00 | BUILD 9dd7facd     |
+--------------------------------------------------+
```

All panel strings pass through an ASCII sanitizer. Identity objects are namespaced as
`QM_SIG_<ea_id>_<magic>_*`, so multiple charts and slots do not collide. Healthy states
are emerald, blocked/fail/stale states red, and unresolved/neutral states amber.

| Token | MQL5 value | Hex | Purpose |
|---|---:|---:|---|
| background | `C'15,23,42'` | `#0F172A` | dark slate card |
| surface | `C'30,41,59'` | `#1E293B` | reserved raised surface |
| border | `C'71,85,105'` | `#475569` | quiet outline |
| text | `C'226,232,240'` | `#E2E8F0` | primary copy |
| muted | `C'148,163,184'` | `#94A3B8` | labels and context |
| steel | `C'41,84,212'` | `#2954D4` | QM identity rail |
| emerald | `C'16,185,129'` | `#10B981` | healthy/armed/open |
| amber | `C'245,158,11'` | `#F59E0B` | pending/unknown |
| red | `C'239,68,68'` | `#EF4444` | halt/block/fail/stale |
| UI font | Segoe UI | - | titles and labels |
| data font | Consolas | - | identity and state values |

## Integration contract

Each EA adds one `CQMChartPanel` instance and one opt-out input such as
`input bool qm_show_chart_panel = true`. In `OnInit`, after magic and environment are
resolved, call `Initialize(ChartID(), ea_id, slug, magic, build_hash,
qm_show_chart_panel)`. If it returns true, arm or reuse an EA timer with a minimum
five-second cadence. Populate `QMChartPanelSnapshot` from already-computed governance
state and call `Refresh` from `OnTimer`; never call it from `OnTick`. Call `Shutdown`
from `OnDeinit`.

Non-visual Strategy Tester runs are fail-inert: `Initialize` creates no objects and
returns false. Visual tester mode may render the same component for screenshots and
inspection. Exposure is a read-only sum for positions matching the logical magic. The
include has no order/trade classes or trade functions.

The EA remains authoritative for news, Friday-flat, governor, risk and heartbeat state.
The panel only renders values supplied by the EA; it must never become a second policy
engine. Build hash is injected from the governed build identity, not calculated from a
runtime file.

## Wiring plan

1. Canary the shared include in a fresh, non-deployable fixture (completed here).
2. Add the panel during the next authorized source revision of the FTMO M13 sleeves:
   `QM5_10706`, `QM5_11421`, `QM5_11422`, `QM5_11910`, `QM5_13054`, `QM5_1537`,
   `QM5_20048`, and `QM5_21505`. One chart/sleeve supplies its own magic and resolved
   native symbol. This is a new build identity and restarts at Q02.
3. Add a governor-specific view to `QM5_13206_ftmo-account-governor`; its risk line must
   show account aggregate exposure and clearly label that scope, rather than pretending
   it is one sleeve magic. This also requires its own governed rebuild/review.
4. Adopt the include in the DXZ live-book source set only when OWNER/Claude selects the
   reconciled manifest. Generate a source-hash-bound migration manifest, compile through
   the governed route, and rerun from Q02 per EA. Do not modify the active
   `portfolio_manifest_live_24sleeve_20260724` binaries in place.
5. After every new identity reaches the necessary Q gates and receives deployment
   authorization, install it in a stopped-state maintenance window. Panel rollout is
   never a reason to bypass evidence, replace an active EX5 ad hoc, or touch AutoTrading.

## MQL5 Market readiness

Market packaging is a future release track, not a verdict from this task.

- Upload one compiled EX5; bundle any auxiliary files as resources. Keep `#property
  version` in `major.minor` form and increment it for every upload.
- Inputs, output messages and screenshots must be English. The current panel is ASCII
  English and exposes no URLs, advertising, broker affiliate copy, or intrusive alerts.
- The EA must not call DLLs, include account/server-based feature restrictions, promise
  profit, or present backtests as real results. Automatic pre-testing uses Strategy
  Tester histories and checks for programming errors; panel rendering must remain inert
  in non-visual tests.
- Product description should explain strategy, risk controls and parameters calmly.
  Group long input lists logically. For screenshots, use English text, 720 px minimum on
  at least one side, at most 1920 x 1080, at most 2 MB, PNG/JPG/GIF/JPEG, maximum 12.
- Official references checked 2026-09-06:
  [Market rules](https://www.mql5.com/en/market/rules) and
  [publication guide](https://www.mql5.com/en/articles/385).

## Verification

Static acceptance:

```text
python tools/strategy_farm/chart_panel_acceptance.py
PASS: ASCII, no trade calls, no OnTick handler, tester/visual guard, timer fixture,
required display fields, object namespace, brand tokens
```

Python test:

```text
python -m pytest tools/strategy_farm/tests/test_chart_panel_acceptance.py -q
1 passed
```

Native artifact-only compile:

```text
MetaEditor: D:/QM/mt5/FTMO_STREAM1/MetaEditor64.exe
Artifact: D:/QM/ftmo/compile_probe_qm_chart_panel_20260906T2010Z
Result: 0 errors, 0 warnings
EX5 SHA-256: d5d697b996db2acb16b7960e0a3ad411d7b9b2b2545e3abc90386213c4691adb
terminal_started: false
```

The earlier fresh probe at `D:/QM/ftmo/compile_probe_qm_chart_panel_20260906T2008Z`
is retained as a negative receipt: it found four errors and four warnings, which were
fixed before the passing probe.
