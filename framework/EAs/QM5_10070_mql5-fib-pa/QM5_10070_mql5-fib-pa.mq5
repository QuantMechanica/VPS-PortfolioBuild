#property strict
#property version   "5.0"
#property description "QM5_10070 MQL5 Fibonacci price-action reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10070;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_depth              = 80;
input double strategy_min_retracement    = 23.6;
input double strategy_max_retracement    = 78.6;
input int    strategy_tolerance_points   = 35;
input int    strategy_max_spread_points  = 45;
input int    strategy_atr_period         = 14;
input double strategy_atr_buffer_mult    = 0.20;
input double strategy_rr_target          = 1.80;
input int    strategy_signal_threshold   = 3;
input int    strategy_session_start_hour = 0;
input int    strategy_session_end_hour   = 24;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

bool SessionAllowsTrade()
  {
   if(strategy_session_start_hour <= 0 && strategy_session_end_hour >= 24)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int h = dt.hour;
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (h >= start_h && h < end_h);
   return (h >= start_h || h < end_h);
  }

int CurrentPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY)
            return 1;
         if(ptype == POSITION_TYPE_SELL)
            return -1;
        }
     }
   return 0;
  }

double RetracementRatio(const int index)
  {
   if(index == 0) return 0.236;
   if(index == 1) return 0.382;
   if(index == 2) return 0.500;
   if(index == 3) return 0.618;
   return 0.786;
  }

int LevelWeight(const int index)
  {
   if(index == 1 || index == 3)
      return 2;
   if(index == 2)
      return 1;
   return 0;
  }

