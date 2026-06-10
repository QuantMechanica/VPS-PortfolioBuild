#property strict
#property version   "5.0"
#property description "QM5_10168 RSI Divergence Reversal"

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
input int    qm_ea_id                   = 10168;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
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
input int    strategy_rsi_period        = 14;
input int    strategy_pivot_order       = 5;
input int    strategy_pivot_count_k     = 2;
input double strategy_centerline        = 50.0;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 1.0;
input int    strategy_warmup_bars       = 60;
input int    strategy_pivot_scan_bars   = 60;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_rsi_period <= 1 ||
      strategy_pivot_order < 1 ||
      strategy_pivot_count_k < 2 ||
      strategy_pivot_count_k > 8 ||
      strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_warmup_bars < 1 ||
      strategy_pivot_scan_bars < strategy_pivot_order * 2 + strategy_pivot_count_k)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const ENUM_TIMEFRAMES tf = PERIOD_D1;
   const int bars_required = MathMax(strategy_warmup_bars,
                                     strategy_pivot_scan_bars + strategy_pivot_order * 2 + 5);
   if(Bars(_Symbol, tf) < bars_required) // perf-allowed: warmup guard, runs once per D1 bar
      return false;

   double pivot_lows[8];
   double pivot_low_rsi[8];
   double pivot_highs[8];
   double pivot_high_rsi[8];
   ArrayInitialize(pivot_lows, 0.0);
   ArrayInitialize(pivot_low_rsi, 0.0);
   ArrayInitialize(pivot_highs, 0.0);
   ArrayInitialize(pivot_high_rsi, 0.0);

   int lows_found = 0;
   int highs_found = 0;
   const int first_shift = strategy_pivot_order + 1;
   const int last_shift = first_shift + strategy_pivot_scan_bars - 1;

   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      const double center_low = iLow(_Symbol, tf, shift); // perf-allowed: bespoke pivot scan, gated by QM_IsNewBar
      const double center_high = iHigh(_Symbol, tf, shift); // perf-allowed: bespoke pivot scan, gated by QM_IsNewBar
      if(center_low <= 0.0 || center_high <= 0.0)
         continue;

      bool is_low_pivot = true;
      bool is_high_pivot = true;
      for(int offset = 1; offset <= strategy_pivot_order; ++offset)
        {
         if(center_low >= iLow(_Symbol, tf, shift - offset) || // perf-allowed: pivot neighborhood check, gated by QM_IsNewBar
            center_low >= iLow(_Symbol, tf, shift + offset)) // perf-allowed: pivot neighborhood check, gated by QM_IsNewBar
            is_low_pivot = false;
         if(center_high <= iHigh(_Symbol, tf, shift - offset) || // perf-allowed: pivot neighborhood check, gated by QM_IsNewBar
            center_high <= iHigh(_Symbol, tf, shift + offset)) // perf-allowed: pivot neighborhood check, gated by QM_IsNewBar
            is_high_pivot = false;
        }

      if(is_low_pivot && lows_found < strategy_pivot_count_k)
        {
         const double rsi_at_pivot = QM_RSI(_Symbol, tf, strategy_rsi_period, shift);
         if(rsi_at_pivot > 0.0)
           {
            pivot_lows[lows_found] = center_low;
            pivot_low_rsi[lows_found] = rsi_at_pivot;
            lows_found++;
           }
        }

      if(is_high_pivot && highs_found < strategy_pivot_count_k)
        {
         const double rsi_at_pivot = QM_RSI(_Symbol, tf, strategy_rsi_period, shift);
         if(rsi_at_pivot > 0.0)
           {
            pivot_highs[highs_found] = center_high;
            pivot_high_rsi[highs_found] = rsi_at_pivot;
            highs_found++;
           }
        }

      if(lows_found >= strategy_pivot_count_k && highs_found >= strategy_pivot_count_k)
         break;
     }

   bool bullish_divergence = (lows_found >= strategy_pivot_count_k &&
                              pivot_low_rsi[0] < strategy_centerline);
   for(int i = 0; bullish_divergence && i < strategy_pivot_count_k - 1; ++i)
     {
      if(!(pivot_lows[i] < pivot_lows[i + 1] &&
           pivot_low_rsi[i] > pivot_low_rsi[i + 1]))
         bullish_divergence = false;
     }

   if(bullish_divergence)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
      if(ask <= 0.0 || atr <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = NormalizeDouble(pivot_lows[0] - strategy_atr_stop_mult * atr, _Digits);
      req.reason = StringFormat("RSI_DIV_LONG_%.2f", pivot_low_rsi[0]);
      return (req.sl > 0.0 && req.sl < ask);
     }

   bool bearish_divergence = (highs_found >= strategy_pivot_count_k &&
                              pivot_high_rsi[0] > strategy_centerline);
   for(int i = 0; bearish_divergence && i < strategy_pivot_count_k - 1; ++i)
     {
      if(!(pivot_highs[i] > pivot_highs[i + 1] &&
           pivot_high_rsi[i] < pivot_high_rsi[i + 1]))
         bearish_divergence = false;
     }

   if(bearish_divergence)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
      if(bid <= 0.0 || atr <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = NormalizeDouble(pivot_highs[0] + strategy_atr_stop_mult * atr, _Digits);
      req.reason = StringFormat("RSI_DIV_SHORT_%.2f", pivot_high_rsi[0]);
      return (req.sl > bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies only initial ATR stop and RSI-based discretionary exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_rsi_period <= 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const string comment = PositionGetString(POSITION_COMMENT);
      const int marker = StringFind(comment, "_", 8);
      double entry_rsi = 0.0;
      if(marker >= 0)
         entry_rsi = StringToDouble(StringSubstr(comment, marker + 1));

      if(ptype == POSITION_TYPE_BUY)
        {
         if(rsi_now >= strategy_centerline && rsi_prev < strategy_centerline)
            return true;
         if(entry_rsi > 0.0 && rsi_now < strategy_centerline && rsi_now < entry_rsi)
            return true;
        }

      if(ptype == POSITION_TYPE_SELL)
        {
         if(rsi_now <= strategy_centerline && rsi_prev > strategy_centerline)
            return true;
         if(entry_rsi > 0.0 && rsi_now > strategy_centerline && rsi_now > entry_rsi)
            return true;
        }
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
