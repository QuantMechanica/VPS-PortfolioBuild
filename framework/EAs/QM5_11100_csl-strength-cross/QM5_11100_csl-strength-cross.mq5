#property strict
#property version   "5.0"
#property description "QM5_11100 Currency Strength Lines cross"

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
input int    qm_ea_id                   = 11100;
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
enum Strategy_CSLMode
  {
   STRATEGY_CSL_ASI_TOT    = 0,
   STRATEGY_CSL_ASI_TOT_MA = 1
  };

input Strategy_CSLMode strategy_calculation_mode = STRATEGY_CSL_ASI_TOT;
input int    strategy_rsi_period                 = 14;
input int    strategy_smoothing_period           = 5;
input bool   strategy_opposite_zeros             = false;
input int    strategy_atr_period                 = 14;
input double strategy_atr_sl_mult                = 2.5;
input int    strategy_max_hold_h1_bars           = 24;

string g_csl_pairs[28] =
  {
   "AUDCAD.DWX", "AUDCHF.DWX", "AUDJPY.DWX", "AUDNZD.DWX", "AUDUSD.DWX",
   "CADCHF.DWX", "CADJPY.DWX", "CHFJPY.DWX", "EURAUD.DWX", "EURCAD.DWX",
   "EURCHF.DWX", "EURGBP.DWX", "EURJPY.DWX", "EURNZD.DWX", "EURUSD.DWX",
   "GBPAUD.DWX", "GBPCAD.DWX", "GBPCHF.DWX", "GBPJPY.DWX", "GBPNZD.DWX",
   "GBPUSD.DWX", "NZDCAD.DWX", "NZDCHF.DWX", "NZDJPY.DWX", "NZDUSD.DWX",
   "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX"
  };

// Cross signal for the last completed bar, refreshed once per new bar inside
// Strategy_EntrySignal (which OnTick gates behind QM_IsNewBar). The per-tick
// Strategy_ExitSignal reads this cache instead of re-running the 28-pair
// currency-strength scan on every tick — a per-tick multi-symbol recompute is
// the QM5_1044/1046 METATESTER_HUNG perf-wall class and must be avoided.
int g_csl_signal = 0;

string CSL_SymbolCore(const string symbol)
  {
   string core = symbol;
   const int len = StringLen(core);
   if(len > 4 && StringSubstr(core, len - 4, 4) == ".DWX")
      core = StringSubstr(core, 0, len - 4);
   return core;
  }

bool CSL_BaseQuote(string &base, string &quote)
  {
   const string core = CSL_SymbolCore(_Symbol);
   if(StringLen(core) < 6)
      return false;
   base = StringSubstr(core, 0, 3);
   quote = StringSubstr(core, 3, 3);
   return true;
  }

bool CSL_IsTargetSymbol()
  {
   const string core = CSL_SymbolCore(_Symbol);
   return (core == "EURUSD" || core == "GBPUSD" || core == "USDJPY" || core == "AUDUSD");
  }

bool CSL_DependenciesSynchronized(const ENUM_TIMEFRAMES tf, const int shift)
  {
   const datetime target_current = iTime(_Symbol, tf, 0); // perf-allowed: source-required cross-symbol closed-bar sync check.
   if(target_current <= 0)
      return false;

   for(int i = 0; i < 28; ++i)
     {
      if(!SymbolSelect(g_csl_pairs[i], true))
         return false;
      const datetime pair_current = iTime(g_csl_pairs[i], tf, 0); // perf-allowed: source-required cross-symbol closed-bar sync check.
      const datetime pair_signal = iTime(g_csl_pairs[i], tf, shift); // perf-allowed: source-required cross-symbol closed-bar sync check.
      if(pair_current != target_current || pair_signal <= 0)
         return false;
     }
   return true;
  }