bool BullishEngulfing()
  {
   const double o1 = iOpen(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   const double o2 = iOpen(_Symbol, _Period, 2);
   const double c2 = iClose(_Symbol, _Period, 2);
   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;
   return (c2 < o2 && c1 > o1 && o1 <= c2 && c1 >= o2);
  }

bool BearishEngulfing()
  {
   const double o1 = iOpen(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   const double o2 = iOpen(_Symbol, _Period, 2);
   const double c2 = iClose(_Symbol, _Period, 2);
   if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
      return false;
   return (c2 > o2 && c1 < o1 && o1 >= c2 && c1 <= o2);
  }

bool Hammer()
  {
   const double o = iOpen(_Symbol, _Period, 1);
   const double c = iClose(_Symbol, _Period, 1);
   const double h = iHigh(_Symbol, _Period, 1);
   const double l = iLow(_Symbol, _Period, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0 || h <= l)
      return false;

   const double body = MathAbs(c - o);
   const double range = h - l;
   const double upper = h - MathMax(o, c);
   const double lower = MathMin(o, c) - l;
   if(body <= 0.0)
      return false;
   return (body <= range * 0.35 && lower >= body * 2.0 && upper <= body * 1.2 && c >= o);
  }

bool ShootingStar()
  {
   const double o = iOpen(_Symbol, _Period, 1);
   const double c = iClose(_Symbol, _Period, 1);
   const double h = iHigh(_Symbol, _Period, 1);
   const double l = iLow(_Symbol, _Period, 1);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0 || h <= l)
      return false;

   const double body = MathAbs(c - o);
   const double range = h - l;
   const double upper = h - MathMax(o, c);
   const double lower = MathMin(o, c) - l;
   if(body <= 0.0)
      return false;
   return (body <= range * 0.35 && upper >= body * 2.0 && lower <= body * 1.2 && c <= o);
  }

int BullishPatternWeight()
  {
   if(BullishEngulfing())
      return 2;
   if(Hammer())
      return 1;
   return 0;
  }

int BearishPatternWeight()
  {
   if(BearishEngulfing())
      return 2;
   if(ShootingStar())
      return 1;
   return 0;
  }

double CloserTakeProfit(const QM_OrderType side,
                        const double entry,
                        const double sl,
                        const double swing_extreme)
  {
   const double rr_tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(rr_tp <= 0.0 || swing_extreme <= 0.0)
      return 0.0;

   if(side == QM_BUY)
     {
      if(swing_extreme <= entry || rr_tp <= entry)
         return 0.0;
      return NormalizeStrategyPrice(MathMin(swing_extreme, rr_tp));
     }

   if(swing_extreme >= entry || rr_tp >= entry)
      return 0.0;
   return NormalizeStrategyPrice(MathMax(swing_extreme, rr_tp));
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   if(!SessionAllowsTrade())
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_depth < 10 || strategy_tolerance_points < 1 ||
      strategy_min_retracement < 0.0 || strategy_max_retracement > 100.0 ||
      strategy_min_retracement >= strategy_max_retracement)
      return false;

   const int bars_available = Bars(_Symbol, _Period);
   if(bars_available <= strategy_depth + 5)
      return false;

   const int hi_shift = iHighest(_Symbol, _Period, MODE_HIGH, strategy_depth, 1);
   const int lo_shift = iLowest(_Symbol, _Period, MODE_LOW, strategy_depth, 1);
   if(hi_shift <= 0 || lo_shift <= 0 || hi_shift == lo_shift)
      return false;

   const double swing_high = iHigh(_Symbol, _Period, hi_shift);
   const double swing_low = iLow(_Symbol, _Period, lo_shift);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(swing_high <= swing_low || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return false;

   const double range = swing_high - swing_low;
   const double tolerance = strategy_tolerance_points * point;
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double buffer = MathMax(tolerance, atr * strategy_atr_buffer_mult);
   if(buffer <= 0.0)
      return false;

   const bool uptrend = (lo_shift > hi_shift);
   const bool downtrend = (hi_shift > lo_shift);
   int best_level_index = -1;
   double best_level = 0.0;
   int best_level_weight = 0;
   double best_distance = DBL_MAX;

   for(int i = 0; i < 5; ++i)
     {
      const double retracement_pct = RetracementRatio(i) * 100.0;
      if(retracement_pct < strategy_min_retracement || retracement_pct > strategy_max_retracement)
         continue;

      const double level = uptrend
         ? swing_high - range * RetracementRatio(i)
         : swing_low + range * RetracementRatio(i);
      const double distance = MathAbs(close1 - level);
      if(distance <= tolerance && distance < best_distance)
        {
         best_level_index = i;
         best_level = level;
         best_level_weight = LevelWeight(i);
         best_distance = distance;
        }
     }

   if(best_level_index < 0)
      return false;

   if(uptrend)
     {
      const int pattern_weight = BullishPatternWeight();
      if(best_level_weight + pattern_weight < strategy_signal_threshold)
         return false;

      const double entry = ask;
      const double raw_sl = MathMin(low1, best_level) - buffer;
      const double sl = NormalizeStrategyPrice(raw_sl);
      const double tp = CloserTakeProfit(QM_BUY, entry, sl, swing_high);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = (pattern_weight >= 2) ? "MQL5_FIB_PA_BUY_ENGULFING" : "MQL5_FIB_PA_BUY_HAMMER";
      return true;
     }

   if(downtrend)
     {
      const int pattern_weight = BearishPatternWeight();
      if(best_level_weight + pattern_weight < strategy_signal_threshold)
         return false;

      const double entry = bid;
      const double raw_sl = MathMax(high1, best_level) + buffer;
      const double sl = NormalizeStrategyPrice(raw_sl);
      const double tp = CloserTakeProfit(QM_SELL, entry, sl, swing_low);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = (pattern_weight >= 2) ? "MQL5_FIB_PA_SELL_ENGULFING" : "MQL5_FIB_PA_SELL_STAR";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP exits with no trailing, BE, or partial close.
  }

bool Strategy_ExitSignal()
  {
   const int position_direction = CurrentPositionDirection();
   if(position_direction == 0)
      return false;

   QM_EntryRequest probe;
   if(!Strategy_EntrySignal(probe))
      return false;

   if(position_direction > 0 && probe.type == QM_SELL)
      return true;
   if(position_direction < 0 && probe.type == QM_BUY)
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10070\",\"ea\":\"mql5-fib-pa\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
