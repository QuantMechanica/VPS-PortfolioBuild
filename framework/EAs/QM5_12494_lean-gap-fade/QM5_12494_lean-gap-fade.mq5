#property strict
#property version   "5.0"
#property description "QM5_12494 lean-gap-fade — Boundary gap fade, target = gap fill (M1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12494 lean-gap-fade
// -----------------------------------------------------------------------------
// Source: QuantConnect Lean PriceGapMeanReversionAlpha.py (commit 261366a7...).
// Card: artifacts/cards_approved/QM5_12494_lean-gap-fade.md (g0_status APPROVED).
//
// *** .DWX GAP REALITY (load-bearing) ***
//   The Lean source fades a "large price gap" using a 3-sigma one-bar return on
//   M1 US-equity data. On Darwinex .DWX CFDs that literal rule is INFEASIBLE:
//   .DWX index/FX CFDs are GAPLESS intraday — open[0] == close[1] within a
//   trading session, so the only genuine gaps are at SESSION / WEEK boundaries
//   (Friday close -> Monday open, and each broker-day's first bar vs the prior
//   day's last close). A 3-sigma intraday-return fade would fire on noise, not
//   on a real gap, and the "gap fill" target would be meaningless.
//
//   Reframe (build-prompt directive): a genuine GAP is a difference between the
//   prior bar's CLOSE and the current bar's OPEN that exceeds a threshold, and
//   ONLY at a session/week boundary (detected in broker time). The gap = STATE;
//   the fade entry (price moving back toward the prior close) = a single trigger
//   EVENT; the target = the gap fill (prior close).
//
//   FLAG: gap availability on .DWX is limited to week/session boundaries, so the
//   realized trade frequency will be far below the card's ~80/yr/symbol (which
//   assumed continuous US-cash intraday gaps). This is the only honest port.
//
// Mechanics (M1, closed-bar reads):
//   Boundary STATE : current bar is the FIRST bar of a new broker DAY (the
//                    prior bar belongs to an earlier broker day). This also
//                    captures the Friday->Monday week boundary as the strongest
//                    case. Broker day derived via QM_BrokerToUTC bucketing.
//   Gap STATE      : gap = open[0] - close[1]. Sigma = QM_StdDev(stdev_lookback)
//                    of M1 closes (price units, source's StandardDeviation(100)).
//                    A gap qualifies if |gap| >= sigma_trigger * sigma.
//   Fade direction : gap UP  (open > prior close) -> fade SHORT, target = fill.
//                    gap DOWN (open < prior close) -> fade LONG,  target = fill.
//   Trigger EVENT  : price has begun retracing toward the fill (not chasing the
//                    gap further). SHORT requires bid below the gap open; LONG
//                    requires ask above the gap open. One position per magic.
//   Target (TP)    : prior close = the gap fill.
//   Stop           : ATR(atr_period) * atr_stop_mult beyond the gap open,
//                    clamped to a sane [min,max]*ATR band.
//   Time exit      : close after hold_bars M1 bars (source's 5-bar expiry).
//   Spread guard   : skip only a genuinely WIDE spread (fail-open on .DWX
//                    zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12494;
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
input int    strategy_stdev_lookback    = 100;   // StandardDeviation(N) of M1 closes (source: 100)
input double strategy_sigma_trigger     = 3.0;   // gap must exceed sigma_trigger * stdev (source: 3.0)
input int    strategy_hold_bars         = 5;     // time-stop: close after N M1 bars (source: 5)
input int    strategy_atr_period        = 14;    // ATR period for the hard stop
input double strategy_atr_stop_mult     = 2.0;   // stop distance = mult * ATR beyond the gap open
input double strategy_stop_min_atr      = 0.80;  // clamp: stop >= this * ATR
input double strategy_stop_max_atr      = 3.50;  // clamp: stop <= this * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip if genuine spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (gap/boundary math; single closed-bar reads are perf-allowed).
// -----------------------------------------------------------------------------

