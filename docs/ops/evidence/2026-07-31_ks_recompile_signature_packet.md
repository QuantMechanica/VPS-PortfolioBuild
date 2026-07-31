# KS vintage recompile — unsigned OWNER signature packet

**Status:** UNSIGNED — NO DEPLOY AUTHORITY

**Prepared:** 2026-07-31

**Router task:** c6a2cfdf-8996-4894-9f5d-889a1f8ffbc7

**Reviewer required:** Claude

**Permitted action after both review and OWNER signature:** the seven-file,
file-side Sunday deployment described below.

This packet authorizes nothing while the signature fields remain empty. It does
not authorize an AutoTrading change, a manual terminal start, a T1–T10
interruption, a preset or baseline rewrite, an adjudication-overlay append, or
any registry change beyond committed cleanup 6fbebcd2d.

## Decision presented to OWNER

The proposed deployment replaces seven old T_Live EX5 files serving nine chart
identities with seven serially compiled, zero-error/zero-warning binaries from
the immutable stage. It is **not a KS-only rebuild**: the behavioral riders
below are part of the decision.

The build gate is complete, but the original off-live
KS_BASELINE_LOADED-9/9 gate is impossible by design. Claude's approved reviewer
revision therefore requires:

1. the bounded Strategy Tester init-chain smoke already recorded;
2. the include-lineage proof in this packet; and
3. KS_BASELINE_LOADED for all nine identities as the **first** post-deploy
   verification in the Sunday market-closed window, with verified rollback
   preimages already backed up.

Any mismatch is fail-explicit. There is no deploy authority until Claude has
reviewed this completed packet and OWNER has signed the still-empty fields at
the end.

## Bound evidence and immutable build

The controlling build record is
docs/ops/evidence/2026-07-31_ks_vintage_recompile_manifest_STAGE2_UNSIGNED.json,
SHA-256
ee12f5097816e60de68d6ff30b60cbc8a401062f7b471c8052a875c5c0950fcc.
It remains correctly labelled unsigned; an OWNER signature on this packet
would bind that exact byte sequence, not silently edit or supersede it.

Supporting records:

| Record | SHA-256 |
|---|---|
| docs/ops/evidence/2026-07-31_ks_recompile_stage2.md | d09409aa80562ae2d83a6166cb1a4e24c7b902d4477964b54cafffcba35edcb5 |
| docs/ops/evidence/2026-07-31_ks_vintage_recompile_plan.md | 443d637cf85e1bb7c803934195b6aca8dc3cb5d736430e1e6d2722e79c55c81c |
| docs/ops/evidence/2026-07-31_ks_vintage_recompile_mnt_bill_PROPOSED.json | 1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1 |

Source lock:

- source commit:
  386151841013afbaf01fe10b23e6cf7538480b71;
- clean detached build worktree:
  C:/QM/worktrees/ks-recompile-stage2-386151841;
- guardrail result: PASS for all seven EAs, zero findings,
  qm_news_stale_max_hours never above 336;
- compiler: D:/QM/mt5/T1/metaeditor64.exe, version 5.0.0.6061,
  SHA-256 bc62cabf758c7debf30073bb8e20c2b5a673bef4104eb856952aae77271cee23;
- compilation: serial, 7/7, zero errors, zero warnings;
- immutable stage:
  D:/QM/strategy_farm/artifacts/ks_vintage_recompile_stage2_20260731_386151841;
- each closure has 29 repository members plus the bound platform include
  Trade/Trade.mqh; there are no unresolved repository includes.

The target root is
C:/QM/mt5/T_Live/MT5_Base/MQL5/Experts/Live EAs. In the table, the staged
file and intended target use the displayed label plus .ex5. The staged hash is
also the required post-copy target hash. The build receipts bind each MQ5 byte
stream and recursive closure to the compiler-produced EX5; the immutable-stage
copy has that same EX5 hash, and the intended T_Live target must acquire that
same hash. This is the final source → closure → Factory EX5 → immutable stage
→ T_Live-target chain.

