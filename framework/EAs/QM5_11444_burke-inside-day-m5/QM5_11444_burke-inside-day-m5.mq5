#property strict
#property version   "5.0"
#property description "QM5_11444 burke-inside-day-m5 — D1 Inside Day -> M5 EMA20 range breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11444 burke-inside-day-m5
// -----------------------------------------------------------------------------
// Source: Stacey Burke Trading Playbook (Inside Day -> M5 EMA20 breakout).
// Card: artifacts/cards_approved/QM5_11444_burke-inside-day-m5.md (g0 APPROVED).
//
// Mechanics (base TF = M5; pattern TF = D1; closed-bar reads only):
//   Inside Day STATE  : prior CLOSED daily bar (D1 shift 1) is contained inside
//                       the bar before it (D1 shift 2):
//                           High[D1,1] < High[D1,2]  AND  Low[D1,1] > Low[D1,2].
//                       The inside-day range = [Low[D1,1], High[D1,1]] is the
//                       breakout reference. Deterministic from CLOSED daily bars
//                       -> gapless-safe (no intraday-gap dependence).
//   Session STATE     : current M5 closed bar (in UTC, derived from broker time
//                       via QM_BrokerToUTC) is inside London (07:00-12:00 UTC) or
//                       NY (13:00-17:00 UTC).
//   Breakout EVENT    : the SINGLE event is the first M5 bar that closes through
//                       the inside-day range in the EMA20 direction:
//                       LONG  -> Close[M5,1] > EMA20  AND  Close[M5,1] > IDH
//                                AND prior bar Close[M5,2] <= IDH  (fresh cross)
//                       SHORT -> mirror with IDL.
//   Stop              : LONG  -> IDH - sl_buffer_pips (back inside the range)
//                       SHORT -> IDL + sl_buffer_pips. Stop DISTANCE capped at
//                       min( range*sl_range_cap_mult , sl_max_pips ).
//   Take profit       : range-width projection from the breakout level:
//                       LONG  -> entry + (IDH - IDL) ; SHORT -> entry - (IDH - IDL).
//   Spread guard      : fail-open on .DWX zero modeled spread; block only a
//                       genuinely wide spread > spread_cap_pips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11444;
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
input int    strategy_ema_period         = 20;     // M5 EMA period (entry timing filter)
// Session windows in UTC (London + NY). Broker time is converted to UTC per bar.
input int    strategy_london_start_utc   = 7;      // London window start hour (UTC, inclusive)
input int    strategy_london_end_utc     = 12;     // London window end hour (UTC, exclusive)
input int    strategy_ny_start_utc       = 13;     // NY window start hour (UTC, inclusive)
input int    strategy_ny_end_utc         = 17;     // NY window end hour (UTC, exclusive)
input int    strategy_sl_buffer_pips     = 5;      // stop placed this many pips inside the range
input double strategy_sl_range_cap_mult  = 1.5;    // stop distance cap = range * this mult ...
input int    strategy_sl_max_pips        = 80;     // ... and also capped at this many pips
input int    strategy_sl_min_pips        = 5;      // floor on stop distance (avoid degenerate stops)
input int    strategy_spread_cap_pips    = 15;     // block only a genuinely wide spread

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// True if the M5 closed bar's UTC hour falls inside London or NY window.
bool BurkeInSession(const int utc_hour)
  {
   const bool in_london = (utc_hour >= strategy_london_start_utc &&
                           utc_hour <  strategy_london_end_utc);
   const bool in_ny     = (utc_hour >= strategy_ny_start_utc &&
                           utc_hour <  strategy_ny_end_utc);
   return (in_london || in_ny);
  }

// Read the inside-day reference levels from the two prior CLOSED daily bars.
// Returns true and fills IDH/IDL only when a valid inside day exists.
bool BurkeInsideDay(double &idh, double &idl)
  {
   idh = 0.0;
   idl = 0.0;
   // perf-allowed: bespoke structural cross-TF OHLC reads of CLOSED daily bars.
   const double h1 = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: inside day (yesterday)
   const double l1 = iLow(_Symbol,  PERIOD_D1, 1);  // perf-allowed: inside day (yesterday)
   const double h2 = iHigh(_Symbol, PERIOD_D1, 2);  // perf-allowed: day before
   const double l2 = iLow(_Symbol,  PERIOD_D1, 2);  // perf-allowed: day before
   if(h1 <= 0.0 || l1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
      return false;
   if(!(h1 < h2 && l1 > l2))   // inside-day containment
      return false;
   if(!(h1 > l1))              // sane range
      return false;
   idh = h1;
   idl = l1;
   return true;
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

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;
   return false;
  }

// Inside-day breakout entry. Caller guarantees QM_IsNewBar() == true (M5 closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Session STATE: M5 closed bar (shift 1) UTC hour in London/NY ---
   const datetime bar_broker = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar open time
   if(bar_broker <= 0)
      return false;
   const datetime bar_utc = QM_BrokerToUTC(bar_broker);
   MqlDateTime ut;
   ZeroMemory(ut);
   TimeToStruct(bar_utc, ut);
   if(!BurkeInSession(ut.hour))
      return false;

   // --- Inside Day STATE: range reference from CLOSED daily bars ---
   double idh = 0.0, idl = 0.0;
   if(!BurkeInsideDay(idh, idl))
      return false;
   const double range = idh - idl;
   if(range <= 0.0)
      return false;

   // --- EMA20 on the M5 base TF (closed bar) ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   // --- Breakout EVENT: fresh close through the inside-day range in EMA dir ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar breakout read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: prior closed-bar breakout read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   QM_OrderType side;
   bool is_long = false;
   if(close1 > ema && close1 > idh && close2 <= idh)
     {
      side = QM_BUY;
      is_long = true;
     }
   else if(close1 < ema && close1 < idl && close2 >= idl)
     {
      side = QM_SELL;
      is_long = false;
     }
   else
      return false;

   // --- Entry, stop, take ---
   const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double min_dist  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_min_pips);
   const double max_pips  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   double cap_dist = range * strategy_sl_range_cap_mult;
   if(max_pips > 0.0 && cap_dist > max_pips)
      cap_dist = max_pips;

   // Literal stop level: just inside the broken range edge.
   double sl_level = is_long ? (idh - buffer) : (idl + buffer);
   double sl_dist  = is_long ? (entry - sl_level) : (sl_level - entry);
   if(sl_dist < min_dist)
      sl_dist = min_dist;          // floor: avoid degenerate near-zero stop
   if(cap_dist > 0.0 && sl_dist > cap_dist)
      sl_dist = cap_dist;          // cap: range*mult, ceilinged at sl_max_pips
   if(sl_dist <= 0.0)
      return false;

   const double sl = is_long ? QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist)
                             : QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist);
   const double tp = is_long ? QM_StopRulesNormalizePrice(_Symbol, entry + range)
                             : QM_StopRulesNormalizePrice(_Symbol, entry - range);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = is_long ? "burke_inside_day_long" : "burke_inside_day_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Fixed stop/target only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// SL/TP handle the exit; no discretionary close.
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
