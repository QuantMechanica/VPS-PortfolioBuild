#property strict
#property version   "5.0"
#property description "QM5_11528 ciurea-inv-hammer-shooting-star-m30 — single-candle upper-wick reversal (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11528 ciurea-inv-hammer-shooting-star-m30
// -----------------------------------------------------------------------------
// Source: Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
//         ScientificForex.com, ~2012 (source_id 0192e348-5570-531c-9110-7954a36caca2).
// Card: artifacts/cards_approved/QM5_11528_ciurea-inv-hammer-shooting-star-m30.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M30):
//   The completed bar[1] is the single trigger EVENT — a long-upper-wick candle:
//     body  = |close1 - open1|
//     upper = high1 - max(open1, close1)
//     lower = min(open1, close1) - low1
//     PATTERN: body > min_body_pips  AND  upper >= upper_ratio * body
//              AND  lower <= lower_ratio * body
//   This single shape (inverted-hammer / shooting-star geometry) is the EVENT.
//
//   Trend CONTEXT is a STATE (never a same-bar second event), selectable via
//   strategy_trend_filter:
//     0 = shape-only (Ciurea's published test): the pattern alone fires.
//         A bullish-body candle (close1 >= open1) is read as Inverted Hammer
//         -> BUY; a bearish-body candle (close1 < open1) as Shooting Star
//         -> SELL. (avoids the two-cross-same-bar zero-trade trap: one EVENT,
//         body sign is a STATE of that same bar.)
//     1 = MA-context: price below SMA(ctx) = "at a low" downtrend -> Inverted
//         Hammer is bullish -> BUY; price above SMA(ctx) = "at a high"
//         uptrend -> Shooting Star is bearish -> SELL. The SMA position is a
//         STATE observed on the closed bar; the candle is the EVENT.
//
//   Stop : 3-bar structural extreme (shifts 1..3) minus/plus sl_buffer_pips,
//          distance hard-capped at sl_cap_pips (card P2: 30 pips).
//   Take : 2R from entry (rr_multiple) using the realised stop distance.
//   No Friday entry (card filter). Spread guard fail-open on .DWX zero spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11528;
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
input double strategy_min_body_pips     = 3.0;    // min body size (pips) — excludes doji
input double strategy_upper_ratio       = 2.0;    // upper wick >= ratio * body
input double strategy_lower_ratio       = 0.5;    // lower wick <= ratio * body
input int    strategy_trend_filter      = 0;      // 0=shape-only (Ciurea), 1=SMA context
input int    strategy_ctx_sma_period    = 100;    // SMA period for the trend STATE (filter=1)
input int    strategy_sl_struct_bars    = 3;      // structural extreme lookback (bars)
input double strategy_sl_buffer_pips    = 3.0;    // buffer beyond the 3-bar extreme (pips)
input double strategy_sl_cap_pips       = 30.0;   // hard cap on stop distance (pips)
input double strategy_rr_multiple       = 2.0;    // TP = rr * realised stop distance
input bool   strategy_no_friday_entry   = true;   // card filter: no Friday entries
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (local) — pip size in price terms for this symbol.
// -----------------------------------------------------------------------------
double PipSizePrice()
  {
   // 1 pip in price units (scale-correct on 3/5-digit symbols via the framework).
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — defer, do not block

   // Reference the capped stop distance so the spread cap scales with the symbol.
   const double cap_distance = strategy_sl_cap_pips * PipSizePrice();
   if(cap_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * cap_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No Friday entries (card filter). Friday = day-of-week 5 in broker time.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Single trigger EVENT: long-upper-wick candle on closed bar[1] ---
   // perf-allowed: bespoke single-candle pattern needs raw OHLC at one shift.
   const double o1 = iOpen(_Symbol, _Period, 1);   // perf-allowed
   const double h1 = iHigh(_Symbol, _Period, 1);   // perf-allowed
   const double l1 = iLow(_Symbol, _Period, 1);    // perf-allowed
   const double c1 = iClose(_Symbol, _Period, 1);  // perf-allowed
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return false;

   const double pip   = PipSizePrice();
   if(pip <= 0.0)
      return false;

   const double body  = MathAbs(c1 - o1);
   const double upper = h1 - MathMax(o1, c1);
   const double lower = MathMin(o1, c1) - l1;

   const double min_body = strategy_min_body_pips * pip;
   if(body <= min_body)
      return false;                                 // doji / too-small body
   if(upper < strategy_upper_ratio * body)
      return false;                                 // upper wick not long enough
   if(lower > strategy_lower_ratio * body)
      return false;                                 // lower wick too long

   // --- Direction from the trend CONTEXT (a STATE, not a second EVENT) ---
   bool go_long  = false;
   bool go_short = false;

   if(strategy_trend_filter == 1)
     {
      // SMA-context: below SMA = downtrend low -> Inverted Hammer (bullish BUY);
      // above SMA = uptrend high -> Shooting Star (bearish SELL).
      const double sma = QM_SMA(_Symbol, _Period, strategy_ctx_sma_period, 1);
      if(sma <= 0.0)
         return false;
      if(c1 < sma)
         go_long = true;
      else if(c1 > sma)
         go_short = true;
     }
   else
     {
      // Shape-only (Ciurea's published test): body sign of the trigger bar is
      // the STATE. Bullish body = Inverted Hammer -> BUY; bearish = Shooting
      // Star -> SELL. Equal open/close already excluded by the body>min check.
      if(c1 >= o1)
         go_long = true;
      else
         go_short = true;
     }

   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;

   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: 3-bar structural extreme +/- buffer, distance hard-capped ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_struct_bars);
   if(sl <= 0.0)
      return false;

   const double buffer = strategy_sl_buffer_pips * pip;
   if(go_long)
      sl -= buffer;          // below the structural low
   else
      sl += buffer;          // above the structural high

   // Hard-cap the stop distance at sl_cap_pips.
   const double cap = strategy_sl_cap_pips * pip;
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   if(cap > 0.0 && sl_dist > cap)
     {
      sl = go_long ? (entry - cap) : (entry + cap);
      sl_dist = cap;
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   // --- Take: 2R from entry using the realised (possibly capped) stop. ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_multiple);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "ciurea_inv_hammer_long" : "ciurea_shooting_star_short";
   return true;
  }

// Fixed stop/target only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP bracket.
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
