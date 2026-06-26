#property strict
#property version   "5.0"
#property description "QM5_12585 EIA RBOB Pullback Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12585 - EIA RBOB Pullback Continuation
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - long-only XTIUSD pullbacks during gasoline crack-spread support months
//   - requires an established D1 uptrend and a controlled multi-day pullback
// Runtime uses MT5 OHLC only; no external EIA/RBOB/refinery data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12585;
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
input int    strategy_trend_period        = 100;
input int    strategy_pullback_days       = 3;
input double strategy_min_pullback_atr    = 0.35;
input double strategy_max_pullback_atr    = 2.25;
input int    strategy_bounce_exit_lookback = 8;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 14;
input int    strategy_max_spread_points   = 1000;

int g_last_signal_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MonthFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

bool Strategy_InGasolineWindow(const int month)
  {
   return (month >= 3 && month <= 8);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_ConsecutiveDownCloses()
  {
   for(int shift = 1; shift <= strategy_pullback_days; ++shift)
     {
      const double close_now = iClose(_Symbol, PERIOD_D1, shift);      // perf-allowed: D1 pullback state.
      const double close_prev = iClose(_Symbol, PERIOD_D1, shift + 1); // perf-allowed: D1 pullback state.
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;
      if(close_now >= close_prev)
         return false;
     }
   return true;
  }

bool Strategy_HighestClose(const int lookback, const int first_shift, double &highest_close)
  {
   if(lookback <= 0 || first_shift < 1)
      return false;

   highest_close = -DBL_MAX;
   for(int shift = first_shift; shift < first_shift + lookback; ++shift)
     {
      const double close_value = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 bounce exit state.
      if(close_value <= 0.0)
         return false;
      highest_close = MathMax(highest_close, close_value);
     }
   return (highest_close > 0.0);
  }

bool Strategy_LoadClosedState(double &close_last,
                              double &trend_sma,
                              double &atr_last,
                              double &pullback_depth_atr,
                              double &bounce_exit_close,
                              int &month,
                              int &day_key)
  {
   const datetime closed_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 seasonal calendar key.
   if(closed_bar_time <= 0)
      return false;

   close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 pullback state.
   if(close_last <= 0.0)
      return false;

   trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(trend_sma <= 0.0 || atr_last <= 0.0)
      return false;

   const double pullback_start_close = iClose(_Symbol, PERIOD_D1, strategy_pullback_days + 1); // perf-allowed: D1 pullback state.
   if(pullback_start_close <= 0.0 || pullback_start_close <= close_last)
      return false;
   pullback_depth_atr = (pullback_start_close - close_last) / atr_last;
   if(!MathIsValidNumber(pullback_depth_atr))
      return false;

   if(!Strategy_HighestClose(strategy_bounce_exit_lookback, 2, bounce_exit_close))
      return false;

   month = Strategy_MonthFromTime(closed_bar_time);
   day_key = Strategy_DayKey(closed_bar_time);
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double trend_sma = 0.0;
   double atr_last = 0.0;
   double pullback_depth_atr = 0.0;
   double bounce_exit_close = 0.0;
   int month = 0;
   int day_key = 0;
   if(!Strategy_LoadClosedState(close_last, trend_sma, atr_last, pullback_depth_atr, bounce_exit_close, month, day_key))
      return;

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const bool in_window = Strategy_InGasolineWindow(month);

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
      bool should_close = (!in_window || close_last < trend_sma || close_last >= bounce_exit_close);
      should_close = should_close || (opened > 0 && now - opened >= hold_seconds);

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_trend_period <= 1 || strategy_pullback_days < 2)
      return true;
   if(strategy_min_pullback_atr <= 0.0 || strategy_max_pullback_atr <= strategy_min_pullback_atr)
      return true;
   if(strategy_bounce_exit_lookback <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12585_EIA_RBOB_PULLBACK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double trend_sma = 0.0;
   double atr_last = 0.0;
   double pullback_depth_atr = 0.0;
   double bounce_exit_close = 0.0;
   int month = 0;
   int day_key = 0;
   if(!Strategy_LoadClosedState(close_last, trend_sma, atr_last, pullback_depth_atr, bounce_exit_close, month, day_key))
      return false;
   if(day_key <= 0 || day_key == g_last_signal_day_key)
      return false;

   if(!Strategy_InGasolineWindow(month))
      return false;
   if(close_last <= trend_sma)
      return false;
   if(!Strategy_ConsecutiveDownCloses())
      return false;
   if(pullback_depth_atr < strategy_min_pullback_atr || pullback_depth_atr > strategy_max_pullback_atr)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;

   req.type = QM_BUY;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "EIA_RBOB_PULLBACK_LONG";
   g_last_signal_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12585\",\"ea\":\"eia-rbob-pullback\"}");
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
