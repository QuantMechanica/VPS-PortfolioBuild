#property strict
#property version   "5.0"
#property description "QM5_11755 Davey Big Range Momentum H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11755 davey-big-range-momentum-h1
// Strategy Card: 82b485a3-2c05-565c-818d-f04e03f74c5a
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11755;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal       = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance     = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_xr                 = 20;
input int    strategy_daysback           = 5;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_atr_tp_mult        = 4.0;
input double strategy_range_stddev_mult  = 2.0;

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

   if(strategy_xr < 2 || strategy_xr > 500 ||
      strategy_daysback < 1 || strategy_daysback > 500 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 ||
      strategy_range_stddev_mult <= 0.0)
      return false;

   const int bars_needed = MathMax(strategy_xr, strategy_daysback + 1);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, bars_needed, rates);
   if(copied < bars_needed)
      return false;

   const double signal_high = rates[0].high;
   const double signal_low = rates[0].low;
   const double signal_close = rates[0].close;
   const double prior_close = rates[strategy_daysback].close;
   if(signal_high <= 0.0 || signal_low <= 0.0 || signal_high <= signal_low ||
      signal_close <= 0.0 || prior_close <= 0.0)
      return false;

   double range_sum = 0.0;
   double ranges[];
   ArrayResize(ranges, strategy_xr);
   for(int i = 0; i < strategy_xr; ++i)
     {
      const double r = rates[i].high - rates[i].low;
      if(r <= 0.0)
         return false;
      ranges[i] = r;
      range_sum += r;
     }

   const double mean_range = range_sum / (double)strategy_xr;
   double variance_sum = 0.0;
   for(int i = 0; i < strategy_xr; ++i)
     {
      const double diff = ranges[i] - mean_range;
      variance_sum += diff * diff;
     }

   const double stddev_range = MathSqrt(variance_sum / (double)strategy_xr);
   const double signal_range = signal_high - signal_low;
   const double big_range_threshold = mean_range + strategy_range_stddev_mult * stddev_range;
   if(signal_range <= big_range_threshold)
      return false;

   QM_OrderType side = QM_BUY;
   if(signal_close > prior_close)
      side = QM_BUY;
   else if(signal_close < prior_close)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr, strategy_atr_tp_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "DAVEY_BIG_RANGE_MOMENTUM_LONG"
                                 : "DAVEY_BIG_RANGE_MOMENTUM_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"82b485a3-2c05-565c-818d-f04e03f74c5a\",\"ea\":\"QM5_11755_davey-big-range-momentum-h1\"}");
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
