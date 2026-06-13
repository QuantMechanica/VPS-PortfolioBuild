#property strict
#property version   "5.0"
#property description "QM5_10630 Elite Trader OB BOS Bounce"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10630;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_swing_width        = 3;
input int    strategy_atr_period         = 14;
input double strategy_bos_atr_mult       = 0.10;
input double strategy_close_extreme_pct  = 0.25;
input double strategy_ob_min_atr_mult    = 0.20;
input double strategy_ob_max_atr_mult    = 1.25;
input double strategy_ob_entry_pct       = 0.50;
input double strategy_sl_atr_mult        = 0.15;
input double strategy_target_rr          = 1.80;
input int    strategy_expiry_bars        = 8;
input int    strategy_time_exit_bars     = 32;
input int    strategy_structure_lookback = 80;
input int    strategy_max_spread_points  = 80;

datetime g_active_zone_time = 0;
datetime g_last_used_zone_time = 0;
int      g_active_zone_side = 0;
double   g_active_ob_low = 0.0;
double   g_active_ob_high = 0.0;
double   g_cached_swing_high = 0.0;
double   g_cached_swing_low = 0.0;

double BarOpen(const int shift)  { return iOpen(_Symbol, _Period, shift); }   // perf-allowed: bespoke closed-bar order-block structure
double BarHigh(const int shift)  { return iHigh(_Symbol, _Period, shift); }   // perf-allowed: bespoke closed-bar order-block structure
double BarLow(const int shift)   { return iLow(_Symbol, _Period, shift); }    // perf-allowed: bespoke closed-bar order-block structure
double BarClose(const int shift) { return iClose(_Symbol, _Period, shift); }  // perf-allowed: bespoke closed-bar order-block structure
datetime BarTime(const int shift){ return iTime(_Symbol, _Period, shift); }   // perf-allowed: bespoke closed-bar order-block structure

bool IsBullCandle(const int shift)
  {
   return (BarClose(shift) > BarOpen(shift));
  }

bool IsBearCandle(const int shift)
  {
   return (BarClose(shift) < BarOpen(shift));
  }

bool IsSwingHigh(const int shift, const int width)
  {
   const double h = BarHigh(shift);
   if(h <= 0.0)
      return false;
   for(int i = 1; i <= width; ++i)
     {
      if(BarHigh(shift - i) >= h || BarHigh(shift + i) > h)
         return false;
     }
   return true;
  }

bool IsSwingLow(const int shift, const int width)
  {
   const double l = BarLow(shift);
   if(l <= 0.0)
      return false;
   for(int i = 1; i <= width; ++i)
     {
      if(BarLow(shift - i) <= l || BarLow(shift + i) < l)
         return false;
     }
   return true;
  }

bool FindRecentSwingHighs(const int width, const int lookback, double &latest, double &previous)
  {
   latest = 0.0;
   previous = 0.0;
   const int first_shift = width + 1;
   const int last_shift = MathMax(first_shift, lookback - width);
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!IsSwingHigh(shift, width))
         continue;
      if(latest <= 0.0)
         latest = BarHigh(shift);
      else
        {
         previous = BarHigh(shift);
         return true;
        }
     }
   return false;
  }

bool FindRecentSwingLows(const int width, const int lookback, double &latest, double &previous)
  {
   latest = 0.0;
   previous = 0.0;
   const int first_shift = width + 1;
   const int last_shift = MathMax(first_shift, lookback - width);
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!IsSwingLow(shift, width))
         continue;
      if(latest <= 0.0)
         latest = BarLow(shift);
      else
        {
         previous = BarLow(shift);
         return true;
        }
     }
   return false;
  }

bool FindOrderBlock(const bool long_side, const int max_shift, int &ob_shift)
  {
   ob_shift = 0;
   for(int shift = 2; shift <= max_shift; ++shift)
     {
      if(long_side && IsBearCandle(shift))
        {
         ob_shift = shift;
         return true;
        }
      if(!long_side && IsBullCandle(shift))
        {
         ob_shift = shift;
         return true;
        }
     }
   return false;
  }

bool HasOurPendingOrder()
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
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

void CancelInvalidPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double close1 = BarClose(1);
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT)
         continue;

      bool cancel = false;
      if(g_active_zone_time > 0 && g_active_zone_side > 0 && close1 < g_active_ob_low)
         cancel = true;
      if(g_active_zone_time > 0 && g_active_zone_side < 0 && close1 > g_active_ob_high)
         cancel = true;

      if(cancel && QM_TM_RemovePendingOrder(ticket, "ob_invalidated_before_fill"))
        {
         g_last_used_zone_time = g_active_zone_time;
         g_active_zone_time = 0;
         g_active_zone_side = 0;
        }
     }
  }

