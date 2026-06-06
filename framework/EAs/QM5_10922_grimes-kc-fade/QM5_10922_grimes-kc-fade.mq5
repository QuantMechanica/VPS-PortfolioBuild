#property strict
#property version   "5.0"
#property description "QM5_10922 Grimes Keltner Channel Fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10922;
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
input int             strategy_ema_period            = 20;
input int             strategy_atr_period            = 20;
input double          strategy_keltner_atr_mult      = 2.25;
input int             strategy_slope_bars            = 5;
input int             strategy_trigger_window_bars   = 3;
input int             strategy_slide_filter_bars     = 5;
input double          strategy_stop_buffer_atr       = 0.20;
input double          strategy_max_stop_atr          = 3.00;
input double          strategy_fallback_target_r     = 1.25;
input int             strategy_time_exit_bars        = 8;
input double          strategy_max_spread_stop_frac  = 0.10;

int    g_event_dir = 0;
double g_event_high = 0.0;
double g_event_low = 0.0;
double g_event_atr = 0.0;
bool   g_event_slope_ok = false;
int    g_event_bars_waited = 0;

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

void Strategy_ClearEvent()
  {
   g_event_dir = 0;
   g_event_high = 0.0;
   g_event_low = 0.0;
   g_event_atr = 0.0;
   g_event_slope_ok = false;
   g_event_bars_waited = 0;
  }

bool Strategy_LoadRates(MqlRates &rates[])
  {
   const int need_bars = Strategy_MaxInt(strategy_slide_filter_bars + strategy_slope_bars + 4,
                                         strategy_trigger_window_bars + strategy_slope_bars + 6);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, need_bars, rates); // perf-allowed: bounded H4 OHLC window, called only from framework closed-bar entry path.
   if(copied < need_bars)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_HasOurPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   return Strategy_SelectOurPosition(ticket, position_type, open_price, sl, open_time);
  }

bool Strategy_EMASlopeOkForEvent(const bool want_long, const int shift)
  {
   if(strategy_slope_bars < 1)
      return false;

   const double ema_now = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, shift);
   const double ema_then = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, shift + strategy_slope_bars);
   if(ema_now <= 0.0 || ema_then <= 0.0)
      return false;

   if(want_long)
      return (ema_now >= ema_then);
   return (ema_now <= ema_then);
  }

bool Strategy_SlideFilterBlocks(const bool want_long, const MqlRates &rates[])
  {
   if(strategy_slide_filter_bars <= 0)
      return false;

   for(int shift = 1; shift <= strategy_slide_filter_bars; ++shift)
     {
      const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, shift);
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(ema <= 0.0 || atr <= 0.0)
         return true;

      const double upper = ema + strategy_keltner_atr_mult * atr;
      const double lower = ema - strategy_keltner_atr_mult * atr;
      if(want_long)
        {
         if(rates[shift].close > lower)
            return false;
        }
      else
        {
         if(rates[shift].close < upper)
            return false;
        }
     }

   return true;
  }

void Strategy_DetectOutsideEvent(const MqlRates &rates[])
  {
   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(ema <= 0.0 || atr <= 0.0)
      return;

   const double upper = ema + strategy_keltner_atr_mult * atr;
   const double lower = ema - strategy_keltner_atr_mult * atr;
   const double close1 = rates[1].close;

   if(close1 > upper && (close1 - ema) >= strategy_keltner_atr_mult * atr)
     {
      if(Strategy_SlideFilterBlocks(false, rates))
         return;
      g_event_dir = -1;
      g_event_high = rates[1].high;
      g_event_low = rates[1].low;
      g_event_atr = atr;
      g_event_slope_ok = Strategy_EMASlopeOkForEvent(false, 1);
      g_event_bars_waited = 0;
      return;
     }

   if(close1 < lower && (ema - close1) >= strategy_keltner_atr_mult * atr)
     {
      if(Strategy_SlideFilterBlocks(true, rates))
         return;
      g_event_dir = 1;
      g_event_high = rates[1].high;
      g_event_low = rates[1].low;
      g_event_atr = atr;
      g_event_slope_ok = Strategy_EMASlopeOkForEvent(true, 1);
      g_event_bars_waited = 0;
     }
  }

