#!/usr/bin/env python3
"""Derive the staged QM5_41478_grimes-complex-pb-opt.mq5 from the parent
QM5_10911_grimes-complex-pb.mq5 by replaying the verified QM5_13013 -> QM5_41321
sibling transformation (7 hunks). Staging only: output lands in the evidence
dir, NOT framework/EAs. Identity-free pattern block is copied verbatim from the
approved sibling QM5_41321 (Amendment-family wiring, byte-identical across the
six 2026-09-05 siblings per amendment_c_opt_siblings.md).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PARENT = ROOT / "framework/EAs/QM5_10911_grimes-complex-pb/QM5_10911_grimes-complex-pb.mq5"
REF = ROOT / "framework/EAs/QM5_41321_grimes-trendday-v2-opt/QM5_41321_grimes-trendday-v2-opt.mq5"
OUT = Path(__file__).resolve().parent / "staged/QM5_41478_grimes-complex-pb-opt.mq5"

EA_ID = "41478"
SLUG = "grimes-complex-pb-opt"

PATTERN_BLOCK = '''
// DL-089 pattern measurement surface. Zero disables a slot.
input group "Optimization Pattern Profile"
input int opt_pp_buy1  = 0;
input int opt_pp_buy2  = 0;
input int opt_pp_buy3  = 0;
input int opt_pp_sell1 = 0;
input int opt_pp_sell2 = 0;
input int opt_pp_sell3 = 0;

const ENUM_TIMEFRAMES QM_PPC_REFERENCE_TF = PERIOD_D1;
const int             QM_PPC_CLOSED_SHIFT = 1;
QM_PatternProfile     g_pp_profile;
bool                  g_pp_active = false;
long                  g_pp_days_evaluated = 0;
long                  g_pp_fire_count = 0;
long                  g_pp_legs_suppressed = 0;
long                  g_pp_invalid_days = 0;

QM_PermissionResult Pattern_Permission()
  {
   QM_PermissionResult perm;
   if(!g_pp_active)
     {
      perm.allow_buy = true;
      perm.allow_sell = true;
      perm.valid = true;
      MqlRates reference_bar;
      perm.reference_bar_time = (QM_ReadBar(_Symbol, QM_PPC_REFERENCE_TF,
                                            QM_PPC_CLOSED_SHIFT, reference_bar)
                                 ? reference_bar.time : 0);
      perm.reason = "census_control";
      return perm;
     }
   return QM_PatternPermissionEvaluate(_Symbol, QM_PPC_REFERENCE_TF,
                                       QM_PPC_CLOSED_SHIFT, g_pp_profile);
  }

bool Opt_AddPattern(const int predicate_id, const bool buy_side, const string input_name)
  {
   if(predicate_id == 0)
      return true;
   if(predicate_id < 0)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\\"input\\":\\"%s\\",\\"predicate_id\\":%d}", input_name, predicate_id));
      return false;
     }
   const QM_PatternId pid = (QM_PatternId)predicate_id;
   const bool added = buy_side ? QM_PP_ProfileAddBuy(g_pp_profile, pid)
                               : QM_PP_ProfileAddSell(g_pp_profile, pid);
   if(!added)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\\"input\\":\\"%s\\",\\"predicate_id\\":%d}", input_name, predicate_id));
      return false;
     }
   g_pp_active = true;
   return true;
  }

bool Pattern_AllowsRequest(const QM_EntryRequest &req)
  {
   const QM_PermissionResult perm = Pattern_Permission();
   g_pp_days_evaluated++;
   if(!perm.valid)
     {
      g_pp_invalid_days++;
      QM_LogEvent(QM_WARN, "PP_CENSUS_BLOCK", "{\\"reason\\":\\"permission_invalid\\"}");
      return false;
     }
   const bool buy_side = QM_OrderTypeIsBuy(req.type);
   const bool allowed = buy_side ? perm.allow_buy : perm.allow_sell;
   if(!allowed)
     {
      g_pp_fire_count++;
      g_pp_legs_suppressed++;
      QM_LogEvent(QM_INFO, "PP_CENSUS_BLOCK",
                  StringFormat("{\\"side\\":\\"%s\\",\\"bar\\":\\"%s\\",\\"reason\\":\\"%s\\"}",
                               (buy_side ? "BUY" : "SELL"),
                               TimeToString(perm.reference_bar_time), perm.reason));
     }
   return allowed;
  }
'''

INIT_BLOCK = '''   g_pp_active = false;
   QM_PP_ProfileInit(g_pp_profile, "DL089_OPT", QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT);
   if(!Opt_AddPattern(opt_pp_buy1, true, "opt_pp_buy1") ||
      !Opt_AddPattern(opt_pp_buy2, true, "opt_pp_buy2") ||
      !Opt_AddPattern(opt_pp_buy3, true, "opt_pp_buy3") ||
      !Opt_AddPattern(opt_pp_sell1, false, "opt_pp_sell1") ||
      !Opt_AddPattern(opt_pp_sell2, false, "opt_pp_sell2") ||
      !Opt_AddPattern(opt_pp_sell3, false, "opt_pp_sell3"))
      return INIT_FAILED;

'''

DEINIT_BLOCK = '''   QM_LogEvent(QM_INFO, "PP_CENSUS_SUMMARY",
               StringFormat("{\\"profile_key\\":\\"%s\\",\\"enabled\\":%s,\\"days_evaluated\\":%I64d,\\"fire_count\\":%I64d,\\"legs_suppressed\\":%I64d,\\"invalid_days\\":%I64d}",
                            QM_PP_ProfileKey(g_pp_profile), (g_pp_active ? "true" : "false"),
                            g_pp_days_evaluated, g_pp_fire_count, g_pp_legs_suppressed, g_pp_invalid_days));
'''


def main() -> None:
    text = PARENT.read_text(encoding="utf-8-sig")
    ref = REF.read_text(encoding="utf-8-sig")

    # Sanity: the identity-free pattern block must be byte-present in the
    # approved reference sibling (guards against template drift).
    block_core = PATTERN_BLOCK.strip()
    assert block_core in ref, "pattern block no longer matches approved 41321 sibling"

    # Hunk 1: identity in #property description.
    old = '#property description "QM5_10911 Grimes Complex Pullback Second-Leg Continuation"'
    new = f'#property description "QM5_{EA_ID} Grimes Complex Pullback Second-Leg Continuation - DL-089 opt sibling"'
    assert text.count(old) == 1
    text = text.replace(old, new)

    # Hunk 2: EA-managed pattern permission wiring at the include site.
    old = "#include <QM/QM_Common.mqh>\n"
    assert text.count(old) == 1
    text = text.replace(
        old,
        "#define QM_PATTERN_PERMISSION_EA_MANAGED\n"
        "#include <QM/QM_Common.mqh>\n"
        "#include <QM/QM_PatternPermission.mqh>\n",
    )

    # Hunk 3: qm_ea_id input value.
    old = "input int    qm_ea_id                   = 10911;"
    assert text.count(old) == 1
    text = text.replace(old, f"input int    qm_ea_id                   = {EA_ID};")

    # Hunk 4: pattern measurement surface after the last strategy input,
    # before the first function definition.
    anchor = "input int    strategy_max_hold_bars             = 30;\n"
    assert text.count(anchor) == 1, "last-input anchor not found"
    text = text.replace(anchor, anchor + PATTERN_BLOCK)

    # Hunk 5: OnInit fail-closed profile wiring before INIT_OK + identity log.
    old = '   QM_LogEvent(QM_INFO, "INIT_OK", "{\\"card\\":\\"QM5_10911_grimes_complex_pb\\"}");'
    assert text.count(old) == 1, "INIT_OK anchor not found"
    text = text.replace(
        old,
        INIT_BLOCK
        + f'   QM_LogEvent(QM_INFO, "INIT_OK", "{{\\"ea\\":\\"QM5_{EA_ID}_{SLUG}\\"}}");',
    )

    # Hunk 6: PP_CENSUS_SUMMARY telemetry at the top of OnDeinit.
    old = '   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\\"reason\\":%d}", reason));'
    assert text.count(old) == 1, "DEINIT anchor not found"
    text = text.replace(old, DEINIT_BLOCK + old)

    # Hunk 7: permission gate on the single order consumer.
    old = "   if(Strategy_EntrySignal(req))\n"
    assert text.count(old) == 1, "entry gate anchor not found"
    text = text.replace(old, "   if(Strategy_EntrySignal(req) && Pattern_AllowsRequest(req))\n")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({len(text.splitlines())} lines)")


if __name__ == "__main__":
    main()
