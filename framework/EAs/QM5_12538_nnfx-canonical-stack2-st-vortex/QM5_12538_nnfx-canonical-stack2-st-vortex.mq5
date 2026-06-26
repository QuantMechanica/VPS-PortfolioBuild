#property strict
#property version   "5.0"
#property description "QM5_12538 NNFX Canonical D1 Stack #2 — McGinley / SuperTrend / Vortex / ADX"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — NNFX canonical stack #2 (doctrine-twin of QM5_12534).
// -----------------------------------------------------------------------------
// Mechanic (closed-bar D1, LONG; SHORT = mirror):
//   1. Baseline: close crosses ABOVE McGinley(20) now, or crossed within the
//      last 3 closed bars and the rest of the stack completes now.
//   2. ATR proximity: |close - McGinley| < 1.0 x ATR(14) at signal, else skip.
//   3. C1: SuperTrend(10, 3.0) is long (price above the SuperTrend line).
//   4. C2: Vortex(14) VI+ > VI-.
//   5. Volume gate: ADX(14) >= 20 AND rising vs previous closed bar.
//   Exit: TP-half at +1.0 x ATR(14); runner to breakeven after TP-half; runner
//   exits on SuperTrend(10,3) flip or close crossing back through McGinley(20).
//   Initial SL 1.5 x ATR(14). One position per symbol per magic; news blackout.
//
// Helper note: McGinley Dynamic, SuperTrend and Vortex have no QM_* reader.
// All three are computed here from PERMITTED primitives only:
//   - ATR via QM_ATR (pooled iATR reader)
//   - raw closed-bar OHLC via iHigh/iLow/iClose (shift >= 1, closed bars only)
// No raw indicator handles, no CopyBuffer, no banned/ML indicators.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12538;
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
input int    strategy_baseline_period   = 20;     // McGinley Dynamic period
input int    strategy_baseline_cross_lookback = 3; // baseline-cross validity window (bars)
input int    strategy_atr_period        = 14;     // ATR period
input double strategy_atr_proximity     = 1.0;    // max |close-baseline| in ATR units
input int    strategy_supertrend_period = 10;     // SuperTrend ATR period
input double strategy_supertrend_mult   = 3.0;    // SuperTrend ATR multiplier
input int    strategy_vortex_period     = 14;     // Vortex period
input int    strategy_adx_period        = 14;     // ADX period
input double strategy_adx_threshold     = 20.0;   // ADX volume gate floor
input double strategy_atr_sl_mult       = 1.5;    // initial SL = mult x ATR
input double strategy_atr_tp_mult       = 1.0;    // TP-half target = mult x ATR
input double strategy_partial_fraction  = 0.5;    // fraction closed at TP-half
input int    strategy_warmup_bars       = 250;    // forward-iteration warmup for ST/McGinley
input int    strategy_max_spread_points = 300;

// -----------------------------------------------------------------------------
// Indicator computations from permitted primitives (closed bars only, shift>=1).
// -----------------------------------------------------------------------------

// McGinley Dynamic at closed-bar `shift`, computed by forward-iterating from a
// seed `warmup` bars earlier. md = md_prev + (c - md_prev)/(N*(c/md_prev)^4).
double Strategy_McGinley(const string sym, const int period, const int shift)
  {
   if(period <= 0 || shift < 1)
      return 0.0;
   const int start = shift + strategy_warmup_bars;          // oldest bar index
   double seed = iClose(sym, PERIOD_D1, start); // perf-allowed: closed-bar McGinley seed
   if(seed <= 0.0)
      return 0.0;
   double md = seed;
   for(int s = start - 1; s >= shift; --s)
     {
      const double c = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar McGinley recursion
      if(c <= 0.0 || md <= 0.0)
         return 0.0;
      const double ratio = c / md;
      const double denom = (double)period * MathPow(ratio, 4.0);
      if(denom <= 0.0)
         return 0.0;
      md = md + (c - md) / denom;
     }
   return md;
  }

