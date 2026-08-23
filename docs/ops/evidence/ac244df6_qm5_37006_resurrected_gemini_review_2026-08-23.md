# Codex review: resurrected QM5_37006 Gemini build

- Review task: `ac244df6-de44-496d-86cd-c1b7fd662eb8`
- Gemini source task: `fc2c4254-fae3-4ad7-bd0c-c44be30334fb`
- Producer artifact: `artifacts/builds/fc2c4254-fae3-4ad7-bd0c-c44be30334fb.json`
- EA: `QM5_37006_cusum-filter-structural-breakout`
- Reviewed tree HEAD at inspection: `37154e7c0b37911c59fceb8e8bf2e3cece5570ad`
- MQ5 SHA-256: `7b7555846abefad5e6ada02a092aaf1b3985befded294f5c9633caab094cfd8e`
- EX5 SHA-256: `37aab81b8139805e9d48e227cd9830a990ac450ed00da7db0a28db3fe4518332`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore performed the mandatory review
directly against the approved card, current source, producer artifact, framework
entry contract, and focused repository checks.

The reviewed MQ5 and EX5 hashes are byte-for-byte identical to the artifacts
rejected in
`docs/ops/evidence/06b9a3cb_qm5_37006_gemini_build_codex_review_2026-08-18.md`.
No source remediation accompanies the resurrected producer result.

## Findings

### 1. Critical: CUSUM still omits the approved expected-return term

The card defines the recurrence as
`S += y_t - E[y_t]` (card line 76). Source lines 103-105 add the raw close
difference directly. `CalculateReturnStdDev` calculates a 50-observation mean at
lines 76-92, but uses it only to calculate variance and never returns or
subtracts it from the CUSUM increment. Ordinary drift is therefore accumulated
as a structural break, changing both signal direction and timing.

If the approved card does not define how `E[y_t]` is estimated precisely enough
for implementation, the card must be amended before Development chooses an
estimator.

### 2. High: a rejected order still consumes and resets the signal

Source lines 181-182 and 192-193 reset both accumulators while only constructing
an entry request. The actual call occurs at lines 299-303 and its boolean result
is ignored. The card requires reset “upon trade execution” (card line 99); an
entry rejection must not silently reset the path-dependent signal.

### 3. High: all three approved loss-limit rails remain absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard stop,
and a 5.0% total-drawdown stop. The current source exposes none of those values
and relies on a generic framework initialization with different defaults. The
current `build_gate_hardening.py` run fails all three D2 checks, contradicting
the routed producer verdict that hardening passed.

### 4. High: CUSUM state is lost on every EA restart

`g_cusum_pos` and `g_cusum_neg` are RAM-only globals initialized to zero (source
lines 59-60). `OnInit` processes only the latest completed delta (line 238), so a
terminal/EA restart introduces an extra reset not authorized by the card and
does not reconstruct the recurrence from history. Identical subsequent prices
can therefore produce different entries depending on restart timing. A durable
reconstruction window and fail-closed warm-up rule are required.

### 5. Medium: an unapproved absolute spread filter changes the entry set

The card authorizes only `spread > 1.8 * ATR(14, M15)[1]` (card line 85). Source
lines 53 and 143-144 add a separate 300-point absolute cap that is absent from
the card and its parameter table. This can reject an otherwise authorized
signal and must be removed or approved as a distinct card variant.

### 6. Medium: the card's three-tick slippage ceiling is not enforced

The card requires at most three ticks (card line 114). This EA supplies no
symbol tick-size conversion or entry deviation override. The framework path
configures a generic 20-point deviation (`QM_Common.mqh` / `QM_Entry.mqh`),
which is not an enforcement of three trade ticks across NDX, SP500, and XTI.

## Focused verification

Executed from `C:/QM/repo` on 2026-08-23:

| Check | Result |
|---|---|
| Current MQ5/EX5 hashes vs August 18 rejected review | exact match |
| `build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_37006_cusum-filter-structural-breakout` | **FAIL**: three approved loss-limit values absent |
| `validate_build_guardrails.py` on MQ5 and all three sets | **PASS**: 336-hour news ceiling and preset guardrails |
| `validate_spec_doc.py` on the EA directory | **PASS** (document shape only) |
| Setfile risk contract | all three use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Producer runtime evidence | none; `smoke_result=deferred_p2_smoke` |

The producer JSON was concurrently modified but uncommitted in the shared
checkout during inspection; its newly recorded hashes match the unchanged
MQ5/EX5 above. That does not cure the semantic findings or establish a pipeline
verdict. This review changed no Gemini source, binary, setfile, registry,
terminal, AutoTrading, live, or pipeline state.
