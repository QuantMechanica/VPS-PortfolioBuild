#property strict
#property version   "5.0"
#property description "QM5_12530 Chan Low-Vol Cross-Sectional Mean Reversion"

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
input int    qm_ea_id                   = 12530;
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
input int    strategy_return_lookback_d1 = 5;
input int    strategy_stddev_window_d1   = 5;
input int    strategy_top_divergence_n   = 3;
input int    strategy_low_vol_n          = 3;
input double strategy_min_abs_weight     = 0.05;
input int    strategy_min_active_symbols = 5;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_spread_median_days = 60;

#define STRATEGY_BASKET_COUNT 8

string g_strategy_symbols[STRATEGY_BASKET_COUNT] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "XAUUSD.DWX"
  };

bool   g_state_ready = false;
bool   g_symbol_selected = false;
double g_symbol_weight = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
      if(_Symbol == g_strategy_symbols[i])
         return i;
   return -1;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;
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
      return true;
     }

   return false;
  }

double Strategy_ReturnPct(const string symbol)
  {
   const int lookback = MathMax(1, strategy_return_lookback_d1);
   const double c0 = iClose(symbol, PERIOD_D1, 1);            // perf-allowed: fixed D1 basket return read, called only from framework QM_IsNewBar-gated EntrySignal.
   const double c1 = iClose(symbol, PERIOD_D1, 1 + lookback); // perf-allowed: fixed D1 basket return read, called only from framework QM_IsNewBar-gated EntrySignal.
   if(c0 <= 0.0 || c1 <= 0.0)
      return 0.0;
   return (c0 / c1) - 1.0;
  }

bool Strategy_FreshEnough(const string symbol, const datetime ref_time)
  {
   const datetime t = iTime(symbol, PERIOD_D1, 1); // perf-allowed: fixed D1 freshness check, called only from framework QM_IsNewBar-gated EntrySignal.
   if(t <= 0)
      return false;
   if(ref_time <= 0)
      return true;
   return (MathAbs((long)(ref_time - t)) <= 3L * 86400L);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_median_days <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask <= bid)
      return true;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, rates); // perf-allowed: bounded D1 spread sample, called only from framework QM_IsNewBar-gated EntrySignal.
   if(copied <= 0)
      return true;

   double spreads[];
   ArrayResize(spreads, copied);
   int used = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[used] = (double)rates[i].spread;
      ++used;
     }

   if(used <= 0)
      return true;

   ArrayResize(spreads, used);
   ArraySort(spreads);
   const double median = ((used % 2) == 1) ? spreads[used / 2]
                                           : 0.5 * (spreads[(used / 2) - 1] + spreads[used / 2]);
   if(median <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return true;
   const double current_points = (ask - bid) / point;
   return (current_points <= 2.0 * median);
  }

int Strategy_IntMax(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

int Strategy_IntMin(const int a, const int b)
  {
   return (a < b) ? a : b;
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_symbol_selected = false;
   g_symbol_weight = 0.0;

   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return false;

   const datetime ref_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: fixed D1 basket freshness anchor, called only from framework QM_IsNewBar-gated EntrySignal.
   double returns[STRATEGY_BASKET_COUNT];
   double stddevs[STRATEGY_BASKET_COUNT];
   double scores[STRATEGY_BASKET_COUNT];
   bool active[STRATEGY_BASKET_COUNT];
   bool selected[STRATEGY_BASKET_COUNT];
   ArrayInitialize(returns, 0.0);
   ArrayInitialize(stddevs, 0.0);
   ArrayInitialize(scores, 0.0);
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      active[i] = false;
      selected[i] = false;
     }

   double mean_return = 0.0;
   int active_count = 0;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      const string symbol = g_strategy_symbols[i];
      if(!QM_SymbolAssertOrLog(symbol))
         continue;
      if(!Strategy_FreshEnough(symbol, ref_time))
         continue;

      const double r = Strategy_ReturnPct(symbol);
      const int std_window = Strategy_IntMax(2, strategy_stddev_window_d1);
      const double sd = QM_StdDev(symbol, PERIOD_D1, std_window, 1, PRICE_CLOSE, MODE_SMA);
      if(sd <= 0.0 || !MathIsValidNumber(sd))
         continue;
      if(!MathIsValidNumber(r))
         continue;

      returns[i] = r;
      stddevs[i] = sd;
      active[i] = true;
      mean_return += r;
      ++active_count;
     }

   if(active_count < Strategy_IntMax(1, strategy_min_active_symbols))
      return false;

   mean_return /= (double)active_count;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
      if(active[i])
         scores[i] = -(returns[i] - mean_return);

   const int top_n = Strategy_IntMax(1, Strategy_IntMin(strategy_top_divergence_n, active_count));
   const int low_n = Strategy_IntMax(1, Strategy_IntMin(strategy_low_vol_n, active_count));
   double sum_abs = 0.0;

   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      if(!active[i])
         continue;

      int divergence_rank = 1;
      int vol_rank = 1;
      for(int j = 0; j < STRATEGY_BASKET_COUNT; ++j)
        {
         if(!active[j] || i == j)
            continue;
         if(MathAbs(scores[j]) > MathAbs(scores[i]))
            ++divergence_rank;
         if(stddevs[j] < stddevs[i])
            ++vol_rank;
        }

      selected[i] = (divergence_rank <= top_n && vol_rank <= low_n);
      if(selected[i])
         sum_abs += MathAbs(scores[i]);
     }

   if(sum_abs <= 0.0)
      return false;

   g_symbol_selected = selected[current_index];
   if(g_symbol_selected)
      g_symbol_weight = scores[current_index] / sum_abs;

   g_state_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter — symbol-universe guard. News and Friday close are handled
   // by framework wiring; the card's spread entry filter is applied in EntrySignal.
   return (Strategy_CurrentSymbolIndex() < 0);
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
   req.reason = "CHAN_XSEC_LOWVOL_D1";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshState())
      return false;
   if(!g_symbol_selected)
      return false;
   if(MathAbs(g_symbol_weight) <= strategy_min_abs_weight)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   ENUM_POSITION_TYPE position_type;
   if(Strategy_HasOpenPosition(position_type))
      return false;

   const bool go_long = (g_symbol_weight > 0.0);
   req.type = go_long ? QM_BUY : QM_SELL;

   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(go_long && req.sl >= entry)
      return false;
   if(!go_long && req.sl <= entry)
      return false;

   req.reason = go_long ? "CHAN_XSEC_LOWVOL_LONG" : "CHAN_XSEC_LOWVOL_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management — no trailing, partial close, or break-even rule in card.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close — close when the D1 rebalance target drops out or flips sign.
   if(!g_state_ready)
      return false;

   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   if(!g_symbol_selected || MathAbs(g_symbol_weight) <= strategy_min_abs_weight)
      return true;
   if(position_type == POSITION_TYPE_BUY && g_symbol_weight <= 0.0)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_symbol_weight >= 0.0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook — defer to framework two-axis news implementation.
   return false;
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

   QM_SymbolGuardInit(g_strategy_symbols);
   const int warmup_bars = Strategy_IntMax(300, strategy_spread_median_days + strategy_return_lookback_d1 + 10);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, warmup_bars);

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
