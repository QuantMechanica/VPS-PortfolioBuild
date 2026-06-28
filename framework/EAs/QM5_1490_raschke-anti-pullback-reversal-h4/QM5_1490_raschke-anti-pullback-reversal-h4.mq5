#property strict
#property version   "5.0"
#property description "QM5_1490 Raschke Anti pullback-reversal H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1490;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input ENUM_TIMEFRAMES strategy_signal_tf            = PERIOD_H4;
input ENUM_TIMEFRAMES strategy_macro_tf             = PERIOD_D1;
input int             strategy_fast_sma_period      = 3;
input int             strategy_slow_sma_period      = 10;
input int             strategy_signal_sma_period    = 16;
input int             strategy_macro_sma_period     = 50;
input int             strategy_macro_slope_bars     = 5;
input int             strategy_signal_slope_bars    = 3;
input int             strategy_signal_confirm_bars  = 6;
input int             strategy_retrace_lookback     = 8;
input int             strategy_stdev_period         = 50;
input int             strategy_cooldown_bars        = 30;
input int             strategy_atr_period           = 14;
input double          strategy_atr_sl_mult          = 2.0;
input double          strategy_cross_sep_atr_frac   = 0.15;
input double          strategy_retrace_stdev_mult   = 0.40;
input double          strategy_tp1_atr_mult         = 1.5;
input double          strategy_tp1_close_fraction   = 0.60;
input int             strategy_time_stop_bars       = 24;
input int             strategy_max_spread_points    = 0;

ulong g_strategy_tp1_done_tickets[128];
int   g_strategy_tp1_done_count = 0;

ENUM_TIMEFRAMES Strategy_SignalTF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

bool Strategy_HasTp1Done(const ulong ticket)
  {
   for(int i = 0; i < g_strategy_tp1_done_count; ++i)
      if(g_strategy_tp1_done_tickets[i] == ticket)
         return true;
   return false;
  }

void Strategy_MarkTp1Done(const ulong ticket)
  {
   if(ticket == 0 || Strategy_HasTp1Done(ticket))
      return;
   if(g_strategy_tp1_done_count >= 128)
      return;
   g_strategy_tp1_done_tickets[g_strategy_tp1_done_count] = ticket;
   g_strategy_tp1_done_count++;
  }

bool Strategy_Oscillator(const int shift, double &out_osc)
  {
   out_osc = 0.0;
   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();
   const double fast = QM_SMA(_Symbol, tf, strategy_fast_sma_period, shift, PRICE_CLOSE);
   const double slow = QM_SMA(_Symbol, tf, strategy_slow_sma_period, shift, PRICE_CLOSE);
   if(fast <= 0.0 || slow <= 0.0)
      return false;
   out_osc = fast - slow;
   return true;
  }

bool Strategy_SignalLine(const int shift, double &out_signal)
  {
   out_signal = 0.0;
   if(strategy_signal_sma_period <= 0)
      return false;

   double sum = 0.0;
   for(int i = 0; i < strategy_signal_sma_period; ++i)
     {
      double osc = 0.0;
      if(!Strategy_Oscillator(shift + i, osc))
         return false;
      sum += osc;
     }
   out_signal = sum / (double)strategy_signal_sma_period;
   return true;
  }

bool Strategy_OscStdDev(const int shift, double &out_stdev)
  {
   out_stdev = 0.0;
   if(strategy_stdev_period <= 1)
      return false;

   double values[];
   ArrayResize(values, strategy_stdev_period);
   double sum = 0.0;
   for(int i = 0; i < strategy_stdev_period; ++i)
     {
      double osc = 0.0;
      if(!Strategy_Oscillator(shift + i, osc))
         return false;
      values[i] = osc;
      sum += osc;
     }

   const double mean = sum / (double)strategy_stdev_period;
   double variance = 0.0;
   for(int i = 0; i < strategy_stdev_period; ++i)
     {
      const double diff = values[i] - mean;
      variance += diff * diff;
     }
   out_stdev = MathSqrt(variance / (double)strategy_stdev_period);
   return (out_stdev > 0.0);
  }

