#property strict
#property version   "5.0"
#property description "QM5_12869 WTI Refinery Ramp Pullback Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12869 - WTI Refinery Ramp Pullback Continuation
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - long only during the May-July refinery-utilization ramp window
//   - requires rising slow trend, measured pullback from a recent high,
//     and short rebound confirmation
//   - exits on ramp-window end, trend/channel failure, max hold, Friday close,
//     or ATR hard stop
// Runtime uses MT5 OHLC only; no EIA, refinery, outage, API, CSV, or futures feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12869;
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
input int    strategy_start_month         = 5;
input int    strategy_start_day           = 1;
input int    strategy_end_month           = 7;
input int    strategy_end_day             = 31;
input int    strategy_trend_period        = 84;
input int    strategy_sma_slope_shift     = 10;
input int    strategy_pullback_lookback   = 20;
input int    strategy_rebound_lookback    = 3;
input int    strategy_exit_channel        = 12;
input int    strategy_atr_period          = 20;
input double strategy_min_pullback_atr    = 0.75;
input double strategy_max_pullback_atr    = 3.0;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 20;
input int    strategy_max_spread_points   = 1000;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_InRampWindow(const int mmdd_key)
  {
   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key = strategy_end_month * 100 + strategy_end_day;

   if(start_key <= end_key)
      return (mmdd_key >= start_key && mmdd_key <= end_key);
   return (mmdd_key >= start_key || mmdd_key <= end_key);
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

bool Strategy_Channel(const int lookback, double &highest_high, double &lowest_low)
  {
   if(lookback <= 0)
      return false;

   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 closed-bar channel math.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 closed-bar channel math.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_LoadClosedState(double &open_last,
                              double &close_last,
                              double &recent_high,
                              double &rebound_high,
                              double &exit_low,
                              double &trend_sma,
                              double &trend_sma_prior,
                              double &atr,
                              int &mmdd_key)
  {
   const int cal_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1);  // yyyymmdd of last closed D1 bar
   if(cal_key == 0)
      return false;
   mmdd_key = cal_key % 10000;
   open_last = iOpen(_Symbol, PERIOD_D1, 1);    // perf-allowed: D1 rebound body check.
   close_last = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: D1 pullback close on closed bars.
   if(open_last <= 0.0 || close_last <= 0.0)
      return false;

   double recent_low = 0.0;
   double rebound_low = 0.0;
   double exit_high = 0.0;
   if(!Strategy_Channel(strategy_pullback_lookback, recent_high, recent_low))
      return false;
   if(!Strategy_Channel(strategy_rebound_lookback, rebound_high, rebound_low))
      return false;
   if(!Strategy_Channel(strategy_exit_channel, exit_high, exit_low))
      return false;

   trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   trend_sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1 + strategy_sma_slope_shift, PRICE_CLOSE);
   atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(trend_sma <= 0.0 || trend_sma_prior <= 0.0 || atr <= 0.0)
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double open_last = 0.0;
   double close_last = 0.0;
   double recent_high = 0.0;
   double rebound_high = 0.0;
   double exit_low = 0.0;
   double trend_sma = 0.0;
   double trend_sma_prior = 0.0;
   double atr = 0.0;
   int mmdd_key = 0;
   if(!Strategy_LoadClosedState(open_last, close_last, recent_high, rebound_high,
                                exit_low, trend_sma, trend_sma_prior, atr, mmdd_key))
      return;

   const bool in_window = Strategy_InRampWindow(mmdd_key);
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

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
      bool should_close = (!in_window || close_last < trend_sma || close_last < exit_low);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

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
   if(strategy_start_month < 1 || strategy_start_month > 12)
      return true;
   if(strategy_end_month < 1 || strategy_end_month > 12)
      return true;
   if(strategy_start_day < 1 || strategy_start_day > 31)
      return true;
   if(strategy_end_day < 1 || strategy_end_day > 31)
      return true;
   if(strategy_trend_period <= 1 || strategy_sma_slope_shift <= 0)
      return true;
   if(strategy_pullback_lookback <= 1 || strategy_rebound_lookback <= 0 || strategy_exit_channel <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_min_pullback_atr <= 0.0)
      return true;
   if(strategy_max_pullback_atr <= strategy_min_pullback_atr)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12869_WTI_REF_RAMP_PB";
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

   double open_last = 0.0;
   double close_last = 0.0;
   double recent_high = 0.0;
   double rebound_high = 0.0;
   double exit_low = 0.0;
   double trend_sma = 0.0;
   double trend_sma_prior = 0.0;
   double atr = 0.0;
   int mmdd_key = 0;
   if(!Strategy_LoadClosedState(open_last, close_last, recent_high, rebound_high,
                                exit_low, trend_sma, trend_sma_prior, atr, mmdd_key))
      return false;
   if(!Strategy_InRampWindow(mmdd_key))
      return false;
   if(close_last <= trend_sma || trend_sma <= trend_sma_prior)
      return false;

   const double pullback_atr = (recent_high - close_last) / atr;
   if(pullback_atr < strategy_min_pullback_atr || pullback_atr > strategy_max_pullback_atr)
      return false;
   if(close_last <= open_last || close_last <= rebound_high)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "WTI_REFINERY_RAMP_PULLBACK_LONG";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12869\",\"ea\":\"wti-ref-ramp-pb\"}");
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
