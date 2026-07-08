<#
  Sunday-morning FTMO Round26 prep (OWNER request 2026-07-08: "Mach das Sonntag
  in der Frueh, takte es da ein").

  Runs prop_challenge_optimizer (preset FTMO_2STEP, worst-case DXZ+FTMO cost,
  challenge Monte-Carlo, daily/max-loss breach caps 5%) over the current
  Q12_REVIEW_READY candidate universe. read_candidates is now rework-guarded, so
  codex_review_rework-flagged builds (QM5_1556, QM5_10706) are excluded
  automatically. Produces a first-pass Round26 FTMO book ranking + combos for the
  Sunday dual-book admission session.

  NOTE: this is the STREAM-based first-pass ranker (DWX streams + FTMO worst-case
  cost). The FTMO-symbol-accurate admission of a specific sleeve still needs its
  report.htm base + `--screen-candidate` (Codex report.htm chain). The 3
  concentration-breakers (11708/EUR, 12778/Coint, 11165/EUR) are ranked here from
  streams; their report.htm screen is the follow-up at/after the session.

  Wired as scheduled task QM_FTMO_Round26_Prep_Sunday (one-time 2026-07-12 05:30).
  Does NOT touch the live FTMO trial or any trading state.
#>
$ErrorActionPreference = 'Continue'
$py    = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$tool  = 'C:\QM\repo\tools\strategy_farm\portfolio\prop_challenge_optimizer.py'
$date  = (Get-Date).ToString('yyyyMMdd')
$out   = "D:\QM\reports\portfolio\prop_challenge_ftmo_round26_sunday_$date.json"
$log   = 'D:\QM\reports\state\sunday_ftmo_round26_prep.log'
$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

"$stamp  START FTMO Round26 prep -> $out" | Out-File -Append -Encoding utf8 $log
& $py $tool --preset FTMO_2STEP --runs 300 --max-combo-size 3 --top-results 25 `
      --max-daily-breach-probability-pct 5.0 --max-max-loss-breach-probability-pct 5.0 `
      --out $out 2>&1 | Tee-Object -Variable result | Out-File -Append -Encoding utf8 $log
"$stamp  DONE exit=$LASTEXITCODE" | Out-File -Append -Encoding utf8 $log
