#property strict
#property version   "5.0"
#property description "QM5_12529 Chan Top-N Cross-Sectional Mean Reversion"

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
input int    qm_ea_id                   = 12529;
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
input int    strategy_num_positions       = 3;
input double strategy_min_abs_weight      = 0.05;
input int    strategy_return_lookback_d1  = 1;
input int    strategy_min_active_symbols  = 5;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_spread_median_days  = 60;
input double strategy_spread_mult         = 2.0;

string g_basket_symbols[8] = {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "XAUUSD.DWX"
};
int g_basket_slots[8] = {0, 1, 2, 3, 4, 5, 6, 7};

bool   g_signal_ready = false;
bool   g_signal_selected[8];
int    g_signal_dir[8];
double g_signal_weight[8];

int Strategy_BasketSize()
  {
   return ArraySize(g_basket_symbols);
  }

int Strategy_CurrentSymbolIndex()
  {
   const int n = Strategy_BasketSize();
   for(int i = 0; i < n; ++i)
     {
      if(g_basket_symbols[i] == _Symbol)
         return i;
     }
   return -1;
  }

bool Strategy_HasOpenPosition()
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

void Strategy_ResetSignals()
  {
   const int n = Strategy_BasketSize();
   for(int i = 0; i < n; ++i)
     {
      g_signal_selected[i] = false;
      g_signal_dir[i] = 0;
      g_signal_weight[i] = 0.0;
     }
   g_signal_ready = false;
  }

bool Strategy_ReadD1Return(const string sym,
                           const int lookback,
                           double &out_return)
  {
   out_return = 0.0;
   if(lookback <= 0)
      return false;
   if(!QM_SymbolAssertOrLog(sym))
      return false;

   const double close_recent = iClose(sym, PERIOD_D1, 1); // perf-allowed: bounded cross-symbol D1 close read.
   const double close_prior = iClose(sym, PERIOD_D1, 1 + lookback); // perf-allowed: bounded cross-symbol D1 close read.
   if(close_recent <= 0.0 || close_prior <= 0.0)
      return false;

   out_return = (close_recent / close_prior) - 1.0;
   return true;
  }

bool Strategy_CurrentSpreadBlocked()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_mult <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(!(ask > bid))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int got = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, rates); // perf-allowed: runs only inside Strategy_EntrySignal after the framework new-bar gate.
   if(got <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, got);
   int spread_count = 0;
   for(int i = 0; i < got; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[spread_count] = (double)rates[i].spread;
         ++spread_count;
        }
     }
   if(spread_count <= 0)
      return false;

   for(int i = 0; i < spread_count - 1; ++i)
     {
      for(int j = i + 1; j < spread_count; ++j)
        {
         if(spreads[j] < spreads[i])
           {
            const double tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }
        }
     }

   double median_spread = spreads[spread_count / 2];
   if((spread_count % 2) == 0 && spread_count > 1)
      median_spread = 0.5 * (spreads[(spread_count / 2) - 1] + spreads[spread_count / 2]);
   if(median_spread <= 0.0)
      return false;

   const double current_spread_points = (ask - bid) / point;
   return (current_spread_points > strategy_spread_mult * median_spread);
  }

bool Strategy_RecomputeSignals()
  {
   Strategy_ResetSignals();

   const int n = Strategy_BasketSize();
   double returns[8];
   double scores[8];
   bool active[8];
   bool picked[8];

   int active_count = 0;
   double return_sum = 0.0;
   const int lookback = MathMax(1, strategy_return_lookback_d1);
   for(int i = 0; i < n; ++i)
     {
      returns[i] = 0.0;
      scores[i] = 0.0;
      active[i] = false;
      picked[i] = false;

      double r = 0.0;
      if(!Strategy_ReadD1Return(g_basket_symbols[i], lookback, r))
         continue;

      returns[i] = r;
      active[i] = true;
      return_sum += r;
      ++active_count;
     }

   if(active_count < MathMax(1, strategy_min_active_symbols))
      return false;

   const double basket_mean = return_sum / (double)active_count;
   for(int i = 0; i < n; ++i)
     {
      if(active[i])
         scores[i] = -(returns[i] - basket_mean);
     }

   int picks = strategy_num_positions;
   if(picks < 1)
      picks = 1;
   if(picks > active_count)
      picks = active_count;

   double denom = 0.0;
   for(int rank = 0; rank < picks; ++rank)
     {
      int best_idx = -1;
      double best_abs = -1.0;
      for(int i = 0; i < n; ++i)
        {
         if(!active[i] || picked[i])
            continue;
         const double score_abs = MathAbs(scores[i]);
         if(score_abs > best_abs)
           {
            best_abs = score_abs;
            best_idx = i;
           }
        }
      if(best_idx < 0)
         break;
      picked[best_idx] = true;
      denom += MathAbs(scores[best_idx]);
     }

   g_signal_ready = true;
   if(denom <= 0.0)
      return true;

   for(int i = 0; i < n; ++i)
     {
      if(!picked[i])
         continue;
      g_signal_selected[i] = true;
      g_signal_weight[i] = scores[i] / denom;
      if(g_signal_weight[i] > 0.0)
         g_signal_dir[i] = 1;
      else if(g_signal_weight[i] < 0.0)
         g_signal_dir[i] = -1;
     }

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
   if(!Strategy_RecomputeSignals())
      return false;
   if(Strategy_CurrentSpreadBlocked())
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;
   if(!g_signal_selected[idx])
      return false;
   if(MathAbs(g_signal_weight[idx]) <= strategy_min_abs_weight)
      return false;

   QM_OrderType side = QM_BUY;
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(g_signal_weight[idx] < 0.0)
     {
      side = QM_SELL;
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = StringFormat("xsec_topn_d1_weight_%.4f", g_signal_weight[idx]);
   req.symbol_slot = g_basket_slots[idx];
   req.expiration_seconds = 0;
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
   if(!g_signal_ready)
      return false;

   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
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

      if(!g_signal_selected[idx])
         return true;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_signal_weight[idx] <= 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_signal_weight[idx] >= 0.0)
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

   QM_SymbolGuardInit(g_basket_symbols);
   QM_BasketWarmupHistory(g_basket_symbols, PERIOD_D1, 300);

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
