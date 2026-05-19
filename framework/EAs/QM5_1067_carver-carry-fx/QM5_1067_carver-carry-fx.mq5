#property strict
#property version   "5.0"
#property description "QM5_1067 Carver Vol-Normalised FX Carry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1067;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input double strategy_entry_forecast    = 2.0;
input int    strategy_vol_span_days     = 25;
input int    strategy_atr_period        = 20;
input double strategy_atr_stop_mult     = 2.5;
input double strategy_forecast_scalar   = 30.0;
input double strategy_forecast_cap      = 20.0;
input int    strategy_spread_median_days = 20;
input int    strategy_rebalance_hour_broker = 1;
input double strategy_swap_days_per_year = 256.0;

double   g_strategy_forecast = 0.0;
bool     g_strategy_forecast_valid = false;
datetime g_strategy_last_d1_bar = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): defer until rollover spread normalises.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_rebalance_hour_broker)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: closed-D1 vol-normalised carry forecast with spread gate.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_strategy_forecast_valid ||
      strategy_entry_forecast <= 0.0 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0)
      return false;

   MqlRates spread_rates[];
   const int spread_copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, spread_rates); // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   if(spread_copied == strategy_spread_median_days)
     {
      int spreads[];
      ArrayResize(spreads, spread_copied);
      int positive_count = 0;
      for(int i = 0; i < spread_copied; ++i)
        {
         if(spread_rates[i].spread > 0)
           {
            spreads[positive_count] = spread_rates[i].spread;
            positive_count++;
           }
        }
      if(positive_count > 0)
        {
         ArrayResize(spreads, positive_count);
         ArraySort(spreads);
         const double median_spread = (positive_count % 2 == 1)
                                      ? (double)spreads[positive_count / 2]
                                      : ((double)spreads[(positive_count / 2) - 1] + (double)spreads[positive_count / 2]) / 2.0;
         const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(median_spread > 0.0 && current_spread > 2.0 * median_spread)
            return false;
        }
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_strategy_forecast > strategy_entry_forecast)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "CARVER_CARRY_LONG";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(g_strategy_forecast < -strategy_entry_forecast)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "CARVER_CARRY_SHORT";
      return (req.sl > req.price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: advance the cached D1 carry forecast once per bar.
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0 || d1_bar == g_strategy_last_d1_bar)
      return;
   g_strategy_last_d1_bar = d1_bar;
   g_strategy_forecast_valid = false;
   g_strategy_forecast = 0.0;

   if(strategy_vol_span_days < 2 ||
      strategy_forecast_scalar <= 0.0 ||
      strategy_forecast_cap <= 0.0 ||
      strategy_swap_days_per_year <= 0.0)
      return;

   const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   if(MathAbs(swap_long) <= 0.0 && MathAbs(swap_short) <= 0.0)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int need = strategy_vol_span_days + 1;
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, need, rates); // perf-allowed: called once per new D1 bar.
   if(copied < need)
      return;

   double ewma_mean = 0.0;
   double ewma_var = 0.0;
   bool initialized = false;
   const double alpha = 2.0 / ((double)strategy_vol_span_days + 1.0);
   for(int i = copied - 1; i >= 1; --i)
     {
      const double ret = rates[i - 1].close - rates[i].close;
      if(!initialized)
        {
         ewma_mean = ret;
         ewma_var = 0.0;
         initialized = true;
         continue;
        }
      const double prev_mean = ewma_mean;
      ewma_mean = alpha * ret + (1.0 - alpha) * ewma_mean;
      const double diff = ret - prev_mean;
      ewma_var = (1.0 - alpha) * (ewma_var + alpha * diff * diff);
     }

   const double daily_vol = MathSqrt(MathMax(0.0, ewma_var));
   const double ann_vol = daily_vol * MathSqrt(strategy_swap_days_per_year);
   const double close_1 = rates[0].close;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ann_vol <= 0.0 || close_1 <= 0.0 || point <= 0.0)
      return;

   const double annualised_carry = ((swap_long - swap_short) * point * strategy_swap_days_per_year) / close_1;
   double forecast = strategy_forecast_scalar * (annualised_carry / (ann_vol / close_1));
   forecast = MathMax(-strategy_forecast_cap, MathMin(strategy_forecast_cap, forecast));

   g_strategy_forecast = forecast;
   g_strategy_forecast_valid = true;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: normal exit when carry forecast decays through zero.
   if(!g_strategy_forecast_valid)
      return false;

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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_strategy_forecast < 0.0)
         return true;
      if(type == POSITION_TYPE_SELL && g_strategy_forecast > 0.0)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: central-bank rate decisions are delegated to the framework calendar.
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
