#property strict
#property version   "5.0"
#property description "QM5_11713 blade-macd-divergence-stoch — MACD divergence + Stochastic trigger (counter-trend, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11713 blade-macd-divergence-stoch
// -----------------------------------------------------------------------------
// Source: Anonymous (ForexSuccessSecrets.com), "The Blade Forex Strategies —
//   Divergence System", self-published PDF (219755537), ~2010.
// Card: artifacts/cards_approved/QM5_11713_blade-macd-divergence-stoch.md
//   (g0_status: APPROVED).
//
// Mechanics (counter-trend reversal, closed-bar reads, H1):
//   Divergence STATE (regular MACD divergence from the last two swing extremes):
//     Bullish  : price LOWER low  at T2 vs T1  AND  MACD HIGHER low  at T2 vs T1.
//     Bearish  : price HIGHER high at T2 vs T1  AND  MACD LOWER high at T2 vs T1.
//     Swings   : 3-bar local extrema (a bar whose high/low is the extreme of
//                itself and its two neighbours), scanned over a bounded window.
//     The MACD value compared is QM_MACD_Main at the swing bar.
//     A divergence STATE latches once detected and is invalidated when price
//     prints a fresh extreme in the divergence direction without MACD confirming
//     the divergence (i.e. a continuation that contradicts the setup), or when
//     it is consumed by an entry.
//   Trigger EVENT (single, one per bar — avoids the two-cross-same-bar trap):
//     Long  : bullish divergence active AND Stoch %K crosses up through os_level
//             (K[2] < os_level AND K[1] >= os_level).
//     Short : bearish divergence active AND Stoch %K crosses down through ob_level
//             (K[2] > ob_level AND K[1] <= ob_level).
//   Stop  : structure stop 1 buffer beyond the most recent swing low/high, with a
//           fixed-pip fallback when structure is unusable.
//   Take  : RR multiple of the realised stop distance (default 2R).
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX zero
//           modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
//
// Symbols: GBPUSD.DWX, EURUSD.DWX — both present in dwx_symbol_matrix.csv, no
//   porting required.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11713;
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
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal EMA
input int    strategy_stoch_k           = 9;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_os          = 20.0;   // oversold level (long trigger)
input double strategy_stoch_ob          = 80.0;   // overbought level (short trigger)
input int    strategy_swing_strength    = 1;      // bars each side for a 3-bar local extreme
input int    strategy_swing_lookback    = 50;     // bars to scan for the last two swings
input double strategy_sl_struct_buffer_pips = 1.0;// buffer beyond swing for structure stop
input double strategy_sl_fixed_pips     = 30.0;   // fallback fixed stop in pips
input double strategy_tp_rr             = 2.0;    // take-profit as RR multiple of stop
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached divergence state (advanced once per closed bar).
// -----------------------------------------------------------------------------
bool   g_bull_div_active = false;   // bullish (long) divergence latched
bool   g_bear_div_active = false;   // bearish (short) divergence latched
double g_bull_swing_low  = 0.0;     // price of most recent swing low (for structure stop)
double g_bear_swing_high = 0.0;     // price of most recent swing high (for structure stop)

// -----------------------------------------------------------------------------
// Swing detection helpers — bounded closed-bar scans, run once per new bar.
// A swing high at shift s: high[s] is the max of high[s-strength..s+strength].
// A swing low  at shift s: low[s]  is the min of low[s-strength..s+strength].
// perf-allowed: bounded iHigh/iLow reads inside a QM_IsNewBar-gated path.
// -----------------------------------------------------------------------------
bool IsSwingHigh(const int s, const int strength)
  {
   const double h = iHigh(_Symbol, _Period, s); // perf-allowed
   if(h <= 0.0)
      return false;
   for(int j = 1; j <= strength; ++j)
     {
      if(iHigh(_Symbol, _Period, s - j) >= h) // perf-allowed
         return false;
      if(iHigh(_Symbol, _Period, s + j) >  h) // perf-allowed
         return false;
     }
   return true;
  }

bool IsSwingLow(const int s, const int strength)
  {
   const double l = iLow(_Symbol, _Period, s); // perf-allowed
   if(l <= 0.0)
      return false;
   for(int j = 1; j <= strength; ++j)
     {
      if(iLow(_Symbol, _Period, s - j) <= l) // perf-allowed
         return false;
      if(iLow(_Symbol, _Period, s + j) <  l) // perf-allowed
         return false;
     }
   return true;
  }