bool Strategy_BuildFadeRequest(const bool want_long, QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || g_event_atr <= 0.0)
      return false;

   const double entry = want_long ? ask : bid;
   const double raw_sl = want_long ? (g_event_low - strategy_stop_buffer_atr * g_event_atr)
                                   : (g_event_high + strategy_stop_buffer_atr * g_event_atr);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   const double stop_distance = MathAbs(entry - sl);
   if(sl <= 0.0 || stop_distance <= 0.0)
      return false;
   if(stop_distance > strategy_max_stop_atr * g_event_atr)
      return false;
   if((ask - bid) > strategy_max_spread_stop_frac * stop_distance)
      return false;

   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   double tp = 0.0;
   if(want_long)
     {
      const double ema_distance = ema - entry;
      const double fallback_distance = strategy_fallback_target_r * stop_distance;
      const double target_distance = (ema_distance > 0.0 && ema_distance <= fallback_distance)
                                     ? ema_distance : fallback_distance;
      tp = QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, entry, target_distance);
     }
   else
     {
      const double ema_distance = entry - ema;
      const double fallback_distance = strategy_fallback_target_r * stop_distance;
      const double target_distance = (ema_distance > 0.0 && ema_distance <= fallback_distance)
                                     ? ema_distance : fallback_distance;
      tp = QM_StopRulesTakeFromDistance(_Symbol, QM_SELL, entry, target_distance);
     }

   if(tp <= 0.0)
      return false;

   req.type = want_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = want_long ? "GRIMES_KC_FADE_LONG" : "GRIMES_KC_FADE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_CheckEventTrigger(const MqlRates &rates[], QM_EntryRequest &req)
  {
   if(g_event_dir == 0)
      return false;

   g_event_high = MathMax(g_event_high, rates[1].high);
   g_event_low = MathMin(g_event_low, rates[1].low);

   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(ema <= 0.0 || atr <= 0.0)
     {
      Strategy_ClearEvent();
      return false;
     }

   const double upper = ema + strategy_keltner_atr_mult * atr;
   const double lower = ema - strategy_keltner_atr_mult * atr;
   const bool want_long = (g_event_dir > 0);
   const bool crossed_inside = want_long ? (rates[1].close > lower)
                                         : (rates[1].close < upper);

   if(crossed_inside && (g_event_slope_ok || crossed_inside))
     {
      g_event_atr = atr;
      const bool built = Strategy_BuildFadeRequest(want_long, req);
      Strategy_ClearEvent();
      return built;
     }

   g_event_bars_waited++;
   if(g_event_bars_waited >= strategy_trigger_window_bars)
      Strategy_ClearEvent();

   return false;
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
   if(strategy_ema_period <= 1 ||
      strategy_atr_period <= 1 ||
      strategy_keltner_atr_mult <= 0.0 ||
      strategy_slope_bars < 1 ||
      strategy_trigger_window_bars < 1 ||
      strategy_slide_filter_bars < 1 ||
      strategy_stop_buffer_atr < 0.0 ||
      strategy_max_stop_atr <= 0.0 ||
      strategy_fallback_target_r <= 0.0 ||
      strategy_max_spread_stop_frac <= 0.0)
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

   if(Strategy_HasOurPosition())
      return false;

   MqlRates rates[];
   if(!Strategy_LoadRates(rates))
      return false;

   if(Strategy_CheckEventTrigger(rates, req))
      return true;

   Strategy_DetectOutsideEvent(rates);
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_price, sl, open_time))
      return false;

   if(strategy_time_exit_bars > 0 && Strategy_BarsHeldSince(open_time) >= strategy_time_exit_bars)
      return true;

   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 && bid >= ema);
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return (ask > 0.0 && ask <= ema);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10922_grimes_kc_fade\"}");
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
