#property strict
#property version   "5.0"
#property description "QM5_11752 nfs-intraday-pivots-ema-macd — Intraday classic pivots + EMA(9/18) + H1 MACD bias (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11752 nfs-intraday-pivots-ema-macd
// -----------------------------------------------------------------------------
// Source: Anonymous, "Forex Intraday Pivots Trading System", 9 Forex Systems
//         compilation (~2005). Card: artifacts/cards_approved/
//         QM5_11752_nfs-intraday-pivots-ema-macd.md (g0_status APPROVED).
//
// Mechanics (M5 entry timeframe, closed-bar reads at shift 1):
//   Classic daily pivots, computed in-EA once per closed bar from the PRIOR D1
//   bar's OHLC (iHigh/iLow/iClose at PERIOD_D1 shift 1) in BROKER time:
//       P  = (H + L + C) / 3
//       R1 = 2*P - L     R2 = P + (H - L)
//       S1 = 2*P - H     S2 = P - (H - L)
//       M1=(P+S1)/2      M2=(P+S2)/2
//       M3=(P+R1)/2      M4=(P+R2)/2
//   Pivots are cached in file-scope and refreshed only when the prior-D1 bar
//   changes (i.e. at the broker-time daily roll). No per-tick recompute.
//
//   Trend STATE (not events):
//     M5 EMA side : EMA(fast) > EMA(slow)   -> bullish ;  < -> bearish.
//     H1 MACD side: main AND signal BOTH > 0 -> bullish bias ;
//                   main AND signal BOTH < 0 -> bearish bias.
//     A LONG needs both the M5 EMA side AND the H1 MACD side bullish; a SHORT
//     needs both bearish. These are STATES read on the closed bar.
//
//   Trigger EVENT (exactly one, avoids the two-cross-same-bar zero-trade trap):
//     LONG  — a pivot-support RECLAIM: the bar at shift 2 traded at/below a
//             support level (low_2 <= level + zone) while the bar at shift 1
//             CLOSED back above that level (close_1 > level). Price penetrated
//             the support and reclaimed it -> bounce.
//     SHORT — a pivot-resistance REJECTION: the bar at shift 2 traded at/above
//             a resistance level (high_2 >= level - zone) while the bar at
//             shift 1 CLOSED back below that level (close_1 < level).
//     Support levels  : S2, M2, S1, M1, P.
//     Resistance levels: R2, M4, R1, M3, P.
//
//   Stop  : fixed pips on the far side of the reclaimed/rejected level
//           (card factory default 15 pips), scale-correct via QM_StopFixedPips.
//   Take  : the next pivot level in trade direction, floored to a minimum pip
//           distance (card default >= 20 pips). If the next level is closer than
//           the floor, the fixed min-pip TP is used instead.
//   Exit  : SL/TP do the work; a defensive manual exit closes when the H1 MACD
//           bias flips against the open position.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// Symbols (card target_symbols, all present in dwx_symbol_matrix.csv, no port):
//   USDCHF.DWX, EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11752;
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
input int    strategy_ema_fast_period   = 9;     // M5 fast EMA (bullish/bearish side)
input int    strategy_ema_slow_period   = 18;    // M5 slow EMA
input int    strategy_macd_fast         = 12;    // H1 MACD fast EMA
input int    strategy_macd_slow         = 26;    // H1 MACD slow EMA
input int    strategy_macd_signal       = 9;     // H1 MACD signal SMA
input double strategy_pivot_zone_pips   = 5.0;   // proximity zone around a pivot level (pips)
input double strategy_hold_above_pips   = 3.0;   // close must hold this far back beyond pivot after penetration
input int    strategy_sl_pips           = 15;    // stop distance beyond the level (pips)
input int    strategy_min_tp_pips       = 20;    // minimum take-profit distance (pips)

// -----------------------------------------------------------------------------
// File-scope cached pivot state (refreshed only at the broker-time daily roll).
// -----------------------------------------------------------------------------
double   g_pivot_P  = 0.0;
double   g_pivot_R1 = 0.0;
double   g_pivot_R2 = 0.0;
double   g_pivot_S1 = 0.0;
double   g_pivot_S2 = 0.0;
double   g_pivot_M1 = 0.0;
double   g_pivot_M2 = 0.0;
double   g_pivot_M3 = 0.0;
double   g_pivot_M4 = 0.0;
datetime g_pivot_day = 0;     // broker-time open of the prior D1 bar the pivots were built from
bool     g_pivots_ready = false;

