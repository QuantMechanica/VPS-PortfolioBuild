#property strict
#property version   "5.0"
#property description "QM5_11513 carter-t-ema4-11-adx13-d1 — EMA(4/11) cross + ADX(13) trend-strength (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11513 carter-t-ema4-11-adx13-d1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #8, self-published 2014.
// Card: artifacts/cards_approved/QM5_11513_carter-t-ema4-11-adx13-d1.md
//       (g0_status APPROVED).
//
// Mechanics (both directions, closed-bar reads at shift 1/2):
//   Trigger EVENT : EMA(4) crosses EMA(11) on the just-closed bar.
//                   cross up   -> LONG candidate.
//                   cross down -> SHORT candidate.
//   ADX STATE     : ADX(13) main > adx_threshold  (trend is trending, not ranging).
//   DI STATE      : LONG  needs +DI > -DI ;  SHORT needs -DI > +DI.
//   Exit          : opposite EMA(4/11) cross (indicator-driven exit; no fixed TP).
//   Stop          : fixed fallback = entry -/+ sl_pips pips (wide D1 stop).
//   Filters       : no Friday entry; spread guard only blocks a genuinely wide
//                   spread (fail-open on .DWX zero modeled spread).
//
// The EMA cross is the SINGLE trigger EVENT; ADX/+DI/-DI are STATES evaluated on
// the same closed bar. This avoids the two-cross-same-bar zero-trade trap: we do
// not require two coincident crossover events.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11513;
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
input int    strategy_ema_fast_period    = 4;      // fast EMA cross leg
input int    strategy_ema_slow_period    = 11;     // slow EMA cross leg
input int    strategy_adx_period         = 13;     // ADX and DI period
input double strategy_adx_threshold      = 22.0;   // ADX must be strictly above this value
input int    strategy_sl_pips            = 100;    // fixed fallback stop
input int    strategy_tp_pips            = 0;      // 0=EMA reversal exit; test 100/200/300 fixed TP
input bool   strategy_no_friday_entry    = true;   // suppress new Friday entries
input int    strategy_spread_cap_pips    = 30;     // maximum entry spread; zero modeled spread passes

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(strategy_spread_cap_pips <= 0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return true;

   // .DWX tester quotes may have ask == bid. Only a genuinely positive,
   // over-cap spread blocks trading.
   return (ask > bid && (ask - bid) > spread_cap);
  }

// Both-direction entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_slow_period <= strategy_ema_fast_period ||
      strategy_adx_period <= 0 ||
      strategy_adx_threshold < 0.0 ||
      strategy_sl_pips <= 0 ||
      strategy_tp_pips < 0)
      return false;

   // The crossover is the one trigger event, evaluated on the just-closed D1
   // bar against the preceding closed D1 bar.
   const double ema_fast_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   if(!cross_up && !cross_down)
      return false;

   // ADX strength and DI direction are states, not additional crossover
   // events, so no coincident-event requirement is introduced.
   const double adx_main = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   if(adx_main <= strategy_adx_threshold)
      return false;

   const double plus_di  = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_adx_period, 1);

   QM_OrderType side;
   if(cross_up && plus_di > minus_di)
      side = QM_BUY;
   else if(cross_down && minus_di > plus_di)
      side = QM_SELL;
   else
      return false;

   const double entry = SymbolInfoDouble(_Symbol, (side == QM_BUY ? SYMBOL_ASK : SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;

   double tp = 0.0;
   if(strategy_tp_pips > 0)
     {
      const double reward_risk = (double)strategy_tp_pips / (double)strategy_sl_pips;
      tp = QM_TakeRR(_Symbol, side, entry, sl, reward_risk);
      if(tp <= 0.0)
         return false;
     }

   req.type   = side;
   req.price  = 0.0; // framework fills the market price
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema4_11_cross_up_adx13" : "ema4_11_cross_down_adx13";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active management beyond the fixed fallback stop. The indicator-driven
// exit (opposite EMA cross) lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Indicator-driven exit: close when EMA(4/11) crosses in the direction opposite
// to the open position. One fresh cross event at shift 1 (vs shift 2).
bool Strategy_ExitSignal()
  {
   // Positive TP values select the card-authorized fixed-TP comparison mode;
   // zero retains the baseline opposite-EMA-cross exit.
   if(strategy_tp_pips > 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   if(!cross_up && !cross_down)
      return false;

   // Determine the direction of the currently-open position for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // A bearish cross exits a long; a bullish cross exits a short.
   if(have_long && cross_down)
      return true;
   if(have_short && cross_up)
      return true;
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
