#property strict
#property version   "5.0"
#property description "QM5_41332 Larry Williams 18-Day MA + Two Outside-Bar D1 - DL-089 opt sibling"
// Strategy Card: QM5_41332 (larry-williams-18ma-2outside-bars-d1-opt), G0 APPROVED 2026-09-03.
// Parent EA: QM5_11910 (larry-williams-18ma-2outside-bars-d1), recompiled 2026-09-03.
//
// DL-089 MEASUREMENT SIBLING - parent QM5_11910 / NZDUSD.DWX.
// This EA preserves the parent entry, exit, sizing, news, and Friday-close
// mechanics byte-for-byte and adds ONLY the six closed-D1 pattern-permission
// veto inputs (opt_pp_buy1..3, opt_pp_sell1..3). Zero disables a slot, so the
// shipped baseline is neutral (census_control) and reproduces the parent
// exactly. It exists solely to run the DL-089 pattern-permission census;
// no live or pipeline verdict is authorized.

#define QM_PATTERN_PERMISSION_EA_MANAGED
#include <QM/QM_Common.mqh>
#include <QM/QM_PatternPermission.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41332
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41332;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ma_period         = 18;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_target_atr_mult   = 4.0;
input int    strategy_order_validity    = 5;
input int    strategy_time_stop_bars    = 30;

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
                  StringFormat("{\"input\":\"%s\",\"predicate_id\":%d}", input_name, predicate_id));
      return false;
     }
   const QM_PatternId pid = (QM_PatternId)predicate_id;
   const bool added = buy_side ? QM_PP_ProfileAddBuy(g_pp_profile, pid)
                               : QM_PP_ProfileAddSell(g_pp_profile, pid);
   if(!added)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\"input\":\"%s\",\"predicate_id\":%d}", input_name, predicate_id));
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
      QM_LogEvent(QM_WARN, "PP_CENSUS_BLOCK", "{\"reason\":\"permission_invalid\"}");
      return false;
     }
   const bool buy_side = QM_OrderTypeIsBuy(req.type);
   const bool allowed = buy_side ? perm.allow_buy : perm.allow_sell;
   if(!allowed)
     {
      g_pp_fire_count++;
      g_pp_legs_suppressed++;
      QM_LogEvent(QM_INFO, "PP_CENSUS_BLOCK",
                  StringFormat("{\"side\":\"%s\",\"bar\":\"%s\",\"reason\":\"%s\"}",
                               (buy_side ? "BUY" : "SELL"),
                               TimeToString(perm.reference_bar_time), perm.reason));
     }
   return allowed;
  }

// State tracking for simulated pending orders
double g_long_level = 0.0;
double g_long_sl    = 0.0;
double g_long_tp    = 0.0;
int    g_long_valid = 0;

double g_short_level = 0.0;
double g_short_sl    = 0.0;
double g_short_tp    = 0.0;
int    g_short_valid = 0;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

