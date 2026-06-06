#property strict
#property version   "5.0"
#property description "QM5_10978 FTMO MACD Crossover Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10978;
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
input ENUM_TIMEFRAMES strategy_timeframe             = PERIOD_H4;
input int             strategy_macd_fast             = 12;
input int             strategy_macd_slow             = 26;
input int             strategy_macd_signal           = 9;
input int             strategy_ema_period            = 50;
input int             strategy_ema_slope_bars        = 10;
input int             strategy_atr_period            = 14;
input int             strategy_atr_percentile_bars   = 120;
input double          strategy_min_atr_percentile    = 0.20;
input int             strategy_swing_lookback_bars   = 10;
input double          strategy_stop_atr_buffer_mult  = 0.50;
input double          strategy_take_profit_r         = 2.50;
input double          strategy_breakeven_trigger_r   = 1.20;
input int             strategy_zero_confirm_bars     = 3;
input int             strategy_max_hold_bars         = 50;
input double          strategy_max_entry_range_atr   = 2.50;
input int             strategy_max_spread_points     = 0;

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &ptype,
                                double &open_price,
                                datetime &open_time,
                                double &sl,
                                double &tp)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;
   sl = 0.0;
   tp = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      return true;
     }

   return false;
  }

bool Strategy_LoadClosedRates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, count, rates); // perf-allowed: closed-bar structure stop and range filter.
   return (copied >= count);
  }

double Strategy_AtrPercentileThreshold()
  {
   const int count_target = MathMax(1, strategy_atr_percentile_bars);
   double values[];
   ArrayResize(values, count_target);
   int count = 0;

   for(int shift = 2; shift < count_target + 2; ++shift)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(atr > 0.0)
        {
         values[count] = atr;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   int idx = (int)MathFloor((count - 1) * strategy_min_atr_percentile);
   idx = MathMax(0, MathMin(count - 1, idx));
   return values[idx];
  }

bool Strategy_BullSignalCross(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double main_prev = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   return (main_prev <= sig_prev && main_now > sig_now);
  }

bool Strategy_BearSignalCross(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double main_prev = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   return (main_prev >= sig_prev && main_now < sig_now);
  }

bool Strategy_OppositeSignalAfter(const bool bullish_setup, const int signal_shift)
  {
   for(int shift = signal_shift - 1; shift >= 1; --shift)
     {
      if(bullish_setup && Strategy_BearSignalCross(shift))
         return true;
      if(!bullish_setup && Strategy_BullSignalCross(shift))
         return true;
     }
   return false;
  }

int Strategy_DirectionSignal()
  {
   const double macd_1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_2 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const bool bull_zero_now = (macd_1 > 0.0);
   const bool bear_zero_now = (macd_1 < 0.0);
   const bool bull_zero_cross_now = (macd_2 <= 0.0 && macd_1 > 0.0);
   const bool bear_zero_cross_now = (macd_2 >= 0.0 && macd_1 < 0.0);
   const int max_signal_shift = MathMax(1, strategy_zero_confirm_bars + 1);

   for(int shift = 1; shift <= max_signal_shift; ++shift)
     {
      if(Strategy_BullSignalCross(shift) && !Strategy_OppositeSignalAfter(true, shift))
        {
         if((shift == 1 && bull_zero_now) || (shift > 1 && bull_zero_cross_now))
            return 1;
        }
      if(Strategy_BearSignalCross(shift) && !Strategy_OppositeSignalAfter(false, shift))
        {
         if((shift == 1 && bear_zero_now) || (shift > 1 && bear_zero_cross_now))
            return -1;
        }
     }

   return 0;
  }

int Strategy_BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, strategy_timeframe, open_time, false); // perf-allowed: time-exit bar count for the open position.
   if(shift < 0)
      return 0;
   return shift;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   double current_sl;
   double current_tp;
   if(Strategy_SelectOurPosition(ticket, ptype, open_price, open_time, current_sl, current_tp))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double atr_threshold = Strategy_AtrPercentileThreshold();
   if(atr <= 0.0 || atr_threshold <= 0.0 || atr < atr_threshold)
      return false;

   MqlRates rates[];
   const int needed = MathMax(strategy_swing_lookback_bars, 1);
   if(!Strategy_LoadClosedRates(rates, needed))
      return false;

   const double entry_range = rates[0].high - rates[0].low;
   if(entry_range <= 0.0 || entry_range > strategy_max_entry_range_atr * atr)
      return false;

   const double ema_now = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1 + strategy_ema_slope_bars);
   if(ema_now <= 0.0 || ema_prev <= 0.0)
      return false;

   const int direction = Strategy_DirectionSignal();
   if(direction == 0)
      return false;
   if(direction > 0 && ema_now <= ema_prev)
      return false;
   if(direction < 0 && ema_now >= ema_prev)
      return false;

   double swing_low = DBL_MAX;
   double swing_high = -DBL_MAX;
   for(int i = 0; i < needed; ++i)
     {
      swing_low = MathMin(swing_low, rates[i].low);
      swing_high = MathMax(swing_high, rates[i].high);
     }
   if(swing_low <= 0.0 || swing_high <= 0.0)
      return false;

   const bool go_long = (direction > 0);
   req.type = go_long ? QM_BUY : QM_SELL;
   req.price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(req.price <= 0.0)
      return false;

   const double raw_sl = go_long ? (swing_low - strategy_stop_atr_buffer_mult * atr)
                                : (swing_high + strategy_stop_atr_buffer_mult * atr);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_r);
   req.reason = go_long ? "FTMO_MACD_X_LONG" : "FTMO_MACD_X_SHORT";

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(go_long && (req.sl >= req.price - point || req.tp <= req.price + point))
      return false;
   if(!go_long && (req.sl <= req.price + point || req.tp >= req.price - point))
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   double sl;
   double tp;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_price, open_time, sl, tp))
      return;

   if(open_price <= 0.0 || tp <= 0.0 || strategy_take_profit_r <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double initial_risk = MathAbs(tp - open_price) / strategy_take_profit_r;
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(initial_risk > 0.0 && moved >= initial_risk * strategy_breakeven_trigger_r)
      QM_TM_MoveSL(ticket, open_price, "ftmo_macd_x_be_after_1_2r");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   double sl;
   double tp;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_price, open_time, sl, tp))
      return false;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   if(is_buy && Strategy_BearSignalCross(1))
      return true;
   if(!is_buy && Strategy_BullSignalCross(1))
      return true;
   if(Strategy_BarsHeld(open_time) >= strategy_max_hold_bars)
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
