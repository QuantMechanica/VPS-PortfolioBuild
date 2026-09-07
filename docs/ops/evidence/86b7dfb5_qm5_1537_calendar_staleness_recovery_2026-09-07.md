# QM5_1537 monthly-sleeve calendar recovery review

Date: 2026-09-07  
Router task: `86b7dfb5-c40f-4e79-9400-7705790714d0`  
Branch: `agents/board-advisor`  
Verdict: **REVIEW / BLOCKED_GOVERNED_INPUT**

## Outcome

`QM5_1537` is confirmed inert on the FTMO demo for September 2026. The
installed, SHA-pinned calendar is byte-identical to the canonical v1 artifact,
but the only rows the XAG host can consume end at `202412`. Two runtime checks
for month `202609` therefore correctly failed closed with `calendar_stale`.

No calendar, EA, preset, terminal attachment, or M13 manifest was changed in
this cycle. A September row cannot be generated honestly from the available
inputs: neither active broker terminal currently has a complete, parseable
37-symbol D1 cache, while the factory custom-history source used by the v1
builder does not carry XAG beyond 2024-12-31. Partial-universe ranking would
violate the existing contract and silently change the strategy.

## Reproduced evidence

Canonical and installed calendar:

- Canonical file:
  `framework/EAs/QM5_1537_aa-vol-sma10/calendar/QM5_1537_monthly_sleeves_v1.csv`
- Canonical and installed SHA-256:
  `401E0D91E2428DAB4ABFF17C1DF651F1C7BC716B7160B71A06D1A3ECA9B5288B`
- Total rows: `3546`; XAG host rows: `87`
- XAG host coverage: `201710` through `202412`; last as-of timestamp:
  `2024-12-02T00:00:00Z`; last row has `valid_count=37`
- FILE_COMMON copies checked:
  `Common/Files/QM5_1537_monthly_sleeves_v1.csv` and
  `Common/Files/QM/calendars/QM5_1537_monthly_sleeves_v1.csv`
- Live preset copies both hash to
  `DDCFBDB3852492FA8238761B17D6B67562B5DBCA4EA3CE9C0EC7B11D4F07E369`.

The FTMO log
`MQL5/Files/QM/QM5_1537_ea-1537.log` contains:

- `2026-09-06T22:05:00.484Z`: `MONTHLY_SLEEVE_STATE`, month `202609`,
  `host_rank=-1`, `valid_count=0`, `ready=false`,
  `reject_reason=calendar_stale`.
- `2026-09-07T05:32:42.765Z`: a fresh `INIT_OK` followed by the same
  fail-closed September state. Reinitialization alone does not repair the
  missing calendar month.

## Input-source admissibility

The governed ranking contract requires all 37 symbols, a 252-return lookback,
top three selection, canonical slot tie-break, and the first host D1 bar of the
month as evaluation time. Its SHA-256 is
`314634871498688C3784984B8EA3DF35716996ACBEDC63623396FBC31D188007`.

The v1 builder reads `Daily.hc` files under
`D:/QM/mt5/T_Export/Bases/Custom/history`. Its pinned input bundle is
`B177F13D49B91B2235D9B2C1013AE46F9F2BD9798D2CBA00922AACD760E41862`.
The XAG input in that manifest ends at epoch `1735603200` (2024-12-31), so it
cannot produce an XAG host row for any 2025 or 2026 month.

Read-only probes of the currently running account terminals found:

| Candidate source | Parseable governed symbols | Missing | Finding |
|---|---:|---:|---|
| Darwinex Live `C:/QM/mt5/T_Live/MT5_Base/Bases/Darwinex-Live/history` | 13 | 24 | Incomplete; XAG is absent. Several available caches have fewer than the contract's 270 minimum bars. |
| FTMO demo `.../81A933.../bases/FTMO-Demo/History` | 8 | 29 | Incomplete and uses broker aliases. It is also a different carrier from the bound DWX ranking universe. |
| Factory custom history | 37 historically | 0 historically | Admissible for the sealed historical interval only; XAG ends 2024-12-31 and cannot support the requested live month. |
| Dukascopy backfill | n/a | n/a | Not admissible now: `OWNER-DEC-DUKASCOPY-BACKFILL-20260829` remains a deferred, per-symbol reconciliation-gated plan. |

The admissible source for a live-month refresh is therefore a new, immutable,
hash-manifested export from the native Darwinex broker history, taken through
the prior completed month. FTMO history is useful only as an independent
carrier comparison; it must not be mixed into the DWX cross-section.

