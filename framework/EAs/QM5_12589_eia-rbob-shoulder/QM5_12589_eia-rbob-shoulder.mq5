#property strict
#property version   "5.0"
#property description "QM5_12589 EIA RBOB Autumn Shoulder Failed-Rally Short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12589 - EIA RBOB Autumn Shoulder Failed-Rally Short
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - short-only XTIUSD during the Sep 1-Nov 15 gasoline crack-spread shoulder
//   - requires a recent peak, falling slow trend, and low-break trigger
// Runtime uses MT5 OHLC only; no external EIA/RBOB/refinery data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12589;
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
input int    strategy_setup_lookback      = 42;
input int    strategy_peak_recent_bars    = 15;
input int    strategy_trend_period        = 63;
input int    strategy_sma_slope_shift     = 10;
input int    strategy_trigger_lookback    = 5;
input int    strategy_exit_lookback       = 8;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 25;
input int    strategy_max_spread_points   = 1000;

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

bool Strategy_InShoulderWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.mon == 9 || dt.mon == 10)
      return true;
   if(dt.mon == 11)
      return (dt.day <= 15);
   return false;
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

bool Strategy_HighLowWindow(const int lookback,
                            const int first_shift,
                            double &highest_high,
                            double &lowest_low,
                            int &highest_shift)
  {
   if(lookback <= 0 || first_shift < 1)
      return false;

   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;
   highest_shift = 0;
   for(int shift = first_shift; shift < first_shift + lookback; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 seasonal failure setup.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 seasonal failure setup.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      if(high > highest_high)
        {
         highest_high = high;
         highest_shift = shift;
        }
      lowest_low = MathMin(lowest_low, low);
     }
   return (highest_high > 0.0 && lowest_low > 0.0 && highest_shift > 0);
  }

bool Strategy_LoadClosedState(double &close_last,
                              double &trend_sma,
                              double &trend_sma_prior,
                              double &trigger_low,
                              double &exit_high,
                              int &setup_peak_shift,
                              datetime &closed_time,
                              int &day_key)
  {
   closed_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 calendar gate.
   if(closed_time <= 0)
      return false;

   close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 trigger close.
   if(close_last <= 0.0)
      return false;

   trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   trend_sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1 + strategy_sma_slope_shift, PRICE_CLOSE);
   if(trend_sma <= 0.0 || trend_sma_prior <= 0.0)
      return false;

   double setup_high = 0.0;
   double setup_low = 0.0;
   if(!Strategy_HighLowWindow(strategy_setup_lookback, 1, setup_high, setup_low, setup_peak_shift))
      return false;

   double trigger_high = 0.0;
   int trigger_high_shift = 0;
   if(!Strategy_HighLowWindow(strategy_trigger_lookback, 2, trigger_high, trigger_low, trigger_high_shift))
      return false;

   double exit_low = 0.0;
   int exit_high_shift = 0;
   if(!Strategy_HighLowWindow(strategy_exit_lookback, 2, exit_high, exit_low, exit_high_shift))
      return false;

   day_key = Strategy_DayKey(closed_time);
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_setup_lookback <= 5 || strategy_peak_recent_bars <= 0)
      return true;
   if(strategy_peak_recent_bars > strategy_setup_lookback)
      return true;
   if(strategy_trend_period <= 1 || strategy_sma_slope_shift <= 0)
      return true;
   if(strategy_trigger_lookback <= 1 || strategy_exit_lookback <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12589_EIA_RBOB_SHOULDER";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

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
   double trend_sma_prior = 0.0;
   double trigger_low = 0.0;
   double exit_high = 0.0;
   int setup_peak_shift = 0;
   datetime closed_time = 0;
   int day_key = 0;
   if(!Strategy_LoadClosedState(close_last, trend_sma, trend_sma_prior, trigger_low, exit_high,
                                setup_peak_shift, closed_time, day_key))
      return false;
   if(day_key <= 0 || day_key == g_last_signal_day_key)
      return false;

   if(!Strategy_InShoulderWindow(closed_time))
      return false;
   if(setup_peak_shift > strategy_peak_recent_bars)
      return false;
   if(close_last >= trend_sma || trend_sma >= trend_sma_prior)
      return false;
   if(close_last >= trigger_low)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_SELL);
   if(entry_price <= 0.0)
      return false;

   req.type = QM_SELL;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "EIA_RBOB_SHOULDER_SHORT";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12589\",\"ea\":\"eia-rbob-shoulder\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
