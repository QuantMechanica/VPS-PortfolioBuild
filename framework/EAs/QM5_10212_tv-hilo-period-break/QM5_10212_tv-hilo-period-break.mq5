#property strict
#property version   "5.0"
#property description "QM5_10212 TradingView High Low Period Breakout Hold"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10212 tv-hilo-period-break
// -----------------------------------------------------------------------------
// Source: TradingView "High/Low Breakout Statistical Analysis Strategy"
//         (author EdgeTools, https://www.tradingview.com/script/q5NHaxo5/).
//
// Mechanic (per APPROVED card QM5_10212):
//   Reference period  = previous broker DAY (D1 prior bar) high / low.
//   Entry  : on a CLOSED H1 bar, go LONG when the H1 close crosses ABOVE the
//            prior-day high; go SHORT when it crosses BELOW the prior-day low.
//   Stop   : protective stop at 1.5 * ATR(14). If the opposite side of the
//            prior-day range is CLOSER than the ATR stop, use that side instead.
//   Exit   : fixed hold of 8 H1 bars, OR an early opposite prior-day breakout,
//            whichever comes first.
//   Sizing : framework risk model (RISK_FIXED $1,000 backtest), one position
//            per magic number.
//   Filters: skip new entries if spread > 15% of stop distance; no new entries
//            in the final two bars of the broker day.
//
// Only the five Strategy_* hooks are implemented; all framework wiring below
// the marker is the canonical skeleton and stays intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10212;
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
input ENUM_TIMEFRAMES strategy_signal_tf            = PERIOD_H1;   // intraday baseline TF
input ENUM_TIMEFRAMES strategy_reference_tf         = PERIOD_D1;   // reference-period TF (prior bar = prior day)
input int             strategy_atr_period           = 14;          // ATR period for protective stop
input double          strategy_atr_sl_mult          = 1.5;         // protective stop = mult * ATR
input int             strategy_hold_bars            = 8;           // fixed holding period (signal-TF bars)
input double          strategy_max_spread_stop_frac = 0.15;        // skip entry if spread > frac * stop distance
input int             strategy_no_entry_final_bars  = 2;           // block entries in last N bars of broker day

// -----------------------------------------------------------------------------
// Helpers (no per-EA new-bar gate; OnTick drives the single QM_IsNewBar consume)
// -----------------------------------------------------------------------------

ENUM_TIMEFRAMES Strategy_SignalTF()
  {
   if(strategy_signal_tf == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)_Period;
   return strategy_signal_tf;
  }

// Prior reference-period (prior-day) high/low from the last CLOSED reference bar.
bool Strategy_PriorRange(double &prior_high, double &prior_low)
  {
   prior_high = iHigh(_Symbol, strategy_reference_tf, 1);
   prior_low  = iLow(_Symbol, strategy_reference_tf, 1);
   return (prior_high > 0.0 && prior_low > 0.0 && prior_high > prior_low);
  }

