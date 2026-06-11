#property strict
#property version   "5.0"
#property description "QM5_9926 ForexFactory Riverband SOP Sweep BOS M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9926;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;
input int    strategy_atr_percentile_lookback = 60;
input double strategy_atr_percentile_min  = 20.0;
input double strategy_level_proximity_atr = 0.35;
input double strategy_sweep_depth_atr     = 0.20;
input int    strategy_sweep_window_bars   = 6;
input int    strategy_bos_lookback_bars   = 5;
input double strategy_sl_buffer_atr       = 0.30;
input double strategy_max_stop_atr        = 2.20;
input double strategy_take_profit_r       = 1.80;
input int    strategy_time_stop_bars      = 36;
input int    strategy_session_window_minutes = 180;
input int    strategy_tokyo_open_hour     = 0;
input int    strategy_london_open_hour    = 8;
input int    strategy_newyork_open_hour   = 13;
input int    strategy_max_spread_points   = 0;
input int    strategy_be_buffer_points    = 0;

int      g_last_closed_bar_signal = 0;
datetime g_last_signal_bar_time   = 0;

double NormalizeSymbolPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool InsideSessionWindow(const datetime t, const int open_hour, const int window_minutes)
  {
   if(window_minutes <= 0)
      return false;
   const int now_min = MinuteOfDay(t);
   const int open_min = open_hour * 60;
   int elapsed = now_min - open_min;
   if(elapsed < 0)
      elapsed += 1440;
   return elapsed >= 0 && elapsed < window_minutes;
  }

bool InTradingSession(const datetime t)
  {
   return InsideSessionWindow(t, strategy_tokyo_open_hour, strategy_session_window_minutes) ||
          InsideSessionWindow(t, strategy_london_open_hour, strategy_session_window_minutes) ||
          InsideSessionWindow(t, strategy_newyork_open_hour, strategy_session_window_minutes);
  }

bool Strategy_NoTradeFilter()
  {
   if(!InTradingSession(TimeCurrent()))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool LoadRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &rates[])
  {
   if(count <= 0)
      return false;
   ArrayResize(rates, count);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, count, rates); // perf-allowed: closed-bar structural sweep/BOS window, caller is gated by QM_IsNewBar().
   if(copied < count)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

void AddLevel(double &levels[], int &count, const double level)
  {
   if(level <= 0.0)
      return;
   for(int i = 0; i < count; ++i)
      if(MathAbs(levels[i] - level) <= _Point * 2.0)
         return;
   ArrayResize(levels, count + 1);
   levels[count] = level;
   count++;
  }

void BuildHtfLevels(const MqlRates &h1[], const int h1_count,
                    const MqlRates &h4[], const int h4_count,
                    double &supports[], int &support_count,
                    double &resistances[], int &resistance_count)
  {
   ArrayResize(supports, 0);
   ArrayResize(resistances, 0);
   support_count = 0;
   resistance_count = 0;

   if(h1_count > 2)
     {
      AddLevel(supports, support_count, h1[1].low);
      AddLevel(resistances, resistance_count, h1[1].high);
     }
   if(h4_count > 2)
     {
      AddLevel(supports, support_count, h4[1].low);
      AddLevel(resistances, resistance_count, h4[1].high);
     }

   for(int shift = 6; shift < h1_count - 5; ++shift)
     {
      bool swing_high = true;
      bool swing_low = true;
      for(int j = shift - 5; j <= shift + 5; ++j)
        {
         if(j == shift)
            continue;
         if(h1[shift].high <= h1[j].high)
            swing_high = false;
         if(h1[shift].low >= h1[j].low)
            swing_low = false;
        }
      if(swing_high)
         AddLevel(resistances, resistance_count, h1[shift].high);
      if(swing_low)
         AddLevel(supports, support_count, h1[shift].low);
     }
  }

