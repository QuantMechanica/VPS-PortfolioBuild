#property strict
#property version   "5.0"
#property description "QM5_12362 Nikhil SuperTrend Flip"

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
input int    qm_ea_id                   = 12362;
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
input int    strategy_supertrend_atr_period = 10;
input double strategy_supertrend_multiplier = 3.0;
input int    strategy_stop_atr_period       = 14;
input double strategy_stop_atr_mult         = 2.0;
input int    strategy_warmup_bars           = 120;
input bool   strategy_atr_median_filter     = false;
input int    strategy_atr_median_lookback   = 120;

bool g_cached_entry_signal = false;
bool g_cached_exit_signal = false;

int StrategyWarmupBars()
  {
   int warmup = strategy_warmup_bars;
   const int min_warmup = strategy_supertrend_atr_period + 5;
   if(warmup < min_warmup)
      warmup = min_warmup;
   if(warmup < 20)
      warmup = 20;
   return warmup;
  }

double StrategyHigh(const int shift)
  {
   return iHigh(_Symbol, _Period, shift); // perf-allowed: bounded SuperTrend OHLC reconstruction on framework new-bar path.
  }

double StrategyLow(const int shift)
  {
   return iLow(_Symbol, _Period, shift); // perf-allowed: bounded SuperTrend OHLC reconstruction on framework new-bar path.
  }

double StrategyClose(const int shift)
  {
   return iClose(_Symbol, _Period, shift); // perf-allowed: bounded SuperTrend OHLC reconstruction on framework new-bar path.
  }

int StrategyBarsAvailable()
  {
   return Bars(_Symbol, _Period); // perf-allowed: warmup availability check only.
  }

bool StrategyHasOpenPosition()
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

bool StrategyHasOpenLongPosition()
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
      return ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
     }
   return false;
  }

bool StrategyAtrMedianAllowsEntry()
  {
   if(!strategy_atr_median_filter)
      return true;

   int lookback = strategy_atr_median_lookback;
   if(lookback < 5)
      lookback = 5;
   if(lookback > 500)
      lookback = 500;
   if(StrategyBarsAvailable() < lookback + 5)
      return false;

   double values[];
   ArrayResize(values, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_stop_atr_period, i + 1);
      if(atr <= 0.0)
         return false;
      values[i] = atr;
     }
   ArraySort(values);

   double median = values[lookback / 2];
   if((lookback % 2) == 0)
      median = 0.5 * (values[(lookback / 2) - 1] + values[lookback / 2]);

   const double atr_now = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_stop_atr_period, 1);
   return (atr_now >= median);
  }

bool StrategyComputeSuperTrendSignals(bool &entry_signal, bool &exit_signal)
  {
   entry_signal = false;
   exit_signal = false;

   const int period = strategy_supertrend_atr_period;
   const double mult = strategy_supertrend_multiplier;
   if(period < 2 || mult <= 0.0)
      return false;

   const int oldest_shift = StrategyWarmupBars();
   if(StrategyBarsAvailable() < oldest_shift + 3)
      return false;

   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   int prev_dir = 0;
   double st1 = 0.0;
   double st2 = 0.0;

   for(int shift = oldest_shift; shift >= 1; --shift)
     {
      const double high = StrategyHigh(shift);
      const double low = StrategyLow(shift);
      const double close = StrategyClose(shift);
      const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         return false;

      const double hl2 = 0.5 * (high + low);
      const double basic_upper = hl2 + (mult * atr);
      const double basic_lower = hl2 - (mult * atr);
      double final_upper = basic_upper;
      double final_lower = basic_lower;
      int dir = prev_dir;

      if(shift == oldest_shift)
        {
         dir = (close >= hl2) ? 1 : -1;
        }
      else
        {
         const double prev_close = StrategyClose(shift + 1);
         if(prev_close <= 0.0)
            return false;
         if(!(basic_upper < prev_final_upper || prev_close > prev_final_upper))
            final_upper = prev_final_upper;
         if(!(basic_lower > prev_final_lower || prev_close < prev_final_lower))
            final_lower = prev_final_lower;

         if(prev_dir < 0 && close > final_upper)
            dir = 1;
         else if(prev_dir > 0 && close < final_lower)
            dir = -1;
        }

      const double st = (dir > 0) ? final_lower : final_upper;
      if(shift == 2)
         st2 = st;
      if(shift == 1)
         st1 = st;

      prev_final_upper = final_upper;
      prev_final_lower = final_lower;
      prev_dir = dir;
     }

   const double close1 = StrategyClose(1);
   const double close2 = StrategyClose(2);
   if(close1 <= 0.0 || close2 <= 0.0 || st1 <= 0.0 || st2 <= 0.0)
      return false;

   entry_signal = (st2 > close2 && st1 < close1);
   exit_signal = (st2 < close2 && st1 > close1);
   return true;
  }

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

   bool entry_signal = false;
   bool exit_signal = false;
   if(!StrategyComputeSuperTrendSignals(entry_signal, exit_signal))
     {
      g_cached_entry_signal = false;
      g_cached_exit_signal = false;
      return false;
     }

   g_cached_entry_signal = entry_signal;
   g_cached_exit_signal = exit_signal;

   if(!g_cached_entry_signal)
      return false;
   if(!StrategyAtrMedianAllowsEntry())
      return false;
   if(StrategyHasOpenPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry_price = ask;
   if(entry_price <= 0.0)
      entry_price = bid;
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_stop_atr_period, strategy_stop_atr_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "supertrend_flip_long";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return (g_cached_exit_signal && StrategyHasOpenLongPosition());
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
