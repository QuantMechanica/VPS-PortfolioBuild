## QUA-579 closeout (WAKE FILTER in Observability-SRE prompt)

Patched and verified in this heartbeat.

- Target file: `paperclip-prompts/observability-sre.md`
- WAKE FILTER block now uses the required event wording at line 71:
  - `When woken via \`comment_added\` event, check the source comment's author.`
- Self-author guard remains present at line 72.
- Anti-loop guard line remains present at line 68.

Change applied:
- Replaced prior broad event phrasing with the audit-required verbatim `comment_added` sentence.