int Strategy_ReCrossAtShift(const int shift)
  {
   double osc_now = 0.0;
   double sig_now = 0.0;
   double osc_prev = 0.0;
   double sig_prev = 0.0;
   if(!Strategy_Oscillator(shift, osc_now) ||
      !Strategy_SignalLine(shift, sig_now) ||
      !Strategy_Oscillator(shift + 1, osc_prev) ||
      !Strategy_SignalLine(shift + 1, sig_prev))
      return 0;

   if(osc_now > sig_now && osc_prev <= sig_prev)
      return 1;
   if(osc_now < sig_now && osc_prev >= sig_prev)
      return -1;
   return 0;
  }

bool Strategy_NoRecentAntiTrigger()
  {
   for(int shift = 2; shift <= strategy_cooldown_bars + 1; ++shift)
      if(Strategy_ReCrossAtShift(shift) != 0)
         return false;
   return true;
  }

bool Strategy_MacroTrendAllows(const int direction)
  {
   const ENUM_TIMEFRAMES tf = (strategy_macro_tf == PERIOD_CURRENT) ? PERIOD_D1 : strategy_macro_tf;
   const double close_1 = iClose(_Symbol, tf, 1); // perf-allowed: single closed D1 bar read for card-mandated macro trend gate.
   const double sma_1 = QM_SMA(_Symbol, tf, strategy_macro_sma_period, 1, PRICE_CLOSE);
   const double sma_then = QM_SMA(_Symbol, tf, strategy_macro_sma_period, 1 + strategy_macro_slope_bars, PRICE_CLOSE);
   if(close_1 <= 0.0 || sma_1 <= 0.0 || sma_then <= 0.0)
      return false;

   if(direction > 0)
      return (close_1 > sma_1 && sma_1 > sma_then);
   return (close_1 < sma_1 && sma_1 < sma_then);
  }

bool Strategy_SignalTrendAllows(const int direction)
  {
   double sig_1 = 0.0;
   double sig_mid = 0.0;
   double sig_far = 0.0;
   if(!Strategy_SignalLine(1, sig_1) ||
      !Strategy_SignalLine(1 + strategy_signal_slope_bars, sig_mid) ||
      !Strategy_SignalLine(1 + strategy_signal_confirm_bars, sig_far))
      return false;

   if(direction > 0)
      return (sig_1 > sig_mid && sig_mid > sig_far);
   return (sig_1 < sig_mid && sig_mid < sig_far);
  }

bool Strategy_RetracementAllows(const int direction)
  {
   double stdev = 0.0;
   if(!Strategy_OscStdDev(1, stdev))
      return false;

   bool have_retrace = false;
   double deepest = (direction > 0) ? DBL_MAX : -DBL_MAX;
   for(int shift = 2; shift <= strategy_retrace_lookback + 1; ++shift)
     {
      double osc = 0.0;
      double sig = 0.0;
      if(!Strategy_Oscillator(shift, osc) || !Strategy_SignalLine(shift, sig))
         return false;

      const double diff = osc - sig;
      if(direction > 0)
        {
         if(diff < 0.0)
            have_retrace = true;
         if(diff < deepest)
            deepest = diff;
        }
      else
        {
         if(diff > 0.0)
            have_retrace = true;
         if(diff > deepest)
            deepest = diff;
        }
     }

   if(!have_retrace)
      return false;

   const double min_depth = strategy_retrace_stdev_mult * stdev;
   if(direction > 0)
      return (deepest <= -min_depth);
   return (deepest >= min_depth);
  }

