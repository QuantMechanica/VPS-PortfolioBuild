#property strict
#property version   "5.0"
#property description "QM5_11134 Clenow 50D Breakout Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11134;
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
input int    strategy_breakout_lookback   = 50;
input int    strategy_trend_fast_sma      = 50;
input int    strategy_trend_slow_sma      = 100;
input int    strategy_atr_period          = 20;
input double strategy_trail_atr_mult      = 3.0;
input double strategy_stop_atr_mult       = 3.5;
input int    strategy_warmup_bars         = 120;
input int    strategy_spread_median_days  = 60;
input double strategy_spread_median_mult  = 2.0;

ulong  g_tracked_ticket          = 0;
double g_best_close_since_entry  = 0.0;
bool   g_block_entry_this_bar    = false;

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

void ResetPositionState()
  {
   g_tracked_ticket = 0;
   g_best_close_since_entry = 0.0;
  }

bool SyncPositionState(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   if(open_price <= 0.0)
      return false;

   if(g_tracked_ticket != ticket)
     {
      g_tracked_ticket = ticket;
      g_best_close_since_entry = open_price;
     }

   return true;
  }

double ClosedD1Close(const int shift)
  {
   if(shift < 1)
      return 0.0;
   return QM_SMA(_Symbol, PERIOD_D1, 1, shift);
  }

double HighestClosedD1Close(const int lookback)
  {
   if(lookback < 1)
      return 0.0;

   double highest = -DBL_MAX;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double close_value = ClosedD1Close(shift);
      if(close_value <= 0.0)
         return 0.0;
      highest = MathMax(highest, close_value);
     }

   return highest;
  }

double LowestClosedD1Close(const int lookback)
  {
   if(lookback < 1)
      return 0.0;

   double lowest = DBL_MAX;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double close_value = ClosedD1Close(shift);
      if(close_value <= 0.0)
         return 0.0;
      lowest = MathMin(lowest, close_value);
     }

   return lowest;
  }

void UpdateBestClosedSinceEntry(const ENUM_POSITION_TYPE ptype)
  {
   const double close_1 = ClosedD1Close(1);
   if(close_1 <= 0.0)
      return;

   if(g_best_close_since_entry <= 0.0)
      g_best_close_since_entry = close_1;
   else if(ptype == POSITION_TYPE_BUY)
      g_best_close_since_entry = MathMax(g_best_close_since_entry, close_1);
   else
      g_best_close_since_entry = MathMin(g_best_close_since_entry, close_1);
  }

bool HasWarmup()
  {
   if(strategy_warmup_bars < 1)
      return false;
   return (ClosedD1Close(strategy_warmup_bars) > 0.0);
  }

bool SpreadWithinCardLimit()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_median_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || point <= 0.0)
      return false;

   int spreads[];
   ArrayResize(spreads, strategy_spread_median_days);
   const int copied = CopySpread(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, spreads); // perf-allowed: bounded 60D spread median, EntrySignal is called only after QM_IsNewBar().
   if(copied <= 0)
      return false;

   ArrayResize(spreads, copied);
   ArraySort(spreads);

   double median = 0.0;
   const int mid = copied / 2;
   if((copied % 2) == 1)
      median = (double)spreads[mid];
   else
      median = ((double)spreads[mid - 1] + (double)spreads[mid]) / 2.0;

   if(median <= 0.0)
      return false;

   const double current_spread = (ask - bid) / point;
   return (current_spread <= median * strategy_spread_median_mult);
  }

bool BuildMarketEntry(QM_EntryRequest &req,
                      const QM_OrderType side,
                      const double entry_price,
                      const double stop_distance,
                      const string reason)
  {
   if(entry_price <= 0.0 || stop_distance <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry_price, stop_distance);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   return (req.sl > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks - No Trade Filter, Trade Entry, Trade Management, Trade Close,
// and News Filter Hook.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   if(strategy_breakout_lookback < 1 ||
      strategy_trend_fast_sma < 1 ||
      strategy_trend_slow_sma < 1 ||
      strategy_atr_period < 1 ||
      strategy_trail_atr_mult <= 0.0 ||
      strategy_stop_atr_mult <= 0.0)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(SelectOurPosition(ticket, ptype))
     {
      if(SyncPositionState(ticket))
         UpdateBestClosedSinceEntry(ptype);
      return false;
     }

   ResetPositionState();

   if(g_block_entry_this_bar)
     {
      g_block_entry_this_bar = false;
      return false;
     }

   if(!HasWarmup())
      return false;
   if(!SpreadWithinCardLimit())
      return false;

   const double close_1 = ClosedD1Close(1);
   const double fast_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_fast_sma, 1);
   const double slow_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_slow_sma, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_1 <= 0.0 || fast_sma <= 0.0 || slow_sma <= 0.0 || atr <= 0.0)
      return false;

   const double highest_close = HighestClosedD1Close(strategy_breakout_lookback);
   const double lowest_close = LowestClosedD1Close(strategy_breakout_lookback);
   const double stop_distance = atr * strategy_stop_atr_mult;
   if(highest_close <= 0.0 || lowest_close <= 0.0 || stop_distance <= 0.0)
      return false;

   if(fast_sma > slow_sma && close_1 >= highest_close)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return BuildMarketEntry(req, QM_BUY, ask, stop_distance, "CLENOW_50D_BREAK_LONG");
     }

   if(fast_sma < slow_sma && close_1 <= lowest_close)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return BuildMarketEntry(req, QM_SELL, bid, stop_distance, "CLENOW_50D_BREAK_SHORT");
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, ptype))
     {
      ResetPositionState();
      return;
     }

   SyncPositionState(ticket);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!SelectOurPosition(ticket, ptype))
      return false;

   if(!SyncPositionState(ticket))
      return false;

   UpdateBestClosedSinceEntry(ptype);

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double close_1 = ClosedD1Close(1);
   if(atr <= 0.0 || close_1 <= 0.0 || g_best_close_since_entry <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY &&
      close_1 <= g_best_close_since_entry - strategy_trail_atr_mult * atr)
     {
      g_block_entry_this_bar = true;
      ResetPositionState();
      return true;
     }

   if(ptype == POSITION_TYPE_SELL &&
      close_1 >= g_best_close_since_entry + strategy_trail_atr_mult * atr)
     {
      g_block_entry_this_bar = true;
      ResetPositionState();
      return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return (broker_time < 0);
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