// Recompute pivots from the prior D1 bar's OHLC (broker time) when that bar
// changes. Cheap: a single D1 shift-1 OHLC read, only when the day rolls.
// Called once per closed M5 bar from Strategy_EntrySignal (new-bar gated).
void RefreshPivots()
  {
   // perf-allowed: prior-day classic-pivot inputs need raw D1 OHLC; one read,
   // only when the prior-D1 bar changes. Broker time is the chart/tester time.
   const datetime prior_day = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: prior-day pivot cache refresh, called only from QM_IsNewBar-gated entry hook.
   if(prior_day <= 0)
      return;
   if(g_pivots_ready && prior_day == g_pivot_day)
      return; // same prior-D1 bar — pivots already current

   const double H = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: prior-day classic-pivot input, cached by D1 bar.
   const double L = iLow(_Symbol, PERIOD_D1, 1);    // perf-allowed: prior-day classic-pivot input, cached by D1 bar.
   const double C = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior-day classic-pivot input, cached by D1 bar.
   if(H <= 0.0 || L <= 0.0 || C <= 0.0 || H <= L)
      return; // bad/empty prior bar — keep previous pivots

   const double P = (H + L + C) / 3.0;
   g_pivot_P  = P;
   g_pivot_R1 = 2.0 * P - L;
   g_pivot_R2 = P + (H - L);
   g_pivot_S1 = 2.0 * P - H;
   g_pivot_S2 = P - (H - L);
   g_pivot_M1 = (P + g_pivot_S1) / 2.0;
   g_pivot_M2 = (P + g_pivot_S2) / 2.0;
   g_pivot_M3 = (P + g_pivot_R1) / 2.0;
   g_pivot_M4 = (P + g_pivot_R2) / 2.0;
   g_pivot_day = prior_day;
   g_pivots_ready = true;
  }

// Next pivot level strictly above `price` (long target). Returns 0.0 if none.
double NextLevelAbove(const double price)
  {
   double best = 0.0;
   double levels[9];
   levels[0] = g_pivot_S2;
   levels[1] = g_pivot_M2;
   levels[2] = g_pivot_S1;
   levels[3] = g_pivot_M1;
   levels[4] = g_pivot_P;
   levels[5] = g_pivot_M3;
   levels[6] = g_pivot_R1;
   levels[7] = g_pivot_M4;
   levels[8] = g_pivot_R2;
   for(int i = 0; i < 9; ++i)
     {
      if(levels[i] > price)
         if(best == 0.0 || levels[i] < best)
            best = levels[i];
     }
   return best;
  }

// Next pivot level strictly below `price` (short target). Returns 0.0 if none.
double NextLevelBelow(const double price)
  {
   double best = 0.0;
   double levels[9];
   levels[0] = g_pivot_S2;
   levels[1] = g_pivot_M2;
   levels[2] = g_pivot_S1;
   levels[3] = g_pivot_M1;
   levels[4] = g_pivot_P;
   levels[5] = g_pivot_M3;
   levels[6] = g_pivot_R1;
   levels[7] = g_pivot_M4;
   levels[8] = g_pivot_R2;
   for(int i = 0; i < 9; ++i)
     {
      if(levels[i] < price)
         if(best == 0.0 || levels[i] > best)
            best = levels[i];
     }
   return best;
  }

