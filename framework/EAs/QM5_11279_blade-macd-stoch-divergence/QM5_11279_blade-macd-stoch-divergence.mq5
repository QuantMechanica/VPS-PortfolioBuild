#property strict
#property version   "5.0"
#property description "QM5_11279 blade-macd-stoch-divergence — MACD/Stoch divergence reversal (H1/H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11279 blade-macd-stoch-divergence
// -----------------------------------------------------------------------------
// Source: "The Blade Forex Strategies" (ForexSuccessSecrets.com PDF), section
//         "The Divergence System" (pp. 51-63).
// Card: artifacts/cards_approved/QM5_11279_blade-macd-stoch-divergence.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads only; reversal / mean-reversion):
//   Swing detection (deterministic pivot): a bar is a swing HIGH if its high is
//     the strict maximum over `pivot_width` bars on EACH side; swing LOW mirror.
//     A pivot at chart-shift p is CONFIRMED only once `pivot_width` later bars
//     have closed (i.e. shift p >= pivot_width+1 from the just-closed bar 1).
//
//   Divergence confirmation is the single EVENT: it fires only on the closed
//     bar at which the NEWER pivot first becomes confirmed — that is, when the
//     newer pivot sits at shift (pivot_width + 1) from the current closed bar.
//     This gives exactly one trigger per newly-confirmed pivot. We then look
//     back for the previous same-type confirmed pivot within `swing_lookback`.
//
//   Oscillator STATE (compared at the two pivot bars, not an event):
//     Bearish (SELL): price higher-high (hi2 > hi1) AND oscillator lower-high
//                     (osc@pivot2 < osc@pivot1) by >= min_div_frac of |osc@1|.
//     Bullish (BUY):  price lower-low  (lo2 < lo1) AND oscillator higher-low
//                     (osc@pivot2 > osc@pivot1) by >= min_div_frac of |osc@1|.
//     MACD line CAN be negative — there is NO <=0 guard on the MACD value.
//     Use MACD divergence OR Stochastic %K divergence (configurable mode).
//
//   Stop  : ATR(atr_period) * sl_atr_mult beyond the pivot-2 price extreme.
//   Take  : ATR(atr_period) * tp_atr_mult from entry (RR-style fixed target).
//   Spread guard: fail-OPEN on .DWX zero modeled spread; block only a genuinely
//                 wide spread > spread_pct_of_stop of the stop distance.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11279;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Oscillator mode: 0 = MACD line, 1 = Stochastic %K, 2 = dual (BOTH must diverge).
input int    strategy_osc_mode          = 0;
// MACD(12,26,9) line divergence vs price.
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
// Stochastic(14,3,3) %K divergence vs price.
input int    strategy_stoch_k           = 14;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slow        = 3;
// Swing/pivot detection.
input int    strategy_pivot_width       = 5;    // bars on each side of a pivot (card: 5)
input int    strategy_swing_lookback    = 50;   // bars to search back for the prior pivot
input int    strategy_min_swing_gap     = 5;    // min bar separation between the two pivots
// Minimum non-trivial divergence: |osc2 - osc1| >= min_div_frac * |osc1| (>=5%).
input double strategy_min_div_frac      = 0.05;
// ATR stop / target.
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 1.5;  // SL beyond the pivot-2 extreme
input double strategy_tp_atr_mult       = 2.0;  // TP distance from entry
// Spread guard (fail-open on zero .DWX spread).
input double strategy_spread_pct_of_stop = 20.0;

// -----------------------------------------------------------------------------
// Helpers (closed-bar, deterministic). All price reads are single-shift OHLC
// reads (perf-allowed): bounded by strategy_swing_lookback, evaluated once per
// closed bar inside Strategy_EntrySignal (which the framework gates on
// QM_IsNewBar()).
// -----------------------------------------------------------------------------

// Is the bar at chart-shift `s` a confirmed swing HIGH? Strict max of its high
// over `width` bars on each side. Requires s-width >= 1 (right side fully
// closed) — the caller guarantees this.
bool IsSwingHigh(const int s, const int width)
  {
   const double h = iHigh(_Symbol, _Period, s); // perf-allowed: bounded pivot scan, closed-bar
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= width; ++k)
     {
      const double hl = iHigh(_Symbol, _Period, s + k); // perf-allowed
      const double hr = iHigh(_Symbol, _Period, s - k); // perf-allowed
      if(hl <= 0.0 || hr <= 0.0)
         return false;
      if(!(h > hl) || !(h > hr))
         return false;
     }
   return true;
  }

// Is the bar at chart-shift `s` a confirmed swing LOW? Strict min mirror.
bool IsSwingLow(const int s, const int width)
  {
   const double l = iLow(_Symbol, _Period, s); // perf-allowed: bounded pivot scan, closed-bar
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= width; ++k)
     {
      const double ll = iLow(_Symbol, _Period, s + k); // perf-allowed
      const double lr = iLow(_Symbol, _Period, s - k); // perf-allowed
      if(ll <= 0.0 || lr <= 0.0)
         return false;
      if(!(l < ll) || !(l < lr))
         return false;
     }
   return true;
  }

// Oscillator value at chart-shift `s` for the active mode. For dual mode the
// caller queries each component separately; this returns the MACD line (mode 0)
// or Stoch %K (mode 1). MACD line CAN be negative — no clamping/guarding here.
double OscAt(const int mode, const int s)
  {
   if(mode == 1)
      return QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, s);
   return QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
  }

