#property strict
#property version   "5.0"
#property description "QM5_11593 robo-midnight-hammer-adx-d1 — Midnight Hammer / Shooting-Star + ADX (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11593 robo-midnight-hammer-adx-d1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         strategy "Midnight", pages 109-110.
// Card: artifacts/cards_approved/QM5_11593_robo-midnight-hammer-adx-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1 = NY-Close = the midnight-anchored daily bar):
//   The single closed daily bar (shift 1) IS the midnight-anchored candle.
//   Its open/close at midnight broker time is what "Midnight" refers to;
//   on D1 there is no intraday clock to gate, so we read the closed bar.
//
//   Trigger EVENT (exactly one per bar — no two-cross trap):
//     LONG  : prior D1 bar is a HAMMER
//             - bottom tail (Low..body-bottom) >= hammer_tail_body_mult * body
//             - upper tail  <= upper_tail_pct of the bottom tail
//     SHORT : prior D1 bar is a SHOOTING STAR
//             - top tail (body-top..High) >= hammer_tail_body_mult * body
//             - lower tail <= upper_tail_pct of the top tail
//
//   Direction / strength STATES (ADX/DI at shift 1):
//     ADX main  > adx_main_min
//     LONG  : +DI > -DI, +DI > di_dir_min, -DI < di_opp_max
//     SHORT : -DI > +DI, -DI > di_dir_min, +DI < di_opp_max
//
//   Stop  : prior D1 Low (long) / prior D1 High (short).
//   Take  : take_rr * stop-distance fixed TP (source closes EOD; factory uses
//           a fixed RR take, configurable, with EOD-style exit as backstop via
//           max-hold).
//   Entry : at the open of the new (current) D1 bar => fire on the new closed
//           bar, market order.
//   EMA(24) from the source is context-only (no entry condition) per the card.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11593;
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
input int    strategy_adx_period          = 14;    // ADX / DI period
input double strategy_adx_main_min         = 20.0; // ADX main line must exceed this
input double strategy_di_dir_min           = 20.0; // directional DI must exceed this
input double strategy_di_opp_max           = 20.0; // opposite DI must stay below this
input double strategy_hammer_tail_body_mult = 3.0; // long tail >= mult * body
input double strategy_upper_tail_pct       = 50.0; // short tail <= this % of long tail
input double strategy_take_rr              = 2.0;  // TP = take_rr * stop distance
input double strategy_spread_pct_of_stop   = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — pattern/ADX work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled
// spread (ask == bid in the tester).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Reference stop distance = prior-bar range proxy via High-Low at shift 1.
   const double hi1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double lo1 = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double stop_distance = hi1 - lo1;
   if(stop_distance <= 0.0)
      return false; // no usable range yet — defer to entry gate, do not block

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The closed
// bar at shift 1 is the midnight-anchored daily candle we evaluate; entry fires
// at the open of the current (new) D1 bar via a market order.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Midnight-anchored candle = the just-closed D1 bar (shift 1). ----------
   // D1 on DXZ = NY-Close, so this bar opened/closed at broker midnight.
   // Make the midnight anchor explicit (documents intent; no fragile clock gate).
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const datetime bar_open_utc    = QM_BrokerToUTC(bar_open_broker);
   if(bar_open_utc <= 0)
      return false;

   // --- Closed-bar OHLC (bespoke candle math — perf-allowed single reads). ----
   const double o1 = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double h1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double l1 = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return false;

   const double body       = MathAbs(c1 - o1);
   const double body_top   = MathMax(o1, c1);
   const double body_bot   = MathMin(o1, c1);
   const double upper_tail = h1 - body_top;   // wick above the body
   const double lower_tail = body_bot - l1;   // wick below the body

   // Degenerate doji with zero body — ratios undefined; skip.
   if(body <= 0.0)
      return false;

   // --- ADX / DI STATES (closed bar, shift 1). --------------------------------
   const double adx_main = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double di_plus  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double di_minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(adx_main <= 0.0 || di_plus <= 0.0 || di_minus <= 0.0)
      return false;
   if(adx_main <= strategy_adx_main_min)
      return false;

   const double tail_mult = strategy_hammer_tail_body_mult;
   const double upper_cap = strategy_upper_tail_pct / 100.0;

   // --- LONG: hammer (long lower tail, small upper tail) + bullish DI. --------
   const bool is_hammer = (lower_tail >= tail_mult * body) &&
                          (upper_tail <= upper_cap * lower_tail);
   const bool long_dir  = (di_plus > di_minus) &&
                          (di_plus > strategy_di_dir_min) &&
                          (di_minus < strategy_di_opp_max);

   // --- SHORT: shooting star (long upper tail, small lower tail) + bearish DI. -
   const bool is_star   = (upper_tail >= tail_mult * body) &&
                          (lower_tail <= upper_cap * upper_tail);
   const bool short_dir = (di_minus > di_plus) &&
                          (di_minus > strategy_di_dir_min) &&
                          (di_plus < strategy_di_opp_max);

   if(is_hammer && long_dir)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Stop = prior D1 Low; TP = take_rr * stop distance.
      const double sl = QM_StopRulesNormalizePrice(_Symbol, l1);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "midnight_hammer_long";
      return true;
     }

   if(is_star && short_dir)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      // Stop = prior D1 High; TP = take_rr * stop distance.
      const double sl = QM_StopRulesNormalizePrice(_Symbol, h1);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "midnight_star_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Source closes at end of the same daily candle. With a fixed RR take + the
// prior-bar structural stop in place, the position resolves on SL/TP; no
// separate discretionary exit is needed (factory variant = fixed-TP test).
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