// SuperTrend(period, mult) trend direction at closed-bar `shift`.
// Returns +1 (long / price above line), -1 (short / price below line), 0 fail.
// Forward-iterates the standard band/flip recursion from a warmup seed.
int Strategy_SuperTrendDir(const string sym, const int period, const double mult, const int shift)
  {
   if(period <= 0 || mult <= 0.0 || shift < 1)
      return 0;
   const int start = shift + strategy_warmup_bars;
   int    dir = 1;
   double final_upper = 0.0;
   double final_lower = 0.0;
   bool   seeded = false;
   for(int s = start; s >= shift; --s)
     {
      const double hi = iHigh(sym, PERIOD_D1, s); // perf-allowed: closed-bar SuperTrend recursion
      const double lo = iLow(sym, PERIOD_D1, s); // perf-allowed: closed-bar SuperTrend recursion
      const double cl = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar SuperTrend recursion
      const double atr = QM_ATR(sym, PERIOD_D1, period, s);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || atr <= 0.0)
         return 0;
      const double mid = (hi + lo) / 2.0;
      const double basic_upper = mid + mult * atr;
      const double basic_lower = mid - mult * atr;
      if(!seeded)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         dir = (cl >= mid) ? 1 : -1;
         seeded = true;
         continue;
        }
      const double cl_prev = iClose(sym, PERIOD_D1, s + 1); // perf-allowed: closed-bar SuperTrend recursion
      if(cl_prev <= 0.0)
         return 0;
      // Final band recursion (standard SuperTrend).
      if(basic_upper < final_upper || cl_prev > final_upper)
         final_upper = basic_upper;
      if(basic_lower > final_lower || cl_prev < final_lower)
         final_lower = basic_lower;
      // Direction flip.
      if(dir == 1 && cl < final_lower)
         dir = -1;
      else if(dir == -1 && cl > final_upper)
         dir = 1;
     }
   return dir;
  }

// Vortex(period): VI+ and VI- at closed-bar `shift`, from raw closed-bar OHLC.
//   VM+ = |High[t] - Low[t-1]|, VM- = |Low[t] - High[t-1]|,
//   TR  = max(High-Low, |High-Close[t-1]|, |Low-Close[t-1]|),
//   VI+ = sum(VM+)/sum(TR), VI- = sum(VM-)/sum(TR) over `period` bars.
bool Strategy_Vortex(const string sym, const int period, const int shift,
                     double &vi_plus, double &vi_minus)
  {
   vi_plus = 0.0;
   vi_minus = 0.0;
   if(period <= 0 || shift < 1)
      return false;
   double sum_vmp = 0.0;
   double sum_vmm = 0.0;
   double sum_tr  = 0.0;
   for(int k = 0; k < period; ++k)
     {
      const int s = shift + k;
      const double hi   = iHigh(sym, PERIOD_D1, s); // perf-allowed: closed-bar Vortex range
      const double lo   = iLow(sym, PERIOD_D1, s); // perf-allowed: closed-bar Vortex range
      const double hi_p = iHigh(sym, PERIOD_D1, s + 1); // perf-allowed: closed-bar Vortex prior range
      const double lo_p = iLow(sym, PERIOD_D1, s + 1); // perf-allowed: closed-bar Vortex prior range
      const double cl_p = iClose(sym, PERIOD_D1, s + 1); // perf-allowed: closed-bar Vortex true range
      if(hi <= 0.0 || lo <= 0.0 || hi_p <= 0.0 || lo_p <= 0.0 || cl_p <= 0.0)
         return false;
      sum_vmp += MathAbs(hi - lo_p);
      sum_vmm += MathAbs(lo - hi_p);
      double tr = hi - lo;
      tr = MathMax(tr, MathAbs(hi - cl_p));
      tr = MathMax(tr, MathAbs(lo - cl_p));
      sum_tr += tr;
     }
   if(sum_tr <= 0.0)
      return false;
   vi_plus  = sum_vmp / sum_tr;
   vi_minus = sum_vmm / sum_tr;
   return true;
  }