// Recompute the divergence STATE from the last two confirmed swings. Called
// once per closed bar (QM_IsNewBar gate). The newest usable swing is at shift
// strategy_swing_strength+1 (it needs `strength` newer bars to be confirmed).
void AdvanceState_OnNewBar()
  {
   const int strength = (strategy_swing_strength < 1 ? 1 : strategy_swing_strength);
   const int lookback = (strategy_swing_lookback < (2 * strength + 3)
                         ? (2 * strength + 3) : strategy_swing_lookback);
   const int first = strength + 1;        // newest confirmable swing shift
   const int last  = first + lookback;    // oldest shift we scan

   // --- Collect the two most recent swing HIGHS (T2 = newer, T1 = older) ---
   int    hi2_shift = -1, hi1_shift = -1;
   double hi2_price = 0.0, hi1_price = 0.0;
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingHigh(s, strength))
         continue;
      if(hi2_shift < 0)
        {
         hi2_shift = s;
         hi2_price = iHigh(_Symbol, _Period, s); // perf-allowed
        }
      else
        {
         hi1_shift = s;
         hi1_price = iHigh(_Symbol, _Period, s); // perf-allowed
         break;
        }
     }

   // --- Collect the two most recent swing LOWS (T2 = newer, T1 = older) ---
   int    lo2_shift = -1, lo1_shift = -1;
   double lo2_price = 0.0, lo1_price = 0.0;
   for(int s = first; s <= last; ++s)
     {
      if(!IsSwingLow(s, strength))
         continue;
      if(lo2_shift < 0)
        {
         lo2_shift = s;
         lo2_price = iLow(_Symbol, _Period, s); // perf-allowed
        }
      else
        {
         lo1_shift = s;
         lo1_price = iLow(_Symbol, _Period, s); // perf-allowed
         break;
        }
     }

   // --- Bullish divergence: price LOWER low, MACD HIGHER low at T2 vs T1 ---
   bool bull = false;
   if(lo2_shift > 0 && lo1_shift > 0)
     {
      const double macd_lo2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, lo2_shift);
      const double macd_lo1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, lo1_shift);
      if(lo2_price < lo1_price && macd_lo2 > macd_lo1)
        {
         bull = true;
         g_bull_swing_low = lo2_price;
        }
     }

   // --- Bearish divergence: price HIGHER high, MACD LOWER high at T2 vs T1 ---
   bool bear = false;
   if(hi2_shift > 0 && hi1_shift > 0)
     {
      const double macd_hi2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, hi2_shift);
      const double macd_hi1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, hi1_shift);
      if(hi2_price > hi1_price && macd_hi2 < macd_hi1)
        {
         bear = true;
         g_bear_swing_high = hi2_price;
        }
     }

   // Latch / invalidate. A divergence stays active until either a contradicting
   // structure forms (the opposite-side divergence appears) or it is consumed by
   // an entry (cleared in Strategy_EntrySignal). Re-detection refreshes the swing.
   if(bull)
     {
      g_bull_div_active = true;
      g_bear_div_active = false; // a fresh bullish setup contradicts a stale bearish one
     }
   if(bear)
     {
      g_bear_div_active = true;
      g_bull_div_active = false;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_fixed_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread → block

   return false;
  }

// Counter-trend entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Divergence is the latched STATE; the Stoch %K cross out of OB/OS is the single
// trigger EVENT (one per bar) — this avoids the two-cross-same-bar zero-trade trap.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_bull_div_active && !g_bear_div_active)
      return false;

   // Stochastic %K at the two most recent closed bars (shift 1 = trigger bar,
   // shift 2 = prior). The cross is the single EVENT.
   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                strategy_stoch_slowing, 2);
   if(k1 <= 0.0 && k2 <= 0.0)
      return false;

   // --- Long: bullish divergence + %K crosses UP through the oversold level ---
   if(g_bull_div_active)
     {
      const bool cross_up = (k2 < strategy_stoch_os && k1 >= strategy_stoch_os);
      if(cross_up)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;

         // Structure stop: buffer below the divergence swing low; fixed-pip fallback.
         double sl = 0.0;
         if(g_bull_swing_low > 0.0 && g_bull_swing_low < entry)
           {
            const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_struct_buffer_pips);
            sl = QM_StopRulesNormalizePrice(_Symbol, g_bull_swing_low - buf);
           }
         if(sl <= 0.0 || sl >= entry)
            sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_fixed_pips);
         if(sl <= 0.0 || sl >= entry)
            return false;

         const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
         if(tp <= 0.0)
            return false;

         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "blade_macd_div_stoch_long";
         g_bull_div_active = false; // consume the setup
         return true;
        }
     }

   // --- Short: bearish divergence + %K crosses DOWN through the overbought level ---
   if(g_bear_div_active)
     {
      const bool cross_down = (k2 > strategy_stoch_ob && k1 <= strategy_stoch_ob);
      if(cross_down)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;

         double sl = 0.0;
         if(g_bear_swing_high > entry)
           {
            const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_struct_buffer_pips);
            sl = QM_StopRulesNormalizePrice(_Symbol, g_bear_swing_high + buf);
           }
         if(sl <= entry)
            sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_fixed_pips);
         if(sl <= entry)
            return false;

         const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
         if(tp <= 0.0)
            return false;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "blade_macd_div_stoch_short";
         g_bear_div_active = false; // consume the setup
         return true;
        }
     }

   return false;
  }

// Fixed SL/TP only (set at entry). No active trailing per the card's baseline.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP bracket placed at entry.
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

   // Advance the divergence STATE once per closed bar, then evaluate entry.
   AdvanceState_OnNewBar();

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
