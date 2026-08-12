#property strict
#property version   "5.0"
#property description "QM5_20266 Collins 9-Day 66 Percent Momentum - WTI"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20266 - Collins 9-Day 66 Percent Momentum - WTI
// -----------------------------------------------------------------------------
// Source-exact daily geometry from Collins (2006), Chapter 41:
//   XH = highest(high[1..9]) - close[1]
//   XL = close[1] - lowest(low[1..9])
//   XX = max(XH, XL)
//   XH > XL: buy stop  at open[0] + 0.66 * XL, SL = entry - 1.32 * XX
//   XL > XH: sell stop at open[0] - 0.66 * XH, SL = entry + 1.32 * XX
// The WTI carrier is a falsification port; no source performance is transferred.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20266;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_d1         = 9;
input double strategy_entry_fraction      = 0.66;
input double strategy_stop_fraction       = 1.32;
input int    strategy_pending_expiry_hours = 24;
input int    strategy_max_hold_bars        = 20;
input int    strategy_max_spread_points    = 1000;
input int    strategy_min_stop_points      = 10;

datetime g_strategy_bar_time       = 0;
double   g_strategy_day_open       = 0.0;
double   g_strategy_xh             = 0.0;
double   g_strategy_xl             = 0.0;
double   g_strategy_xx             = 0.0;
bool     g_strategy_geometry_valid = false;
bool     g_strategy_entry_eligible = false;
bool     g_strategy_new_bar_tick   = false;
string   g_strategy_arm_key        = "";

bool Strategy_IsFinitePositive(const double value)
  {
   return (MathIsValidNumber(value) && value > 0.0);
  }

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_IsStopOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_HasPendingStop()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsStopOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_FindOpenPosition(ulong &ticket,
                               ENUM_POSITION_TYPE &position_type,
                               datetime &opened_at)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_LoadDailyGeometry()
  {
   g_strategy_geometry_valid = false;
   g_strategy_day_open = 0.0;
   g_strategy_xh = 0.0;
   g_strategy_xl = 0.0;
   g_strategy_xx = 0.0;

   // Hard safety bound keeps the raw-price scan finite even under a malformed set.
   if(strategy_lookback_d1 < 2 || strategy_lookback_d1 > 64)
      return false;
   if(Bars(_Symbol, PERIOD_D1) < strategy_lookback_d1 + 2) // perf-allowed: bounded D1 warmup guard, evaluated once per D1 transition.
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: once per new D1 bar.
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: bounded D1 geometry scan.
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: bounded D1 geometry scan.
   g_strategy_day_open = iOpen(_Symbol, PERIOD_D1, 0);  // perf-allowed: source next-open reference.
   if(!Strategy_IsFinitePositive(close1) ||
      !Strategy_IsFinitePositive(high1) ||
      !Strategy_IsFinitePositive(low1) ||
      !Strategy_IsFinitePositive(g_strategy_day_open))
      return false;

   double highest = high1;
   double lowest = low1;
   for(int shift = 2; shift <= strategy_lookback_d1; ++shift)
     {
      const double bar_high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: <=64 reads once per D1 bar.
      const double bar_low  = iLow(_Symbol, PERIOD_D1, shift);  // perf-allowed: <=64 reads once per D1 bar.
      if(!Strategy_IsFinitePositive(bar_high) || !Strategy_IsFinitePositive(bar_low))
         return false;
      highest = MathMax(highest, bar_high);
      lowest = MathMin(lowest, bar_low);
     }

   if(!MathIsValidNumber(highest) || !MathIsValidNumber(lowest) || highest <= lowest)
      return false;

   g_strategy_xh = highest - close1;
   g_strategy_xl = close1 - lowest;
   g_strategy_xx = MathMax(g_strategy_xh, g_strategy_xl);
   if(!Strategy_IsFinitePositive(g_strategy_xh) ||
      !Strategy_IsFinitePositive(g_strategy_xl) ||
      !Strategy_IsFinitePositive(g_strategy_xx) ||
      g_strategy_xh == g_strategy_xl)
      return false;

   g_strategy_geometry_valid = true;
   return true;
  }