// Non-trivial divergence magnitude test: |o2 - o1| >= frac * |o1| AND the
// directional sign is correct. dir = +1 wants o2 > o1 (bullish higher-low),
// dir = -1 wants o2 < o1 (bearish lower-high).
bool OscDiverges(const double o1, const double o2, const int dir)
  {
   if(dir > 0 && !(o2 > o1))
      return false;
   if(dir < 0 && !(o2 < o1))
      return false;
   const double base = MathAbs(o1);
   const double need = strategy_min_div_frac * (base > 0.0 ? base : 1.0);
   return (MathAbs(o2 - o1) >= need);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — divergence work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Divergence reversal entry. Caller guarantees QM_IsNewBar() == true.
// The EVENT is "a newer pivot just became confirmed on this closed bar".
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_pivot_width < 1 || strategy_swing_lookback < (2 * strategy_pivot_width + 2))
      return false;

   // The newer pivot becomes confirmed exactly when it sits `pivot_width` bars
   // back from the just-closed bar (shift 1). So pivot-2 chart-shift:
   const int p2 = strategy_pivot_width + 1;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int last_search = strategy_swing_lookback; // furthest-back pivot shift

   // ---------------- BEARISH divergence (SELL): higher-high in price -----------
   if(IsSwingHigh(p2, strategy_pivot_width))
     {
      // Find the previous CONFIRMED swing high older than p2 (with the required
      // gap), the most recent one within the lookback window.
      int p1 = -1;
      for(int s = p2 + strategy_min_swing_gap; s <= last_search; ++s)
        {
         // Ensure the right side of this older pivot is fully closed.
         if(s - strategy_pivot_width < 1)
            continue;
         if(IsSwingHigh(s, strategy_pivot_width))
           { p1 = s; break; }
        }
      if(p1 > 0)
        {
         const double hi2 = iHigh(_Symbol, _Period, p2); // perf-allowed
         const double hi1 = iHigh(_Symbol, _Period, p1); // perf-allowed
         if(hi2 > 0.0 && hi1 > 0.0 && hi2 > hi1) // price higher-high (state)
           {
            bool macd_div = true, stoch_div = true;
            if(strategy_osc_mode == 0 || strategy_osc_mode == 2)
              {
               const double m1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, p1);
               const double m2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, p2);
               macd_div = OscDiverges(m1, m2, -1); // lower-high in MACD line
              }
            if(strategy_osc_mode == 1 || strategy_osc_mode == 2)
              {
               const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, p1);
               const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, p2);
               stoch_div = OscDiverges(k1, k2, -1); // lower-high in %K
              }
            const bool osc_ok = (strategy_osc_mode == 0) ? macd_div
                              : (strategy_osc_mode == 1) ? stoch_div
                              : (macd_div && stoch_div);
            if(osc_ok)
              {
               const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(entry > 0.0)
                 {
                  // SL beyond the pivot-2 high; TP fixed ATR distance from entry.
                  const double sl = hi2 + strategy_sl_atr_mult * atr;
                  const double tp = entry - strategy_tp_atr_mult * atr;
                  if(sl > entry && tp > 0.0 && tp < entry)
                    {
                     req.type   = QM_SELL;
                     req.price  = 0.0;
                     req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
                     req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
                     req.reason = "blade_div_sell";
                     return true;
                    }
                 }
              }
           }
        }
     }

   // ---------------- BULLISH divergence (BUY): lower-low in price -------------
   if(IsSwingLow(p2, strategy_pivot_width))
     {
      int p1 = -1;
      for(int s = p2 + strategy_min_swing_gap; s <= last_search; ++s)
        {
         if(s - strategy_pivot_width < 1)
            continue;
         if(IsSwingLow(s, strategy_pivot_width))
           { p1 = s; break; }
        }
      if(p1 > 0)
        {
         const double lo2 = iLow(_Symbol, _Period, p2); // perf-allowed
         const double lo1 = iLow(_Symbol, _Period, p1); // perf-allowed
         if(lo2 > 0.0 && lo1 > 0.0 && lo2 < lo1) // price lower-low (state)
           {
            bool macd_div = true, stoch_div = true;
            if(strategy_osc_mode == 0 || strategy_osc_mode == 2)
              {
               const double m1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, p1);
               const double m2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, p2);
               macd_div = OscDiverges(m1, m2, +1); // higher-low in MACD line
              }
            if(strategy_osc_mode == 1 || strategy_osc_mode == 2)
              {
               const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, p1);
               const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, p2);
               stoch_div = OscDiverges(k1, k2, +1); // higher-low in %K
              }
            const bool osc_ok = (strategy_osc_mode == 0) ? macd_div
                              : (strategy_osc_mode == 1) ? stoch_div
                              : (macd_div && stoch_div);
            if(osc_ok)
              {
               const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if(entry > 0.0)
                 {
                  const double sl = lo2 - strategy_sl_atr_mult * atr;
                  const double tp = entry + strategy_tp_atr_mult * atr;
                  if(sl > 0.0 && sl < entry && tp > entry)
                    {
                     req.type   = QM_BUY;
                     req.price  = 0.0;
                     req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
                     req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
                     req.reason = "blade_div_buy";
                     return true;
                    }
                 }
              }
           }
        }
     }

   return false;
  }

// Fixed ATR stop / target set at entry; no trailing or break-even per card P2.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP — divergence reversal exits on the target
// or the ATR stop set at entry.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
