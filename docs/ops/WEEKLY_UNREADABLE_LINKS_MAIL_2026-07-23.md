# Weekly Unreadable-Links Mail

**OWNER authorization:** 2026-07-23

**Task:** `QM_StrategyFarm_UnreadableLinks_Friday`

**Schedule:** Friday 06:30 local (`W. Europe Standard Time`)

**Recipient:** `fabian.grabner@gmail.com`

## Purpose

Send one weekly manual-work list containing only sources that QuantMechanica's
automation could not reliably open or evaluate. This is an OWNER-requested
research-intake report. It is independent from the deliberately disabled
`QM_StrategyFarm_GmailAlarm_Hourly` PIPELINE FAIL/OK channel.

## Canonical inputs

1. Unchecked Markdown links between
   `<!-- qm-weekly-unreadable-links:start -->` and
   `<!-- qm-weekly-unreadable-links:end -->` in:

   `G:\My Drive\QuantMechanica - Company Reference\Strategie Links.md`

2. Rows in `D:\QM\reports\sourcing_intake\leads.csv` whose status indicates
   that the source itself could not be read:

   - `DEFERRED:SOURCE_POLICY`
   - `DEFERRED:ACCESS_BLOCKED*`
   - `DEFERRED:ROBOTS_BLOCKED*`
   - `DEFERRED:FETCH_ERROR*`
   - `DEFERRED:PERMISSION_REQUIRED*`
   - `DEFERRED:LOGIN_REQUIRED*`
   - `DEFERRED:TECHNICAL_RETRY*`
   - specific permanent dead-link `DEFERRED:*` reasons

`DISCOVERY_ONLY`, already EA-mapped fidelity links, `NEW`, `QUALIFIED`,
`REJECTED`, and `DEFERRED:HANDOFF_FAILED*` are excluded because they are not
proven source-access failures.

The Vault note and intake CSV are both required. Missing/corrupt sources fail
closed and trigger the Scheduler retry contract instead of sending a misleading
zero-link report.

## Delivery and duplicate control

- SMTP is delegated to `gmail_alarm._send_mail`; this job has no credential
  implementation of its own.
- The SMTP helper's canonical recipient must exactly equal
  `fabian.grabner@gmail.com`, otherwise the job fails closed.
- Before SMTP, the job atomically creates one ISO-week claim under
  `D:\QM\strategy_farm\state\weekly_unreadable_links_mail_claims`.
- The sender makes up to three bounded attempts only for failures proven to
  have happened before delivery began, with one deterministic Message-ID per
  ISO week.
- An ambiguous error after SMTP delivery starts retains the claim and is never
  retried automatically. This favors no duplicate OWNER mail over a blind
  resend when Gmail may already have accepted the message.
- Successful delivery writes
  `D:\QM\strategy_farm\state\weekly_unreadable_links_mail_state.json`.
- Gmail acceptance is written to the claim before the secondary state update.
  A recorded or claimed ISO week is not sent again, even if the process dies
  after SMTP or the later state write fails.
- A corrupt primary state or claim fails closed even if an older state backup
  exists.
- Windows Task Scheduler adds four retries at 15-minute intervals for a delayed
  G: mount or failures proven to occur before SMTP delivery.
- An empty backlog still produces the requested weekly confirmation mail.

Latest rendered evidence:

- `D:\QM\strategy_farm\dashboards\weekly_unreadable_links_mail.txt`
- `D:\QM\strategy_farm\dashboards\weekly_unreadable_links_mail.html`
- `D:\QM\reports\state\weekly_unreadable_links_mail_latest.json`
- `D:\QM\reports\state\weekly_unreadable_links_mail.jsonl`
- `C:\Windows\Temp\weekly_unreadable_links_mail.log`

## Operations

Safe render without SMTP or send-state mutation:

```powershell
cd C:\QM\repo
python tools\strategy_farm\weekly_unreadable_links_mail.py --dry-run
```

Idempotent task installation (does not start the task or send a mail):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\QM\repo\tools\strategy_farm\install_weekly_unreadable_links_task.ps1
```

Read-only scheduler verification:

```powershell
$name = 'QM_StrategyFarm_UnreadableLinks_Friday'
Get-ScheduledTask -TaskName $name
Get-ScheduledTaskInfo -TaskName $name
Export-ScheduledTask -TaskName $name
```

After manually processing a Vault link, change its checkbox from `[ ]` to
`[x]`; it disappears from the next report. For a mailbox-intake link, replace
the access-related `DEFERRED` status only after the canonical intake workflow
has a truthful terminal result.

If a failure artifact reports claim stage `ambiguous` or `in_progress`, do not
delete the claim and resend blindly. First verify the Gmail inbox/Sent mailbox
using its deterministic Message-ID. Claim removal is a deliberate manual
recovery action, never part of the scheduled path.