| EA / label | MQ5 SHA-256 | closure aggregate SHA-256 | staged EX5 / required target SHA-256 | current T_Live preimage SHA-256 |
|---|---|---|---|---|
| 10911 / QM5_10911_grimes-complex-pb | b874d6a025f9f4a29ca42ed5f7c5f7f5497ff0237b7fb924b4f17bdbf5fa2ef4 | f00283000624be205f7fe381c163e3728dec540f66c28ac8095d62bc6c55bfd4 | a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158 | 99e774ec0e03dd12474023fb212976119d20a851e8fe593e627b44e8e8c9ddc9 |
| 10919 / QM5_10919_grimes-overshoot | 17f60ed4f7b0d34d48729eae22bb5f5ce454d784b08924586780dfa866a20d70 | 2de520e07feb1c00eeb09d5cfd6b403554c485c288bf43f9f020686a859be6f6 | 57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691 | 873e377197f456b10b38f4f554696eb86f467e2d7db13d798d43e0342e0d7508 |
| 10939 / QM5_10939_grimes-context-pb | 8d153796f055dd3f01ff182b3d17068a10760de8b279aa29b5928d26ee20ffce | 9aee4b166f0334ef92a6c0591b5e5ce66949e259b876b908eec3bd6880251a9d | 308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac | ed64e912ab95c803cb4bbbdeb0001091bf49efe15f5358fae616804ae136bda3 |
| 11132 / QM5_11132_tm-cum-rsi2 | dc66c331268eb8898daa02231468508216beafd9e4afef13c60cd2e4b8b55d27 | 99c5b34126bfd20e02b3891339c1ed650ee54adaa59270b2df8dd882f7e3f8c1 | 25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152 | d5cbddaaa988bea46959bd7ba5044d6a3128824683614596878cc4b1d63f8bd7 |
| 11421 / QM5_11421_ohlc-daily-squeeze-reversal-d1 | 5bab448a8bbedf231a212ee9a0a4408b129fb0edd55f3011104b2ae04e9e8c24 | 0bc38d0ff8759dac84d79cac881f5d31bebbab291d1b3a972465e2a071be4c0c | 0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7 | db7ca15097c9a696b58d9ea2cd355050cc6aea7c280a7882f7aab02b86b8279e |
| 12567 / QM5_12567_cum-rsi2-commodity | fec2b16bdf816aae14c8e3c996a13a3bfad27fecd663dc4f4618786f660baafa | 49720184507b596a25e57b2cf76636da185e5d3e450e026c058864911a48c09b | 5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9 | 086eee8a6fe3ad0f962417f45017c39f490058ac45c5db06eb673a33f9f5e7a1 |
| 12989 / QM5_12989_grimes-nested-pb-v2 | 98f7397011b543d27a4b00b50dc976a10e3365451a6e375abd6764bb310821ba | 610ef66856b0aedef69c73c307ee8f9d5585c9e8f5b579db6708378c37de579d | 7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2 | 43cc9a91e6041e71ff28c19081e4d91529a5035f458774c186bf2a77591ae092 |

The complete compiler-log and receipt hashes are in the bound build manifest.
The current live preimage bytes must be copied to the rollback directory and
re-hashed **before any overwrite**. A hash mismatch blocks the action.

## Nine identities bound to the deploy

Presets are read-only in this action. Their full paths and SHA-256 values are in
the bound manifest and must reproduce before and after the file copy.

| EA | symbol / timeframe | magic | required baseline file / SHA-256 |
|---:|---|---:|---|
| 10911 | GDAXI / H1 | 109110003 | QM5_10911_GDAXI.json / dbfb9a54fe8f231285efc43dd9fa037074f3a2968a0accc2f5f1c0e37c35ea5c |
| 10919 | XTIUSD / H4 | 109190001 | QM5_10919_XTIUSD.json / ea0dd3d63872b5a717b00beb067258f38e24214a9c34a16bb0c42087fc1da84c |
| 10939 | GBPUSD / H4 | 109390001 | QM5_10939_GBPUSD.json / b07a39d01cec4b9a1b40a8314425b5b6546e31bfd34982ad2a52edcf3e26e5e2 |
| 11132 | SP500 / D1 | 111320000 | QM5_11132_SP500.json / 77b7056176d210729705f146ca88886257ec7c630cb85df028c456e005fc2646 |
| 11421 | EURUSD / D1 | 114210000 | QM5_11421_EURUSD.json / 9e0c37ce68b243cd37aa9355b61372804228f0f0fb75df3d7ef56b76fb415958 |
| 11421 | AUDUSD / D1 | 114210003 | QM5_11421_AUDUSD.json / c9435880a1c20b77ea292268b98a81ee9b227ff5df14195804396a998fe02f30 |
| 12567 | XAUUSD / D1 | 125670003 | QM5_12567_XAUUSD.json / c7184fce94dd1a68cae50f51c52310a10df647e02c4fef653951e4112fd2b3d1 |
| 12567 | XNGUSD / D1 | 125670002 | QM5_12567_XNGUSD.json / 806994cd24e1c368f2858990404a305e9ce36aa0608d14906f6d7669ac9825f9 |
| 12989 | XAUUSD / H4 | 129890003 | QM5_12989_XAUUSD.json / 432ba8bb1e7f76a0106ce35b83ce1dd93fb8ebeb755fcd5529e770ec50bd26be |

