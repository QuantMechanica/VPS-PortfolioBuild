# QM5_10327 (eod-reversal) / GDAXI.DWX — OnInit root-cause dig

Task: `4216dd75-6430-4ccb-b545-6c6cf6f3fd4b`. Never requeued; no verdict touched.

## Finding: the most recent attempt did NOT reproduce an OnInit rejection

The ticket title groups this pair with the other three under "ONINIT_FAILED", but the
**most recent** real-MT5 evidence for QM5_10327/GDAXI does not show that signature:

- work_item `838e5951-d2a4-4dab-98cd-6542ff29ffed`, 2026-09-15 16:27–16:57Z, verdict
  `INFRA_FAIL`.
- `evidence_path`: `D:\QM\reports\work_items\838e5951-d2a4-4dab-98cd-6542ff29ffed\QM5_10327\20260915_162732\summary.json`
- `ex5_sha256`: `af1b49c4361a7bc3e60b991f6600200dad096323b3dc1cb82b940472126c04f4`
- `oninit_failure_detected`: **`false`**
- `reason_classes`: `["TIMEOUT", "INCOMPLETE_RUNS"]` — not `ONINIT_FAILED`.
- `tester_log_decisive_lines`: `null` (no OnInit rejection line was captured because there was
  none this run — the run ran long enough to hit the tester's own timeout instead).

The worker-level log
(`D:\QM\strategy_farm\logs\work_item_838e5951-d2a4-4dab-98cd-6542ff29ffed.log`, still on disk)
is consistent with a hang/timeout rather than an immediate init rejection (contrast the
sub-19-second GDAXI/NDX runs of QM5_10369, which exit almost instantly).

The two older `INFRA_FAIL` rows for this same EA+symbol (2026-07-27/28,
`ed418b10-...`/`11ccf611-...`) predate the current disk retention window; their raw evidence
is gone, so it cannot be checked whether *those* attempts were genuine OnInit rejections or
also timeouts. The 13-attempt count in the ticket title is a farm-wide tally across all four
EA/symbol groups, not per-pair, and this pair's own history is evidently a mix of causes, not
a single deterministic one.

## Checked, not assumed

- Magic registry: `10327,eod-reversal,3,GDAXI.DWX,103270003,...,active` — present, matches the
  set file's `qm_magic_slot_offset=3`.
- Source: `grep -n "QM_InputRequire" QM5_10327_eod-reversal.mq5` → 0 hits; no source-level hard
  input pin.
- `SP500.DWX` for this EA is currently `pending` (row `94a4ff96-...`, never run to a verdict
  yet) and `NDX.DWX`/`WS30.DWX` carry a *different*, already-closed `INVALID` verdict from
  2026-08-23 (unrelated to this ticket) — GDAXI is genuinely this EA's only currently-stranded
  member.

## No fresh reproduction this cycle — why

Same Custom-history/terminal-identity constraint as the other three pairs — see
`oninit_rootcause_4216dd75.md`.

## Classification

**Disposition: `INFRA_TRANSIENT_UNCONFIRMED_ONINIT`** — this pair's current evidence does not
support an ONINIT_FAILED classification at all. It does not fit "source/setfile defect" or
"framework pin defect" (no OnInit rejection was even captured this run), and it does not fit
"dead hypothesis / RETIRE" (a TIMEOUT is not an economic/frequency verdict). Recommendation:
**leave as-is, do not fold into the ONINIT_FAILED remediation batch**; if a future attempt
reproduces the same TIMEOUT signature 2–3× in a row, that is a distinct infra investigation
(tick-sync duration / terminal load on GDAXI Custom history), not this ticket's scope. **No
requeue performed.**
