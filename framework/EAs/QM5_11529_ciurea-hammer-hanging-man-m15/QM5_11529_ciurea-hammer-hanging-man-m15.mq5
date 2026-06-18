#property strict
#property version   "5.0"
#property description "QM5_11529 ciurea-hammer-hanging-man-m15 — Hammer / Hanging-Man single-candle reversal (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11529 ciurea-hammer-hanging-man-m15
// -----------------------------------------------------------------------------
// Source: Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
//   ScientificForex.com (~2012). Source ID 0192e348-5570-531c-9110-7954a36caca2.
// Card: artifacts/cards_approved/QM5_11529_ciurea-hammer-hanging-man-m15.md
//   (g0_status APPROVED).
//
// Mechanics (single-candle pattern, closed bar at shift 1):
//   Pattern SHAPE (the trigger EVENT on the just-closed bar):
//     body  = |close1 - open1|
//     lower = min(open1, close1) - low1     (lower shadow)
//     upper = high1 - max(open1, close1)    (upper shadow)
//     Hammer / Hanging-Man shape:
//       body  > body_min_pips  (in price)            AND
//       lower >= lower_shadow_mult * body            AND
//       upper <= upper_shadow_max_mult * body
//   The completed candle is the single trigger EVENT (fires at most once per
//   closed bar). There is NO second cross condition — no two-cross zero-trade
//   trap. Trend context is an optional STATE filter, not a second event.
//
//   Direction (the card's pure-shape test fires the same shape both ways; to
//   keep one deterministic signal per bar we disambiguate by candle body color
//   by default, and optionally by an SMA trend STATE):
//     require_body_color = true  -> bullish body (close1>open1) => Hammer  (BUY)
//                                    bearish body (close1<open1) => HangingMan (SELL)
//     trend_filter_period > 0    -> additionally require price below the SMA for
//                                    a Hammer BUY (downtrend context) and above
//                                    the SMA for a Hanging-Man SELL (uptrend
//                                    context). The SMA is a STATE; the shape is
//                                    the EVENT. Default 0 = pure shape (card
//                                    baseline). P3 sweeps trend_filter_period.
//
//   Stop  : 3-bar extreme of the closed bars BEFORE entry, +/- sl_buffer_pips,
//           hard-capped at sl_cap_pips (card P2 cap = 20 pips).
//     BUY  SL = lowest_low(shift 1..N)  - buffer
//     SELL SL = highest_high(shift 1..N) + buffer
//   Take  : tp_rr * stop-distance from entry (card default 2R).
//   Filters: optional spread cap (fail-open on .DWX zero spread), no Friday
//            entry.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11529;
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
input double strategy_body_min_pips        = 3.0;   // min real-body size in pips (body>0 guard, card =3)
input double strategy_lower_shadow_mult    = 2.0;   // lower shadow >= this * body (card =2.0)
input double strategy_upper_shadow_max_mult = 0.5;  // upper shadow <= this * body (card =0.5)
input bool   strategy_require_body_color   = true;  // bullish body=>Hammer/BUY, bearish=>HangingMan/SELL
input int    strategy_trend_filter_period  = 0;     // SMA trend STATE; 0 = pure shape (card baseline)
input int    strategy_sl_extreme_bars      = 3;     // N-bar extreme for the stop (card =3)
input double strategy_sl_buffer_pips       = 3.0;   // buffer beyond the extreme, in pips (card =3)
input double strategy_sl_cap_pips          = 20.0;  // hard cap on stop distance, in pips (card P2 cap)
input double strategy_tp_rr                = 2.0;   // take-profit = this * stop distance (card =2R)
input bool   strategy_no_friday_entry      = true;  // card: no Friday entry
input double strategy_spread_cap_pips      = 12.0;  // skip a genuinely wide spread (card spread cap)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// One pip in price terms, scale-correct on 3/5-digit and JPY symbols.
double PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread);
// the pattern / Friday work lives on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   if(strategy_spread_cap_pips <= 0.0)
      return false;

   const double spread   = ask - bid;
   const double cap_dist = strategy_spread_cap_pips * PipSize();
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap_dist > 0.0 && spread > cap_dist)
      return true;

   return false;
  }