For every row, the baseline file must match in all three standing locations:

1. D:/QM/data/baselines;
2. C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/baselines;
3. C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/baselines.

## Behavioral riders — explicit acceptance required

The proposed binaries contain all source and include changes at source pin
386151841, not merely the KS path repair:

- **10911 risk change:** new input qm_risk_cap_pct defaults to 1.0 and is bound
  through QM_FrameworkSetRiskCapPct. This is a new 1.0% per-trade cap and can
  reduce trade size.
- **Execution contracts and bar cadence:** 10911 declares H1; 10919, 10939 and
  12989 declare H4; 11132, 11421 and 12567 declare D1. Their new-bar gates are
  bound to those periods; 10939 binds both entry and retrace-exit gates. A
  wrong timeframe or incompatible Friday configuration now fails at init
  instead of silently running at the wrong cadence.
- **News entry gating:** native live-calendar support, symbol/index mapping,
  tester staleness correction, live UTC cache/day semantics and refresh/
  coverage warnings are included. These changes can block an otherwise valid
  entry. The fail-closed stale limit remains at no more than 336 hours.
- **Risk and order hardening:** hardened sizing, per-strategy magic/risk
  context, the explicit fixed-risk path and the execution-time limit-fill
  guard are included. They can change sizing or reject an unsafe order.
- **KS/halt and telemetry:** the sandbox-relative baseline path, book-scoped
  halt channel, restart persistence/day anchor, tester hardening, foreign
  persisted-state preservation and Q08 close telemetry are included.

Acceptance of this packet is acceptance of these riders. They must not be
described downstream as evidence-neutral compile noise or as a KS-only change.

## Include-lineage proof for the revised gate

The July 13 live-build pin is
cf2264bb09f1761b5340381647b0c5bb0144235b, authored
2026-07-13T06:47:55+02:00, subject “build: true rebuilds of all 20 DXZ-23 book
EA binaries (post no-op-compile fix).” The build pin proposed here is
386151841013afbaf01fe10b23e6cf7538480b71, authored
2026-07-31T19:03:33+02:00.

These commands were run:

~~~powershell
git rev-parse "cf2264bb:framework/include/QM/QM_KillSwitchKS.mqh"
git rev-parse "386151841:framework/include/QM/QM_KillSwitchKS.mqh"
git diff --exit-code cf2264bb 386151841 -- framework/include/QM/QM_KillSwitchKS.mqh
git log -L 141,188:framework/include/QM/QM_KillSwitchKS.mqh 386151841
git log -L 190,233:framework/include/QM/QM_KillSwitchKS.mqh 386151841
~~~

Both rev-parse commands return the same Git blob,
e5bfbda48d087fa3c0ce740aba405c16daa5e039, and the file diff returns exit 0.
Thus the **entire include**, not only a selected region, is byte-identical at
the two pins.

At the build pin:

- lines 141–188 implement the terminal-local FileOpen followed by FILE_COMMON
  retry and emit KS_BASELINE_LOADED;
- line 209 constructs
  QM\baselines\QM5_%d_%s.json;
- lines 217–220 return early when MQL_TESTER is nonzero;
- line 223 calls the loader;
- lines 229–231 emit KS_BASELINE_ABSENT if both live sandbox opens fail.

The line-history result is consistent with the full-file identity. The loader
region was last changed by
8e597ca1e47bed4a1282dc9c950d25bbebbceda0 on 2026-05-23. The live path change
d8b741d02febfc6fea4d33d3bcb7729611cc8eba and tester guard/hardening
841449513e63449a2dcd3d5c9c2950af91ccd1ed both landed on 2026-07-06, before
the July 13 pin.

The contemporary-build cohort's live loading evidence is recorded in
docs/ops/evidence/2026-07-31_ks_arming_after_owner_restart.md. The lineage
proof establishes that the same path construction and load behavior is in the
proposed binaries; it does not claim that a tester run exercised the live-only
branch.

## Honest tester result and reviewer gate revision