bool AtrAbovePercentile(const double atr_value)
  {
   if(atr_value <= 0.0 || strategy_atr_percentile_lookback <= 1)
      return false;

   double values[];
   ArrayResize(values, strategy_atr_percentile_lookback);
   for(int i = 0; i < strategy_atr_percentile_lookback; ++i)
     {
      values[i] = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, i + 1);
      if(values[i] <= 0.0)
         return false;
     }

   ArraySort(values);
   int idx = (int)MathFloor((strategy_atr_percentile_lookback - 1) * strategy_atr_percentile_min / 100.0);
   if(idx < 0)
      idx = 0;
   if(idx >= strategy_atr_percentile_lookback)
      idx = strategy_atr_percentile_lookback - 1;
   return atr_value > values[idx];
  }

double HighestM5High(const MqlRates &m5[], const int start_shift, const int bars)
  {
   double highest = -DBL_MAX;
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
      highest = MathMax(highest, m5[shift].high);
   return highest;
  }

double LowestM5Low(const MqlRates &m5[], const int start_shift, const int bars)
  {
   double lowest = DBL_MAX;
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
      lowest = MathMin(lowest, m5[shift].low);
   return lowest;
  }

bool FindLongSweep(const double level, const double atr_value,
                   const MqlRates &m5[], const int m5_count,
                   double &sweep_low)
  {
   sweep_low = DBL_MAX;
   const double threshold = strategy_sweep_depth_atr * atr_value;
   for(int shift = 2; shift <= strategy_sweep_window_bars + 1 && shift < m5_count; ++shift)
     {
      if(m5[shift].low <= level - threshold && m5[1].close > level)
         sweep_low = MathMin(sweep_low, m5[shift].low);
     }
   return sweep_low < DBL_MAX;
  }

bool FindShortSweep(const double level, const double atr_value,
                    const MqlRates &m5[], const int m5_count,
                    double &sweep_high)
  {
   sweep_high = -DBL_MAX;
   const double threshold = strategy_sweep_depth_atr * atr_value;
   for(int shift = 2; shift <= strategy_sweep_window_bars + 1 && shift < m5_count; ++shift)
     {
      if(m5[shift].high >= level + threshold && m5[1].close < level)
         sweep_high = MathMax(sweep_high, m5[shift].high);
     }
   return sweep_high > -DBL_MAX;
  }

double NearestAbove(const double &levels[], const int count, const double price)
  {
   double nearest = 0.0;
   for(int i = 0; i < count; ++i)
     {
      if(levels[i] <= price)
         continue;
      if(nearest <= 0.0 || levels[i] < nearest)
         nearest = levels[i];
     }
   return nearest;
  }

double NearestBelow(const double &levels[], const int count, const double price)
  {
   double nearest = 0.0;
   for(int i = 0; i < count; ++i)
     {
      if(levels[i] >= price)
         continue;
      if(nearest <= 0.0 || levels[i] > nearest)
         nearest = levels[i];
     }
   return nearest;
  }

bool FillRequestFromSignal(const int signal, const double sweep_extreme,
                           const double atr_value,
                           const double &resistances[], const int resistance_count,
                           const double &supports[], const int support_count,
                           QM_EntryRequest &req)
  {
   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr_value <= 0.0)
      return false;

   double sl = 0.0;
   if(signal > 0)
      sl = sweep_extreme - strategy_sl_buffer_atr * atr_value;
   else
      sl = sweep_extreme + strategy_sl_buffer_atr * atr_value;
   sl = NormalizeSymbolPrice(sl);
   if(sl <= 0.0)
      return false;

   const double risk_distance = MathAbs(entry - sl);
   if(risk_distance <= 0.0 || risk_distance > strategy_max_stop_atr * atr_value)
      return false;

   const double rr_tp = (signal > 0) ? entry + risk_distance * strategy_take_profit_r
                                     : entry - risk_distance * strategy_take_profit_r;
   double tp = rr_tp;
   if(signal > 0)
     {
      const double opposite = NearestAbove(resistances, resistance_count, entry);
      if(opposite > entry)
         tp = MathMin(rr_tp, opposite);
     }
   else
     {
      const double opposite = NearestBelow(supports, support_count, entry);
      if(opposite > 0.0 && opposite < entry)
         tp = MathMax(rr_tp, opposite);
     }
   tp = NormalizeSymbolPrice(tp);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (signal > 0) ? "RIVERBAND_LONG_SWEEP_BOS" : "RIVERBAND_SHORT_SWEEP_BOS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

