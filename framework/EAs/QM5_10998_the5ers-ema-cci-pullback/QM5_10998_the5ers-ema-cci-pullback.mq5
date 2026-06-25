#property strict
#property version   "5.0"
#property description "QM5_10998 The5ers EMA CCI Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_10998_the5ers-ema-cci-pullback
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_10998_the5ers-ema-cci-pullback.md
// Source: The5ers pullback crossover article, H4 forex EMA20/50 + CCI setup.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10998;
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
input int    strategy_ema_fast_period     = 20;
input int    strategy_ema_slow_period     = 50;
input int    strategy_cci_period          = 20;
input double strategy_cci_threshold       = 100.0;
input int    strategy_atr_period          = 14;
input double strategy_sep_atr_mult        = 0.25;
input int    strategy_swing_lookback      = 5;
input double strategy_sl_atr_buffer       = 0.25;
input double strategy_tp_rr               = 1.5;
input int    strategy_struct_lookback     = 20;
input int    strategy_time_stop_bars      = 12;
input int    strategy_vol_pctile_lookback = 120;
input double strategy_vol_pctile          = 20.0;

// -----------------------------------------------------------------------------
// No Trade Filter (time, spread, news)
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_slow_period <= 0 ||
      strategy_cci_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_swing_lookback <= 0 ||
      strategy_struct_lookback <= 0 ||
      strategy_time_stop_bars <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double cci_value = QM_CCI(_Symbol, _Period, strategy_cci_period, 1, PRICE_TYPICAL);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || atr_value <= 0.0)
      return false;

   if(MathAbs(ema_fast - ema_slow) < strategy_sep_atr_mult * atr_value)
      return false;

   int vol_counted = 0;
   int vol_below = 0;
   if(strategy_vol_pctile_lookback > 0)
     {
      for(int s = 1; s <= strategy_vol_pctile_lookback; ++s)
        {
         const double atr_sample = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
         if(atr_sample <= 0.0)
            continue;
         vol_counted++;
         if(atr_sample < atr_value)
            vol_below++;
        }
      if(vol_counted > 0)
        {
         const double percentile = (double)vol_below / (double)vol_counted * 100.0;
         if(percentile < strategy_vol_pctile)
            return false;
        }
     }

   const double high1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar touch check
   const double low1 = iLow(_Symbol, _Period, 1);     // perf-allowed: single closed-bar touch check
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar close-back check
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   const double zone_low = MathMin(ema_fast, ema_slow);
   const double zone_high = MathMax(ema_fast, ema_slow);
   if(!(low1 <= zone_high && high1 >= zone_low))
      return false;

   bool is_long = false;
   QM_OrderType side = QM_BUY;
   if(ema_fast > ema_slow && cci_value <= -strategy_cci_threshold && close1 > ema_fast)
     {
      is_long = true;
      side = QM_BUY;
     }
   else if(ema_fast < ema_slow && cci_value >= strategy_cci_threshold && close1 < ema_fast)
     {
      is_long = false;
      side = QM_SELL;
     }
   else
      return false;

   const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double swing_low = low1;
   double swing_high = high1;
   for(int s = 1; s <= strategy_swing_lookback; ++s)
     {
      const double hh = iHigh(_Symbol, _Period, s); // perf-allowed: bounded swing SL scan on closed-bar entry path
      const double ll = iLow(_Symbol, _Period, s);  // perf-allowed: bounded swing SL scan on closed-bar entry path
      if(hh > swing_high)
         swing_high = hh;
      if(ll > 0.0 && ll < swing_low)
         swing_low = ll;
     }

   double sl = 0.0;
   if(is_long)
      sl = QM_StopRulesNormalizePrice(_Symbol, swing_low - strategy_sl_atr_buffer * atr_value);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, swing_high + strategy_sl_atr_buffer * atr_value);
   if(sl <= 0.0 || MathAbs(entry - sl) <= 0.0)
      return false;

   const double rr_tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(rr_tp <= 0.0)
      return false;

   double struct_high = high1;
   double struct_low = low1;
   for(int s = 1; s <= strategy_struct_lookback; ++s)
     {
      const double hh = iHigh(_Symbol, _Period, s); // perf-allowed: bounded structure TP scan on closed-bar entry path
      const double ll = iLow(_Symbol, _Period, s);  // perf-allowed: bounded structure TP scan on closed-bar entry path
      if(hh > struct_high)
         struct_high = hh;
      if(ll > 0.0 && ll < struct_low)
         struct_low = ll;
     }

   double tp = rr_tp;
   if(is_long)
     {
      if(struct_high > entry && struct_high < rr_tp)
         tp = struct_high;
     }
   else
     {
      if(struct_low > 0.0 && struct_low < entry && struct_low > rr_tp)
         tp = struct_low;
     }
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = is_long ? "ema_cci_pullback_long" : "ema_cci_pullback_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int tf_seconds = PeriodSeconds(_Period);
   const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: current bar time for card time stop
   if(tf_seconds <= 0 || bar_open <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened <= 0)
         continue;
      if((long)((bar_open - opened) / tf_seconds) >= strategy_time_stop_bars)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless the framework changes.
// -----------------------------------------------------------------------------

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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