// H1 MACD bias STATE: +1 bullish (both lines > 0), -1 bearish (both < 0), else 0.
int MacdBias()
  {
   const double m = QM_MACD_Main(_Symbol, PERIOD_H1,
                                 strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double s = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                   strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   if(m > 0.0 && s > 0.0)
      return 1;
   if(m < 0.0 && s < 0.0)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Cap a genuinely wide spread relative to the fixed stop distance.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Zero/negative modeled spread (.DWX) passes; only a real wide spread blocks.
   if(spread > 0.0 && spread > 0.5 * stop_distance)
      return true;

   return false;
  }

// Pivot-reclaim long / pivot-rejection short. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Refresh cached pivots from the prior D1 bar (only when the day rolls).
   RefreshPivots();
   if(!g_pivots_ready)
      return false;

   // --- M5 trend STATE: EMA fast vs slow on the closed bar ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   const int ema_side = (ema_fast > ema_slow) ? 1 : ((ema_fast < ema_slow) ? -1 : 0);
   if(ema_side == 0)
      return false;

   // --- H1 MACD bias STATE ---
   const int macd_bias = MacdBias();
   if(macd_bias == 0)
      return false;

   // Closed-bar prices: shift 2 is the penetration bar, shift 1 the reclaim bar.
   // perf-allowed: classic-pivot reclaim needs the prior two closed bars' OHLC.
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar pivot reclaim/rejection confirmation, entry hook is new-bar gated.
   const double low_2   = iLow(_Symbol, _Period, 2);   // perf-allowed: closed-bar pivot penetration test, entry hook is new-bar gated.
   const double high_2  = iHigh(_Symbol, _Period, 2);  // perf-allowed: closed-bar pivot penetration test, entry hook is new-bar gated.
   if(close_1 <= 0.0 || low_2 <= 0.0 || high_2 <= 0.0)
      return false;

   const double zone = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_pivot_zone_pips));
   const double hold = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_hold_above_pips));
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(zone <= 0.0)
      return false;
   if(hold <= 0.0 || stop_distance <= 0.0)
      return false;

   // ============================= LONG =============================
   if(ema_side > 0 && macd_bias > 0)
     {
      double support[5];
      support[0] = g_pivot_S2;
      support[1] = g_pivot_M2;
      support[2] = g_pivot_S1;
      support[3] = g_pivot_M1;
      support[4] = g_pivot_P;
      for(int i = 0; i < 5; ++i)
        {
         const double level = support[i];
         if(level <= 0.0)
            continue;
         // Trigger EVENT: penetration bar dipped to/under the level, reclaim
         // bar closed back above it. One event; EMA/MACD are the states.
         const bool penetrated = (low_2 <= level + zone);
         const bool reclaimed  = (close_1 >= level + hold);
         if(!(penetrated && reclaimed))
            continue;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;

         const double sl = QM_StopRulesNormalizePrice(_Symbol, level - stop_distance);

         // TP = next pivot above entry, floored to the min-pip distance.
         double tp = NextLevelAbove(entry);
         const double min_tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_min_tp_pips);
         if(tp <= 0.0 || tp < min_tp)
            tp = min_tp;
         if(sl <= 0.0 || tp <= 0.0)
            return false;

         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "pivot_support_reclaim_long";
         return true;
        }
     }

   // ============================= SHORT ============================
   if(ema_side < 0 && macd_bias < 0)
     {
      double resistance[5];
      resistance[0] = g_pivot_R2;
      resistance[1] = g_pivot_M4;
      resistance[2] = g_pivot_R1;
      resistance[3] = g_pivot_M3;
      resistance[4] = g_pivot_P;
      for(int i = 0; i < 5; ++i)
        {
         const double level = resistance[i];
         if(level <= 0.0)
            continue;
         const bool penetrated = (high_2 >= level - zone);
         const bool rejected   = (close_1 <= level - hold);
         if(!(penetrated && rejected))
            continue;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;

         const double sl = QM_StopRulesNormalizePrice(_Symbol, level + stop_distance);

         double tp = NextLevelBelow(entry);
         const double min_tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_min_tp_pips);
         if(tp <= 0.0 || tp > min_tp)
            tp = min_tp;
         if(sl <= 0.0 || tp <= 0.0)
            return false;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "pivot_resistance_reject_short";
         return true;
        }
     }

   return false;
  }

// SL/TP manage the trade; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: close when the H1 MACD bias flips against the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int bias = MacdBias();
   if(bias == 0)
      return false; // ambiguous bias — let SL/TP handle it

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && bias < 0)
         return true;  // bias turned bearish against the long
      if(ptype == POSITION_TYPE_SELL && bias > 0)
         return true;  // bias turned bullish against the short
     }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