int EvaluateClosedBarSignal(QM_EntryRequest &req)
  {
   const int m5_needed = MathMax(strategy_sweep_window_bars + strategy_bos_lookback_bars + 4, 16);
   MqlRates m5[];
   MqlRates h1[];
   MqlRates h4[];
   if(!LoadRates(PERIOD_M5, m5_needed, m5))
      return 0;
   if(!LoadRates(PERIOD_H1, 90, h1))
      return 0;
   if(!LoadRates(PERIOD_H4, 8, h4))
      return 0;

   const double atr_value = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if(!AtrAbovePercentile(atr_value))
      return 0;

   double supports[];
   double resistances[];
   int support_count = 0;
   int resistance_count = 0;
   BuildHtfLevels(h1, ArraySize(h1), h4, ArraySize(h4),
                  supports, support_count, resistances, resistance_count);

   const double h1_midpoint = (h1[1].high + h1[1].low) * 0.5;
   const double close1 = m5[1].close;
   const double bos_high = HighestM5High(m5, 2, strategy_bos_lookback_bars);
   const double bos_low = LowestM5Low(m5, 2, strategy_bos_lookback_bars);

   for(int i = 0; i < support_count; ++i)
     {
      const double level = supports[i];
      if(MathAbs(close1 - level) > strategy_level_proximity_atr * atr_value)
         continue;
      if(close1 <= level || close1 >= h1_midpoint || close1 <= bos_high)
         continue;
      double sweep_low = 0.0;
      if(FindLongSweep(level, atr_value, m5, ArraySize(m5), sweep_low) &&
         FillRequestFromSignal(1, sweep_low, atr_value, resistances, resistance_count,
                               supports, support_count, req))
         return 1;
     }

   for(int i = 0; i < resistance_count; ++i)
     {
      const double level = resistances[i];
      if(MathAbs(close1 - level) > strategy_level_proximity_atr * atr_value)
         continue;
      if(close1 >= level || close1 <= h1_midpoint || close1 >= bos_low)
         continue;
      double sweep_high = 0.0;
      if(FindShortSweep(level, atr_value, m5, ArraySize(m5), sweep_high) &&
         FillRequestFromSignal(-1, sweep_high, atr_value, resistances, resistance_count,
                               supports, support_count, req))
         return -1;
     }

   return 0;
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

   const int signal = EvaluateClosedBarSignal(req);
   g_last_closed_bar_signal = signal;
   if(signal != 0)
      g_last_signal_bar_time = iTime(_Symbol, PERIOD_M5, 1); // perf-allowed: closed-bar timestamp cache for opposite-signal exit.

   if(signal == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double favorable = is_buy ? market - open_price : open_price - market;
      if(favorable < risk_distance)
         continue;

      const double buffer = strategy_be_buffer_points * point;
      const double target_sl = NormalizeSymbolPrice(is_buy ? open_price + buffer : open_price - buffer);
      const bool improves = is_buy ? target_sl > current_sl + point * 0.5
                                   : target_sl < current_sl - point * 0.5;
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "riverband_move_sl_to_breakeven_at_1r");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M5);
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(hold_seconds > 0 && now - opened >= hold_seconds)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(g_last_signal_bar_time > opened)
        {
         if(ptype == POSITION_TYPE_BUY && g_last_closed_bar_signal < 0)
            return true;
         if(ptype == POSITION_TYPE_SELL && g_last_closed_bar_signal > 0)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
