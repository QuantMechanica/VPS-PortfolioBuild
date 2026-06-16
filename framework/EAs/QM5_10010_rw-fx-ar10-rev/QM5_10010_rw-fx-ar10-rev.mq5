#property strict
#property version   "5.0"
#property description "QM5_10010 Robot Wealth FX AR10 Reversal"
// rework v2 2026-06-16: AR(10) coefficients were all 0.0 -> pred_ret always 0 < threshold -> ZERO trades; seeded thesis-faithful negative (reversal) lag coeffs so the forecast is non-degenerate.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10010;
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
input int    strategy_atr_period              = 14;
input double strategy_entry_threshold_atr     = 0.15;
input double strategy_sl_atr_mult             = 1.20;
input double strategy_tp_atr_mult             = 0.0;
input int    strategy_vol_lookback_bars       = 60;
input double strategy_vol_percentile_min      = 50.0;
input double strategy_max_spread_atr_fraction = 0.20;
input int    strategy_max_hold_bars           = 6;
input int    strategy_ny_close_hour_broker    = 23;
input int    strategy_ny_close_minute_broker  = 50;
// AR(10) short-term reversal coefficients (Robot Wealth thesis: negative
// short-horizon FX autocorrelation). Seeded with decaying NEGATIVE lag weights
// so recent up-moves forecast a pull-back (reversal). These are deterministic,
// fixed in-sample defaults — no ML/online adaptation. Higher lags left ~0 since
// the documented effect is concentrated at the shortest horizons.
input double strategy_ar_intercept            = 0.0;
input double strategy_ar_lag1                 = -0.20;
input double strategy_ar_lag2                 = -0.10;
input double strategy_ar_lag3                 = -0.05;
input double strategy_ar_lag4                 = -0.025;
input double strategy_ar_lag5                 = 0.0;
input double strategy_ar_lag6                 = 0.0;
input double strategy_ar_lag7                 = 0.0;
input double strategy_ar_lag8                 = 0.0;
input double strategy_ar_lag9                 = 0.0;
input double strategy_ar_lag10                = 0.0;

int g_cached_forecast_signal = 0;

int BrokerMinutesOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week * 24 * 60) + (dt.hour * 60) + dt.min;
  }

int BrokerMinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 60) + dt.min;
  }

bool IsSessionCloseWindow(const datetime t)
  {
   const int cutoff = strategy_ny_close_hour_broker * 60 + strategy_ny_close_minute_broker;
   if(cutoff < 0 || cutoff >= 24 * 60)
      return false;
   return (BrokerMinutesOfDay(t) >= cutoff);
  }

bool HasOpenStrategyPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double LagCoefficient(const int lag)
  {
   switch(lag)
     {
      case 1:  return strategy_ar_lag1;
      case 2:  return strategy_ar_lag2;
      case 3:  return strategy_ar_lag3;
      case 4:  return strategy_ar_lag4;
      case 5:  return strategy_ar_lag5;
      case 6:  return strategy_ar_lag6;
      case 7:  return strategy_ar_lag7;
      case 8:  return strategy_ar_lag8;
      case 9:  return strategy_ar_lag9;
      case 10: return strategy_ar_lag10;
     }
   return 0.0;
  }

bool VolatilityPercentilePass(const MqlRates &rates[])
  {
   const int lookback = strategy_vol_lookback_bars;
   if(lookback < 2)
      return false;

   double vols[];
   ArrayResize(vols, lookback);
   int samples = 0;
   for(int i = 1; i <= lookback; ++i)
     {
      if(rates[i + 1].close <= 0.0)
         return false;
      vols[samples++] = MathAbs((rates[i].close / rates[i + 1].close) - 1.0);
     }

   if(samples < lookback || vols[0] <= 0.0)
      return false;

   int below_or_equal = 0;
   for(int i = 0; i < samples; ++i)
     {
      if(vols[i] <= vols[0])
         below_or_equal++;
     }

   const double percentile = 100.0 * (double)below_or_equal / (double)samples;
   return (percentile > strategy_vol_percentile_min);
  }

bool ComputeForecastSignal(int &signal)
  {
   signal = 0;
   g_cached_forecast_signal = 0;

   if(strategy_atr_period <= 0 || strategy_vol_lookback_bars < 2)
      return false;

   const int bars_needed = MathMax(strategy_vol_lookback_bars + 2, 12);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, bars_needed, rates);
   if(copied < bars_needed)
      return false;

   const double close_last = rates[1].close;
   if(close_last <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(!VolatilityPercentilePass(rates))
      return false;

   double pred_ret = strategy_ar_intercept;
   for(int lag = 1; lag <= 10; ++lag)
     {
      const double base_close = rates[lag + 1].close;
      if(base_close <= 0.0)
         return false;
      const double lag_ret = (rates[lag].close / base_close) - 1.0;
      pred_ret += LagCoefficient(lag) * lag_ret;
     }

   const double threshold = strategy_entry_threshold_atr * atr / close_last;
   if(threshold <= 0.0)
      return false;

   if(pred_ret >= threshold)
      signal = 1;
   else if(pred_ret <= -threshold)
      signal = -1;

   g_cached_forecast_signal = signal;
   return true;
  }

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   // Entry-specific time/spread/news filters live in Strategy_EntrySignal so
   // high spread or session-close windows cannot suppress required exits.
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   int signal = 0;
   ComputeForecastSignal(signal);

   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   if(HasOpenStrategyPosition(ptype, opened_at))
      return false;

   const datetime now = TimeCurrent();
   const int mow = BrokerMinutesOfWeek(now);
   if(mow >= 1 * 24 * 60 && mow < (1 * 24 * 60 + 10))
      return false;
   if(mow >= (5 * 24 * 60 + 23 * 60 + 50))
      return false;
   if(IsSessionCloseWindow(now))
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   if((ask - bid) > strategy_max_spread_atr_fraction * atr)
      return false;

   if(g_cached_forecast_signal == 0)
      return false;

   const QM_OrderType side = (g_cached_forecast_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (g_cached_forecast_signal > 0) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = (strategy_tp_atr_mult > 0.0) ? QM_TakeATR(_Symbol, side, entry, strategy_atr_period, strategy_tp_atr_mult) : 0.0;
   req.reason = (g_cached_forecast_signal > 0) ? "RW_AR10_REV_LONG" : "RW_AR10_REV_SHORT";
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime opened_at = 0;
   if(!HasOpenStrategyPosition(ptype, opened_at))
      return false;

   if(IsSessionCloseWindow(TimeCurrent()))
      return true;

   const int period_seconds = PeriodSeconds(_Period);
   if(strategy_max_hold_bars > 0 && period_seconds > 0 && opened_at > 0)
     {
      if((TimeCurrent() - opened_at) >= strategy_max_hold_bars * period_seconds)
         return true;
     }

   if(ptype == POSITION_TYPE_BUY && g_cached_forecast_signal < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_cached_forecast_signal > 0)
      return true;

   return false;
  }

// News Filter Hook.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
