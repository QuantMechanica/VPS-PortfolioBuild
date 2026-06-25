#property strict
#property version   "5.0"
#property description "QM5_1081 Chan Lo 1-Day Cross-Sectional Reversal"
// v3 2026-06-25 — rebuild from Strategy Card on QM_* readers only (no raw
//   iClose/CopyBuffer for the rank universe): foreign-symbol 1-day returns are
//   read via QM_SMA(sym,D1,1,shift) (period-1 SMA == that bar's close). Keeps
//   the proven basket-warmup wiring (QM_SymbolGuardInit + QM_BasketWarmupHistory,
//   same pattern as QM5_10717/10718) so the tester syncs each universe symbol's
//   D1 history before it is ranked. NoTradeFilter gates _Period != D1.

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
input int    qm_ea_id                   = 1081;
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
// Chan (2007) cross-sectional 1-day reversal. Each EA instance trades ONE
// symbol (_Symbol) but ranks it against a FIXED cross-sectional universe by
// prior 1-day close-to-close return. Long the worst-N performers, short the
// best-N, exit at the next daily close (hold strategy_max_hold_bars closed D1
// bars; the framework re-ranks and re-enters into the new set each day).
//   strategy_universe_symbols  — comma list of DWX symbols forming the rank set.
//   strategy_rank_count        — N: go long the worst N, short the best N.
//   strategy_max_hold_bars     — exit after this many closed D1 bars (1 = next close).
//   strategy_atr_period        — ATR period for the protective per-leg stop.
//   strategy_atr_sl_mult       — ATR multiple for the protective stop.
//   strategy_max_spread_points — O(1) liquidity/spread guard.
//   strategy_use_atr_regime_filter / lookback / percentile — optional card filter:
//     skip entries when the universe-average ATR percentile exceeds the threshold.
input string strategy_universe_symbols  = "SP500.DWX,NDX.DWX,WS30.DWX,GDAXI.DWX,XAUUSD.DWX,XAGUSD.DWX,EURUSD.DWX,GBPUSD.DWX,USDJPY.DWX,AUDUSD.DWX,USDCAD.DWX,USDCHF.DWX,NZDUSD.DWX,UK100.DWX";
input int    strategy_rank_count        = 1;
input int    strategy_max_hold_bars     = 1;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_max_spread_points = 300;
input bool   strategy_use_atr_regime_filter = false;
input int    strategy_regime_lookback   = 100;
input double strategy_regime_percentile = 90.0;

