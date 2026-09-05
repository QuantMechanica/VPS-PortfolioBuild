#property strict
#property version   "5.0"
#property description "QM5_41342 anon-market-squeeze-d1-opt"

#define QM_PATTERN_PERMISSION_EA_MANAGED
#include <QM/QM_Common.mqh>
#include <QM/QM_PatternPermission.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_41342 anon-market-squeeze-d1-opt
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_41342_anon-market-squeeze-d1-opt.md
// Source: Anonymous, "Scalping Forex Strategies — Forex Market Squeeze",
// self-published PDF (93933996), ~2014.
//
// Implements the card-literal bearish D1 market squeeze:
// - two consecutive higher closes
// - Day 1 close in the lower half of Day 2's range
// - Variant A sell stop at Day 2 close minus Day 2 range
// - Variant B sell stop one pip below Day 3 close if A was not filled
// - close the short after the first completed bearish daily candle post-entry
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41342;
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
input double strategy_range_fraction     = 0.50;
input double strategy_sl_range_mult      = 1.50;
input int    strategy_fallback_pips      = 1;
input int    strategy_order_valid_days   = 1;
input bool   strategy_enable_variant_b   = true;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
// The card has no additional time/session/spread filter beyond framework gates.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   const int valid_days = (strategy_order_valid_days > 0) ? strategy_order_valid_days : 1;
   const int expiration_seconds = valid_days * 86400;
   double one_pip = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fallback_pips);
   if(one_pip <= 0.0)
      one_pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(one_pip <= 0.0)
      return false;

   // perf-allowed: this strategy is bespoke D1 OHLC structure; each read is a
   // single fixed closed-bar value inside the framework's once-per-bar gate.
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double open_1  = iOpen(_Symbol, PERIOD_D1, 1);  // perf-allowed
   const double high_1  = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed
   const double low_1   = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double close_2 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed
   const double high_2  = iHigh(_Symbol, PERIOD_D1, 2);  // perf-allowed
   const double low_2   = iLow(_Symbol, PERIOD_D1, 2);   // perf-allowed
   const double close_3 = iClose(_Symbol, PERIOD_D1, 3); // perf-allowed
   const double close_4 = iClose(_Symbol, PERIOD_D1, 4); // perf-allowed

   if(close_1 <= 0.0 || open_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 ||
      close_2 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0 ||
      close_3 <= 0.0 || close_4 <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   if(strategy_enable_variant_b)
     {
      const double prior_range = high_2 - low_2;
      const bool prior_setup = (prior_range > 0.0 &&
                                close_3 > close_4 &&
                                close_2 > close_3 &&
                                (high_2 - close_3) >= strategy_range_fraction * prior_range);
      if(prior_setup)
        {
         const double entry_b = QM_StopRulesNormalizePrice(_Symbol, close_1 - one_pip);
         const double sl_b = QM_StopRulesNormalizePrice(_Symbol, high_1 + strategy_sl_range_mult * (high_1 - low_1));
         if(entry_b > 0.0 && sl_b > entry_b && entry_b < bid)
           {
            req.type = QM_SELL_STOP;
            req.price = entry_b;
            req.sl = sl_b;
            req.tp = 0.0;
            req.reason = "market_squeeze_variant_b";
            req.expiration_seconds = expiration_seconds;
            return true;
           }
        }
     }

   const double day2_range = high_1 - low_1;
   const bool setup_a = (day2_range > 0.0 &&
                         close_2 > close_3 &&
                         close_1 > close_2 &&
                         (high_1 - close_2) >= strategy_range_fraction * day2_range);
   if(!setup_a)
      return false;

   const double entry_a = QM_StopRulesNormalizePrice(_Symbol, close_1 - day2_range);
   const double sl_a = QM_StopRulesNormalizePrice(_Symbol, high_1 + strategy_sl_range_mult * day2_range);
   const double tp_dist_a = close_1 - low_1;
   const double tp_a = (tp_dist_a > 0.0) ? QM_StopRulesNormalizePrice(_Symbol, entry_a - tp_dist_a) : 0.0;

   if(entry_a <= 0.0 || sl_a <= entry_a || entry_a >= bid)
      return false;

   req.type = QM_SELL_STOP;
   req.price = entry_a;
   req.sl = sl_a;
   req.tp = (tp_a > 0.0 && tp_a < entry_a) ? tp_a : 0.0;
   req.reason = "market_squeeze_variant_a";
   req.expiration_seconds = expiration_seconds;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   const int valid_days = (strategy_order_valid_days > 0) ? strategy_order_valid_days : 1;
   const int max_age_seconds = valid_days * 86400;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_SELL_STOP)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && (now - setup_time) >= max_age_seconds)
         QM_TM_RemovePendingOrder(ticket, "market_squeeze_pending_expired");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   // perf-allowed: fixed D1 closed-bar exit check for the card's first
   // downward daily movement after entry.
   const datetime current_daily_open = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed
   const double open_1 = iOpen(_Symbol, PERIOD_D1, 1);               // perf-allowed
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);             // perf-allowed
   if(current_daily_open <= 0 || open_1 <= 0.0 || close_1 <= 0.0 || close_1 >= open_1)
      return false;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      const datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(position_time > 0 && position_time < current_daily_open)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------


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

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   g_pp_active = false;
   QM_PP_ProfileInit(g_pp_profile, "DL089_OPT", QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT);
   if(!Opt_AddPattern(opt_pp_buy1, true, "opt_pp_buy1") ||
      !Opt_AddPattern(opt_pp_buy2, true, "opt_pp_buy2") ||
      !Opt_AddPattern(opt_pp_buy3, true, "opt_pp_buy3") ||
      !Opt_AddPattern(opt_pp_sell1, false, "opt_pp_sell1") ||
      !Opt_AddPattern(opt_pp_sell2, false, "opt_pp_sell2") ||
      !Opt_AddPattern(opt_pp_sell3, false, "opt_pp_sell3"))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_LogEvent(QM_INFO, "PP_CENSUS_SUMMARY",
               StringFormat("{\"profile_key\":\"%s\",\"enabled\":%s,\"days_evaluated\":%I64d,\"fire_count\":%I64d,\"legs_suppressed\":%I64d,\"invalid_days\":%I64d}",
                            QM_PP_ProfileKey(g_pp_profile), (g_pp_active ? "true" : "false"),
                            g_pp_days_evaluated, g_pp_fire_count, g_pp_legs_suppressed, g_pp_invalid_days));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. The kill-switch retains a compatibility fallback, but current V5
   // builds keep this explicit first-statement hook.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req) && Pattern_AllowsRequest(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }

