#property strict
#property version   "5.0"
#property description "QM5_11874 usdjpy-24hr-range-breakout — prior-day (D1) range breakout, JPY pairs, H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11874 usdjpy-24hr-range-breakout
// -----------------------------------------------------------------------------
// Source: JanusTrader, "100 Pips Daily Trading System",
//         forexstrategiesresources.com, 2012 (local PDF archive).
// Card: artifacts/cards_approved/QM5_11874_usdjpy-24hr-range-breakout.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads; entry timeframe = H1 per card):
//   Range STATE  : prior completed 24h window = the prior D1 bar (D1 shift 1),
//                  read in BROKER time. High = prior-day high, Low = prior-day
//                  low. The card's "6pm-EST-to-6pm-EST" 24h window maps onto the
//                  broker's NY-Close D1 bar, which is exactly the prior-day
//                  session frame the strategy references. Read once per new D1
//                  bar and cache (perf).
//   Levels       : buy_level  = prior_high + offset_pips
//                  sell_level = prior_low  - offset_pips
//   Trigger EVENT: on a NEW H1 closed bar, if that bar's CLOSE breaks a level
//                  (close > buy_level for long, close < sell_level for short).
//                  Close-based confirmation is correct on gapless .DWX CFDs
//                  (open[0]==close[1]); a raw intrabar pierce would also fire on
//                  the gap-equivalent. ONE direction is the trigger per bar
//                  (buy checked first, else sell) — never two crosses one bar.
//   OCO / single : framework is one-position-per-magic; once a breakout fills,
//                  no second order arms until it closes. This reproduces the
//                  card's "cancel the other side once one triggers" OCO rule.
//   Re-arm       : each side fires at most once per range window (latched), and
//                  the latches reset when a new D1 range is established — this is
//                  the card's "orders expire at the next setup time" rule.
//   Stop / target: fixed pips. SL = sl_pips, TP = tp_pips (card 25 / 50, RR 2.0),
//                  pip-scaled via QM_StopFixedPips / QM_TakeRR so JPY 3-digit
//                  symbols size correctly.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11874;
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
input double strategy_breakout_offset_pips = 7.0;   // breakout buffer beyond range edge
input double strategy_sl_pips              = 25.0;  // fixed stop, in pips
input double strategy_tp_pips              = 50.0;  // fixed target, in pips (RR 2.0)

// -----------------------------------------------------------------------------
// File-scope cached range state (advanced once per new D1 closed bar).
// -----------------------------------------------------------------------------
datetime g_range_d1_time   = 0;     // open time of the D1 bar that defined the range
double   g_buy_level       = 0.0;   // prior_high + offset
double   g_sell_level      = 0.0;   // prior_low  - offset
bool     g_buy_armed       = false; // long not yet triggered this range window
bool     g_sell_armed      = false; // short not yet triggered this range window
bool     g_range_valid     = false;

// Refresh the prior-day range from the prior completed D1 bar (shift 1), in
// broker time. Called only when a new D1 bar has rolled, so it runs at most once
// per trading day. Re-arms both sides (card: orders renewed at each setup time).
void RefreshRange_OnNewDay()
  {
   // perf-allowed: bespoke prior-day session frame; single closed-bar reads of
   // the prior D1 bar in broker time. No per-tick recompute (gated by new-D1).
   const datetime d1_time = iTime(_Symbol, PERIOD_D1, 1);
   if(d1_time <= 0)
      return;

   const double prior_high = iHigh(_Symbol, PERIOD_D1, 1);
   const double prior_low  = iLow(_Symbol,  PERIOD_D1, 1);
   if(prior_high <= 0.0 || prior_low <= 0.0 || prior_high <= prior_low)
      return;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_breakout_offset_pips);

   g_range_d1_time = d1_time;
   g_buy_level     = prior_high + offset;
   g_sell_level    = prior_low  - offset;
   g_buy_armed     = true;   // re-arm at the new setup window
   g_sell_armed    = true;
   g_range_valid   = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No standing block; this strategy trades any H1 bar that breaks the cached
// range. Time / range gating lives in the entry trigger. O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Breakout entry on the H1 closed bar. Caller guarantees QM_IsNewBar()==true.
// Reads only the cached range levels + the just-closed H1 bar's close.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (OCO: no second side while one is live).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_range_valid)
      return false;

   // Just-closed H1 bar (shift 1) close — gapless-correct breakout confirmation.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // ONE trigger per bar: buy-break checked first, else sell-break. Latches
   // prevent re-firing the same side until a new range window re-arms it.
   if(g_buy_armed && close1 > g_buy_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      g_buy_armed  = false; // consumed for this range window
      g_sell_armed = false; // OCO: cancel the opposite side
      req.type   = QM_BUY;
      req.price  = 0.0;     // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "range_breakout_long";
      return true;
     }

   if(g_sell_armed && close1 < g_sell_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      g_sell_armed = false; // consumed for this range window
      g_buy_armed  = false; // OCO: cancel the opposite side
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "range_breakout_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only; no active management (card has no trail/BE rule).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; SL/TP close the trade. The card's only "exit" is the
// next-setup-time order cancellation, handled by the re-arm latches, not here.
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

   // Advance the prior-day range once per new D1 bar (re-arms both sides).
   if(iTime(_Symbol, PERIOD_D1, 1) != g_range_d1_time)
      RefreshRange_OnNewDay();

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
