#property strict
#property version   "5.0"
#property description "QM5_10026 Robot Wealth FX Squeeze Mean Reversion"

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
input int    qm_ea_id                   = 10026;
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
// TODO: declare strategy-specific input params here, e.g.:
//   input int    strategy_atr_period   = 14;
//   input double strategy_atr_sl_mult  = 2.0;
//   input double strategy_atr_tp_mult  = 3.0;
input int    strategy_bb_period              = 20;
input double strategy_bb_deviation           = 2.0;
input int    strategy_bb_width_lookback      = 120;
input double strategy_squeeze_percentile     = 20.0;
input double strategy_expand_percentile      = 80.0;
input int    strategy_rsi_period             = 14;
input double strategy_rsi_long_threshold     = 30.0;
input double strategy_rsi_short_threshold    = 70.0;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input int    strategy_extreme_lookback       = 24;
input double strategy_extreme_atr_buffer     = 0.25;
input int    strategy_time_stop_bars         = 24;
input double strategy_max_spread_atr_frac    = 0.15;

bool   g_long_setup_pending = false;
bool   g_short_setup_pending = false;
double g_cached_midline = 0.0;
double g_cached_width_percentile = 100.0;
bool   g_cached_state_ready = false;

double Strategy_BBWidth(const int shift)
  {
   const double upper = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, shift);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, shift);
   if(upper <= 0.0 || lower <= 0.0 || upper <= lower)
      return 0.0;
   return upper - lower;
  }

// FW8 perf 2026-05-23 — rolling-window BB-width cache. Pre-fix this percentile
// rank did 240 CopyBuffer reads per closed bar (Strategy_BBWidth called 120x,
// each = 2 CopyBuffer). ~6M reads over a 4y H1 backtest. Now: ring buffer
// holds the most recent N closed-bar widths; per closed bar we read ONE new
// width (2 CopyBuffer) and append. Rank is computed by counting in-memory.
#define BB_WIDTH_RING_MAX 512
double   g_bb_width_ring[BB_WIDTH_RING_MAX];
int      g_bb_width_ring_count = 0;
int      g_bb_width_ring_head  = 0;   // next-write index
datetime g_bb_width_ring_last_bar = 0;

void Strategy_BBWidthRingPrefill()
  {
   // Called once when the ring is empty (typically first Strategy_RefreshCachedState).
   // Walks shifts 1..lookback and seeds the ring with historical widths.
   const int lookback = MathMin(strategy_bb_width_lookback, BB_WIDTH_RING_MAX);
   if(lookback <= 0) return;
   // Fill OLDEST to NEWEST: shift=lookback first, shift=1 last.
   for(int s = lookback; s >= 1; --s)
     {
      const double w = Strategy_BBWidth(s);
      if(w <= 0.0) continue;
      if(g_bb_width_ring_count < BB_WIDTH_RING_MAX)
        {
         g_bb_width_ring[g_bb_width_ring_count] = w;
         g_bb_width_ring_count++;
         g_bb_width_ring_head = g_bb_width_ring_count % BB_WIDTH_RING_MAX;
        }
     }
   g_bb_width_ring_last_bar = iTime(_Symbol, PERIOD_H1, 0);
  }

void Strategy_BBWidthRingTick()
  {
   // Cheap no-op when bar hasn't changed since last call.
   const datetime bar_now = iTime(_Symbol, PERIOD_H1, 0);
   if(bar_now == g_bb_width_ring_last_bar) return;

   if(g_bb_width_ring_count == 0)
     {
      Strategy_BBWidthRingPrefill();
      return;
     }

   // A new bar has formed. The PREVIOUSLY-forming bar (shift 1) is now closed.
   const double w = Strategy_BBWidth(1);
   g_bb_width_ring_last_bar = bar_now;
   if(w <= 0.0) return;

   if(g_bb_width_ring_count < BB_WIDTH_RING_MAX)
     {
      g_bb_width_ring[g_bb_width_ring_count] = w;
      g_bb_width_ring_count++;
      g_bb_width_ring_head = g_bb_width_ring_count % BB_WIDTH_RING_MAX;
     }
   else
     {
      g_bb_width_ring[g_bb_width_ring_head] = w;
      g_bb_width_ring_head = (g_bb_width_ring_head + 1) % BB_WIDTH_RING_MAX;
     }
  }

