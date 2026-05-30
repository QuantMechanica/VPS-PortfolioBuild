#property strict
#property version   "5.0"
#property description "QM5_10442 MQL5 intraday price-action day trader"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10442;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M15;
input int             strategy_fast_ema_period    = 20;
input int             strategy_slow_ema_period    = 50;
input int             strategy_sr_lookback        = 50;
input int             strategy_atr_period         = 14;
input int             strategy_stop_loss_pips     = 30;
input double          strategy_atr_stop_mult      = 1.2;
input double          strategy_h1_atr_stop_cap    = 3.0;
input double          strategy_rr                 = 2.0;
input int             strategy_session_start_hour = 7;
input int             strategy_session_end_hour   = 20;
input int             strategy_spread_max_points  = 35;
input bool            strategy_close_eod_enabled  = true;

bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   bool session_ok = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         session_ok = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         session_ok = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(!session_ok)
      return true;

   if(strategy_spread_max_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_spread_max_points)
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

   if(strategy_signal_tf != (ENUM_TIMEFRAMES)_Period)
      return false;
   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= strategy_fast_ema_period ||
      strategy_sr_lookback < 3 ||
      strategy_atr_period <= 0 ||
      strategy_stop_loss_pips <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_h1_atr_stop_cap <= 0.0 ||
      strategy_rr <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double ema_fast = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 1);
   const double ema_slow = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 1);
   const double atr_m15 = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || atr_m15 <= 0.0 || atr_h1 <= 0.0)
      return false;

   const double open_1 = iOpen(_Symbol, strategy_signal_tf, 1);
   const double high_1 = iHigh(_Symbol, strategy_signal_tf, 1);
   const double low_1 = iLow(_Symbol, strategy_signal_tf, 1);
   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double open_2 = iOpen(_Symbol, strategy_signal_tf, 2);
   const double high_2 = iHigh(_Symbol, strategy_signal_tf, 2);
   const double low_2 = iLow(_Symbol, strategy_signal_tf, 2);
   const double close_2 = iClose(_Symbol, strategy_signal_tf, 2);
   const double high_3 = iHigh(_Symbol, strategy_signal_tf, 3);
   const double low_3 = iLow(_Symbol, strategy_signal_tf, 3);
   if(open_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0 ||
      open_2 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0 || close_2 <= 0.0 ||
      high_3 <= 0.0 || low_3 <= 0.0)
      return false;

   double support = DBL_MAX;
   double resistance = -DBL_MAX;
   for(int shift = 1; shift <= strategy_sr_lookback; ++shift)
     {
      const double lo = iLow(_Symbol, strategy_signal_tf, shift);
      const double hi = iHigh(_Symbol, strategy_signal_tf, shift);
      if(lo <= 0.0 || hi <= 0.0)
         return false;
      support = MathMin(support, lo);
      resistance = MathMax(resistance, hi);
     }
   if(support == DBL_MAX || resistance == -DBL_MAX || resistance <= support)
      return false;

   const double body_1 = MathAbs(close_1 - open_1);
   const double range_1 = high_1 - low_1;
   if(body_1 <= 0.0 || range_1 <= 0.0)
      return false;

   const double lower_wick = MathMin(open_1, close_1) - low_1;
   const double upper_wick = high_1 - MathMax(open_1, close_1);
   const bool bullish_pin = (lower_wick >= 2.0 * body_1 &&
                             close_1 >= low_1 + 0.5 * range_1 &&
                             MathAbs(low_1 - support) <= 0.5 * atr_m15);
   const bool bearish_pin = (upper_wick >= 2.0 * body_1 &&
                             close_1 <= low_1 + 0.5 * range_1 &&
                             MathAbs(high_1 - resistance) <= 0.5 * atr_m15);

   const double body_low_1 = MathMin(open_1, close_1);
   const double body_high_1 = MathMax(open_1, close_1);
   const double body_low_2 = MathMin(open_2, close_2);
   const double body_high_2 = MathMax(open_2, close_2);
   const bool bullish_engulfing = (close_1 > open_1 &&
                                   close_2 < open_2 &&
                                   body_low_1 <= body_low_2 &&
                                   body_high_1 >= body_high_2 &&
                                   close_1 > high_2);
   const bool bearish_engulfing = (close_1 < open_1 &&
                                   close_2 > open_2 &&
                                   body_low_1 <= body_low_2 &&
                                   body_high_1 >= body_high_2 &&
                                   close_1 < low_2);

   const bool inside_bar = (high_2 < high_3 && low_2 > low_3);
   const bool inside_break_long = (inside_bar && close_1 > high_3);
   const bool inside_break_short = (inside_bar && close_1 < low_3);

   const bool long_signal = (ema_fast > ema_slow) &&
                            (bullish_pin || bullish_engulfing || inside_break_long);
   const bool short_signal = (ema_fast < ema_slow) &&
                             (bearish_pin || bearish_engulfing || inside_break_short);
   if(!long_signal && !short_signal)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return false;
   const double pip_size = (digits == 3 || digits == 5) ? 10.0 * point : point;
   const double fixed_stop = strategy_stop_loss_pips * pip_size;
   const double stop_dist = MathMax(fixed_stop, strategy_atr_stop_mult * atr_m15);
   if(stop_dist <= 0.0 || stop_dist > strategy_h1_atr_stop_cap * atr_h1)
      return false;

   if(long_signal)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = ask - stop_dist;
      req.tp = ask + strategy_rr * stop_dist;
      req.reason = "PA_DAY_LONG";
      return true;
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;
   req.type = QM_SELL;
   req.sl = bid + stop_dist;
   req.tp = bid - strategy_rr * stop_dist;
   req.reason = "PA_DAY_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // P2 baseline: breakeven, trailing, partial close, and pyramiding disabled.
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_close_eod_enabled)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool session_ok = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         session_ok = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         session_ok = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(session_ok)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
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