## Governed recovery path

1. With AutoTrading state unchanged and without restarting any terminal, run a
   reviewed one-shot D1 exporter inside the already-running Darwinex live
   terminal. It must `SymbolSelect` the exact 37-symbol contract, use native
   broker symbols mapped to canonical `.DWX` names, export timestamp and close
   through `2026-08-31`, and write an immutable snapshot plus SHA-256 manifest.
   The receipt must bind server, account class, terminal build, canonical
   symbol mapping, first/last timestamp, bar count, and file hash for every
   symbol. Any missing symbol, fewer than 270 bars, duplicate timestamp,
   non-positive close, or last completed month before `202608` fails closed.
2. Extend `build_monthly_sleeve_calendar.py` only to consume that explicit
   manifested broker-native export. Preserve the ranking payload exactly; if
   universe, order, lookback, annualization, top-N, tie-break, or evaluation
   rule changes, this is a new strategy contract rather than a refresh.
3. Generate an append-only versioned artifact, proposed basename
   `QM5_1537_monthly_sleeves_v2_202609.csv`, plus its input manifest. Keep the
   v1 CSV and manifest. Require an XAG row for `202609` with
   `valid_count=37`, recompute the calendar SHA and input-bundle SHA, and retain
   the current contract SHA if and only if the ranking payload is byte-identical.
4. Update the EA defaults and every affected factory set/preset with the new
   basename, calendar SHA, unchanged-or-explicitly-versioned contract SHA, and
   new input-bundle SHA. Backtest sets remain `RISK_FIXED > 0` and
   `RISK_PERCENT = 0`; `qm_news_stale_max_hours` remains at most `336`.
5. Compile and run the focused calendar loader/equivalence checks. A clean
   `MONTHLY_SLEEVE_STATE` for `202609` is runtime evidence only after the exact
   reviewed bytes are installed and the EA has been reinitialized.
6. Stage the new CSV in both reviewed FILE_COMMON locations and stage the two
   M13 preset copies. Record all hashes in a new install receipt. Do not delete
   or overwrite v1.
7. Amend the M13 manifest: changing any calendar/preset pin changes the trial
   configuration identity. The OWNER must review the new identity, re-attach
   `QM5_1537` with the new preset, and control AutoTrading. No agent may toggle
   AutoTrading. Until that re-attach, the existing instance must remain
   fail-closed and inert.

## Refresh rule

Install a separate `QM_MonthlySleeveCalendar_Refresh` scheduled check at 05:30
Europe/Berlin on days 1-3 of each month. It should stage, never activate:

- Export and hash the prior completed month from native Darwinex data.
- Generate the new month only after all 37 inputs pass freshness and integrity.
- Produce an append-only CSV/manifest/preset/install-candidate bundle.
- Alert and retain the old fail-closed configuration on any defect.
- Require OWNER review/re-attach because the SHA-pinned configuration identity
  changes. The task must never launch `terminal64.exe`, change terminal state,
  attach an EA, or toggle AutoTrading.

No such monthly sleeve refresh task is currently installed. The similarly
timed `QM_NewsCalendar_Refresh` is a different data contract and must not be
repurposed.

## Sibling exposure

- `QM5_21505_xag-weekly-lowvol-momentum` is **not** in this staleness class.
  It has no external sleeve CSV. It reads a bounded completed-D1 vector from
  the chart symbol (`CopyRates`, 40 prior five-bar windows) and ranks native
  tick volume. Its relevant failure mode is insufficient/invalid XAG D1 data,
  not a SHA-pinned month table.
- `QM5_41195_aa-vol-sma10-opt` **is** in the same staleness class. Its bound
  calendar `QM5_41195_monthly_sleeves_xag_slot0_v1.csv` has SHA-256
  `80AA661E7C3389AEE83CE8CFB2B851F4DDB60323FBDF5466F4CD6EF2403C31F9`,
  3546 total rows, and the same 87 XAG rows ending at `202412`. It is not an
  M13 FTMO sleeve, but it will fail closed for a current-month XAG deployment
  until regenerated under its own XAG-slot-zero contract
  (`034223AA0965B4EFF0B72FB9519482D80F91BE3629D590538D595AFC8746082C`).

## Review disposition

Keep `QM5_1537` attached only in its current inert/fail-closed state until the
37-symbol native snapshot and resulting hashes exist. Reviewer action is to
authorize/provide the governed native export step, then route a bounded build
and install task. There is deliberately no fabricated `202609` row, no partial
`valid_count`, and no live mutation in this packet.