// True only when the broker-day clock is within the final N signal-TF bars.
// Keyed off the current bar-open time (broker time), per .DWX invariant #12.
bool Strategy_InFinalBrokerDayBars()
  {
   if(strategy_no_entry_final_bars <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();
   const int seconds_per_bar = PeriodSeconds(tf);
   if(seconds_per_bar <= 0)
      return false;

   const datetime bar_open = iTime(_Symbol, tf, 0);
   if(bar_open <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   const int seconds_today = dt.hour * 3600 + dt.min * 60 + dt.sec;
   const int seconds_left  = 86400 - seconds_today;
   return (seconds_left <= strategy_no_entry_final_bars * seconds_per_bar);
  }

// Genuine-wide-spread guard ONLY. .DWX quotes ask==bid (0 modeled spread) in the
// tester, so this fails OPEN on zero/equal spread (invariant #1) and blocks only
// a real positive spread wider than frac * stop distance.
bool Strategy_SpreadTooWideForStop(const double stop_distance)
  {
   if(stop_distance <= 0.0 || strategy_max_spread_stop_frac < 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)   // zero/equal spread -> fail open
      return false;

   const double spread = ask - bid;
   return (spread > stop_distance * strategy_max_spread_stop_frac);
  }

// Locate this EA's single open position (by magic + symbol).
bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype,
                             double &price_open,
                             datetime &time_open,
                             ulong &ticket)
  {
   ptype      = POSITION_TYPE_BUY;
   price_open = 0.0;
   time_open  = 0;
   ticket     = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      time_open  = (datetime)PositionGetInteger(POSITION_TIME);
      ticket     = t;
      return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double price_open;
   datetime time_open;
   ulong ticket;
   return Strategy_GetOurPosition(ptype, price_open, time_open, ticket);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Cheap O(1) checks only.
bool Strategy_NoTradeFilter()
  {
   // Keep management/exits live for an open position; only gate new entries.
   if(Strategy_HasOpenPosition())
      return false;

   if(Strategy_InFinalBrokerDayBars())
      return true;

   return false;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true. Lots come from the framework risk
// model inside QM_TM_OpenPosition (req.sl set) — never sized inline here.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(Strategy_InFinalBrokerDayBars())
      return false;

   double prior_high = 0.0;
   double prior_low  = 0.0;
   if(!Strategy_PriorRange(prior_high, prior_low))
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();
   // Off-by-one: compare the two most recent CLOSED bars (1 and 2); the live
   // forming bar (shift 0) is excluded so the cross is confirmed on close.
   const double close_1 = iClose(_Symbol, tf, 1);
   const double close_2 = iClose(_Symbol, tf, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const bool cross_up   = (close_2 <= prior_high && close_1 > prior_high);
   const bool cross_down = (close_2 >= prior_low  && close_1 < prior_low);
   if(cross_up == cross_down)   // neither, or (impossible) both -> no signal
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_distance = atr * strategy_atr_sl_mult;

   if(cross_up)
     {
      req.type  = QM_BUY;
      req.price = ask;
      double sl = req.price - atr_distance;
      // Tighten to the opposite (lower) side of the prior-day range if closer.
      if(prior_low > 0.0 && prior_low < req.price && (req.price - prior_low) < atr_distance)
         sl = prior_low;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = 0.0;
      req.reason = "PRIOR_DAY_HIGH_BREAK_LONG";
     }
   else
     {
      req.type  = QM_SELL;
      req.price = bid;
      double sl = req.price + atr_distance;
      // Tighten to the opposite (upper) side of the prior-day range if closer.
      if(prior_high > 0.0 && prior_high > req.price && (prior_high - req.price) < atr_distance)
         sl = prior_high;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = 0.0;
      req.reason = "PRIOR_DAY_LOW_BREAK_SHORT";
     }

   if(req.price <= 0.0 || req.sl <= 0.0)
      return false;

   const double stop_distance = MathAbs(req.price - req.sl);
   if(stop_distance <= 0.0)
      return false;
   if(Strategy_SpreadTooWideForStop(stop_distance))
      return false;

   return true;
  }

// Called every tick when an open position exists. Card specifies no trailing,
// break-even, or partial-close logic, so this is intentionally empty.
void Strategy_ManageOpenPosition()
  {
   // No active position management per card.
  }

// Return TRUE to close the open position now: fixed hold-bar timer expired OR
// an opposite prior-day breakout (whichever first).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   double price_open;
   datetime time_open;
   ulong ticket;
   if(!Strategy_GetOurPosition(ptype, price_open, time_open, ticket))
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();

   // Fixed holding period: close once N closed signal-TF bars elapsed since entry.
   if(strategy_hold_bars > 0 && time_open > 0)
     {
      const int bars_since_entry = iBarShift(_Symbol, tf, time_open, false);
      if(bars_since_entry >= strategy_hold_bars)
         return true;
     }

   // Early opposite-breakout exit against the current prior-day range.
   double prior_high = 0.0;
   double prior_low  = 0.0;
   if(!Strategy_PriorRange(prior_high, prior_low))
      return false;

   const double close_1 = iClose(_Symbol, tf, 1);
   if(close_1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (close_1 < prior_low);
   return (close_1 > prior_high);
  }

// Optional news-filter override. Defer to the central framework filter.
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

   // Per-closed-bar: entry-signal evaluation. Single QM_IsNewBar consume per
   // tick (invariant #3) — exit/management above use position state, not the
   // new-bar event.
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
