#property strict
#property version   "5.0"
#property description "QM5_10749 TV ORB Atlas"

#include <QM/QM_Common.mqh>

enum StrategyStopMode
  {
   STRATEGY_STOP_OPPOSITE_OR = 0,
   STRATEGY_STOP_ATR         = 1
  };

enum StrategyTargetMode
  {
   STRATEGY_TARGET_RR  = 0,
   STRATEGY_TARGET_OR  = 1,
   STRATEGY_TARGET_ATR = 2
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10749;
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
input int                strategy_session_start_hhmm      = 1630;
input int                strategy_session_end_hhmm        = 2300;
input int                strategy_opening_range_minutes   = 15;
input int                strategy_atr_period              = 14;
input double             strategy_min_or_atr              = 0.50;
input double             strategy_max_or_atr              = 3.00;
input double             strategy_padding_atr_fraction    = 0.15;
input bool               strategy_use_htf_ema_slope       = false;
input ENUM_TIMEFRAMES    strategy_htf_tf                  = PERIOD_H1;
input int                strategy_htf_ema_period          = 100;
input StrategyStopMode   strategy_stop_mode               = STRATEGY_STOP_OPPOSITE_OR;
input double             strategy_atr_stop_mult           = 1.50;
input StrategyTargetMode strategy_target_mode             = STRATEGY_TARGET_RR;
input double             strategy_rr_target               = 2.00;
input double             strategy_or_target_mult          = 1.00;
input double             strategy_atr_target_mult         = 2.00;
input bool               strategy_exit_before_close       = true;
input int                strategy_flat_hhmm               = 2255;
input int                strategy_max_hold_minutes        = 0;
input double             strategy_max_spread_points       = 0.0;

int      g_session_day_key = 0;
bool     g_or_has_range = false;
bool     g_or_ready = false;
bool     g_trade_taken_today = false;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
datetime g_or_locked_at = 0;

int HhmmToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   return hour * 60 + minute;
  }

int HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int DayKeyFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = HhmmToMinutes(hhmm);
   const int start_m = HhmmToMinutes(start_hhmm);
   const int end_m = HhmmToMinutes(end_hhmm);
   if(start_m == end_m)
      return true;
   if(start_m < end_m)
      return (now_m >= start_m && now_m < end_m);
   return (now_m >= start_m || now_m < end_m);
  }

int MinutesFromSessionStart(const int hhmm)
  {
   int delta = HhmmToMinutes(hhmm) - HhmmToMinutes(strategy_session_start_hhmm);
   if(delta < 0)
      delta += 1440;
   return delta;
  }

void ResetSessionState(const int day_key)
  {
   g_session_day_key = day_key;
   g_or_has_range = false;
   g_or_ready = false;
   g_trade_taken_today = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_locked_at = 0;
  }

bool GetClosedBar(MqlRates &bar)
  {
   MqlRates bars[1];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, bars) != 1) // perf-allowed: one closed bar for opening-range structural state.
      return false;
   bar = bars[0];
   return true;
  }

bool HasOurOpenPosition()
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
      return true;
     }
   return false;
  }

void AdvanceOpeningRangeState(const MqlRates &bar)
  {
   const int hhmm = HhmmFromTime(bar.time);
   if(!HhmmInWindow(hhmm, strategy_session_start_hhmm, strategy_session_end_hhmm))
      return;

   const int day_key = DayKeyFromTime(bar.time);
   if(day_key != g_session_day_key)
      ResetSessionState(day_key);

   const int or_minutes = MathMax(5, MathMin(60, strategy_opening_range_minutes));
   const int from_start = MinutesFromSessionStart(hhmm);
   const int bar_minutes = MathMax(1, PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60);

   if(from_start < or_minutes)
     {
      if(!g_or_has_range)
        {
         g_or_high = bar.high;
         g_or_low = bar.low;
         g_or_has_range = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, bar.high);
         g_or_low = MathMin(g_or_low, bar.low);
        }

      if(from_start + bar_minutes >= or_minutes)
        {
         g_or_ready = true;
         g_or_locked_at = bar.time + bar_minutes * 60;
        }
      return;
     }

   if(g_or_has_range && !g_or_ready)
     {
      g_or_ready = true;
      g_or_locked_at = bar.time;
     }
  }

