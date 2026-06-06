#property strict
#property version   "5.0"
#property description "QM5_10918 Grimes Slide Along The Bands"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10918;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H4;
input int             strategy_ema_period         = 20;
input int             strategy_atr_period         = 20;
input double          strategy_channel_atr_mult   = 2.25;
input int             strategy_pressure_lookback  = 8;
input int             strategy_pressure_min_bars  = 5;
input double          strategy_pressure_near_atr  = 0.15;
input double          strategy_pullback_atr_mult  = 0.75;
input int             strategy_breakout_lookback  = 5;
input int             strategy_initial_stop_bars  = 5;
input double          strategy_initial_stop_atr   = 0.25;
input double          strategy_max_stop_atr       = 3.5;
input int             strategy_trail_interval_bars = 3;
input int             strategy_trail_window_bars  = 3;
input double          strategy_trail_atr_buffer   = 0.20;
input int             strategy_max_hold_bars      = 30;
input double          strategy_max_spread_stop_frac = 0.10;

int MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

bool LoadRates(const int start_pos, const int count, MqlRates &rates[])
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, start_pos, count, rates); // perf-allowed: bounded card OHLC window, caller is closed-bar gated or O(1) management.
   if(copied < count)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

double HighestHigh(const MqlRates &rates[], const int first_shift, const int count)
  {
   double highest = -DBL_MAX;
   for(int i = first_shift; i < first_shift + count; ++i)
      highest = MathMax(highest, rates[i].high);
   return highest;
  }

double LowestLow(const MqlRates &rates[], const int first_shift, const int count)
  {
   double lowest = DBL_MAX;
   for(int i = first_shift; i < first_shift + count; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

int BarsHeldSince(const datetime open_time)
  {
   const int period_seconds = PeriodSeconds(strategy_timeframe);
   if(open_time <= 0 || period_seconds <= 0)
      return 0;
   const int elapsed = (int)(TimeCurrent() - open_time);
   if(elapsed <= 0)
      return 0;
   return elapsed / period_seconds;
  }

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_ema_period <= 1 || strategy_atr_period <= 1 ||
      strategy_pressure_lookback < 1 || strategy_pressure_min_bars < 1 ||
      strategy_breakout_lookback < 1 || strategy_initial_stop_bars < 1)
      return false;

   const int need_bars = MaxInt(strategy_pressure_lookback + 2,
                         MaxInt(strategy_breakout_lookback + 2, strategy_initial_stop_bars + 2));
   MqlRates rates[];
   if(!LoadRates(0, need_bars, rates))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ema_now = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 2);
   if(atr <= 0.0 || ema_now <= 0.0 || ema_prev <= 0.0)
      return false;

   int long_pressure = 0;
   int short_pressure = 0;
   double long_pullback = 0.0;
   double short_pullback = 0.0;
   for(int shift = 1; shift <= strategy_pressure_lookback; ++shift)
     {
      const double ema_i = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, shift);
      const double atr_i = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(ema_i <= 0.0 || atr_i <= 0.0)
         return false;

      const double upper_i = ema_i + strategy_channel_atr_mult * atr_i;
      const double lower_i = ema_i - strategy_channel_atr_mult * atr_i;
      if(rates[shift].close >= upper_i - strategy_pressure_near_atr * atr_i)
         long_pressure++;
      if(rates[shift].close <= lower_i + strategy_pressure_near_atr * atr_i)
         short_pressure++;

      long_pullback = MathMax(long_pullback, MathMax(0.0, upper_i - rates[shift].low));
      short_pullback = MathMax(short_pullback, MathMax(0.0, rates[shift].high - lower_i));
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const bool ema_up = (ema_now > ema_prev);
   const bool ema_down = (ema_now < ema_prev);
   const double prior_5_high = HighestHigh(rates, 2, strategy_breakout_lookback);
   const double prior_5_low = LowestLow(rates, 2, strategy_breakout_lookback);
   const double stop_5_low = LowestLow(rates, 1, strategy_initial_stop_bars);
   const double stop_5_high = HighestHigh(rates, 1, strategy_initial_stop_bars);
   const double spread = ask - bid;

   if(long_pressure >= strategy_pressure_min_bars &&
      ema_up &&
      long_pullback <= strategy_pullback_atr_mult * atr &&
      rates[1].close > prior_5_high)
     {
      const double sl = NormalizeDouble(stop_5_low - strategy_initial_stop_atr * atr, _Digits);
      const double stop_dist = ask - sl;
      if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr * atr)
         return false;
      if(spread > strategy_max_spread_stop_frac * stop_dist)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "grimes_slide_long";
      return true;
     }

   if(short_pressure >= strategy_pressure_min_bars &&
      ema_down &&
      short_pullback <= strategy_pullback_atr_mult * atr &&
      rates[1].close < prior_5_low)
     {
      const double sl = NormalizeDouble(stop_5_high + strategy_initial_stop_atr * atr, _Digits);
      const double stop_dist = sl - bid;
      if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr * atr)
         return false;
      if(spread > strategy_max_spread_stop_frac * stop_dist)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "grimes_slide_short";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(strategy_trail_interval_bars <= 0 || strategy_trail_window_bars <= 0)
      return;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!SelectOurPosition(ticket, position_type, open_time))
      return;

   const int bars_held = BarsHeldSince(open_time);
   if(bars_held <= 0 || (bars_held % strategy_trail_interval_bars) != 0)
      return;

   MqlRates rates[];
   if(!LoadRates(1, strategy_trail_window_bars, rates))
      return;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double new_sl = NormalizeDouble(LowestLow(rates, 0, strategy_trail_window_bars) -
                                            strategy_trail_atr_buffer * atr, _Digits);
      if(current_sl <= 0.0 || new_sl > current_sl + point * 0.5)
         QM_TM_MoveSL(ticket, new_sl, "grimes_slide_3bar_trail_long");
      return;
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      const double new_sl = NormalizeDouble(HighestHigh(rates, 0, strategy_trail_window_bars) +
                                            strategy_trail_atr_buffer * atr, _Digits);
      if(current_sl <= 0.0 || new_sl < current_sl - point * 0.5)
         QM_TM_MoveSL(ticket, new_sl, "grimes_slide_3bar_trail_short");
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!SelectOurPosition(ticket, position_type, open_time))
      return false;

   if(strategy_max_hold_bars > 0 && BarsHeldSince(open_time) >= strategy_max_hold_bars)
      return true;

   MqlRates rates[];
   if(!LoadRates(1, 1, rates))
      return false;

   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && rates[0].close < ema)
      return true;
   if(position_type == POSITION_TYPE_SELL && rates[0].close > ema)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time < 0)
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10918_grimes_slide\"}");
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
