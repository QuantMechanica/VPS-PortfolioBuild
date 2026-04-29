# QUA-524 Doc-KM Handoff (Token-Cost One-Pager)

Doc-KM request:

Mirror the generated daily markdown summary to Notion once per day:

- Source markdown pattern: `D:\QM\reports\ops\token_usage_summary_YYYY-MM-DD.md`
- Source JSON pattern: `D:\QM\reports\ops\token_usage_YYYY-MM-DD.json`
- Latest alias: `D:\QM\reports\ops\token_usage_latest.json`

Required one-pager fields:

- Alarm level (`ok` / `warn` / `critical`)
- Forecast `%` against monthly cap
- Per-agent tokens for `last_24h`, `last_7d`, `month_to_date`
- Placeholder-cap flag until OWNER cap decision lands

Boundary reminder:

- Public/redacted wording only.
- No T6/live details.