void Strategy_PrepareDailyBar()
  {
   g_strategy_entry_eligible = false;
   g_strategy_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: once per observed D1 transition.
   Strategy_LoadDailyGeometry();

   if(g_strategy_bar_time <= 0 || g_strategy_arm_key == "")
      return;

   // A restart on the same D1 bar must preserve any already-armed pending order
   // and must never create a second attempt.
   if(GlobalVariableCheck(g_strategy_arm_key) &&
      (datetime)GlobalVariableGet(g_strategy_arm_key) == g_strategy_bar_time)
      return;

   Strategy_CancelPendingStops("COLLINS_66MOM_NEW_D1");

   // Consume before news, spread, quote, broker-distance, and send gates.
   if(GlobalVariableSet(g_strategy_arm_key, (double)g_strategy_bar_time) == 0)
     {
      QM_LogEvent(QM_ERROR,
                  "PENDING_STATE_WRITE_FAILED",
                  StringFormat("{\"key\":\"%s\",\"bar\":%I64d}",
                               QM_LoggerEscapeJson(g_strategy_arm_key),
                               (long)g_strategy_bar_time));
      return;
     }
   GlobalVariablesFlush();
   g_strategy_entry_eligible = g_strategy_geometry_valid;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_ea_id != 20266 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_lookback_d1 < 2 || strategy_lookback_d1 > 64)
      return true;
   if(!MathIsValidNumber(strategy_entry_fraction) || strategy_entry_fraction <= 0.0)
      return true;
   if(!MathIsValidNumber(strategy_stop_fraction) || strategy_stop_fraction <= 0.0)
      return true;
   if(strategy_pending_expiry_hours <= 0 || strategy_max_hold_bars <= 0)
      return true;
   if(strategy_max_spread_points < 0 || strategy_min_stop_points <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20266_COLLINS_66MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(3600, strategy_pending_expiry_hours * 3600);

   if(!g_strategy_entry_eligible || !g_strategy_geometry_valid)
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingStop())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points < 0 || spread_points > strategy_max_spread_points)
         return false;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!Strategy_IsFinitePositive(point) ||
      !Strategy_IsFinitePositive(ask) ||
      !Strategy_IsFinitePositive(bid))
      return false;

   const double broker_stop_points = MathMax(0.0, (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL));
   const double required_distance = (broker_stop_points + (double)strategy_min_stop_points) * point;
   if(!Strategy_IsFinitePositive(required_distance))
      return false;

   double raw_entry = 0.0;
   double raw_sl = 0.0;
   if(g_strategy_xh > g_strategy_xl)
     {
      raw_entry = g_strategy_day_open + strategy_entry_fraction * g_strategy_xl;
      raw_sl = raw_entry - strategy_stop_fraction * g_strategy_xx;
      req.type = QM_BUY_STOP;
      req.reason = "COLLINS_66MOM_BUY_STOP";
     }
   else if(g_strategy_xl > g_strategy_xh)
     {
      raw_entry = g_strategy_day_open - strategy_entry_fraction * g_strategy_xh;
      raw_sl = raw_entry + strategy_stop_fraction * g_strategy_xx;
      req.type = QM_SELL_STOP;
      req.reason = "COLLINS_66MOM_SELL_STOP";
     }
   else
      return false;

   if(!Strategy_IsFinitePositive(raw_entry) || !Strategy_IsFinitePositive(raw_sl))
      return false;

   req.price = QM_TM_NormalizePrice(_Symbol, raw_entry);
   req.sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
   if(!Strategy_IsFinitePositive(req.price) || !Strategy_IsFinitePositive(req.sl))
      return false;
   if(MathAbs(req.price - req.sl) < required_distance)
      return false;

   if(req.type == QM_BUY_STOP)
     {
      if(req.price <= ask + required_distance || req.sl >= req.price)
         return false;
     }
   else
     {
      if(req.price >= bid - required_distance || req.sl <= req.price)
         return false;
     }

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // A filled stop consumes the single order; fail closed if a broker leaves a
   // sibling/stale stop behind after a position appears.
   if(Strategy_HasOpenPosition() && Strategy_HasPendingStop())
      Strategy_CancelPendingStops("COLLINS_66MOM_POSITION_OPEN");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   if(!Strategy_FindOpenPosition(ticket, position_type, opened_at))
      return false;

   if(g_strategy_new_bar_tick && opened_at > 0)
     {
      const int held_bars = iBarShift(_Symbol, PERIOD_D1, opened_at, false); // perf-allowed: once per D1 transition.
      if(held_bars >= strategy_max_hold_bars)
         return true;
     }

   if(!g_strategy_geometry_valid)
      return false;

   if(position_type == POSITION_TYPE_BUY && g_strategy_xl > g_strategy_xh)
     {
      const double short_trigger = g_strategy_day_open - strategy_entry_fraction * g_strategy_xh;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (Strategy_IsFinitePositive(short_trigger) &&
              Strategy_IsFinitePositive(bid) && bid <= short_trigger);
     }

   if(position_type == POSITION_TYPE_SELL && g_strategy_xh > g_strategy_xl)
     {
      const double long_trigger = g_strategy_day_open + strategy_entry_fraction * g_strategy_xl;
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return (Strategy_IsFinitePositive(long_trigger) &&
              Strategy_IsFinitePositive(ask) && ask >= long_trigger);
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   g_strategy_arm_key = StringFormat("QM5_%d_%d_%s_D1_ARM",
                                     qm_ea_id,
                                     QM_FrameworkMagic(),
                                     _Symbol);
   if(StringLen(g_strategy_arm_key) > 63)
     {
      QM_LogEvent(QM_ERROR, "SETUP_CONFIG_INVALID", "{\"field\":\"arm_state_key\"}");
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20266\",\"ea\":\"collins-66mom\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   g_strategy_new_bar_tick = QM_IsNewBar();
   if(g_strategy_new_bar_tick)
     {
      QM_EquityStreamOnNewBar();
      if(Strategy_IsXtiD1())
         Strategy_PrepareDailyBar();
     }

   // The central Friday closer handles positions; this strategy also owns a
   // day-only pending stop, so remove it before returning from the boundary.
   if(QM_FrameworkFridayCloseNow(broker_now))
      Strategy_CancelPendingStops("COLLINS_66MOM_FRIDAY_CLOSE");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      return; // opposite source trigger is flatten-only; never reverse this tick.
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !g_strategy_new_bar_tick)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
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