// Single-candle entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No Friday entry (card filter). Broker-time weekday of the forming bar.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Closed-bar OHLC of the just-completed candle (the trigger EVENT). ---
   // perf-allowed: bespoke single-candle pattern math on fixed closed-bar shift 1.
   const double o1 = iOpen(_Symbol, _Period, 1);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return false;

   const double body  = MathAbs(c1 - o1);
   const double lower = MathMin(o1, c1) - l1;
   const double upper = h1 - MathMax(o1, c1);

   const double pip = PipSize();
   if(pip <= 0.0)
      return false;

   const double body_min = strategy_body_min_pips * pip;

   // --- Pattern SHAPE: small body, long lower shadow, small upper shadow. ---
   const bool shape_ok = (body > body_min) &&
                         (body > 0.0) &&
                         (lower >= strategy_lower_shadow_mult * body) &&
                         (upper <= strategy_upper_shadow_max_mult * body);
   if(!shape_ok)
      return false;

   // --- Direction. Default: disambiguate by body color so one shape gives one
   //     deterministic signal per bar (not both BUY and SELL on the same bar). ---
   bool want_buy  = false;
   bool want_sell = false;
   if(strategy_require_body_color)
     {
      if(c1 > o1)      want_buy  = true;  // bullish body  => Hammer
      else if(c1 < o1) want_sell = true;  // bearish body  => Hanging-Man
      else             return false;      // doji body — no direction
     }
   else
     {
      // Pure-shape (card baseline): the shape alone qualifies. Without a body
      // color or trend disambiguator there is no directional bias, so fall back
      // to body color anyway to keep one signal per bar deterministic.
      if(c1 >= o1) want_buy = true; else want_sell = true;
     }

   // --- Optional trend STATE filter (SMA). Hammer wants a down context (price
   //     below SMA); Hanging-Man wants an up context (price above SMA). ---
   if(strategy_trend_filter_period > 0)
     {
      const double sma = QM_SMA(_Symbol, _Period, strategy_trend_filter_period, 1);
      if(sma <= 0.0)
         return false;
      if(want_buy  && !(c1 < sma)) return false;
      if(want_sell && !(c1 > sma)) return false;
     }

   if(!want_buy && !want_sell)
      return false;

   const QM_OrderType otype = want_buy ? QM_BUY : QM_SELL;

   // --- Stop: N-bar extreme of the closed bars (shift 1..N) +/- buffer, capped. ---
   // perf-allowed: bespoke structural stop from raw closed-bar extremes.
   int    bars = strategy_sl_extreme_bars;
   if(bars < 1) bars = 1;
   const double buffer = strategy_sl_buffer_pips * pip;

   double sl_price = 0.0;
   if(want_buy)
     {
      const int idx = iLowest(_Symbol, _Period, MODE_LOW, bars, 1);
      if(idx < 0) return false;
      const double ll = iLow(_Symbol, _Period, idx);
      if(ll <= 0.0) return false;
      sl_price = ll - buffer;
     }
   else
     {
      const int idx = iHighest(_Symbol, _Period, MODE_HIGH, bars, 1);
      if(idx < 0) return false;
      const double hh = iHigh(_Symbol, _Period, idx);
      if(hh <= 0.0) return false;
      sl_price = hh + buffer;
     }

   // --- Entry reference price and stop-distance (with the P2 cap). ---
   const double entry = want_buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double stop_dist = MathAbs(entry - sl_price);
   if(stop_dist <= 0.0)
      return false;

   // Hard cap the stop distance (card P2 cap = 20 pips); re-derive the SL price.
   const double cap_dist = strategy_sl_cap_pips * pip;
   if(cap_dist > 0.0 && stop_dist > cap_dist)
     {
      stop_dist = cap_dist;
      sl_price  = want_buy ? (entry - stop_dist) : (entry + stop_dist);
     }

   // --- Take profit: tp_rr * stop distance from entry. ---
   const double tp_price = want_buy ? (entry + strategy_tp_rr * stop_dist)
                                    : (entry - strategy_tp_rr * stop_dist);

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_TM_NormalizePrice(_Symbol, sl_price);
   req.tp     = QM_TM_NormalizePrice(_Symbol, tp_price);
   req.reason = want_buy ? "hammer_long" : "hanging_man_short";
   return true;
  }

// Fixed SL/TP only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
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