The bounded registered DEV1 smoke used
10911/GDAXI.DWX/H1/magic 109110003 for 2025-01-02 through 2025-01-10 with
RISK_FIXED=1000 and RISK_PERCENT=0. It passed, retained the staged EX5 hash,
loaded a news calendar aged 31 hours, produced NEWS_TESTER_CALENDAR_SELFTEST,
NEWS_CALENDAR_LOADED, KILL_SWITCH_INIT, EXECUTION_CONTRACT, INIT_OK, entry,
order and close events, and completed two trades.

It produced zero KS_BASELINE_LOADED events. That is the correct result because
QM_KillSwitchKS.mqh lines 217–220 state:

~~~text
if(MQLInfoInteger(MQL_TESTER) != 0)
  {
   g_qm_ks_baseline_loaded = false;
   return;
  }
~~~

The source deliberately returns before QM_KS_LoadBaseline. No registered
non-live demo/chart lane exists, so repeating tester runs cannot satisfy the
original gate. Claude's approved close-review for router task 45da1fa0 replaces
that impossible gate only for this packet with the three-part evidence stated
at the top. It does not convert 0/9 into PASS and does not pre-approve deploy.

The first post-deploy check must therefore show, after the recorded controlled
re-init epoch:

- KS_BASELINE_LOADED for all nine exact EA/symbol/timeframe/magic identities;
- each event's payload hash equal to the validated baseline JSON's internal
  hash;
- zero fresh KS_BASELINE_ABSENT events for those identities;
- fresh EXECUTION_CONTRACT and INIT_OK for every identity;
- fresh NEWS_CALENDAR_LOADED for every identity;
- stage SHA equal to T_Live SHA for all seven binaries; and
- unchanged preset and three-copy baseline SHA values.

Failure of any item invokes the stop/rollback decision. It is not a pipeline
verdict.

## Registry cleanup and exact-baseline exception

Commit 6fbebcd2d180b42b048bb1403ce8dc65614a84bf deletes only the later
redundant physical row:

~~~text
12567,cum-rsi2-commodity,ee172909-2f40-5169-9fa3-c1dc0657dee0,active,Development,2026-06-26
~~~

The earlier active Codex row is retained. The commit is exactly one file and
one deletion. No magic row or resolver mapping changed.

The brief expected one validator finding to disappear. The validator actually
emits two findings for that one duplicated physical row:

- ea_id_registry:duplicate_ea_id:12567:lines=3511,3515
- ea_id_registry:duplicate_slug:cum-rsi2-commodity:lines=3511,3515

Both disappear. Therefore the issue count falls from 1,363 to 1,361, not
1,362. After adding one to later physical line references to compensate for
the deleted CSV row, every one of the remaining 1,361 findings is identical to
the pre-cleanup finding set; normalized fingerprint:
9be61ce98b963d90ddcf0d5713ffe335da76b674b3e986aec9b3232c99142471.
Warnings remain 1,230 with fingerprint
16bb356314044abf94dc515c9dc5dc1e036ff4e3404ed89cc674cd92abe192d3.
These fingerprints use the Windows PowerShell Sort-Object collation, LF joining
and no trailing LF; the committed registry, magic and resolver file hashes
below are the byte-level cross-platform anchors.

The exact post-cleanup global baseline at 6fbebcd2d is:

| Item | Exact value |
|---|---|
| validator status | FAIL |
| EA rows | 4,246 |
| magic rows | 15,397 |
| issues | 1,361 |
| warnings | 1,230 |
| sorted raw issue fingerprint | 16dc3097e18f15beeaf084b79e86e57fea2f7fa48dc2c74d6655e426e209c1e5 |
| sorted raw warning fingerprint | 16bb356314044abf94dc515c9dc5dc1e036ff4e3404ed89cc674cd92abe192d3 |
| ea_id_registry.csv SHA-256 | 08dd4b43ab9929eae188cb3c3c0ca4c8b2b0c120e949a2a6a78d7aed31adb005 |
| magic_numbers.csv SHA-256 | 7ae5b6ff5d1e01230d639d2443ae5f08565f5ebfd57b551907f1f33b4adbe0c3 |
| QM_MagicResolver.mqh SHA-256 | 4c6fc13fa506f41e29fcbbd2b64f95462a9a2bc68453c01bc4dcc77ca058f93d |

**Exact exception text proposed for OWNER signature:**