bool HtfSlopeAllows(const bool want_long)
  {
   if(!strategy_use_htf_ema_slope)
      return true;
   const int ema_period = MathMax(2, strategy_htf_ema_period);
   const double ema1 = QM_EMA(_Symbol, strategy_htf_tf, ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, strategy_htf_tf, ema_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0)
      return false;
   return want_long ? (ema1 > ema2) : (ema1 < ema2);
  }

bool BuildRequest(const bool want_long, const double entry_price, const double atr, QM_EntryRequest &req)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || atr <= 0.0 || g_or_high <= g_or_low)
      return false;

   double sl = 0.0;
   if(strategy_stop_mode == STRATEGY_STOP_ATR)
      sl = want_long ? entry_price - atr * strategy_atr_stop_mult
                     : entry_price + atr * strategy_atr_stop_mult;
   else
      sl = want_long ? g_or_low : g_or_high;

   const double risk_distance = MathAbs(entry_price - sl);
   if(risk_distance < point * 10.0)
      return false;

   const double or_range = g_or_high - g_or_low;
   double tp = 0.0;
   if(strategy_target_mode == STRATEGY_TARGET_OR)
      tp = want_long ? entry_price + or_range * strategy_or_target_mult
                     : entry_price - or_range * strategy_or_target_mult;
   else if(strategy_target_mode == STRATEGY_TARGET_ATR)
      tp = want_long ? entry_price + atr * strategy_atr_target_mult
                     : entry_price - atr * strategy_atr_target_mult;
   else
      tp = want_long ? entry_price + risk_distance * strategy_rr_target
                     : entry_price - risk_distance * strategy_rr_target;

   if(tp <= 0.0)
      return false;

   req.type = want_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = want_long ? "TV_ORB_ATLAS_LONG_CLOSE_CONFIRM" : "TV_ORB_ATLAS_SHORT_CLOSE_CONFIRM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int hhmm = HhmmFromTime(broker_now);
   if(!HhmmInWindow(hhmm, strategy_session_start_hhmm, strategy_session_end_hhmm))
      return true;
   if(strategy_exit_before_close && hhmm >= strategy_flat_hhmm)
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
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

   MqlRates bar;
   if(!GetClosedBar(bar))
      return false;

   AdvanceOpeningRangeState(bar);

   if(HasOurOpenPosition())
     {
      g_trade_taken_today = true;
      return false;
     }
   if(g_trade_taken_today || !g_or_ready || !g_or_has_range)
      return false;
   if(bar.time < g_or_locked_at)
      return false;

   const int hhmm = HhmmFromTime(bar.time);
   if(!HhmmInWindow(hhmm, strategy_session_start_hhmm, strategy_session_end_hhmm))
      return false;
   if(strategy_exit_before_close && hhmm >= strategy_flat_hhmm)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   const double or_range = g_or_high - g_or_low;
   if(atr <= 0.0 || or_range <= 0.0)
      return false;

   const double or_atr = or_range / atr;
   if(or_atr < strategy_min_or_atr || or_atr > strategy_max_or_atr)
      return false;

   const double padding = atr * strategy_padding_atr_fraction;
   const bool long_signal = (bar.close > g_or_high + padding);
   const bool short_signal = (bar.close < g_or_low - padding);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(long_signal && HtfSlopeAllows(true) && BuildRequest(true, ask, atr, req))
     {
      g_trade_taken_today = true;
      return true;
     }
   if(short_signal && HtfSlopeAllows(false) && BuildRequest(false, bid, atr, req))
     {
      g_trade_taken_today = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   const int hhmm = HhmmFromTime(broker_now);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(strategy_exit_before_close && hhmm >= strategy_flat_hhmm)
         return true;

      if(strategy_max_hold_minutes > 0)
        {
         const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened_at > 0 && broker_now - opened_at >= strategy_max_hold_minutes * 60)
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
   ResetSessionState(0);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10749\",\"ea\":\"QM5_10749_tv_orb_atlas\"}");
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
