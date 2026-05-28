#property strict
#property version   "5.0"
#property description "QM5_10350 Elite Trader SP ADX 15-Bar Breakout"

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
input int    qm_ea_id                   = 10350;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_M30;
input int    strategy_adx_period        = 14;
input double strategy_adx_max           = 25.0;
input int    strategy_entry_channel     = 15;
input int    strategy_exit_channel      = 5;
input int    strategy_atr_period        = 14;
input double strategy_max_stop_atr_mult = 3.0;
input double strategy_min_stop_spreads  = 4.0;
input double strategy_max_spread_mult   = 2.5;
input int    strategy_spread_window     = 31;
input int    strategy_session_start_h   = 1;
input int    strategy_session_end_h     = 23;

double g_spread_window[31];
int    g_spread_count = 0;
int    g_spread_next = 0;

double HighestHigh(const int start_shift, const int bars)
  {
   if(start_shift < 1 || bars < 1)
      return 0.0;

   double value = -DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double high = iHigh(_Symbol, strategy_tf, i);
      if(high <= 0.0)
         return 0.0;
      value = MathMax(value, high);
     }
   return value;
  }

double LowestLow(const int start_shift, const int bars)
  {
   if(start_shift < 1 || bars < 1)
      return 0.0;

   double value = DBL_MAX;
   for(int i = start_shift; i < start_shift + bars; ++i)
     {
      const double low = iLow(_Symbol, strategy_tf, i);
      if(low <= 0.0)
         return 0.0;
      value = MathMin(value, low);
     }
   return value;
  }

double CurrentSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return 0.0;
   return ask - bid;
  }

void RecordSpread(const double spread)
  {
   if(spread <= 0.0)
      return;

   int max_window = strategy_spread_window;
   if(max_window > 31)
      max_window = 31;
   if(max_window < 3)
      return;

   g_spread_window[g_spread_next] = spread;
   g_spread_next = (g_spread_next + 1) % max_window;
   if(g_spread_count < max_window)
      g_spread_count++;
  }

double MedianSpread()
  {
   if(g_spread_count <= 0)
      return 0.0;

   double sorted[31];
   for(int i = 0; i < g_spread_count; ++i)
      sorted[i] = g_spread_window[i];

   for(int i = 1; i < g_spread_count; ++i)
     {
      const double key = sorted[i];
      int j = i - 1;
      while(j >= 0 && sorted[j] > key)
        {
         sorted[j + 1] = sorted[j];
         j--;
        }
      sorted[j + 1] = key;
     }

   const int mid = g_spread_count / 2;
   if((g_spread_count % 2) == 1)
      return sorted[mid];
   return 0.5 * (sorted[mid - 1] + sorted[mid]);
  }

bool HasOurPosition()
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
      return true;
     }
   return false;
  }

bool StopDistanceAllowed(const double entry_price, const double stop_price)
  {
   const double distance = MathAbs(entry_price - stop_price);
   const double spread = CurrentSpread();
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(distance <= 0.0 || spread <= 0.0 || atr <= 0.0)
      return false;
   if(distance < strategy_min_stop_spreads * spread)
      return false;
   if(distance > strategy_max_stop_atr_mult * atr)
      return false;
   return true;
  }

bool SpreadAllowed()
  {
   const double spread = CurrentSpread();
   if(spread <= 0.0)
      return false;
   if(g_spread_count < 3)
      return true;

   const double median = MedianSpread();
   if(median <= 0.0)
      return true;
   return (spread <= strategy_max_spread_mult * median);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(HasOurPosition())
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;
   if(dt.hour < strategy_session_start_h || dt.hour >= strategy_session_end_h)
      return true;
   if(dt.hour == strategy_session_start_h && dt.min < 30)
      return true;

   return false;
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

   RecordSpread(CurrentSpread());

   if(HasOurPosition())
      return false;
   if(strategy_entry_channel < 2 || strategy_exit_channel < 1 || strategy_adx_period < 1)
      return false;
   if(!SpreadAllowed())
      return false;

   const double adx = QM_ADX(_Symbol, strategy_tf, strategy_adx_period, 1);
   if(adx <= 0.0 || adx >= strategy_adx_max)
      return false;

   const double prev_high = iHigh(_Symbol, strategy_tf, 1);
   const double prev_low = iLow(_Symbol, strategy_tf, 1);
   const double entry_high = HighestHigh(2, strategy_entry_channel);
   const double entry_low = LowestLow(2, strategy_entry_channel);
   const double exit_low = LowestLow(1, strategy_exit_channel);
   const double exit_high = HighestHigh(1, strategy_exit_channel);
   if(prev_high <= 0.0 || prev_low <= 0.0 || entry_high <= 0.0 || entry_low <= 0.0 ||
      exit_low <= 0.0 || exit_high <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(prev_high > entry_high && StopDistanceAllowed(ask, exit_low))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exit_low);
      req.tp = 0.0;
      req.reason = "ET_SP_ADX15_LONG";
      return true;
     }

   if(prev_low < entry_low && StopDistanceAllowed(bid, exit_high))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exit_high);
      req.tp = 0.0;
      req.reason = "ET_SP_ADX15_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const double long_stop = LowestLow(1, strategy_exit_channel);
   const double short_stop = HighestHigh(1, strategy_exit_channel);
   if(long_stop <= 0.0 || short_stop <= 0.0)
      return;

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
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double target_sl = QM_TM_NormalizePrice(_Symbol, (type == POSITION_TYPE_BUY) ? long_stop : short_stop);
      if(type == POSITION_TYPE_BUY && target_sl > 0.0 &&
         (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
         QM_TM_MoveSL(ticket, target_sl, "ET_SP_ADX15_CHANNEL_STOP");
      if(type == POSITION_TYPE_SELL && target_sl > 0.0 &&
         (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
         QM_TM_MoveSL(ticket, target_sl, "ET_SP_ADX15_CHANNEL_STOP");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double long_exit = LowestLow(1, strategy_exit_channel);
   const double short_exit = HighestHigh(1, strategy_exit_channel);
   if(long_exit <= 0.0 || short_exit <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && bid <= long_exit)
         return true;
      if(type == POSITION_TYPE_SELL && ask >= short_exit)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
