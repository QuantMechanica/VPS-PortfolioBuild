#property strict
#property version   "5.0"
#property description "QM5_9934 Bandy Ulcer Index Spike RSI2 Mean Reversion Index"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9934
// Strategy Card: C:/QM/repo/framework/EAs/QM5_9934_bandy-ulcer-index-spike-rsi2-mr-index/docs/strategy_card.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9934;
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
input int    strategy_ui_period          = 14;
input int    strategy_percentile_lookback = 252;
input double strategy_percentile_threshold = 80.0;
input int    strategy_rsi_period         = 2;
input double strategy_rsi_entry_threshold = 10.0;
input double strategy_rsi_exit_threshold = 70.0;
input int    strategy_regime_sma_period  = 200;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 3.0;
input int    strategy_time_stop_bars     = 10;
input int    strategy_warmup_bars        = 270;

// -----------------------------------------------------------------------------
// Strategy calculation — bounded and cached once per D1 calendar key.
// -----------------------------------------------------------------------------

bool Strategy_CalculateUlcerIndexSpike(double &ui_current, double &ui_p80, double &closed_price)
{
   static int    cached_calendar_key = 0;
   static bool   cached_valid        = false;
   static double cached_ui_current   = 0.0;
   static double cached_ui_p80       = 0.0;
   static double cached_close        = 0.0;

   ui_current   = 0.0;
   ui_p80       = 0.0;
   closed_price = 0.0;

   const int calendar_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(calendar_key <= 0)
      return false;

   if(calendar_key == cached_calendar_key)
   {
      ui_current   = cached_ui_current;
      ui_p80       = cached_ui_p80;
      closed_price = cached_close;
      return cached_valid;
   }

   cached_calendar_key = calendar_key;
   cached_valid        = false;
   cached_ui_current   = 0.0;
   cached_ui_p80       = 0.0;
   cached_close        = 0.0;

   if(strategy_ui_period < 1 || strategy_percentile_lookback < 2)
      return false;

   const int bars_needed = strategy_percentile_lookback + strategy_ui_period;
   MqlRates rates[];
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   // perf-allowed: the card requires rolling Ulcer Index percentile over trailing 252 daily bars; cached by QM_CalendarPeriodKey and scans once per closed D1 bar.
   if(CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates) != bars_needed)
      return false;

   double ui_series[];
   ArrayResize(ui_series, strategy_percentile_lookback);

   for(int i = 0; i < strategy_percentile_lookback; ++i)
   {
      double peak_high = 0.0;
      for(int k = 0; k < strategy_ui_period; ++k)
      {
         const double h = rates[i + k].high;
         if(h > peak_high)
            peak_high = h;
      }
      if(peak_high <= 0.0)
         return false;

      double dd_sq_sum = 0.0;
      for(int k = 0; k < strategy_ui_period; ++k)
      {
         const double c = rates[i + k].close;
         if(c <= 0.0)
            return false;
         const double dd = 100.0 * (peak_high - c) / peak_high;
         dd_sq_sum += dd * dd;
      }

      ui_series[i] = MathSqrt(dd_sq_sum / (double)strategy_ui_period);
   }

   cached_ui_current = ui_series[0];
   cached_close      = rates[0].close;

   double ui_sorted[];
   ArrayResize(ui_sorted, strategy_percentile_lookback);
   ArrayCopy(ui_sorted, ui_series);
   ArraySort(ui_sorted);

   int p_idx = (int)MathFloor((strategy_percentile_threshold / 100.0) * (double)(strategy_percentile_lookback - 1));
   if(p_idx < 0 || p_idx >= ArraySize(ui_sorted))
      return false;

   cached_ui_p80 = ui_sorted[p_idx];
   cached_valid  = true;

   ui_current   = cached_ui_current;
   ui_p80       = cached_ui_p80;
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

   return (strategy_ui_period < 1 ||
           strategy_percentile_lookback < 2 ||
           strategy_percentile_threshold <= 0.0 ||
           strategy_percentile_threshold >= 100.0 ||
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

   double ui_val = 0.0;
   double ui_thresh = 0.0;
   double closed_price = 0.0;
   if(!Strategy_CalculateUlcerIndexSpike(ui_val, ui_thresh, closed_price))
      return false;

   if(ui_val < ui_thresh)
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
   req.reason = StringFormat("BANDY_UI_SPIKE_RSI2_LONG ui=%.2f p80=%.2f rsi=%.2f", ui_val, ui_thresh, rsi_val);
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

