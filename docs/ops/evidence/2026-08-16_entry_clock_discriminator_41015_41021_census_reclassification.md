# Entry-clock discriminator: QM5_41015-41021 and the 27-row census

- Router task: `06377991-5d26-4eff-8853-02279c57fd3c`, follow-up to `6dfa3117-dc9d-4758-841c-d576020d73e4`
- Branch: `agents/board-advisor`
- Scope: read-only source analysis. No card mutation, no source mutation, no
  build/compile/setfile/work-item action taken.

## Question asked

Why do `QM5_41019`/`QM5_41020` trade normally (Q02 PASS -> Q04 economic
evaluation) while `QM5_41015`/`QM5_41016`/`QM5_41017`/`QM5_41018`/`QM5_41021`
produce zero trades, if all seven share the same ~61-minute XTIUSD
label-to-first-tick session-break offset (`fea371c2` measurement:
3,600-3,696 s, 60.0-61.6 min)? Three structural hypotheses were proposed to
test: (a) "label modulo one day" normalization lands inside grace for week
anchors but not month/exact-date anchors; (b) month/exact-date anchors
disproportionately select stub bars; (c) the two trading EAs evaluate a
later bar than the anchor bar.

## Finding: none of (a)/(b)/(c). The discriminator is the declared
`strategy_entry_grace_minutes` input constant.

Reading the BINDING elapsed-time computation (not card prose) in each of the
seven `.mq5` sources:

| EA | file:line | `strategy_entry_grace_minutes` | modulo-one-day used? | Q02 result |
|---|---|---:|---|---|
| QM5_41015_xtixng-tue-rv | `QM5_41015_xtixng-tue-rv.mq5:43` | 5 | yes (`:104`) | zero trades |
| QM5_41016_wti-mclose-mom | `QM5_41016_wti-mclose-mom.mq5:45` | 5 | no (raw `TimeCurrent()-current_bar.time`, `:314`) | zero trades |
| QM5_41017_wti-dom-ctrreg | `QM5_41017_wti-dom-ctrreg.mq5:48` | 5 | no (raw `now-current_bar`, `:106`) | zero trades |
| QM5_41018_xtixng-wed-rv | `QM5_41018_xtixng-wed-rv.mq5:43` | 5 | yes (`:104`) | zero trades |
| QM5_41019_wti-wopen-mom | `QM5_41019_wti-wopen-mom.mq5:44` | **180** | yes (`:117`) | Q02 PASS -> Q04 economic FAIL (traded) |
| QM5_41020_wti-wclose-mom | `QM5_41020_wti-wclose-mom.mq5:44` | **180** | yes (`:117`) | Q02 PASS -> Q04 economic FAIL (traded) |
| QM5_41021_wti-mdual-mom | `QM5_41021_wti-mdual-mom.mq5:46` | 5 | yes (`:151`) | zero trades |

100% correlation, no exceptions: every EA with `grace=5` produced zero
trades against the ~61-min offset; both EAs with `grace=180` traded. The
formula itself (`Strategy_EntryWithinGrace` / equivalent) is structurally
identical across siblings — `session_elapsed = elapsed % 86400; return
session_elapsed <= grace_minutes*60` (or, in 41016/41017, the same
comparison without the modulo defensive normalization, which is immaterial
here since 5 min is smaller than the offset either way). The only variable
that changes is the grace constant itself, and it is card-documented and
source-hardcoded per EA, not derived from anchor type:

- `QM5_41019` SPEC.md:9,24-25 and `QM5_41020` SPEC.md (identical pattern):
  "On the first executable tick, within 180 minutes, of a genuine
  broker-clock [Wednesday/Monday] ... entry grace: 180 minutes from
  executable session open." This is an intentional, documented design
  choice, not a bug or an accidental card/source mismatch.
- All five zero-trade siblings' cards and sources declare the tight 5-minute
  "falsifiable-attach" grace inherited from the parent card family.

### Why hypotheses (a)/(b)/(c) are falsified

- **(a) week-anchor vs month/exact-date normalization:** `QM5_41015`
  (Tuesday) and `QM5_41018` (Wednesday) are both week-anchor (day-of-week)
  types, structurally identical in normalization to `QM5_41019`/`QM5_41020`
  (`elapsed % 86400`), yet both zero-trade at `grace=5`. Anchor type does not
  predict outcome; grace constant does.
- **(b) stub-bar selection:** does not generalize — `QM5_41015`/`QM5_41018`/
  `QM5_41021` are not month/exact-date anchors and still zero-trade. Stub-bar
  rejection is a real, separate, narrower phenomenon specific to
  `QM5_41016`'s one observed Saturday attempt, not the cross-EA
  discriminator.
