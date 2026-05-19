#property strict
#property version   "5.0"
#property description "QM5_1371 Bernstein Stochastic Pop H1"

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
input int    qm_ea_id                   = 1371;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_stoch_k_period    = 14;
input int    strategy_stoch_d_period    = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_upper       = 80.0;
input double strategy_stoch_lower       = 20.0;
input int    strategy_ema_period        = 200;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input int    strategy_max_hold_bars     = 24;
input bool   strategy_skip_asian        = true;
input int    strategy_asian_end_hour    = 6;
input int    strategy_spread_median_bars = 20;
input double strategy_spread_median_mult = 1.5;

datetime g_last_exit_eval_bar = 0;
bool     g_cached_exit_signal = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(strategy_skip_asian && dt.hour >= 0 && dt.hour < strategy_asian_end_hour)
      return true;

   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(strategy_spread_median_bars <= 0 || strategy_spread_median_bars > 64 || strategy_spread_median_mult <= 0.0)
      return true;

   double spreads[64];
   int count = 0;
   for(int i = 1; i <= strategy_spread_median_bars; ++i)
     {
      const long bar_spread = iSpread(_Symbol, _Period, i);
      if(bar_spread <= 0)
         continue;
      spreads[count] = (double)bar_spread;
      ++count;
     }

   for(int i = 1; i < count; ++i)
     {
      const double v = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > v)
        {
         spreads[j + 1] = spreads[j];
         --j;
        }
      spreads[j + 1] = v;
     }

   if(count <= 0)
      return true;

   const int mid = count / 2;
   const double median = (count % 2 == 1) ? spreads[mid] : (spreads[mid - 1] + spreads[mid]) * 0.5;
   const double current_spread_points = (ask - bid) / point;
   return (median <= 0.0 || current_spread_points <= strategy_spread_median_mult * median);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double k_sig = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double close_sig = iClose(_Symbol, _Period, 1);
   if(k_prev < 0.0 || k_sig < 0.0 || ema <= 0.0 || close_sig <= 0.0)
      return false;

   const bool buy_pop = (k_prev < strategy_stoch_upper && k_sig >= strategy_stoch_upper && k_sig > k_prev && close_sig > ema);
   const bool sell_pop = (k_prev > strategy_stoch_lower && k_sig <= strategy_stoch_lower && k_sig < k_prev && close_sig < ema);
   if(!buy_pop && !sell_pop)
      return false;

   req.type = buy_pop ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.reason = buy_pop ? "BERNSTEIN_STOCH_POP_LONG" : "BERNSTEIN_STOCH_POP_SHORT";
   if(entry <= 0.0 || req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 0);
   if(bar_time > 0 && bar_time == g_last_exit_eval_bar)
      return g_cached_exit_signal;
   if(bar_time > 0)
      g_last_exit_eval_bar = bar_time;
   g_cached_exit_signal = false;

   const int magic = QM_FrameworkMagic();
   bool have_buy = false;
   bool have_sell = false;
   bool time_stop = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_buy = have_buy || (ptype == POSITION_TYPE_BUY);
      have_sell = have_sell || (ptype == POSITION_TYPE_SELL);

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_max_hold_bars > 0 && open_time > 0 && TimeCurrent() - open_time >= strategy_max_hold_bars * PeriodSeconds(_Period))
         time_stop = true;
     }

   if(!have_buy && !have_sell)
      return false;
   if(time_stop)
     {
      g_cached_exit_signal = true;
      return true;
     }

   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double k_sig = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(k_prev < 0.0 || k_sig < 0.0)
      return false;

   const bool buy_deflated = (k_prev >= strategy_stoch_upper && k_sig < strategy_stoch_upper);
   const bool sell_deflated = (k_prev <= strategy_stoch_lower && k_sig > strategy_stoch_lower);
   g_cached_exit_signal = ((have_buy && buy_deflated) || (have_sell && sell_deflated));
   return g_cached_exit_signal;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to QM_NewsAllowsTrade(...); qm_news_mode defaults to PAUSE.
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
