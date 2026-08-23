#property strict
#property version   "5.0"
#property description "QM5_9932 Bandy ROC Z-Score Normalised Mean Reversion Index"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9932
// Strategy Card: C:/QM/repo/framework/EAs/QM5_9932_bandy-roc-zscore-normalised-mr-index/docs/strategy_card.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9932;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_roc_period         = 10;
input int    strategy_zscore_lookback    = 60;
input double strategy_entry_z            = -2.0;
input double strategy_exit_z             = 0.0;
input int    strategy_regime_sma_period  = 200;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 2.5;
input int    strategy_time_stop_bars     = 8;
input double strategy_min_stdev          = 0.20;
input int    strategy_warmup_bars        = 270;

// -----------------------------------------------------------------------------
// Strategy calculation — bounded and cached once per D1 calendar key.
// -----------------------------------------------------------------------------

bool Strategy_CalculateROCZ(double &zscore, double &latest_close)
{
   static int    cached_calendar_key = 0;
   static bool   cached_valid        = false;
   static double cached_zscore       = 0.0;
   static double cached_close        = 0.0;

   zscore = 0.0;
   latest_close = 0.0;

   const int calendar_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(calendar_key <= 0)
      return false;

   if(calendar_key == cached_calendar_key)
   {
      zscore = cached_zscore;
      latest_close = cached_close;
      return cached_valid;
   }

   cached_calendar_key = calendar_key;
   cached_valid = false;
   cached_zscore = 0.0;
   cached_close = 0.0;

   if(strategy_roc_period < 1 || strategy_zscore_lookback < 2)
      return false;

   const int bars_needed = strategy_zscore_lookback + strategy_roc_period;
   MqlRates rates[];
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   // perf-allowed: the card requires a bounded rolling ROC array; this helper is cached by QM_CalendarPeriodKey and scans once per closed D1 bar.
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) != bars_needed)
      return false;

   double roc_series[];
   ArrayResize(roc_series, strategy_zscore_lookback);
   double sum = 0.0;
   for(int i = 0; i < strategy_zscore_lookback; ++i)
   {
      const double recent_close = rates[i].close;
      const double earlier_close = rates[i + strategy_roc_period].close;
      if(recent_close <= 0.0 || earlier_close <= 0.0)
         return false;
      roc_series[i] = 100.0 * (recent_close - earlier_close) / earlier_close;
      sum += roc_series[i];
   }

   const double mean = sum / (double)strategy_zscore_lookback;
   double variance_sum = 0.0;
   for(int i = 0; i < strategy_zscore_lookback; ++i)
   {
      const double deviation = roc_series[i] - mean;
      variance_sum += deviation * deviation;
   }

   const double variance = variance_sum / (double)strategy_zscore_lookback;
   if(variance <= 0.0)
      return false;

   const double stdev = MathSqrt(variance);
   if(stdev < strategy_min_stdev)
      return false;

   cached_zscore = (roc_series[0] - mean) / stdev;
   cached_close = rates[0].close;
   cached_valid = true;

   zscore = cached_zscore;
   latest_close = cached_close;
   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   return (strategy_roc_period < 1 ||
           strategy_zscore_lookback < 2 ||
           strategy_entry_z >= strategy_exit_z ||
           strategy_regime_sma_period < 2 ||
           strategy_atr_period < 1 ||
           strategy_atr_stop_mult <= 0.0 ||
           strategy_time_stop_bars < 1 ||
           strategy_min_stdev < 0.0);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   double zscore = 0.0;
   double closed_price = 0.0;
   if(!Strategy_CalculateROCZ(zscore, closed_price))
      return false;

   if(zscore > strategy_entry_z)
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1,
                                     strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(regime_sma <= 0.0 || closed_price <= regime_sma)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ask <= 0.0 || atr_value <= 0.0)
      return false;

   const double stop_price = QM_StopATRFromValue(_Symbol, QM_BUY, ask,
                                                  atr_value, strategy_atr_stop_mult);
   if(stop_price <= 0.0 || stop_price >= ask)
      return false;

   req.sl = stop_price;
   req.reason = StringFormat("BANDY_ROC_Z_LONG z=%.4f", zscore);
   return true;
}

void Strategy_ManageOpenPosition()
{
   // No trailing; fixed catastrophic stop attached at entry.
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(!QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
      return false;

   double zscore = 0.0;
   double closed_price = 0.0;
   if(Strategy_CalculateROCZ(zscore, closed_price) && zscore >= strategy_exit_z)
      return true;

   const int held_bars = QM_TM_HeldPeriodsForMagic((long)magic,
                                                    _Symbol,
                                                    PERIOD_D1,
                                                    TimeCurrent());
   return (held_bars >= strategy_time_stop_bars);
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
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
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
