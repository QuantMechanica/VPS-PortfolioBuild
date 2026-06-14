#property strict
#property version   "5.0"
#property description "QM5_10750 TradingView Reversal Breakout ORB"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10750;
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
input bool   strategy_enable_reversal       = true;
input bool   strategy_enable_breakout       = true;
input bool   strategy_enable_orb            = true;
input int    strategy_ema_fast_period       = 9;
input int    strategy_ema_slow_period       = 20;
input int    strategy_sma_cross_period      = 50;
input int    strategy_sma_trend_period      = 200;
input int    strategy_rsi_period            = 14;
input double strategy_rsi_oversold          = 30.0;
input double strategy_rsi_overbought        = 70.0;
input int    strategy_atr_period            = 14;
input double strategy_atr_stop_mult         = 1.5;
input int    strategy_structure_lookback    = 7;
input double strategy_target_rr             = 2.0;
input int    strategy_opening_range_bars    = 15;
input double strategy_orb_volume_mult       = 1.5;
input bool   strategy_session_filter_enabled = true;
input int    strategy_session_start_hour    = 15;
input int    strategy_session_start_minute  = 30;
input int    strategy_session_end_hour      = 22;
input int    strategy_session_end_minute    = 0;
input int    strategy_max_spread_points     = 0;
input bool   strategy_breakeven_enabled     = false;

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
         return true;
     }

   if(!strategy_session_filter_enabled)
      return false;

   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   const int now_min = t.hour * 60 + t.min;
   const int start_min = strategy_session_start_hour * 60 + strategy_session_start_minute;
   const int end_min = strategy_session_end_hour * 60 + strategy_session_end_minute;

   if(start_min == end_min)
      return false;
   if(start_min < end_min)
      return (now_min < start_min || now_min >= end_min);
   return (now_min < start_min && now_min >= end_min);
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

   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_slow_period <= 0 ||
      strategy_sma_cross_period <= 0 ||
      strategy_sma_trend_period <= 1 ||
      strategy_rsi_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_structure_lookback <= 0 ||
      strategy_opening_range_bars <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_target_rr <= 0.0 ||
      strategy_orb_volume_mult <= 0.0)
      return false;

   int need_bars = strategy_sma_trend_period + 10;
   if(need_bars < strategy_opening_range_bars + 120)
      need_bars = strategy_opening_range_bars + 120;
   if(need_bars < strategy_structure_lookback + 5)
      need_bars = strategy_structure_lookback + 5;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, need_bars, rates); // perf-allowed: closed-bar structural VWAP/ORB/volume state, called only after framework QM_IsNewBar gate.
   if(copied < 3 || copied < strategy_structure_lookback)
      return false;

   const double close_now = rates[0].close;
   const double close_prev = rates[1].close;
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_slow_period, 1);
   const double sma_cross = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_cross_period, 1);
   const double sma_cross_prev = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_cross_period, 2);
   const double sma_trend = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_trend_period, 1);
   const double sma_trend_prev = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_trend_period, 2);
   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 ||
      sma_cross <= 0.0 || sma_cross_prev <= 0.0 ||
      sma_trend <= 0.0 || sma_trend_prev <= 0.0 ||
      rsi <= 0.0 || atr <= 0.0)
      return false;

   MqlDateTime bar_dt;
   TimeToStruct(rates[0].time, bar_dt);
   const datetime session_start = StringToTime(StringFormat("%04d.%02d.%02d %02d:%02d",
                                                            bar_dt.year,
                                                            bar_dt.mon,
                                                            bar_dt.day,
                                                            strategy_session_start_hour,
                                                            strategy_session_start_minute));
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(session_start <= 0 || period_seconds <= 0)
      return false;

   double vwap_num = 0.0;
   double vwap_den = 0.0;
   double or_high = -DBL_MAX;
   double or_low = DBL_MAX;
   double or_vol_sum = 0.0;
   int or_vol_count = 0;

   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time < session_start)
         continue;

      const long elapsed_sec = (long)(rates[i].time - session_start);
      const int session_bar = (int)(elapsed_sec / period_seconds) + 1;
      if(session_bar < 1)
         continue;

      double vol = (double)rates[i].tick_volume;
      if(vol <= 0.0)
         vol = 1.0;
      const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      vwap_num += typical * vol;
      vwap_den += vol;

      if(session_bar <= strategy_opening_range_bars)
        {
         if(rates[i].high > or_high)
            or_high = rates[i].high;
         if(rates[i].low < or_low)
            or_low = rates[i].low;
         or_vol_sum += vol;
         or_vol_count++;
        }
     }

   if(vwap_den <= 0.0)
      return false;
   const double vwap = vwap_num / vwap_den;

   double structure_low = DBL_MAX;
   double structure_high = -DBL_MAX;
   for(int i = 0; i < strategy_structure_lookback; ++i)
     {
      if(rates[i].low < structure_low)
         structure_low = rates[i].low;
      if(rates[i].high > structure_high)
         structure_high = rates[i].high;
     }
   if(structure_low <= 0.0 || structure_high <= 0.0)
      return false;

   const bool trend_up = (sma_trend > sma_trend_prev);
   const bool trend_down = (sma_trend < sma_trend_prev);
   const bool cross_up = (close_prev <= sma_cross_prev && close_now > sma_cross);
   const bool cross_down = (close_prev >= sma_cross_prev && close_now < sma_cross);

   bool long_reversal = false;
   bool short_reversal = false;
   if(strategy_enable_reversal)
     {
      long_reversal = (cross_up && rsi < strategy_rsi_oversold && close_now < vwap && trend_up);
      short_reversal = (cross_down && rsi > strategy_rsi_overbought && close_now > vwap && trend_down);
     }

   bool long_breakout = false;
   bool short_breakout = false;
   if(strategy_enable_breakout)
     {
      long_breakout = (ema_fast > ema_slow && close_now > vwap && trend_up);
      short_breakout = (ema_fast < ema_slow && close_now < vwap && trend_down);
     }

   bool long_orb = false;
   bool short_orb = false;
   if(strategy_enable_orb && or_vol_count > 0 && or_high > 0.0 && or_low > 0.0)
     {
      const int current_session_bar = (int)(((long)(rates[0].time - session_start)) / period_seconds) + 1;
      const double avg_or_volume = or_vol_sum / (double)or_vol_count;
      const double current_volume = (rates[0].tick_volume > 0) ? (double)rates[0].tick_volume : 1.0;
      const bool volume_ok = (current_volume > avg_or_volume * strategy_orb_volume_mult);
      if(current_session_bar > strategy_opening_range_bars && volume_ok)
        {
         long_orb = (close_now > or_high);
         short_orb = (close_now < or_low);
        }
     }

   const bool long_signal = (long_orb || long_reversal || long_breakout);
   const bool short_signal = (short_orb || short_reversal || short_breakout);
   if(long_signal == short_signal)
      return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   double sl = 0.0;
   if(long_signal)
      sl = NormalizeDouble(structure_low - atr * strategy_atr_stop_mult, _Digits);
   else
      sl = NormalizeDouble(structure_high + atr * strategy_atr_stop_mult, _Digits);

   const double risk_distance = MathAbs(entry - sl);
   if(sl <= 0.0 || risk_distance <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.symbol_slot = qm_magic_slot_offset;
   if(long_orb || short_orb)
      req.reason = long_signal ? "ORB_LONG" : "ORB_SHORT";
   else if(long_reversal || short_reversal)
      req.reason = long_signal ? "REVERSAL_LONG" : "REVERSAL_SHORT";
   else
      req.reason = long_signal ? "BREAKOUT_LONG" : "BREAKOUT_SHORT";

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_breakeven_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double initial_risk = MathAbs(open_price - current_sl);
      if(initial_risk <= 0.0)
         continue;

      if(type == POSITION_TYPE_BUY && bid - open_price >= initial_risk && current_sl < open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "BREAKEVEN_1R");
      if(type == POSITION_TYPE_SELL && open_price - ask >= initial_risk && current_sl > open_price)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "BREAKEVEN_1R");
     }
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10750_tv_rev_brk_orb\"}");
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