- **(c) later anchor bar:** `QM5_41019` reads `QM_ReadBar(_Symbol,
  PERIOD_D1, 0, current_bar)` (`:236`) — the same bar-0 anchor convention as
  `QM5_41015`/`QM5_41018` (`g_current_host_bar` populated from bar 0, see
  `:703`/`:749` in each). No later-bar effect exists to explain the split.

## Re-classification of the 23 `CONFIRMED_AFFECTED` + 4 `LIKELY_AFFECTED` census rows

Source: `D:/QM/strategy_farm/codex_outbox/bar_open_clock_sweep_6dfa3117_20260816.md`
(router task `6dfa3117`). That census's "Correction" section reclassified
`QM5_41019`/`QM5_41020`/`QM5_41021` from `NOT_AFFECTED` to `LIKELY_AFFECTED`
by pattern-matching card **prose** ("executable session open" vs "D1 bar
open") rather than reading the binding source constant — the same
prose-vs-code trap the sweep itself was created to catch. Applying the
now-proven discriminator (direct `strategy_entry_grace_minutes` +
elapsed-formula source read) to all 27 named rows:

| Result | Count | Rows |
|---|---:|---|
| `CONFIRMED_AFFECTED` (grace=5, formula matches defect signature) | 25 | the original 23, plus `QM5_20011` and `QM5_41021` upgraded from `LIKELY_AFFECTED` |
| `NOT_AFFECTED` (grace=180, comfortably exceeds measured 60.0-61.6 min offset) | 2 | `QM5_41019`, `QM5_41020` — revert the census's "correction"; the original pre-correction sweep call was right, for a different and now-verified reason |

Verification grep run against all 27 `.mq5` sources (`strategy_entry_grace_minutes`
value + presence of `% 86400`/`86400L` modulo normalization) is reproducible:
every one of the original 23 rows independently confirmed `grace=5` in
source (not just prose, closing that residual doubt); `QM5_20011` confirmed
`grace=5` (`QM5_20011_xng-thu-tue.mq5:45`, raw non-modulo comparison at
`:131-134`); `QM5_41021` confirmed `grace=5` (`:46`); `QM5_41019`/`QM5_41020`
confirmed `grace=180` (`:44` each).

**Count changed exactly as the follow-up anticipated**: 23+4 candidate rows
resolve to 25 confirmed / 2 cleared, not 27/0 or 23/4.

## Correction to the proposed build-preflight gate design

The originating task's "then" item 2 proposed: "refuse to build a card whose
entry clock is label-anchored on a session-offset symbol (XTI/XNG today)
until an OWNER-approved variant exists." That formulation would incorrectly
block `QM5_41019`/`QM5_41020`-style cards, which are legitimately
label-anchored on XTI/XNG and already proven to trade correctly. The finding
above shows the actual defect condition is a **relationship**, not a
symbol-membership test:

> declared `strategy_entry_grace_minutes` (or equivalent card-declared grace
> window) < measured label-to-first-tradable-tick offset for the target
> symbol (with margin).

A correct preflight gate must compare the card's declared grace against a
measured-or-registry offset for the symbol (the `fea371c2` XTIUSD constant,
60.0-61.6 min, pinned as `strategy_session_offset_min` in the two draft
variants already produced under `6dfa3117`), not simply key off
symbol membership. This is a design correction to hand to whoever implements
item 2, not an implementation performed here — no build-preflight code was
touched by this task.

## Constraints observed

No card in `cards_approved` or `strategy-seeds/cards/approved` was mutated.
No build, compile, setfile, or work-item action was taken. No mass hold was
placed on any hypothesis; the finding is a direct source read with a
reproducible grep, not an inference. `QM5_41016`/`QM5_41017` variant cards
from the prior `6dfa3117` cycle remain `DRAFT`/`PENDING_REVIEW` under
`D:/QM/strategy_farm/artifacts/cards_review/` untouched by this task.

## Recommended next steps (Research/OWNER, not self-authorized here)

1. Update the `6dfa3117` census table's disposition for `QM5_41019`/
   `QM5_41020` back to `NOT_AFFECTED` and upgrade `QM5_20011`/`QM5_41021` to
   `CONFIRMED_AFFECTED`.
2. When drafting the build-preflight check, gate on
   `declared_grace_minutes < measured_symbol_offset_minutes`, not on
   XTI/XNG symbol membership alone, so legitimately wide-grace cards (like
   the two week-boundary EAs here) are never blocked.
3. The 21 remaining `CONFIRMED_AFFECTED` cards beyond `QM5_41016`/`QM5_41017`
   can reuse the same `D1_bar_open + strategy_session_offset_min` variant
   template already drafted under `6dfa3117` — this task did not draft new
   variants (out of scope; the originating task's "then" item 3 already
   completed for the two exemplar EAs in the prior cycle).