> I acknowledge that the global registry validator remains FAIL at the exact
> 6fbebcd2d baseline: 4,246 EA rows, 15,397 magic rows, 1,361 issues and 1,230
> warnings, with the file and finding fingerprints recorded in this packet. I
> authorize only the seven-file deployment bound here despite that inherited
> global backlog. This exception does not declare the registry healthy, does
> not waive any target identity or magic check, and authorizes no further
> registry, magic or resolver edit. Any pre-deploy drift from this exact
> baseline blocks the action and requires fresh review.

## MNT-043/044 consequence and Q reruns

The proposed bill is
docs/ops/evidence/2026-07-31_ks_vintage_recompile_mnt_bill_PROPOSED.json at
SHA-256
1d448200d8252010432371ff941d05c898fdf89716aadce24c94ae7fd3dae1a1.
It is still PREPARED_NOT_APPENDED. This packet does not append it or alter raw
work-item rows.

The bill identifies 26 historical PASS rows: 22 admission-priority rows and
four history-priority rows. Multiple old rows for 11132/SP500 collapse to one
new identity-bound run per Q gate. Required admission reruns are:

| EA / symbol | required reruns |
|---|---|
| 10911 / GDAXI.DWX | Q06, Q07 |
| 10919 / XTIUSD.DWX | Q06, Q07 |
| 10939 / GBPUSD.DWX | Q06, Q07 |
| 11132 / SP500.DWX | Q06, Q07 |
| 11421 / AUDUSD.DWX | Q06, Q07 |
| 11421 / EURUSD.DWX | Q06, Q07 |
| 12567 / XAUUSD.DWX | Q06, Q07 |
| 12567 / XNGUSD.DWX | Q06, Q07 |
| 12989 / XAUUSD.DWX | Q06, Q07 |

History-only reruns, if those histories are requalified, are
10939/XAUUSD.DWX Q06+Q07 and 11132/NDX.DWX Q06+Q07. New EX5 hashes cannot
inherit the historical evidence. Any effective EVIDENCE_VINTAGE_STALE update
must be append-only and separately reviewed/applied; only later Q evidence can
produce a pipeline verdict.

## Sunday runbook — execute only after signatures

The standing file-side procedure is source/stage hash verification, exact live
preimage backup, file copy, and destination hash verification. The historical
one-shot scratchpad deploy helper is not present in the canonical checkout, so
the commands below spell out that same fail-closed procedure against the bound
manifest.

Preconditions:

- Sunday market-closed window confirmed by OWNER;
- Claude review and OWNER wording/date/signature below are filled;
- no command in this runbook starts terminal64.exe or changes AutoTrading;
- T1–T10 work is not stopped or interrupted;
- presets and baselines remain byte-identical;
- no open-position or chart consequence remains unaccepted by OWNER; and
- T_Live re-init is a separate controlled OWNER action after the file copy.

### 1. Read-only preflight, preimage backup, and seven-file deploy

Run in PowerShell from C:/QM/repo. The first loop validates **all** sources,
destinations, presets and baseline copies before creating the backup. The
second loop creates and verifies the complete rollback set before the third
loop overwrites anything.

~~~powershell
$manifestPath = 'C:\QM\repo\docs\ops\evidence\2026-07-31_ks_vintage_recompile_manifest_STAGE2_UNSIGNED.json'
$expectedManifestSha = 'ee12f5097816e60de68d6ff30b60cbc8a401062f7b471c8052a875c5c0950fcc'
$rollbackRoot = 'C:\QM\deploy\KSRecompile_20260802_386151841\preimages'
$terminalBaselineRoot = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines'
$sourceBaselineRoot = 'D:\QM\data\baselines'
$commonBaselineRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines'

function Assert-Sha256([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing file: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "SHA256 mismatch: $Path expected=$Expected actual=$actual"
    }
}

Assert-Sha256 $manifestPath $expectedManifestSha
Assert-Sha256 'C:\QM\repo\framework\registry\ea_id_registry.csv' '08dd4b43ab9929eae188cb3c3c0ca4c8b2b0c120e949a2a6a78d7aed31adb005'
Assert-Sha256 'C:\QM\repo\framework\registry\magic_numbers.csv' '7ae5b6ff5d1e01230d639d2443ae5f08565f5ebfd57b551907f1f33b4adbe0c3'
Assert-Sha256 'C:\QM\repo\framework\include\QM\QM_MagicResolver.mqh' '4c6fc13fa506f41e29fcbbd2b64f95462a9a2bc68453c01bc4dcc77ca058f93d'

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.source_lock.commit -ne '386151841013afbaf01fe10b23e6cf7538480b71') {
    throw 'Source-lock commit mismatch'
}
if (@($manifest.builds).Count -ne 7 -or @($manifest.sleeves).Count -ne 9) {
    throw 'Manifest cardinality mismatch'
}