// Baseline cross-direction within the validity window, evaluated on closed bars.
// Returns +1 if close crossed ABOVE McGinley at some bar in [shift, shift+lb-1],
// -1 if it crossed BELOW, 0 if no cross in the window.
int Strategy_BaselineCross(const string sym, const int period, const int shift, const int lookback)
  {
   for(int k = 0; k < lookback; ++k)
     {
      const int s = shift + k;
      const double c_now  = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar baseline cross
      const double c_prev = iClose(sym, PERIOD_D1, s + 1); // perf-allowed: closed-bar baseline cross
      const double md_now  = Strategy_McGinley(sym, period, s);
      const double md_prev = Strategy_McGinley(sym, period, s + 1);
      if(c_now <= 0.0 || c_prev <= 0.0 || md_now <= 0.0 || md_prev <= 0.0)
         continue;
      if(c_prev <= md_prev && c_now > md_now)
         return 1;
      if(c_prev >= md_prev && c_now < md_now)
         return -1;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Cheap O(1) checks only.
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

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_baseline_period <= 0 ||
      strategy_baseline_cross_lookback <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_proximity <= 0.0 ||
      strategy_supertrend_period <= 0 ||
      strategy_supertrend_mult <= 0.0 ||
      strategy_vortex_period <= 0 ||
      strategy_adx_period <= 0 ||
      strategy_adx_threshold <= 0.0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_warmup_bars <= 0)
      return false;

   // Stack inputs on the last closed bar (shift = 1).
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar stack input
   const double md_last    = Strategy_McGinley(_Symbol, strategy_baseline_period, 1);
   const double atr_last   = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_last <= 0.0 || md_last <= 0.0 || atr_last <= 0.0)
      return false;

   // 1. Baseline cross direction within the validity window.
   const int cross_dir = Strategy_BaselineCross(_Symbol, strategy_baseline_period,
                                                1, strategy_baseline_cross_lookback);
   if(cross_dir == 0)
      return false;

   // 2. ATR proximity at signal.
   if(MathAbs(close_last - md_last) >= strategy_atr_proximity * atr_last)
      return false;

   // 3. C1 — SuperTrend direction.
   const int st_dir = Strategy_SuperTrendDir(_Symbol, strategy_supertrend_period,
                                             strategy_supertrend_mult, 1);
   if(st_dir == 0)
      return false;

   // 4. C2 — Vortex VI+ vs VI-.
   double vi_plus = 0.0, vi_minus = 0.0;
   if(!Strategy_Vortex(_Symbol, strategy_vortex_period, 1, vi_plus, vi_minus))
      return false;

   // 5. Volume gate — ADX >= threshold AND rising.
   const double adx_last = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   const double adx_prev = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 2);
   if(adx_last <= 0.0 || adx_prev <= 0.0)
      return false;
   if(adx_last < strategy_adx_threshold || adx_last <= adx_prev)
      return false;

   const bool long_ok  = (cross_dir == 1) && (close_last > md_last) &&
                         (st_dir == 1) && (vi_plus > vi_minus);
   const bool short_ok = (cross_dir == -1) && (close_last < md_last) &&
                         (st_dir == -1) && (vi_minus > vi_plus);

   if(!long_ok && !short_ok)
      return false;

   req.type = long_ok ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   // No fixed TP: the TP-half partial and runner are managed in
   // Strategy_ManageOpenPosition / Strategy_ExitSignal.
   req.reason = long_ok ? "NNFX_ST_VORTEX_LONG" : "NNFX_ST_VORTEX_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// TP-half partial close at +1.0 x ATR, then runner to breakeven.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return;
   const double tp_distance = strategy_atr_tp_mult * atr_last;
   if(tp_distance <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_vol    = PositionGetDouble(POSITION_VOLUME);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0 || cur_vol <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);

      // TP-half has not fired yet if SL is not at/beyond breakeven. We move the
      // runner SL to breakeven only after the partial, so SL-at-BE is the
      // durable "already partialled" marker.
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const bool at_breakeven = is_buy
                                ? (cur_sl >= open_price - _Point * 0.5)
                                : (cur_sl > 0.0 && cur_sl <= open_price + _Point * 0.5);

      if(!at_breakeven && moved >= tp_distance)
        {
         // Close half (TP-half), then move the runner SL to breakeven.
         const double close_lots = QM_TM_NormalizeVolume(_Symbol, cur_vol * strategy_partial_fraction);
         if(close_lots > 0.0 && close_lots < cur_vol)
            QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL);
         QM_TM_MoveToBreakEven(ticket, 1, 0);
        }
     }
  }

// Return TRUE to close the open position now. Runner exits on SuperTrend flip
// or close crossing back through McGinley (whichever first).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar exit input
   const double md_last    = Strategy_McGinley(_Symbol, strategy_baseline_period, 1);
   const int    st_dir     = Strategy_SuperTrendDir(_Symbol, strategy_supertrend_period,
                                                    strategy_supertrend_mult, 1);
   if(close_last <= 0.0 || md_last <= 0.0)
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
      if(ptype == POSITION_TYPE_BUY)
        {
         if(st_dir == -1 || close_last < md_last)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(st_dir == 1 || close_last > md_last)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Defer to the central two-axis filter.
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

   // Per-tick: discretionary exit (e.g. opposite-signal). Separate from SL/TP.
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