int Strategy_AntiSignal()
  {
   const int recross = Strategy_ReCrossAtShift(1);
   if(recross == 0)
      return 0;
   if(!Strategy_NoRecentAntiTrigger())
      return 0;

   double osc_1 = 0.0;
   double sig_1 = 0.0;
   if(!Strategy_Oscillator(1, osc_1) || !Strategy_SignalLine(1, sig_1))
      return 0;

   const double atr = QM_ATR(_Symbol, Strategy_SignalTF(), strategy_atr_period, 1);
   if(atr <= 0.0)
      return 0;
   if(MathAbs(osc_1 - sig_1) <= strategy_cross_sep_atr_frac * atr)
      return 0;

   if(!Strategy_MacroTrendAllows(recross))
      return 0;
   if(!Strategy_SignalTrendAllows(recross))
      return 0;
   if(!Strategy_RetracementAllows(recross))
      return 0;

   return recross;
  }

bool Strategy_SelectOpenPosition(ulong &ticket,
                                 ENUM_POSITION_TYPE &ptype,
                                 double &volume,
                                 double &open_price,
                                 datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   volume = 0.0;
   open_price = 0.0;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_fast_sma_period <= 0 ||
      strategy_slow_sma_period <= strategy_fast_sma_period ||
      strategy_signal_sma_period <= 1 ||
      strategy_macro_sma_period <= 1 ||
      strategy_macro_slope_bars <= 0 ||
      strategy_signal_slope_bars <= 0 ||
      strategy_signal_confirm_bars <= strategy_signal_slope_bars ||
      strategy_retrace_lookback <= 0 ||
      strategy_stdev_period <= 1 ||
      strategy_cooldown_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_cross_sep_atr_frac < 0.0 ||
      strategy_retrace_stdev_mult <= 0.0 ||
      strategy_tp1_atr_mult <= 0.0 ||
      strategy_tp1_close_fraction <= 0.0 ||
      strategy_tp1_close_fraction >= 1.0 ||
      strategy_time_stop_bars <= 0)
      return true;

   const ENUM_TIMEFRAMES signal_tf = Strategy_SignalTF();
   const ENUM_TIMEFRAMES macro_tf = (strategy_macro_tf == PERIOD_CURRENT) ? PERIOD_D1 : strategy_macro_tf;
   const int signal_warmup = strategy_cooldown_bars + strategy_stdev_period + strategy_signal_sma_period + strategy_slow_sma_period + 10;
   const int macro_warmup = strategy_macro_sma_period + strategy_macro_slope_bars + 10;
   if(Bars(_Symbol, signal_tf) < signal_warmup || Bars(_Symbol, macro_tf) < macro_warmup) // perf-allowed: O(1) warm-up availability check only.
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > 0 && spread > strategy_max_spread_points)
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

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return false;

   const int signal = Strategy_AntiSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, Strategy_SignalTF(), strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (signal > 0) ? "RASCHKE_ANTI_BULL_RECROSS" : "RASCHKE_ANTI_BEAR_RECROSS";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return;

   if(open_time > 0 && strategy_time_stop_bars > 0)
     {
      const int stop_seconds = strategy_time_stop_bars * PeriodSeconds(Strategy_SignalTF());
      if(stop_seconds > 0 && TimeCurrent() - open_time >= stop_seconds)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         return;
        }
     }

   if(Strategy_HasTp1Done(ticket))
      return;

   const double atr = QM_ATR(_Symbol, Strategy_SignalTF(), strategy_atr_period, 1);
   if(atr <= 0.0 || open_price <= 0.0 || volume <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double move = is_buy ? (market - open_price) : (open_price - market);
   if(move < strategy_tp1_atr_mult * atr)
      return;

   const double lots_to_close = volume * strategy_tp1_close_fraction;
   if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
      Strategy_MarkTp1Done(ticket);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double volume = 0.0;
   double open_price = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOpenPosition(ticket, ptype, volume, open_price, open_time))
      return false;

   double sig_1 = 0.0;
   double sig_then = 0.0;
   if(!Strategy_SignalLine(1, sig_1) ||
      !Strategy_SignalLine(1 + strategy_signal_slope_bars, sig_then))
      return false;

   if(ptype == POSITION_TYPE_BUY && sig_1 < sig_then)
      return true;
   if(ptype == POSITION_TYPE_SELL && sig_1 > sig_then)
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
                        60,
                        60,
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