bool CSL_Strength(const string currency,
                  const ENUM_TIMEFRAMES tf,
                  const int shift,
                  double &strength)
  {
   strength = 0.0;
   if(strategy_rsi_period < 2 || shift < 1)
      return false;

   int smooth_count = 1;
   if(strategy_calculation_mode == STRATEGY_CSL_ASI_TOT_MA)
      smooth_count = (strategy_smoothing_period > 1) ? strategy_smoothing_period : 1;
   double total = 0.0;

   for(int i = 0; i < 28; ++i)
     {
      const string pair = g_csl_pairs[i];
      const int pos = StringFind(pair, currency, 0);
      if(pos < 0)
         continue;

      double rsi_sum = 0.0;
      for(int h = 0; h < smooth_count; ++h)
        {
         const double rsi = QM_RSI(pair, tf, strategy_rsi_period, shift + h);
         if(rsi <= 0.0 || rsi >= 100.0)
            return false;
         rsi_sum += rsi;
        }

      const double value = rsi_sum / smooth_count;
      if(pos == 0)
         total += (value - 50.0) / 7.0;
      else
         total += ((100.0 - value) - 50.0) / 7.0;
     }

   strength = NormalizeDouble(total, 4);
   return true;
  }

int CSL_CrossSignal(const int shift)
  {
   string base = "";
   string quote = "";
   if(!CSL_BaseQuote(base, quote))
      return 0;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   if(!CSL_DependenciesSynchronized(tf, shift + 1))
      return 0;

   double base_curr = 0.0;
   double quote_curr = 0.0;
   double base_prev = 0.0;
   double quote_prev = 0.0;
   if(!CSL_Strength(base, tf, shift, base_curr) ||
      !CSL_Strength(quote, tf, shift, quote_curr) ||
      !CSL_Strength(base, tf, shift + 1, base_prev) ||
      !CSL_Strength(quote, tf, shift + 1, quote_prev))
      return 0;

   if(strategy_opposite_zeros)
     {
      if(base_curr > 0.0 && quote_curr < 0.0 && (quote_prev > 0.0 || base_prev < 0.0))
         return +1;
      if(base_curr < 0.0 && quote_curr > 0.0 && (quote_prev < 0.0 || base_prev > 0.0))
         return -1;
      return 0;
     }

   if(base_prev < quote_prev && base_curr > quote_curr)
      return +1;
   if(base_prev > quote_prev && base_curr < quote_curr)
      return -1;
   return 0;
  }

bool CSL_SelectOurPosition(ENUM_POSITION_TYPE &position_type,
                           datetime &open_time)
  {
   position_type = POSITION_TYPE_BUY;
   open_time = 0;
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return !CSL_IsTargetSymbol();
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

   // Refresh the per-bar cache here (OnTick only reaches this on a new bar).
   g_csl_signal = CSL_CrossSignal(1);
   const int signal = g_csl_signal;
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (signal > 0) ? "CSL_STRENGTH_CROSS_LONG" : "CSL_STRENGTH_CROSS_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!CSL_SelectOurPosition(position_type, open_time))
      return false;

   if(strategy_max_hold_h1_bars > 0 && open_time > 0)
     {
      const int hold_seconds = strategy_max_hold_h1_bars * 3600;
      if(TimeCurrent() - open_time >= hold_seconds)
         return true;
     }

   // Read the per-bar cache; never re-run the 28-pair scan on the per-tick path.
   const int signal = g_csl_signal;
   if(position_type == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && signal > 0)
      return true;
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

   // Basket EA: the strategy reads RSI across the full 28-pair major-currency
   // universe to build each currency's strength line. Register the basket so
   // foreign-symbol reads are guard-allowed (no SYMBOL_GUARD_VIOLATION spam),
   // and force the strategy tester to load each pair's history. FW9: in the
   // tester SymbolSelect alone does NOT load history — CopyClose does, which is
   // exactly what QM_BasketWarmupHistory performs. Without this the per-bar
   // cross-symbol sync check never passes and the EA generates zero trades.
   QM_SymbolGuardInit(g_csl_pairs);
   QM_BasketWarmupHistory(g_csl_pairs, (ENUM_TIMEFRAMES)_Period, 300);

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