foreach ($build in $manifest.builds) {
    Assert-Sha256 ([string]$build.staged_ex5) ([string]$build.ex5_sha256)
    Assert-Sha256 ([string]$build.live_target) ([string]$build.live_preimage_sha256)
}
foreach ($sleeve in $manifest.sleeves) {
    Assert-Sha256 ([string]$sleeve.preset) ([string]$sleeve.preset_sha256)
    foreach ($root in @($sourceBaselineRoot, $terminalBaselineRoot, $commonBaselineRoot)) {
        Assert-Sha256 (Join-Path $root ([string]$sleeve.baseline)) ([string]$sleeve.baseline_sha256)
    }
}

if (Test-Path -LiteralPath $rollbackRoot) {
    throw "Rollback directory already exists; do not overwrite: $rollbackRoot"
}
New-Item -ItemType Directory -Path $rollbackRoot | Out-Null

foreach ($build in $manifest.builds) {
    $backup = Join-Path $rollbackRoot ([IO.Path]::GetFileName([string]$build.live_target))
    Copy-Item -LiteralPath ([string]$build.live_target) -Destination $backup
    Assert-Sha256 $backup ([string]$build.live_preimage_sha256)
}

foreach ($build in $manifest.builds) {
    Copy-Item -LiteralPath ([string]$build.staged_ex5) -Destination ([string]$build.live_target) -Force
    Assert-Sha256 ([string]$build.live_target) ([string]$build.ex5_sha256)
}

foreach ($sleeve in $manifest.sleeves) {
    Assert-Sha256 ([string]$sleeve.preset) ([string]$sleeve.preset_sha256)
}

$deploymentEpochUtc = [DateTimeOffset]::UtcNow
$deploymentEpochUtc.ToString('o')
~~~

Record the printed deployment epoch in the operator decision record. Stop
here. OWNER performs the standing controlled T_Live re-init; do not start
terminal64.exe manually and do not toggle AutoTrading.

If a stale-news init check fails, refresh the news-calendar seed under
D:/QM/data/news_calendar and its FILE_COMMON copy through the standing seed
procedure. Never raise qm_news_stale_max_hours above 336 and never weaken the
fail-closed check.

### 2. First post-deploy grep and authoritative 9/9 check

Set deploymentEpochUtc below to the exact value printed before the controlled
re-init.

~~~powershell
$deploymentEpochUtc = [DateTimeOffset]::Parse('REPLACE_WITH_RECORDED_UTC_EPOCH')
$logRoot = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM'
$targetIds = 10911,10919,10939,11132,11421,12567,12989

foreach ($eaId in $targetIds) {
    $log = Join-Path $logRoot "QM5_$($eaId)_ea-$($eaId).log"
    rg -n '"event":"(KS_BASELINE_LOADED|KS_BASELINE_ABSENT|EXECUTION_CONTRACT|INIT_OK|NEWS_CALENDAR_LOADED)"' $log
}
~~~

The grep is operator-readable evidence; the following JSON parse is the
fail-closed decision. It also rechecks the baseline file SHA and compares the
loaded event's payload hash to the validated JSON's internal hash.

~~~powershell
$manifestPath = 'C:\QM\repo\docs\ops\evidence\2026-07-31_ks_vintage_recompile_manifest_STAGE2_UNSIGNED.json'
$terminalBaselineRoot = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines'
$sourceBaselineRoot = 'D:\QM\data\baselines'
$commonBaselineRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines'
$logRoot = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM'
$targetIds = 10911,10919,10939,11132,11421,12567,12989
$deploymentEpochUtc = [DateTimeOffset]::Parse('REPLACE_WITH_RECORDED_UTC_EPOCH')
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

function Assert-Sha256([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing file: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "SHA256 mismatch: $Path expected=$Expected actual=$actual"
    }
}

