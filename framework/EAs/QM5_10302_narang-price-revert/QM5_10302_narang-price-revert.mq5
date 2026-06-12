#property strict
#property version   "5.0"
#property description "QM5_10302 Narang Price Deviation Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10302;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_mean_lookback          = 48;
input int    strategy_atr_period             = 24;
input double strategy_deviation_threshold    = 1.5;
input double strategy_long_reject_frac       = 0.35;
input double strategy_short_reject_frac      = 0.65;
input int    strategy_slope_lookback         = 96;
input int    strategy_slope_bars             = 24;
input double strategy_slope_atr_mult         = 0.75;
input double strategy_stop_atr_mult          = 1.25;
input int    strategy_time_stop_bars         = 24;
input double strategy_emergency_atr_mult     = 2.5;
input int    strategy_atr_percentile_lookback = 500;
input double strategy_atr_percentile_rank    = 20.0;
input int    strategy_max_spread_points      = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_mean_lookback <= 1 || strategy_atr_period <= 0 ||
      strategy_deviation_threshold <= 0.0 || strategy_stop_atr_mult <= 0.0)
      return false;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, rates) != 1) // perf-allowed: one closed H1 bar; caller already passed QM_IsNewBar().
      return false;

   MqlDateTime bar_dt;
   TimeToStruct(rates[0].time, bar_dt);
   if(bar_dt.day_of_week == 0 || (bar_dt.day_of_week == 1 && bar_dt.hour == 0))
      return false;

   if(QM_NewsIsAvailable())
     {
      datetime utc_time = QM_BrokerToUTC(TimeCurrent());
      if(utc_time > 0 && QM_NewsInWindow(utc_time, _Symbol, 120, 120, "HIGH"))
         return false;
     }

   const double bar_high = rates[0].high;
   const double bar_low = rates[0].low;
   const double bar_close = rates[0].close;
   const double bar_range = bar_high - bar_low;
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0 || bar_range <= 0.0)
      return false;

   const double sma_mean = QM_SMA(_Symbol, PERIOD_H1, strategy_mean_lookback, 1);
   const double atr_now = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(sma_mean <= 0.0 || atr_now <= 0.0)
      return false;

   const int atr_lookback = (strategy_atr_percentile_lookback < 1000)
                            ? strategy_atr_percentile_lookback : 1000;
   if(atr_lookback > 0 && strategy_atr_percentile_rank > 0.0)
     {
      double atr_samples[];
      ArrayResize(atr_samples, atr_lookback);
      int atr_count = 0;
      for(int shift = 2; shift < 2 + atr_lookback; ++shift)
        {
         const double sample = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
         if(sample <= 0.0)
            continue;
         atr_samples[atr_count] = sample;
         atr_count++;
        }

      if(atr_count < MathMin(50, atr_lookback))
         return false;

      ArrayResize(atr_samples, atr_count);
      ArraySort(atr_samples);
      int rank_index = (int)MathFloor((strategy_atr_percentile_rank / 100.0) * (double)(atr_count - 1));
      if(rank_index < 0)
         rank_index = 0;
      if(rank_index >= atr_count)
         rank_index = atr_count - 1;
      if(atr_now < atr_samples[rank_index])
         return false;
     }

   if(strategy_slope_lookback <= 1 || strategy_slope_bars <= 0 || strategy_slope_atr_mult < 0.0)
      return false;

   const double sma_slope_now = QM_SMA(_Symbol, PERIOD_H1, strategy_slope_lookback, 1);
   const double sma_slope_then = QM_SMA(_Symbol, PERIOD_H1, strategy_slope_lookback, 1 + strategy_slope_bars);
   if(sma_slope_now <= 0.0 || sma_slope_then <= 0.0)
      return false;
   if(MathAbs(sma_slope_now - sma_slope_then) >= strategy_slope_atr_mult * atr_now)
      return false;

   const double deviation = (bar_close - sma_mean) / atr_now;
   const bool long_rejection = (bar_close > bar_low + strategy_long_reject_frac * bar_range);
   const bool short_rejection = (bar_close < bar_low + strategy_short_reject_frac * bar_range);

   if(deviation <= -strategy_deviation_threshold && long_rejection)
     {
      req.type = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.reason = "NARANG_PRICE_REVERT_LONG";
     }
   else if(deviation >= strategy_deviation_threshold && short_rejection)
     {
      req.type = QM_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.reason = "NARANG_PRICE_REVERT_SHORT";
     }
   else
      return false;

   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_now, strategy_stop_atr_mult);
   if(req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double sl_points = MathAbs(req.price - req.sl) / point;
   const int min_stop_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(min_stop_points > 0 && sl_points < (double)min_stop_points)
      return false;

   if(QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int direction = 0;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(direction == 0)
      return false;

   const int h1_seconds = PeriodSeconds(PERIOD_H1);
   if(strategy_time_stop_bars > 0 && h1_seconds > 0 && open_time > 0)
     {
      const int bars_held = (int)((TimeCurrent() - open_time) / h1_seconds);
      if(bars_held >= strategy_time_stop_bars)
         return true;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, rates) != 1) // perf-allowed: one closed H1 bar only for completed-bar exits.
      return false;

   const double sma_mean = QM_SMA(_Symbol, PERIOD_H1, strategy_mean_lookback, 1);
   const double atr_now = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double bar_close = rates[0].close;
   if(sma_mean <= 0.0 || atr_now <= 0.0 || bar_close <= 0.0)
      return false;

   if(direction > 0)
     {
      if(bar_close >= sma_mean)
         return true;
      if(bar_close <= sma_mean - strategy_emergency_atr_mult * atr_now)
         return true;
     }
   else
     {
      if(bar_close <= sma_mean)
         return true;
      if(bar_close >= sma_mean + strategy_emergency_atr_mult * atr_now)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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
