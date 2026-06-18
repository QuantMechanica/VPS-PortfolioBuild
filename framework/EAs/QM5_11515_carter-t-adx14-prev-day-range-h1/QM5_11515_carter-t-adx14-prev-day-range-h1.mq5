#property strict
#property version   "5.0"
#property description "QM5_11515 carter-t-adx14-prev-day-range-h1 — ADX(14) range filter + prior-day range breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11515 carter-t-adx14-prev-day-range-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//   Systems" (self-published 2014), System #11.
// Card: artifacts/cards_approved/QM5_11515_carter-t-adx14-prev-day-range-h1.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, H1 base TF):
//   Trend STATE  : ADX(14) on H1 (closed bar). The card's edge is a rangebound
//                  fade — the break is only acted on when ADX is BELOW the
//                  range threshold (no strong trend). Direction of the gate is
//                  configurable via strategy_adx_below_is_signal.
//   Range STATE  : prior D1 bar's High / Low, read once per closed H1 bar via
//                  explicit-TF iHigh/iLow at D1 shift 1 (perf-allowed; one read
//                  per new bar, cached). This is the prior-day range — a STATE.
//   Trigger EVENT: the H1 close breaks BEYOND a prior-day extreme on THIS closed
//                  bar while the PREVIOUS closed H1 bar had NOT yet broken it.
//                  That "fresh break" is a single event per bar — it cannot
//                  collide with the opposite-side event on the same bar, so the
//                  two-cross zero-trade trap is avoided.
//                    - close[1] > pd_high + offset AND close[2] <= pd_high+offset
//                      -> upside break  -> LONG (continuation of the broken range)
//                    - close[1] < pd_low  - offset AND close[2] >= pd_low -offset
//                      -> downside break -> SHORT
//   Stop / Take  : fixed pips from the card (SL 30 pips, TP 60 pips = 2R),
//                  scaled correctly via QM_StopFixedPips / QM_TakeRR (pip-aware).
//   Day boundary : broker time (D1 bars on the .DWX feed are broker-time days).
//   No-Friday    : optional gate — no fresh entry on Friday (card filter).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// NOTE on card vs build directive: the card's literal text stages a false-break
// then a BuyStop pending order at the OPPOSITE extreme. Per the build directive
// the prior-day range is modelled as STATE and the H1 close breaking a prior-day
// extreme is the SINGLE market-entry EVENT (the framework single-entry path uses
// market orders, not session-expiry pending orders). The break offset, ADX
// threshold, SL/TP and direction-of-gate are all P3-sweepable inputs.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11515;
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
input double strategy_adx_threshold        = 35.0;   // ADX(14) range/trend gate level
input bool   strategy_adx_below_is_signal  = true;   // true: trade when ADX < threshold (card: rangebound fade)
input int    strategy_adx_period           = 14;     // ADX period
input double strategy_break_offset_pips     = 15.0;  // break offset beyond prior-day extreme (pips)
input double strategy_sl_pips               = 30.0;  // stop-loss distance (pips, card value)
input double strategy_tp_rr                 = 2.0;   // take-profit as R-multiple (card: 60/30 = 2R)
input bool   strategy_no_friday_entry       = true;  // card filter: no fresh entry on Friday
input double strategy_spread_pct_of_stop    = 50.0;  // skip only a genuinely wide spread (% of stop distance)

// -----------------------------------------------------------------------------
// File-scope cached state — advanced once per closed H1 bar.
// -----------------------------------------------------------------------------
double g_pd_high      = 0.0;   // prior-day (D1 shift 1) high, broker-time day
double g_pd_low       = 0.0;   // prior-day (D1 shift 1) low
double g_close1       = 0.0;   // last closed H1 close (shift 1)
double g_close2       = 0.0;   // previous closed H1 close (shift 2)
double g_adx1         = 0.0;   // ADX(14) at the last closed H1 bar
bool   g_state_ready  = false; // all cached reads valid this bar

// Advance cached strategy state. Called ONCE per closed H1 bar from OnTick
// after the framework QM_IsNewBar() gate. No second timestamp gate here.
void AdvanceState_OnNewBar()
  {
   g_state_ready = false;

   // Prior-day range (broker-time D1). Explicit-TF closed-bar reads, one each
   // per new bar — perf-allowed for bespoke prior-day-extreme structural logic.
   g_pd_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: single prior-day read
   g_pd_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: single prior-day read

   g_close1  = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   g_close2  = iClose(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read

   g_adx1    = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);

   if(g_pd_high <= 0.0 || g_pd_low <= 0.0 || g_pd_low >= g_pd_high)
      return;
   if(g_close1 <= 0.0 || g_close2 <= 0.0)
      return;
   if(g_adx1 < 0.0)
      return;

   g_state_ready = true;
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

   // Reference stop distance (price) for the spread cap, scaled per symbol.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate) and that
// AdvanceState_OnNewBar() has already refreshed cached state this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_state_ready)
      return false;

   // --- Trend STATE gate: ADX vs threshold (card edge = rangebound fade). ---
   const bool adx_ok = strategy_adx_below_is_signal
                       ? (g_adx1 < strategy_adx_threshold)
                       : (g_adx1 > strategy_adx_threshold);
   if(!adx_ok)
      return false;

   // --- No-Friday-entry filter (broker time). ---
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Range STATE: prior-day extremes + break offset (pip-scaled). ---
   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_break_offset_pips);
   if(offset < 0.0)
      return false;
   const double up_level   = g_pd_high + offset; // break level above prior-day high
   const double down_level = g_pd_low  - offset; // break level below prior-day low

   // --- Trigger EVENT: a FRESH break of a prior-day extreme on the last closed
   //     bar that the bar before had NOT yet broken. Single event per side per
   //     bar — the two sides are mutually exclusive (up_level > down_level), so
   //     no same-bar two-cross collision is possible. ---
   const bool fresh_up   = (g_close1 > up_level   && g_close2 <= up_level);
   const bool fresh_down = (g_close1 < down_level && g_close2 >= down_level);

   if(!fresh_up && !fresh_down)
      return false;

   const QM_OrderType side = fresh_up ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, (int)strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = fresh_up ? "pd_range_break_long" : "pd_range_break_short";
   return true;
  }

// Fixed SL/TP only; no active trail/scale management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP (card: TP 60 / SL 30 pips).
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
