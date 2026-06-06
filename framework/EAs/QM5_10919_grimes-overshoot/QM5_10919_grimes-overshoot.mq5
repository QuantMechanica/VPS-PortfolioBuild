#property strict
#property version   "5.0"
#property description "QM5_10919 Grimes Overshoot Climax Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10919;
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
input ENUM_TIMEFRAMES strategy_timeframe           = PERIOD_H4;
input int             strategy_ema_period          = 20;
input int             strategy_mature_ema_period   = 50;
input int             strategy_atr_period          = 20;
input double          strategy_channel_atr_mult    = 2.25;
input double          strategy_accel_atr_mult      = 2.00;
input int             strategy_mature_slope_bars   = 30;
input int             strategy_breakout_lookback   = 20;
input double          strategy_exhaust_range_atr   = 1.50;
input double          strategy_exhaust_close_frac  = 0.35;
input int             strategy_trigger_window_bars = 3;
input double          strategy_stop_buffer_atr     = 0.25;
input double          strategy_max_stop_atr        = 3.50;
input double          strategy_target1_r           = 1.00;
input double          strategy_target2_r           = 2.00;
input int             strategy_time_exit_bars      = 12;
input double          strategy_max_spread_stop_frac = 0.10;
input int             strategy_grimes_slide_ea_id  = 10918;

int    g_pending_dir = 0;
double g_pending_high = 0.0;
double g_pending_low = 0.0;
double g_pending_atr = 0.0;
int    g_pending_bars_waited = 0;
ulong  g_partial_done_ticket = 0;

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

void Strategy_ClearPending()
  {
   g_pending_dir = 0;
   g_pending_high = 0.0;
   g_pending_low = 0.0;
   g_pending_atr = 0.0;
   g_pending_bars_waited = 0;
  }

bool Strategy_LoadRates(MqlRates &rates[])
  {
   const int bars_needed = Strategy_MaxInt(strategy_breakout_lookback + 3, 8);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, bars_needed, rates); // perf-allowed: bounded card OHLC window, called only from framework closed-bar entry path.
   if(copied < bars_needed)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

double Strategy_HighestHigh(const MqlRates &rates[], const int first_shift, const int count)
  {
   double highest = -DBL_MAX;
   for(int i = first_shift; i < first_shift + count; ++i)
      highest = MathMax(highest, rates[i].high);
   return highest;
  }

double Strategy_LowestLow(const MqlRates &rates[], const int first_shift, const int count)
  {
   double lowest = DBL_MAX;
   for(int i = first_shift; i < first_shift + count; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

bool Strategy_EMASlopeOK(const bool want_up)
  {
   if(strategy_mature_slope_bars < 1)
      return false;

   for(int shift = 1; shift <= strategy_mature_slope_bars; ++shift)
     {
      const double ema_now = QM_EMA(_Symbol, strategy_timeframe, strategy_mature_ema_period, shift);
      const double ema_prev = QM_EMA(_Symbol, strategy_timeframe, strategy_mature_ema_period, shift + 1);
      if(ema_now <= 0.0 || ema_prev <= 0.0)
         return false;
      if(want_up && ema_now <= ema_prev)
         return false;
      if(!want_up && ema_now >= ema_prev)
         return false;
     }

   return true;
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                double &volume,
                                datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   volume = 0.0;
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
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_GrimesSlideConflict(const bool want_long)
  {
   if(strategy_grimes_slide_ea_id <= 0)
      return false;

   const int min_magic = strategy_grimes_slide_ea_id * 10000;
   const int max_magic = min_magic + 9999;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const int pos_magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(pos_magic < min_magic || pos_magic > max_magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(want_long && pos_type == POSITION_TYPE_SELL)
         return true;
      if(!want_long && pos_type == POSITION_TYPE_BUY)
         return true;
     }

   return false;
  }

bool Strategy_BuildRequest(const bool long_signal,
                           const double exhaustion_low,
                           const double exhaustion_high,
                           const double atr,
                           const string reason,
                           QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || atr <= 0.0)
      return false;

   if(Strategy_GrimesSlideConflict(long_signal))
      return false;

   const double entry = long_signal ? exhaustion_high : exhaustion_low;
   if(entry <= 0.0)
      return false;

   const double raw_sl = long_signal ? (exhaustion_low - strategy_stop_buffer_atr * atr)
                                     : (exhaustion_high + strategy_stop_buffer_atr * atr);
   const double sl = NormalizeDouble(raw_sl, _Digits);
   const double stop_dist = MathAbs(entry - sl);
   if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr * atr)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_stop_frac * stop_dist)
      return false;

   const double tp_dist = strategy_target2_r * stop_dist;
   if(tp_dist <= 0.0)
      return false;

   req.type = long_signal ? QM_BUY_STOP : QM_SELL_STOP;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = sl;
   req.tp = NormalizeDouble(long_signal ? (entry + tp_dist) : (entry - tp_dist), _Digits);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_trigger_window_bars * PeriodSeconds(strategy_timeframe);
   return true;
  }