// Broker-day index in UTC space (days since epoch). A new broker day => the
// boundary where .DWX produces a genuine open gap. Using QM_BrokerToUTC keeps
// the day bucket aligned to the broker's NY-Close convention (DST-aware).
long BrokerDayIndex(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return (long)(utc / 86400);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: genuine-wide-spread guard only. Fail-open on .DWX
// zero modeled spread (ask==bid reads 0 spread in the tester).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Fade entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Boundary STATE: the current bar must be the first bar of a new broker
   //     day. That is the only place .DWX produces a genuine open gap. ---
   const datetime cur_bar_time  = iTime(_Symbol, _Period, 0); // perf-allowed: bar-open time
   const datetime prev_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed
   if(cur_bar_time <= 0 || prev_bar_time <= 0)
      return false;
   if(BrokerDayIndex(cur_bar_time) == BrokerDayIndex(prev_bar_time))
      return false; // same broker day -> gapless intraday, no real gap here

   // --- Gap STATE: gap = current open - prior close. ---
   const double gap_open    = iOpen(_Symbol, _Period, 0);  // perf-allowed: single closed-bar read
   const double prior_close = iClose(_Symbol, _Period, 1); // perf-allowed
   if(gap_open <= 0.0 || prior_close <= 0.0)
      return false;

   const double gap = gap_open - prior_close;

   // Sigma = StandardDeviation(lookback) of M1 closes (price units), the
   // source's StandardDeviation(100). Threshold = sigma_trigger * sigma.
   const double sigma = QM_StdDev(_Symbol, _Period, strategy_stdev_lookback, 1, PRICE_CLOSE);
   if(sigma <= 0.0)
      return false;
   const double threshold = strategy_sigma_trigger * sigma;
   if(MathAbs(gap) < threshold)
      return false;

   // Fade direction: gap up -> short (expect fade down to fill); gap down ->
   // long (expect fade up to fill).
   const int direction = (gap > 0.0) ? -1 : 1; // -1 short, +1 long

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // --- Trigger EVENT: price has begun retracing toward the fill, i.e. it is
   //     not extending the gap further away from the prior close. Single check;
   //     no two-cross-same-bar trap (boundary STATE + this one EVENT). ---
   if(direction < 0)
     {
      // gap up: only fade if price is at/below the gap open (rolling toward fill)
      if(!(bid <= gap_open))
         return false;
     }
   else
     {
      // gap down: only fade if price is at/above the gap open (rolling toward fill)
      if(!(ask >= gap_open))
         return false;
     }

   // --- Stop: ATR * mult beyond the gap open, clamped to a sane band. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   double stop_distance = strategy_atr_stop_mult * atr_value;
   stop_distance = MathMax(stop_distance, strategy_stop_min_atr * atr_value);
   stop_distance = MathMin(stop_distance, strategy_stop_max_atr * atr_value);
   if(stop_distance <= 0.0)
      return false;

   const QM_OrderType side        = (direction > 0) ? QM_BUY : QM_SELL;
   const double        entry_price = (direction > 0) ? ask : bid;

   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, entry_price, stop_distance);
   const double tp = QM_StopRulesNormalizePrice(_Symbol, prior_close); // gap fill
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;            // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (direction > 0) ? "gap_fade_long_fill" : "gap_fade_short_fill";
   return true;
  }

// No active management beyond the fixed ATR stop and the gap-fill TP. The
// time-stop lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time-stop: close after hold_bars M1 bars have elapsed since position open.
// (TP at the gap fill and the ATR stop are handled by the broker order.)
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(strategy_hold_bars <= 0)
      return false;

   datetime open_time = 0;
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found = true;
      break;
     }
   if(!found || open_time <= 0)
      return false;

   // Period seconds * hold_bars = max hold duration. PeriodSeconds() honors the
   // chart timeframe (M1 -> 60s) without a per-EA new-bar reimplementation.
   const int    bar_secs  = PeriodSeconds(_Period);
   const datetime deadline = open_time + (datetime)(strategy_hold_bars * bar_secs);
   return (TimeCurrent() >= deadline);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12494\",\"strategy\":\"lean-gap-fade\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