$expected = @(
    [pscustomobject]@{ea=10911; symbol='GDAXI'; tf='H1'; magic=109110003; baseline='QM5_10911_GDAXI.json'; file_sha='dbfb9a54fe8f231285efc43dd9fa037074f3a2968a0accc2f5f1c0e37c35ea5c'},
    [pscustomobject]@{ea=10919; symbol='XTIUSD'; tf='H4'; magic=109190001; baseline='QM5_10919_XTIUSD.json'; file_sha='ea0dd3d63872b5a717b00beb067258f38e24214a9c34a16bb0c42087fc1da84c'},
    [pscustomobject]@{ea=10939; symbol='GBPUSD'; tf='H4'; magic=109390001; baseline='QM5_10939_GBPUSD.json'; file_sha='b07a39d01cec4b9a1b40a8314425b5b6546e31bfd34982ad2a52edcf3e26e5e2'},
    [pscustomobject]@{ea=11132; symbol='SP500'; tf='D1'; magic=111320000; baseline='QM5_11132_SP500.json'; file_sha='77b7056176d210729705f146ca88886257ec7c630cb85df028c456e005fc2646'},
    [pscustomobject]@{ea=11421; symbol='EURUSD'; tf='D1'; magic=114210000; baseline='QM5_11421_EURUSD.json'; file_sha='9e0c37ce68b243cd37aa9355b61372804228f0f0fb75df3d7ef56b76fb415958'},
    [pscustomobject]@{ea=11421; symbol='AUDUSD'; tf='D1'; magic=114210003; baseline='QM5_11421_AUDUSD.json'; file_sha='c9435880a1c20b77ea292268b98a81ee9b227ff5df14195804396a998fe02f30'},
    [pscustomobject]@{ea=12567; symbol='XAUUSD'; tf='D1'; magic=125670003; baseline='QM5_12567_XAUUSD.json'; file_sha='c7184fce94dd1a68cae50f51c52310a10df647e02c4fef653951e4112fd2b3d1'},
    [pscustomobject]@{ea=12567; symbol='XNGUSD'; tf='D1'; magic=125670002; baseline='QM5_12567_XNGUSD.json'; file_sha='806994cd24e1c368f2858990404a305e9ce36aa0608d14906f6d7669ac9825f9'},
    [pscustomobject]@{ea=12989; symbol='XAUUSD'; tf='H4'; magic=129890003; baseline='QM5_12989_XAUUSD.json'; file_sha='432ba8bb1e7f76a0106ce35b83ce1dd93fb8ebeb755fcd5529e770ec50bd26be'}
)

$events = foreach ($eaId in $targetIds) {
    $log = Join-Path $logRoot "QM5_$($eaId)_ea-$($eaId).log"
    Get-Content -LiteralPath $log | ForEach-Object {
        try { $_ | ConvertFrom-Json -ErrorAction Stop } catch { }
    }
}
$post = @($events | Where-Object {
    [DateTimeOffset]::Parse([string]$_.ts_utc) -ge $deploymentEpochUtc
})

$result = foreach ($row in $expected) {
    $scope = @($post | Where-Object {
        [int]$_.ea_id -eq $row.ea -and
        [string]$_.symbol -eq $row.symbol -and
        [string]$_.tf -eq $row.tf -and
        [long]$_.magic -eq $row.magic
    })
    $loaded = @($scope | Where-Object event -eq 'KS_BASELINE_LOADED')
    $absent = @($scope | Where-Object event -eq 'KS_BASELINE_ABSENT')
    $init = @($scope | Where-Object event -eq 'INIT_OK')
    $contract = @($scope | Where-Object event -eq 'EXECUTION_CONTRACT')
    $news = @($scope | Where-Object event -eq 'NEWS_CALENDAR_LOADED')

    $baselinePath = Join-Path $terminalBaselineRoot $row.baseline
    Assert-Sha256 $baselinePath $row.file_sha
    $baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
    $latestLoaded = $loaded | Sort-Object { [DateTimeOffset]::Parse([string]$_.ts_utc) } | Select-Object -Last 1
    $eventHash = if ($null -eq $latestLoaded) { '' } else { ([string]$latestLoaded.payload.hash).ToLowerInvariant() }
    $baselineHash = ([string]$baseline.hash).ToLowerInvariant()

    $ok = $loaded.Count -ge 1 -and $absent.Count -eq 0 -and
          $init.Count -ge 1 -and $contract.Count -ge 1 -and
          $news.Count -ge 1 -and $eventHash -eq $baselineHash
    [pscustomobject]@{
        ea=$row.ea; symbol=$row.symbol; tf=$row.tf; magic=$row.magic
        loaded=$loaded.Count; absent=$absent.Count; init=$init.Count
        execution_contract=$contract.Count; news_loaded=$news.Count
        baseline_event_hash_match=($eventHash -eq $baselineHash); verdict=if($ok){'PASS'}else{'FAIL'}
    }
}