bool Strategy_CheckPendingTrigger(const MqlRates &rates[], QM_EntryRequest &req)
  {
   if(g_pending_dir == 0)
      return false;

   const bool want_long = (g_pending_dir > 0);
   const bool triggered = want_long ? (rates[1].high > g_pending_high)
                                    : (rates[1].low < g_pending_low);
   if(triggered)
     {
      const bool built = Strategy_BuildRequest(want_long,
                                               g_pending_low,
                                               g_pending_high,
                                               g_pending_atr,
                                               want_long ? "grimes_overshoot_long_trigger" : "grimes_overshoot_short_trigger",
                                               req);
      Strategy_ClearPending();
      return built;
     }

   g_pending_bars_waited++;
   if(g_pending_bars_waited >= strategy_trigger_window_bars)
      Strategy_ClearPending();
   return false;
  }

void Strategy_DetectExhaustion(const MqlRates &rates[])
  {
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double ema20 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double ema50 = QM_EMA(_Symbol, strategy_timeframe, strategy_mature_ema_period, 1);
   if(atr <= 0.0 || ema20 <= 0.0 || ema50 <= 0.0)
      return;

   const double range = rates[1].high - rates[1].low;
   if(range <= 0.0 || range < strategy_exhaust_range_atr * atr)
      return;

   const double close_position = (rates[1].close - rates[1].low) / range;
   const double upper = ema20 + strategy_channel_atr_mult * atr;
   const double lower = ema20 - strategy_channel_atr_mult * atr;
   const bool new_high = (rates[1].high > Strategy_HighestHigh(rates, 2, strategy_breakout_lookback));
   const bool new_low = (rates[1].low < Strategy_LowestLow(rates, 2, strategy_breakout_lookback));

   if(rates[1].close > ema50 &&
      Strategy_EMASlopeOK(true) &&
      (rates[1].close >= ema20 + strategy_accel_atr_mult * atr || rates[1].high > upper) &&
      new_high &&
      close_position <= strategy_exhaust_close_frac)
     {
      g_pending_dir = -1;
      g_pending_high = rates[1].high;
      g_pending_low = rates[1].low;
      g_pending_atr = atr;
      g_pending_bars_waited = 0;
      return;
     }

   if(rates[1].close < ema50 &&
      Strategy_EMASlopeOK(false) &&
      (rates[1].close <= ema20 - strategy_accel_atr_mult * atr || rates[1].low < lower) &&
      new_low &&
      close_position >= 1.0 - strategy_exhaust_close_frac)
     {
      g_pending_dir = 1;
      g_pending_high = rates[1].high;
      g_pending_low = rates[1].low;
      g_pending_atr = atr;
      g_pending_bars_waited = 0;
     }
  }

int Strategy_BarsHeldSince(const datetime open_time)
  {
   const int seconds = PeriodSeconds(strategy_timeframe);
   if(open_time <= 0 || seconds <= 0)
      return 0;
   const int elapsed = (int)(TimeCurrent() - open_time);
   if(elapsed <= 0)
      return 0;
   return elapsed / seconds;
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

   if(strategy_ema_period <= 1 || strategy_mature_ema_period <= 1 ||
      strategy_atr_period <= 1 || strategy_breakout_lookback < 2 ||
      strategy_mature_slope_bars < 1 || strategy_trigger_window_bars < 1 ||
      strategy_target1_r <= 0.0 || strategy_target2_r <= 0.0)
      return false;

   MqlRates rates[];
   if(!Strategy_LoadRates(rates))
      return false;

   Strategy_DetectExhaustion(rates);
   if(g_pending_dir != 0)
     {
      const bool want_long = (g_pending_dir > 0);
      const bool built = Strategy_BuildRequest(want_long,
                                               g_pending_low,
                                               g_pending_high,
                                               g_pending_atr,
                                               want_long ? "grimes_overshoot_long_stop" : "grimes_overshoot_short_stop",
                                               req);
      Strategy_ClearPending();
      return built;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl = 0.0;
   double volume = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, volume, open_time))
     {
      g_partial_done_ticket = 0;
      return;
     }

   if(ticket == g_partial_done_ticket)
      return;

   const double r = MathAbs(open_price - sl);
   if(r <= 0.0 || volume <= 0.0)
      return;

   const bool is_long = (position_type == POSITION_TYPE_BUY);
   const double current = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(current <= 0.0)
      return;

   const double favorable = is_long ? (current - open_price) : (open_price - current);
   if(favorable >= strategy_target1_r * r)
     {
      QM_TM_PartialClose(ticket, volume * 0.50, QM_EXIT_STRATEGY);
      g_partial_done_ticket = ticket;
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl = 0.0;
   double volume = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, volume, open_time))
      return false;

   if(strategy_time_exit_bars > 0 && Strategy_BarsHeldSince(open_time) >= strategy_time_exit_bars)
      return true;

   const double ema20 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   if(ema20 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 && bid >= ema20);
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return (ask > 0.0 && ask <= ema20);
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10919_grimes_overshoot\"}");
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
