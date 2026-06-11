#property strict
#property version   "5.0"
#property description "QM5_11459 Blade MACD Stochastic Divergence H1"

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
input int    qm_ea_id                   = 11459;
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
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_stoch_k           = 9;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input int    strategy_div_lookback      = 20;
input int    strategy_signal_window     = 2;
input double strategy_stoch_overbought  = 80.0;
input double strategy_stoch_oversold    = 20.0;
input bool   strategy_confirm_candle    = true;
input int    strategy_atr_period        = 14;
input double strategy_atr_tp_mult       = 2.0;
input int    strategy_sl_buffer_pips    = 5;
input int    strategy_max_sl_pips       = 80;
input int    strategy_spread_cap_pips   = 20;

double BarOpen(const int shift)  { return iOpen(_Symbol, PERIOD_CURRENT, shift); }  // perf-allowed
double BarHigh(const int shift)  { return iHigh(_Symbol, PERIOD_CURRENT, shift); }  // perf-allowed
double BarLow(const int shift)   { return iLow(_Symbol, PERIOD_CURRENT, shift); }   // perf-allowed
double BarClose(const int shift) { return iClose(_Symbol, PERIOD_CURRENT, shift); } // perf-allowed

double MacdHist(const int shift)
  {
   return QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                       strategy_macd_fast,
                       strategy_macd_slow,
                       strategy_macd_signal,
                       shift)
          - QM_MACD_Signal(_Symbol, PERIOD_CURRENT,
                           strategy_macd_fast,
                           strategy_macd_slow,
                           strategy_macd_signal,
                           shift);
  }

bool IsLocalMacdPeak(const int shift)
  {
   const double h = MacdHist(shift);
   return (h > MacdHist(shift + 1) && h > MacdHist(shift - 1));
  }

bool IsLocalMacdTrough(const int shift)
  {
   const double h = MacdHist(shift);
   return (h < MacdHist(shift + 1) && h < MacdHist(shift - 1));
  }

bool FindPriorMacdPeak(int &peak_shift, double &peak_value)
  {
   peak_shift = -1;
   peak_value = 0.0;
   int max_shift = strategy_div_lookback;
   if(max_shift < 3)
      max_shift = 3;
   for(int shift = 2; shift <= max_shift; ++shift)
     {
      if(IsLocalMacdPeak(shift))
        {
         peak_shift = shift;
         peak_value = MacdHist(shift);
         return true;
        }
     }
   return false;
  }

bool FindPriorMacdTrough(int &trough_shift, double &trough_value)
  {
   trough_shift = -1;
   trough_value = 0.0;
   int max_shift = strategy_div_lookback;
   if(max_shift < 3)
      max_shift = 3;
   for(int shift = 2; shift <= max_shift; ++shift)
     {
      if(IsLocalMacdTrough(shift))
        {
         trough_shift = shift;
         trough_value = MacdHist(shift);
         return true;
        }
     }
   return false;
  }

bool StochExitedOverbought(int &exit_shift)
  {
   exit_shift = -1;
   int max_shift = strategy_signal_window;
   if(max_shift < 1)
      max_shift = 1;
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const double prev_k = QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                                       strategy_stoch_k,
                                       strategy_stoch_d,
                                       strategy_stoch_slowing,
                                       shift + 1);
      const double curr_k = QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                                       strategy_stoch_k,
                                       strategy_stoch_d,
                                       strategy_stoch_slowing,
                                       shift);
      if(prev_k > strategy_stoch_overbought && curr_k < strategy_stoch_overbought)
        {
         exit_shift = shift;
         return true;
        }
     }
   return false;
  }

bool StochExitedOversold(int &exit_shift)
  {
   exit_shift = -1;
   int max_shift = strategy_signal_window;
   if(max_shift < 1)
      max_shift = 1;
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const double prev_k = QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                                       strategy_stoch_k,
                                       strategy_stoch_d,
                                       strategy_stoch_slowing,
                                       shift + 1);
      const double curr_k = QM_Stoch_K(_Symbol, PERIOD_CURRENT,
                                       strategy_stoch_k,
                                       strategy_stoch_d,
                                       strategy_stoch_slowing,
                                       shift);
      if(prev_k < strategy_stoch_oversold && curr_k > strategy_stoch_oversold)
        {
         exit_shift = shift;
         return true;
        }
     }
   return false;
  }

bool BearishDivergence()
  {
   if(!IsLocalMacdPeak(1))
      return false;

   int peak_shift = -1;
   double peak_value = 0.0;
   if(!FindPriorMacdPeak(peak_shift, peak_value))
      return false;

   const double current_peak = MacdHist(1);
   return (current_peak < peak_value && BarHigh(1) > BarHigh(peak_shift));
  }

bool BullishDivergence()
  {
   if(!IsLocalMacdTrough(1))
      return false;

   int trough_shift = -1;
   double trough_value = 0.0;
   if(!FindPriorMacdTrough(trough_shift, trough_value))
      return false;

   const double current_trough = MacdHist(1);
   return (current_trough > trough_value && BarLow(1) < BarLow(trough_shift));
  }

bool GetOurPositionType(ENUM_POSITION_TYPE &ptype)
  {
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool BuildMarketRequest(const QM_OrderType side, const string reason, QM_EntryRequest &req)
  {
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double max_sl = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_sl_pips);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || buffer <= 0.0 || max_sl <= 0.0 || point <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
     {
      sl = BarLow(1) - buffer;
      const double capped = entry - max_sl;
      if(sl < capped)
         sl = capped;
      if(sl >= entry)
         sl = entry - buffer;
     }
   else
     {
      sl = BarHigh(1) + buffer;
      const double capped = entry + max_sl;
      if(sl > capped)
         sl = capped;
      if(sl <= entry)
         sl = entry + buffer;
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   const double tp = QM_TakeATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_tp_mult);
   if(tp <= 0.0 || MathAbs(entry - sl) / point <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return true;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return true;

   const double spread_pips = (tick.ask - tick.bid) / pip;
   return (spread_pips > strategy_spread_cap_pips);
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

   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_div_lookback < 3)
      return false;

   int stoch_shift = -1;
   if(BearishDivergence() && StochExitedOverbought(stoch_shift) &&
      MathAbs(stoch_shift - 1) <= strategy_signal_window)
     {
      if(strategy_confirm_candle && BarClose(1) >= BarOpen(1))
         return false;
      return BuildMarketRequest(QM_SELL, "MACD_STOCH_BEAR_DIV", req);
     }

   if(BullishDivergence() && StochExitedOversold(stoch_shift) &&
      MathAbs(stoch_shift - 1) <= strategy_signal_window)
     {
      if(strategy_confirm_candle && BarClose(1) <= BarOpen(1))
         return false;
      return BuildMarketRequest(QM_BUY, "MACD_STOCH_BULL_DIV", req);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial close, or pyramiding rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!GetOurPositionType(ptype))
      return false;

   const double hist1 = MacdHist(1);
   const double hist2 = MacdHist(2);
   if(ptype == POSITION_TYPE_BUY)
      return (hist1 < hist2);
   if(ptype == POSITION_TYPE_SELL)
      return (hist1 > hist2);

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