double Strategy_BBWidthPercentileRank(const int shift)
  {
   if(strategy_bb_width_lookback <= 1)
      return 100.0;

   // Fast path: shift==1 (the only caller — line 192's Strategy_RefreshCachedState).
   // Use the in-memory ring; one CopyBuffer pair per new bar, zero per repeat call.
   if(shift == 1)
     {
      Strategy_BBWidthRingTick();
      const int lookback = MathMin(strategy_bb_width_lookback, g_bb_width_ring_count);
      if(lookback < 2)
         return 100.0;

      // Most recent value in the ring lives at (head-1) with wrap.
      const int newest_idx = (g_bb_width_ring_head - 1 + BB_WIDTH_RING_MAX) % BB_WIDTH_RING_MAX;
      const double current_width = g_bb_width_ring[newest_idx];
      if(current_width <= 0.0)
         return 100.0;

      int less_or_equal = 0;
      for(int i = 0; i < lookback; ++i)
        {
         const int idx = (g_bb_width_ring_head - 1 - i + BB_WIDTH_RING_MAX) % BB_WIDTH_RING_MAX;
         if(g_bb_width_ring[idx] <= current_width)
            less_or_equal++;
        }
      return 100.0 * (double)less_or_equal / (double)lookback;
     }

   // Defensive fallback for shift != 1 (no caller today, kept for parity).
   const double current_width = Strategy_BBWidth(shift);
   if(current_width <= 0.0)
      return 100.0;

   int valid = 0;
   int less_or_equal = 0;
   for(int i = shift; i < shift + strategy_bb_width_lookback; ++i)
     {
      const double width = Strategy_BBWidth(i);
      if(width <= 0.0)
         continue;
      valid++;
      if(width <= current_width)
         less_or_equal++;
     }

   if(valid <= 0)
      return 100.0;
   return 100.0 * (double)less_or_equal / (double)valid;
  }

double Strategy_LowestLow(const int lookback)
  {
   double lowest = DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
     {
      const double value = iLow(_Symbol, PERIOD_H1, i);
      if(value > 0.0 && value < lowest)
         lowest = value;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

double Strategy_HighestHigh(const int lookback)
  {
   double highest = -DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
     {
      const double value = iHigh(_Symbol, PERIOD_H1, i);
      if(value > highest)
         highest = value;
     }
   return (highest == -DBL_MAX) ? 0.0 : highest;
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

void Strategy_RefreshCachedState()
  {
   g_cached_midline = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   g_cached_width_percentile = Strategy_BBWidthPercentileRank(1);
   g_cached_state_ready = (g_cached_midline > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 1 && dt.hour < 2)
      return true;
   if(dt.day_of_week == 5 && dt.hour >= 22)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if((ask - bid) > atr * strategy_max_spread_atr_frac)
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

   Strategy_RefreshCachedState();

   if(strategy_bb_period < 2 || strategy_bb_width_lookback < 2 ||
      strategy_atr_period < 1 || strategy_extreme_lookback < 1)
      return false;

   ulong existing_ticket;
   ENUM_POSITION_TYPE existing_type;
   datetime existing_open_time;
   if(Strategy_SelectOurPosition(existing_ticket, existing_type, existing_open_time))
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_H1, 1);
   const double upper_1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower_1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_1 <= 0.0 || upper_1 <= 0.0 || lower_1 <= 0.0 || atr_1 <= 0.0 || point <= 0.0)
      return false;

   if(g_long_setup_pending && close_1 > lower_1)
     {
      const double prior_low = Strategy_LowestLow(strategy_extreme_lookback);
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(prior_low <= 0.0 || entry <= 0.0)
         return false;

      const double atr_stop = strategy_atr_sl_mult * atr_1;
      const double structure_stop = entry - prior_low + strategy_extreme_atr_buffer * atr_1;
      const double stop_distance = MathMax(atr_stop, structure_stop);
      if(stop_distance <= point)
         return false;

      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry - stop_distance);
      req.reason = "RW_FX_SQUEEZE_MR_LONG_REENTRY";
      g_long_setup_pending = false;
      g_short_setup_pending = false;
      return true;
     }

   if(g_short_setup_pending && close_1 < upper_1)
     {
      const double prior_high = Strategy_HighestHigh(strategy_extreme_lookback);
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(prior_high <= 0.0 || entry <= 0.0)
         return false;

      const double atr_stop = strategy_atr_sl_mult * atr_1;
      const double structure_stop = prior_high - entry + strategy_extreme_atr_buffer * atr_1;
      const double stop_distance = MathMax(atr_stop, structure_stop);
      if(stop_distance <= point)
         return false;

      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry + stop_distance);
      req.reason = "RW_FX_SQUEEZE_MR_SHORT_REENTRY";
      g_long_setup_pending = false;
      g_short_setup_pending = false;
      return true;
     }

   const bool squeeze = (g_cached_width_percentile <= strategy_squeeze_percentile);
   if(squeeze && close_1 < lower_1 && rsi_1 < strategy_rsi_long_threshold)
     {
      g_long_setup_pending = true;
      g_short_setup_pending = false;
      return false;
     }

   if(squeeze && close_1 > upper_1 && rsi_1 > strategy_rsi_short_threshold)
     {
      g_short_setup_pending = true;
      g_long_setup_pending = false;
      return false;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or averaging.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, position_type, open_time))
      return false;

   if(!g_cached_state_ready)
      Strategy_RefreshCachedState();

   const datetime now = TimeCurrent();
   const int seconds_per_bar = PeriodSeconds(PERIOD_H1);
   if(open_time > 0 && seconds_per_bar > 0 &&
      now - open_time >= strategy_time_stop_bars * seconds_per_bar)
      return true;

   if(g_cached_state_ready)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(position_type == POSITION_TYPE_BUY && bid >= g_cached_midline)
         return true;
      if(position_type == POSITION_TYPE_SELL && ask <= g_cached_midline)
         return true;
      if(g_cached_width_percentile >= strategy_expand_percentile)
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