string TrimToken(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

// Parsed universe basket (built once in OnInit) used to register the symbol
// guard and force the MT5 tester to sync each foreign symbol's D1 history.
// Without the warmup the per-symbol QM_* reads return 0/stale in the tester and
// the EA never trades (same failure class fixed for QM5_10717 / QM5_10718).
string g_universe_basket[];
int    g_universe_basket_count = 0;
bool   g_rebalance_bar_active = false;
int    g_open_hold_bars = 0;

void QM5_1081_BuildUniverseBasket()
  {
   string symbols[];
   const int count = StringSplit(strategy_universe_symbols, ',', symbols);
   g_universe_basket_count = 0;
   ArrayResize(g_universe_basket, MathMax(count, 0));
   for(int i = 0; i < count; ++i)
     {
      const string candidate = TrimToken(symbols[i]);
      if(candidate == "")
         continue;
      g_universe_basket[g_universe_basket_count] = candidate;
      g_universe_basket_count++;
     }
   ArrayResize(g_universe_basket, g_universe_basket_count);
  }

// 1-day close-to-close return for `symbol` on the last closed D1 bar.
// QM_SMA(period=1) returns that bar's close — a QM_* reader, never raw iClose.
bool GetD1Return(const string symbol, double &ret)
  {
   ret = 0.0;
   const double close_last = QM_SMA(symbol, PERIOD_D1, 1, 1, PRICE_CLOSE); // shift 1 = last closed bar
   const double close_prev = QM_SMA(symbol, PERIOD_D1, 1, 2, PRICE_CLOSE); // shift 2 = prior closed bar
   if(close_last <= 0.0 || close_prev <= 0.0)
      return false;
   ret = (close_last / close_prev) - 1.0;
   return true;
  }

// Rank _Symbol within the configured universe by prior 1-day return.
//   worse_count  = universe symbols with a strictly lower 1-day return
//   better_count = universe symbols with a strictly higher 1-day return
//   valid_count  = universe symbols whose returns are readable this bar
// Returns true only when _Symbol itself is in the universe and >= 2 symbols
// have valid returns (otherwise no cross-section exists -> stand aside).
bool GetCurrentSymbolRank(double &own_return,
                          int &valid_count,
                          int &worse_count,
                          int &better_count)
  {
   own_return = 0.0;
   valid_count = 0;
   worse_count = 0;
   better_count = 0;

   if(!GetD1Return(_Symbol, own_return))
      return false;

   bool symbol_listed = false;
   for(int i = 0; i < g_universe_basket_count; ++i)
     {
      const string candidate = g_universe_basket[i];
      if(candidate == "")
         continue;

      double candidate_return = 0.0;
      if(!GetD1Return(candidate, candidate_return))
         continue;

      valid_count++;
      if(candidate == _Symbol)
        {
         symbol_listed = true;
         continue; // never compare the symbol against itself
        }
      // Deterministic tie-break by symbol name so bottom/top sets are stable.
      if(candidate_return < own_return ||
         (candidate_return == own_return && candidate < _Symbol))
         worse_count++;
      else
         better_count++;
     }

   return (symbol_listed && valid_count >= 2);
  }

// Optional card filter: skip entries when the universe-average ATR percentile
// over `strategy_regime_lookback` closed bars exceeds `strategy_regime_percentile`.
bool AtrRegimeBlocked()
  {
   if(!strategy_use_atr_regime_filter)
      return false;
   if(strategy_regime_lookback < 20 || strategy_regime_percentile <= 0.0)
      return false;

   double current_sum = 0.0;
   int current_samples = 0;
   for(int i = 0; i < g_universe_basket_count; ++i)
     {
      const string candidate = g_universe_basket[i];
      if(candidate == "")
         continue;
      const double atr = QM_ATR(candidate, PERIOD_D1, strategy_atr_period, 1);
      if(atr > 0.0)
        {
         current_sum += atr;
         current_samples++;
        }
     }
   if(current_samples <= 0)
      return false;

   const double current_avg = current_sum / current_samples;
   int below_or_equal = 0;
   int history_samples = 0;
   for(int shift = 2; shift <= strategy_regime_lookback + 1; ++shift)
     {
      double hist_sum = 0.0;
      int hist_count = 0;
      for(int i = 0; i < g_universe_basket_count; ++i)
        {
         const string candidate = g_universe_basket[i];
         if(candidate == "")
            continue;
         const double atr = QM_ATR(candidate, PERIOD_D1, strategy_atr_period, shift);
         if(atr > 0.0)
           {
            hist_sum += atr;
            hist_count++;
           }
        }
      if(hist_count <= 0)
         continue;

      history_samples++;
      if((hist_sum / hist_count) <= current_avg)
         below_or_equal++;
     }

   if(history_samples <= 0)
      return false;
   const double percentile = 100.0 * (double)below_or_equal / (double)history_samples;
   return (percentile > strategy_regime_percentile);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }
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

   if(strategy_rank_count < 1 ||
      strategy_max_hold_bars < 1 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   if(AtrRegimeBlocked())
      return false;

   double own_return = 0.0;
   int valid_count = 0;
   int worse_count = 0;
   int better_count = 0;
   if(!GetCurrentSymbolRank(own_return, valid_count, worse_count, better_count))
      return false;

   // Cap N so the two legs never overlap on a small/partially-warmed universe.
   const int effective_n = MathMin(strategy_rank_count, valid_count / 2);
   if(effective_n < 1)
      return false;

   const bool is_worst_bucket = (worse_count < effective_n);   // among worst N -> long losers
   const bool is_best_bucket  = (better_count < effective_n);  // among best  N -> short winners
   if(is_worst_bucket == is_best_bucket)
      return false; // neither bucket, or (degenerate) both -> no trade

   req.type = is_worst_bucket ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = is_worst_bucket ? "CHAN_LO_1D_LONG_WORST" : "CHAN_LO_1D_SHORT_BEST";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
// Chan exit: close at the NEXT daily close. OnTick calls this only after the
// framework D1 new-bar gate, so each held leg is closed once per rebalance bar
// before the new rank set is entered.
bool Strategy_ExitSignal()
  {
   if(!g_rebalance_bar_active)
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      g_open_hold_bars++;
      return (g_open_hold_bars >= strategy_max_hold_bars);
     }

   g_open_hold_bars = 0;
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

   // Register the cross-sectional basket and force the tester to load each
   // symbol's D1 history before the rank reads it. Same pattern as the
   // reference basket EAs (QM5_10717 / QM5_10718).
   QM5_1081_BuildUniverseBasket();
   if(g_universe_basket_count > 0)
     {
      QM_SymbolGuardInit(g_universe_basket);
      QM_BasketWarmupHistory(g_universe_basket, PERIOD_D1, 300);
     }

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

   // Per-closed-D1-bar: rebalance, close old legs, then enter the new rank set.
   // Exit and entry share this single QM_IsNewBar call.
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   g_rebalance_bar_active = true;
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
   g_rebalance_bar_active = false;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         g_open_hold_bars = 0;
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