$result | Format-Table -AutoSize
if (@($result | Where-Object verdict -ne 'PASS').Count -ne 0) {
    throw 'POST-DEPLOY GATE FAILED: do not proceed; use the signed rollback decision'
}

foreach ($build in $manifest.builds) {
    Assert-Sha256 ([string]$build.live_target) ([string]$build.ex5_sha256)
}
foreach ($sleeve in $manifest.sleeves) {
    Assert-Sha256 ([string]$sleeve.preset) ([string]$sleeve.preset_sha256)
    foreach ($root in @($sourceBaselineRoot, $terminalBaselineRoot, $commonBaselineRoot)) {
        Assert-Sha256 (Join-Path $root ([string]$sleeve.baseline)) ([string]$sleeve.baseline_sha256)
    }
}
~~~

Expected result is nine PASS rows. This is the first live-only canary and
remains fail-explicit.

### 3. Rollback commands — require separate written OWNER authority

Do not run this block merely because deployment is pending. Run it only after
the stop condition is met and the rollback authorization field below is
signed. It restores all seven recorded preimage bytes, verifies every target,
then stops for an OWNER-controlled re-init. It does not touch presets,
baselines, AutoTrading, charts, or T1–T10.

~~~powershell
$manifestPath = 'C:\QM\repo\docs\ops\evidence\2026-07-31_ks_vintage_recompile_manifest_STAGE2_UNSIGNED.json'
$rollbackRoot = 'C:\QM\deploy\KSRecompile_20260802_386151841\preimages'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

function Assert-Sha256([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing file: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "SHA256 mismatch: $Path expected=$Expected actual=$actual"
    }
}

foreach ($build in $manifest.builds) {
    $backup = Join-Path $rollbackRoot ([IO.Path]::GetFileName([string]$build.live_target))
    Assert-Sha256 $backup ([string]$build.live_preimage_sha256)
}
foreach ($build in $manifest.builds) {
    $backup = Join-Path $rollbackRoot ([IO.Path]::GetFileName([string]$build.live_target))
    Copy-Item -LiteralPath $backup -Destination ([string]$build.live_target) -Force
    Assert-Sha256 ([string]$build.live_target) ([string]$build.live_preimage_sha256)
}
~~~

After rollback, OWNER performs the controlled re-init and records fresh
identity/init evidence. The old preimages are known to emit
KS_BASELINE_ABSENT for these nine identities; restoring them restores the old
dormant KS behavior and must not be described as an armed state.

## Empty review and signature fields

**Claude review verdict:** APPROVED. Independently verified: include-lineage
blobs identical at both pins (`e5bfbda48d08…`, whole file — stronger than the
required region proof); manifest SHA `ee12f509…` and post-cleanup registry SHA
`08dd4b43…` match; cleanup commit `6fbebcd2d` is exactly one row deletion;
runbook logic reviewed (validate-all → backup-verify → deploy-verify →
authoritative 9/9 JSON gate incl. payload-hash==baseline-internal-hash →
separately-authorized rollback). Behavioral riders correctly enumerated and
NOT disguised as KS-only. Deploy authority arises only with the OWNER
signature below plus the approved Sunday window.

**Claude reviewed commit / packet SHA-256:** commit `2c336c072`; packet file
SHA-256 at review `80dd4a3971095df0e0b87b2e86f4658966b42048769ad27797c8a97ffd1128d9`

**Claude review date/time:** 2026-07-31T19:02Z

**OWNER decision wording:** „passt alles, Sonntagsfenster bestätigt!"
(Chat, 2026-07-31 — Antwort auf die vollständige Paket-Vorlage inkl.
Verhaltens-Mitfahrer, Registry-Ausnahme mit 6fbebcd2d-Baseline und
Gate-Revision; transkribiert durch Claude, Referenz: Session-Verlauf +
Ledger docs/ops/CONVERGENCE_LEDGER_WEEKEND_2026-07-31.md)

**OWNER name/signature:** OWNER (Chat-Signatur 2026-07-31)

**OWNER date/time:** 2026-07-31, ~21:15 lokal (19:15Z)

**Approved Sunday window:** 2026-08-02, marktgeschlossenes Fenster bis
Broker-Reopen (~22:00–01:00 UTC): Deploy per Runbook §1, danach
OWNER-kontrollierter T_Live-Re-Init, dann Verifikation §2 (9/9-Gate).

**Separate OWNER rollback authorization wording (leave empty unless invoked):**

**Separate OWNER rollback signature/date (leave empty unless invoked):**