bool IsInsideBar(int shift)
{
   double high_curr = iHigh(_Symbol, PERIOD_D1, shift);      // perf-allowed: D1 outside-bar structure read, gated by QM_IsNewBar in OnTick
   double low_curr  = iLow(_Symbol, PERIOD_D1, shift);       // perf-allowed: D1 outside-bar structure read, gated by QM_IsNewBar in OnTick
   double high_prev = iHigh(_Symbol, PERIOD_D1, shift + 1);  // perf-allowed: D1 outside-bar structure read, gated by QM_IsNewBar in OnTick
   double low_prev  = iLow(_Symbol, PERIOD_D1, shift + 1);   // perf-allowed: D1 outside-bar structure read, gated by QM_IsNewBar in OnTick

   return (high_curr < high_prev && low_curr > low_prev);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false;

   // Bar t = 1, Bar t-1 = 2
   const double low1 = iLow(_Symbol, PERIOD_D1, 1);      // perf-allowed: D1 setup bar structure read, gated by QM_IsNewBar in OnTick
   const double low2 = iLow(_Symbol, PERIOD_D1, 2);      // perf-allowed: D1 setup bar structure read, gated by QM_IsNewBar in OnTick
   const double high1 = iHigh(_Symbol, PERIOD_D1, 1);    // perf-allowed: D1 setup bar structure read, gated by QM_IsNewBar in OnTick
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2);    // perf-allowed: D1 setup bar structure read, gated by QM_IsNewBar in OnTick

   const double ma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 1);
   const double ma2 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 2);
   const double atr1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(low1 <= 0.0 || low2 <= 0.0 || ma1 <= 0.0 || ma2 <= 0.0 || atr1 <= 0.0) return false;

   // Check Bullish Setup
   if(low1 > ma1 && low2 > ma2 && !IsInsideBar(1) && !IsInsideBar(2))
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      g_long_level = MathMax(high1, high2) + (10 * point); // +1 pip
      g_long_sl = g_long_level - (strategy_atr_sl_mult * atr1);
      g_long_tp = g_long_level + (strategy_target_atr_mult * atr1);
      g_long_valid = strategy_order_validity;
   }

   // Check Bearish Setup
   if(high1 < ma1 && high2 < ma2 && !IsInsideBar(1) && !IsInsideBar(2))
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      g_short_level = MathMin(low1, low2) - (10 * point); // -1 pip
      g_short_sl = g_short_level + (strategy_atr_sl_mult * atr1);
      g_short_tp = g_short_level - (strategy_target_atr_mult * atr1);
      g_short_valid = strategy_order_validity;
   }

   // Decrease validity
   if(g_long_valid > 0)  g_long_valid--;
   if(g_short_valid > 0) g_short_valid--;

   // Check Trigger
   bool trigger_long = false;
   bool trigger_short = false;

   if(g_long_valid >= 0 && g_long_level > 0.0)
   {
      if(high1 >= g_long_level)
      {
         trigger_long = true;
         g_long_valid = 0; // consumed
      }
   }

   if(g_short_valid >= 0 && g_short_level > 0.0)
   {
      if(low1 <= g_short_level)
      {
         trigger_short = true;
         g_short_valid = 0; // consumed
      }
   }

   if(!trigger_long && !trigger_short) return false;

   QM_OrderType side = trigger_long ? QM_BUY : QM_SELL;

   req.type = side;
   req.price = 0.0;
   req.sl = (side == QM_BUY) ? g_long_sl : g_short_sl;
   req.tp = (side == QM_BUY) ? g_long_tp : g_short_tp;
   req.reason = (side == QM_BUY) ? "WILLIAMS_18MA_LONG" : "WILLIAMS_18MA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time stop
      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_D1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }

      // MA Cross Exit
      const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 close-vs-MA exit read, gated by QM_IsNewBar in OnTick
      const double ma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_ma_period, 1);

      if(close1 <= 0.0 || ma1 <= 0.0) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(ptype == POSITION_TYPE_BUY && close1 < ma1) return true;
      if(ptype == POSITION_TYPE_SELL && close1 > ma1) return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   g_pp_active = false;
   QM_PP_ProfileInit(g_pp_profile, "DL089_OPT", QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT);
   if(!Opt_AddPattern(opt_pp_buy1, true, "opt_pp_buy1") ||
      !Opt_AddPattern(opt_pp_buy2, true, "opt_pp_buy2") ||
      !Opt_AddPattern(opt_pp_buy3, true, "opt_pp_buy3") ||
      !Opt_AddPattern(opt_pp_sell1, false, "opt_pp_sell1") ||
      !Opt_AddPattern(opt_pp_sell2, false, "opt_pp_sell2") ||
      !Opt_AddPattern(opt_pp_sell3, false, "opt_pp_sell3"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_41332_larry-williams-18ma-2outside-bars-d1-opt\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "PP_CENSUS_SUMMARY",
               StringFormat("{\"profile_key\":\"%s\",\"enabled\":%s,\"days_evaluated\":%I64d,\"fire_count\":%I64d,\"legs_suppressed\":%I64d,\"invalid_days\":%I64d}",
                            QM_PP_ProfileKey(g_pp_profile), (g_pp_active ? "true" : "false"),
                            g_pp_days_evaluated, g_pp_fire_count, g_pp_legs_suppressed, g_pp_invalid_days));
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req) && Pattern_AllowsRequest(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
