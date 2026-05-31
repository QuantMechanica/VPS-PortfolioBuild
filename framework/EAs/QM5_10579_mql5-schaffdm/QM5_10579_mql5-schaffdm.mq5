#property strict
#property version   "5.0"
#property description "QM5_10579 ColorSchaff DeMarker zero break"

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
input int    qm_ea_id                   = 10579;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H4;
input int             strategy_signal_bar         = 1;
input int             strategy_fast_demarker      = 23;
input int             strategy_slow_demarker      = 50;
input int             strategy_cycle              = 10;
input int             strategy_zero_level         = 0;
input int             strategy_atr_period         = 14;
input double          strategy_atr_sl_mult        = 2.0;
input double          strategy_take_profit_rr     = 1.5;
input int             strategy_max_spread_points  = 0;

int g_schaffdm_last_signal = 0;

double Strategy_Clamp(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

double Strategy_DeMarkerValue(const int period, const int shift)
  {
   if(period <= 1 || shift < 1)
      return 0.5;

   double up_sum = 0.0;
   double down_sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double high_now = iHigh(_Symbol, strategy_signal_tf, i);
      const double high_prev = iHigh(_Symbol, strategy_signal_tf, i + 1);
      const double low_now = iLow(_Symbol, strategy_signal_tf, i);
      const double low_prev = iLow(_Symbol, strategy_signal_tf, i + 1);
      if(high_now <= 0.0 || high_prev <= 0.0 || low_now <= 0.0 || low_prev <= 0.0)
         continue;

      up_sum += MathMax(high_now - high_prev, 0.0);
      down_sum += MathMax(low_prev - low_now, 0.0);
     }

   const double denom = up_sum + down_sum;
   if(denom <= 0.0)
      return 0.5;
   return Strategy_Clamp(up_sum / denom, 0.0, 1.0);
  }

double Strategy_ArrayMin(const double &values[], const int count)
  {
   double result = DBL_MAX;
   for(int i = 0; i < count; ++i)
      result = MathMin(result, values[i]);
   return result;
  }

double Strategy_ArrayMax(const double &values[], const int count)
  {
   double result = -DBL_MAX;
   for(int i = 0; i < count; ++i)
      result = MathMax(result, values[i]);
   return result;
  }

bool Strategy_SchaffValues(const int newest_shift, double &value_now, double &value_prev)
  {
   value_now = 0.0;
   value_prev = 0.0;

   if(newest_shift < 1 ||
      strategy_fast_demarker <= 1 ||
      strategy_slow_demarker <= 1 ||
      strategy_cycle <= 1)
      return false;

   const int max_period = MathMax(strategy_fast_demarker, strategy_slow_demarker);
   const int warmup = max_period + 4 * strategy_cycle + 5;
   const int oldest_shift = newest_shift + warmup;
   if(Bars(_Symbol, strategy_signal_tf) <= oldest_shift + max_period + 2)
      return false;

   double macd_ring[];
   double st_ring[];
   ArrayResize(macd_ring, strategy_cycle);
   ArrayResize(st_ring, strategy_cycle);
   ArrayInitialize(macd_ring, 0.0);
   ArrayInitialize(st_ring, 0.0);

   int ring_count = 0;
   int ring_pos = 0;
   bool st1_pass = false;
   bool st2_pass = false;
   double prev_st = 0.0;
   double prev_stc = 0.0;

   for(int shift = oldest_shift; shift >= newest_shift; --shift)
     {
      const double fast_dm = Strategy_DeMarkerValue(strategy_fast_demarker, shift);
      const double slow_dm = Strategy_DeMarkerValue(strategy_slow_demarker, shift);
      const double macd = fast_dm - slow_dm;

      macd_ring[ring_pos] = macd;
      const int used = MathMin(ring_count + 1, strategy_cycle);
      const double macd_low = Strategy_ArrayMin(macd_ring, used);
      const double macd_high = Strategy_ArrayMax(macd_ring, used);

      double st = prev_st;
      if(macd_high - macd_low != 0.0)
         st = ((macd - macd_low) / (macd_high - macd_low)) * 100.0;
      if(st1_pass)
         st = 0.5 * (st - prev_st) + prev_st;
      st1_pass = true;
      st_ring[ring_pos] = st;

      const double st_low = Strategy_ArrayMin(st_ring, used);
      const double st_high = Strategy_ArrayMax(st_ring, used);
      double stc = prev_stc;
      if(st_high - st_low != 0.0)
         stc = ((st - st_low) / (st_high - st_low)) * 200.0 - 100.0;
      if(st2_pass)
         stc = 0.5 * (stc - prev_stc) + prev_stc;
      st2_pass = true;

      if(shift == newest_shift + 1)
         value_prev = stc;
      if(shift == newest_shift)
         value_now = stc;

      prev_st = st;
      prev_stc = stc;
      ring_pos++;
      if(ring_pos >= strategy_cycle)
         ring_pos = 0;
      ring_count++;
     }

   return (value_now != 0.0 || value_prev != 0.0);
  }

int Strategy_ClosedBarSignal()
  {
   const int shift = MathMax(1, strategy_signal_bar);
   double stc_now = 0.0;
   double stc_prev = 0.0;
   if(!Strategy_SchaffValues(shift, stc_now, stc_prev))
      return 0;

   const double zero = (double)strategy_zero_level;
   if(stc_prev <= zero && stc_now > zero)
      return 1;
   if(stc_prev >= zero && stc_now < zero)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_signal_tf != (ENUM_TIMEFRAMES)_Period)
      return true;
   if(strategy_signal_bar < 1 ||
      strategy_fast_demarker <= 1 ||
      strategy_slow_demarker <= 1 ||
      strategy_fast_demarker == strategy_slow_demarker ||
      strategy_cycle <= 1 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0 ||
      strategy_max_spread_points < 0)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
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

   g_schaffdm_last_signal = Strategy_ClosedBarSignal();
   if(g_schaffdm_last_signal == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   req.type = (g_schaffdm_last_signal > 0) ? QM_BUY : QM_SELL;
   req.price = QM_EntryMarketPrice(req.type);
   if(req.price <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_rr);
   req.reason = (g_schaffdm_last_signal > 0) ? "SCHAFFDM_ZERO_UP" : "SCHAFFDM_ZERO_DOWN";
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   return (QM_LotsForRisk(_Symbol, MathAbs(req.price - req.sl) / point) > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // P2 baseline has no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_schaffdm_last_signal == 0)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_schaffdm_last_signal < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_schaffdm_last_signal > 0)
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