bool HasOurPosition(ENUM_POSITION_TYPE &pos_type, datetime &open_time)
  {
   pos_type = POSITION_TYPE_BUY;
   open_time = 0;
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
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool BuildLongRequest(QM_EntryRequest &req, const double atr)
  {
   double swing_high = 0.0;
   double prev_high = 0.0;
   double swing_low = 0.0;
   double prev_low = 0.0;
   if(!FindRecentSwingHighs(strategy_swing_width, strategy_structure_lookback, swing_high, prev_high))
      return false;
   if(!FindRecentSwingLows(strategy_swing_width, strategy_structure_lookback, swing_low, prev_low))
      return false;
   g_cached_swing_high = swing_high;
   g_cached_swing_low = swing_low;
   if(swing_low <= prev_low || swing_high <= prev_high)
      return false;

   const double h1 = BarHigh(1);
   const double l1 = BarLow(1);
   const double c1 = BarClose(1);
   const double range1 = h1 - l1;
   if(range1 <= 0.0)
      return false;
   if(c1 < swing_high + strategy_bos_atr_mult * atr)
      return false;
   if((h1 - c1) / range1 > strategy_close_extreme_pct)
      return false;
   if(BarLow(1) <= BarHigh(3))
      return false;

   int ob_shift = 0;
   if(!FindOrderBlock(true, strategy_structure_lookback, ob_shift))
      return false;

   const double ob_high = BarHigh(ob_shift);
   const double ob_low = BarLow(ob_shift);
   const double ob_height = ob_high - ob_low;
   if(ob_height < strategy_ob_min_atr_mult * atr || ob_height > strategy_ob_max_atr_mult * atr)
      return false;

   const datetime zone_time = BarTime(1);
   if(zone_time <= 0 || zone_time == g_last_used_zone_time)
      return false;

   const double entry = ob_low + ob_height * strategy_ob_entry_pct;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0 || ask <= 0.0 || entry >= ask)
      return false;

   req.type = QM_BUY_LIMIT;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(ob_low - strategy_sl_atr_mult * atr, _Digits);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_target_rr);
   req.reason = "ET_OB_BOS_BOUNCE_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_expiry_bars) * PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   g_active_zone_time = zone_time;
   g_active_zone_side = 1;
   g_active_ob_low = ob_low;
   g_active_ob_high = ob_high;
   g_last_used_zone_time = zone_time;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool BuildShortRequest(QM_EntryRequest &req, const double atr)
  {
   double swing_high = 0.0;
   double prev_high = 0.0;
   double swing_low = 0.0;
   double prev_low = 0.0;
   if(!FindRecentSwingHighs(strategy_swing_width, strategy_structure_lookback, swing_high, prev_high))
      return false;
   if(!FindRecentSwingLows(strategy_swing_width, strategy_structure_lookback, swing_low, prev_low))
      return false;
   g_cached_swing_high = swing_high;
   g_cached_swing_low = swing_low;
   if(swing_high >= prev_high || swing_low >= prev_low)
      return false;

   const double h1 = BarHigh(1);
   const double l1 = BarLow(1);
   const double c1 = BarClose(1);
   const double range1 = h1 - l1;
   if(range1 <= 0.0)
      return false;
   if(c1 > swing_low - strategy_bos_atr_mult * atr)
      return false;
   if((c1 - l1) / range1 > strategy_close_extreme_pct)
      return false;
   if(BarHigh(1) >= BarLow(3))
      return false;

   int ob_shift = 0;
   if(!FindOrderBlock(false, strategy_structure_lookback, ob_shift))
      return false;

   const double ob_high = BarHigh(ob_shift);
   const double ob_low = BarLow(ob_shift);
   const double ob_height = ob_high - ob_low;
   if(ob_height < strategy_ob_min_atr_mult * atr || ob_height > strategy_ob_max_atr_mult * atr)
      return false;

   const datetime zone_time = BarTime(1);
   if(zone_time <= 0 || zone_time == g_last_used_zone_time)
      return false;

   const double entry = ob_low + ob_height * strategy_ob_entry_pct;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0 || entry <= bid)
      return false;

   req.type = QM_SELL_LIMIT;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = NormalizeDouble(ob_high + strategy_sl_atr_mult * atr, _Digits);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_target_rr);
   req.reason = "ET_OB_BOS_BOUNCE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_expiry_bars) * PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   g_active_zone_time = zone_time;
   g_active_zone_side = -1;
   g_active_ob_low = ob_low;
   g_active_ob_high = ob_high;
   g_last_used_zone_time = zone_time;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M30)
      return true;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   CancelInvalidPendingOrders();
   if(HasOurPendingOrder())
      return false;

   if(strategy_swing_width < 1 || strategy_atr_period < 1 || strategy_target_rr <= 0.0)
      return false;
   if(strategy_structure_lookback < strategy_swing_width * 2 + 5)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(BuildLongRequest(req, atr))
      return true;
   return BuildShortRequest(req, atr);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, BE, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   datetime open_time;
   if(!HasOurPosition(pos_type, open_time))
      return false;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar > 0 && strategy_time_exit_bars > 0)
     {
      if(TimeCurrent() - open_time >= strategy_time_exit_bars * seconds_per_bar)
         return true;
     }

   const double close1 = BarClose(1);
   if(pos_type == POSITION_TYPE_BUY && g_cached_swing_low > 0.0 && close1 < g_cached_swing_low)
      return true;
   if(pos_type == POSITION_TYPE_SELL && g_cached_swing_high > 0.0 && close1 > g_cached_swing_high)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10630_et-ob-bos-bounce\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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
