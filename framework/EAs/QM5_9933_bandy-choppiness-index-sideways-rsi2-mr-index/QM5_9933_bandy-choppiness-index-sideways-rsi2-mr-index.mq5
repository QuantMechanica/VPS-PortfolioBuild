#property strict
#property version   "5.0"
#property description "QM5_9933 Bandy Choppiness Index Sideways RSI2 Mean Reversion Index"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9933
// Strategy Card: C:/QM/repo/framework/EAs/QM5_9933_bandy-choppiness-index-sideways-rsi2-mr-index/docs/strategy_card.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9933;
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
input int    strategy_ci_period          = 14;
input double strategy_ci_threshold       = 61.8;
input int    strategy_rsi_period         = 2;
input double strategy_rsi_entry_threshold = 10.0;
input double strategy_rsi_exit_threshold = 70.0;
input int    strategy_regime_sma_period  = 200;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 2.5;
input int    strategy_time_stop_bars     = 6;
input int    strategy_warmup_bars        = 220;

// -----------------------------------------------------------------------------
// Strategy calculation — bounded and cached once per D1 calendar key.
// -----------------------------------------------------------------------------

bool Strategy_CalculateChoppinessIndex(double &ci_value, double &closed_price)
{
   static int    cached_calendar_key = 0;
   static bool   cached_valid        = false;
   static double cached_ci           = 0.0;
   static double cached_close        = 0.0;

   ci_value     = 0.0;
   closed_price = 0.0;

   const int calendar_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(calendar_key <= 0)
      return false;

   if(calendar_key == cached_calendar_key)
   {
      ci_value     = cached_ci;
      closed_price = cached_close;
      return cached_valid;
   }

   cached_calendar_key = calendar_key;
   cached_valid        = false;
   cached_ci           = 0.0;
   cached_close        = 0.0;

   if(strategy_ci_period < 2)
      return false;

   const int bars_needed = strategy_ci_period + 1;
   MqlRates rates[];
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   // perf-allowed: the card requires rolling Choppiness Index over 14 daily bars; cached by QM_CalendarPeriodKey and scans once per closed D1 bar.
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) != bars_needed)
      return false;

   double sum_tr   = 0.0;
   double max_high = rates[0].high;
   double min_low  = rates[0].low;

   for(int k = 0; k < strategy_ci_period; ++k)
   {
      const double h_k    = rates[k].high;
      const double l_k    = rates[k].low;
      const double c_prev = rates[k + 1].close;

      if(h_k <= 0.0 || l_k <= 0.0 || c_prev <= 0.0)
         return false;

      const double hl = h_k - l_k;
      const double hc = MathAbs(h_k - c_prev);
      const double lc = MathAbs(l_k - c_prev);
      const double tr = MathMax(hl, MathMax(hc, lc));

      sum_tr += tr;
      if(h_k > max_high) max_high = h_k;
      if(l_k < min_low)  min_low  = l_k;
   }

   const double range = max_high - min_low;
   if(range <= 0.0 || sum_tr <= 0.0)
      return false;

   const double log10_n = MathLog10((double)strategy_ci_period);
   if(log10_n <= 0.0)
      return false;

   cached_ci    = 100.0 * MathLog10(sum_tr / range) / log10_n;
   cached_close = rates[0].close;
   cached_valid = true;

   ci_value     = cached_ci;
   closed_price = cached_close;
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

   return (strategy_ci_period < 2 ||
           strategy_ci_threshold <= 0.0 ||
           strategy_ci_threshold >= 100.0 ||
           strategy_rsi_period < 1 ||
           strategy_rsi_entry_threshold <= 0.0 ||
           strategy_rsi_exit_threshold <= strategy_rsi_entry_threshold ||
           strategy_regime_sma_period < 2 ||
           strategy_atr_period < 1 ||
           strategy_atr_stop_mult <= 0.0 ||
           strategy_time_stop_bars < 1);
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

   double ci_val = 0.0;
   double closed_price = 0.0;
   if(!Strategy_CalculateChoppinessIndex(ci_val, closed_price))
      return false;

   if(ci_val < strategy_ci_threshold)
      return false;

   const double rsi_val = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi_val <= 0.0 || rsi_val > strategy_rsi_entry_threshold)
      return false;

   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   if(regime_sma <= 0.0 || closed_price <= regime_sma)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ask <= 0.0 || atr_val <= 0.0)
      return false;

   const double stop_price = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_val, strategy_atr_stop_mult);
   if(stop_price <= 0.0 || stop_price >= ask)
      return false;

   req.sl = stop_price;
   req.reason = StringFormat("BANDY_CHOPPINESS_MR_LONG ci=%.2f rsi=%.2f", ci_val, rsi_val);
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

   const double rsi_val = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(rsi_val >= strategy_rsi_exit_threshold)
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

