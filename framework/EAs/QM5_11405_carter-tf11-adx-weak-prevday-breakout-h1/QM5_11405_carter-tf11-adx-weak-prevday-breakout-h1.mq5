#property strict
#property version   "5.0"
#property description "QM5_11405 carter-tf11-adx-weak-prevday-breakout — ADX-weak prior-day breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11405 carter-tf11-adx-weak-prevday-breakout-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Trend Following Systems" (2014), Strategy #11.
// Card: artifacts/cards_approved/QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1.md
//       (g0_status: APPROVED).
//
// Mechanics (H1 base, closed-bar reads at shift 1):
//   Regime STATE : ADX(14) on H1 < adx_weak_threshold  -> weak/ranging trend.
//                  This filters for consolidation, NOT a strong-trend fade.
//   Prior-day levels (STATE): yesterday's D1 High / Low from PERIOD_D1 shift 1.
//                  Read once per new D1 session via QM_BrokerToUTC broker-day
//                  boundary on the H1 bar timestamp (no per-EA new-bar gate).
//   Probe EVENT  : on the LAST CLOSED H1 bar (shift 1) price punched through
//                  the OPPOSITE prior-day extreme by buffer pips:
//                    LONG setup : Low[1]  < prevDayLow  - buffer  (false breakdown)
//                    SHORT setup: High[1] > prevDayHigh + buffer  (false breakout)
//                  This is a genuine intraday excursion on the H1 bar (Low/High),
//                  NOT an open-gap rule -> valid on gapless .DWX CFDs.
//   Entry        : place a single pending STOP order at the SAME-SIDE extreme:
//                    LONG : BUYSTOP  at prevDayHigh + buffer
//                    SHORT: SELLSTOP at prevDayLow  - buffer
//                  Expires (cancels) at end of the current broker day.
//   Stop         : entry -/+ sl_pips (capped at 30 pips per card; P2 cap 40).
//   Take profit  : entry +/- tp_pips (60 pips per card).
//   Break-even   : move SL to entry once price runs +be_trigger_pips.
//   One position per magic. Only one live pending stop order per magic at a time.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11405;
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
input int    strategy_adx_period        = 14;     // ADX period on the H1 base TF
input double strategy_adx_weak_threshold = 35.0;  // trade only when ADX < this (weak/ranging)
input int    strategy_breakout_buffer_pips = 15;  // pips beyond prior-day extreme (probe + entry)
input int    strategy_sl_pips           = 30;     // initial stop distance from entry (pips)
input int    strategy_tp_pips           = 60;     // take-profit distance from entry (pips)
input int    strategy_be_trigger_pips   = 30;     // move SL to break-even after +this many pips
input double strategy_spread_cap_pips   = 20.0;   // block a genuinely wide spread above this (pips)

// -----------------------------------------------------------------------------
// File-scope cached prior-day levels. Advanced once per broker-day rollover on
// the closed-bar path (NOT a per-EA new-bar gate — keyed off the broker-day
// number derived from the H1 bar timestamp via QM_BrokerToUTC).
// -----------------------------------------------------------------------------
double g_prev_day_high = 0.0;
double g_prev_day_low  = 0.0;
int    g_cached_day_id = -1;   // broker-day index of the day the cache belongs to

// Broker-day index (days since epoch) for a broker-time timestamp. Uses the
// DST-aware broker<->UTC mapping so the day boundary matches the broker session.
int BrokerDayId(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return (int)(utc / 86400);
  }

// Refresh the cached prior-day High/Low for the current broker day if it rolled.
// Reads PERIOD_D1 shift 1 (yesterday's completed daily bar).
void RefreshPrevDayLevels(const datetime broker_now)
  {
   const int day_id = BrokerDayId(broker_now);
   if(day_id == g_cached_day_id && g_prev_day_high > 0.0 && g_prev_day_low > 0.0)
      return; // already cached for this broker day

   const double dh = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed D1 read per day
   const double dl = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: one closed D1 read per day
   if(dh <= 0.0 || dl <= 0.0 || dh <= dl)
      return; // leave cache as-is until valid prior-day data is available

   g_prev_day_high = dh;
   g_prev_day_low  = dl;
   g_cached_day_id = day_id;
  }

// Seconds remaining until the end of the current broker day (for pending-order
// expiration). Cancels any untriggered stop order at the broker-day boundary.
int SecondsToBrokerDayEnd(const datetime broker_now)
  {
   const int secs_into_day = (int)(broker_now % 86400);
   int remaining = 86400 - secs_into_day;
   if(remaining < 60)
      remaining = 60; // floor so the order is at least briefly live
   return remaining;
  }

// True if this EA's magic already has a live pending stop order on this symbol.
bool HasLivePendingOrder(const int magic)
  {
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true on the H1 base TF.
// Places a single pending STOP order beyond the same-side prior-day extreme when
// (a) ADX is weak (ranging) AND (b) the last closed H1 bar probed the OPPOSITE
// prior-day extreme by the buffer.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic; and at most one live pending stop order per magic.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(HasLivePendingOrder(magic))
      return false;

   // Refresh cached prior-day levels for the current broker day.
   const datetime broker_now = TimeCurrent();
   RefreshPrevDayLevels(broker_now);
   if(g_prev_day_high <= 0.0 || g_prev_day_low <= 0.0)
      return false; // prior-day data not yet available

   // --- Regime STATE: ADX weak (ranging) on the H1 base TF, closed bar. ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx < strategy_adx_weak_threshold))
      return false;

   // --- Probe EVENT on the last closed H1 bar (shift 1). ---
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_buffer_pips);
   if(buffer <= 0.0)
      return false;

   // LONG setup: false breakdown below prior-day low -> arm BUYSTOP above prior-day high.
   const bool long_setup  = (low1  < g_prev_day_low  - buffer);
   // SHORT setup: false breakout above prior-day high -> arm SELLSTOP below prior-day low.
   const bool short_setup = (high1 > g_prev_day_high + buffer);

   // If neither (or — defensively — both) fire, do nothing.
   if(long_setup == short_setup)
      return false;

   const int expiry = SecondsToBrokerDayEnd(broker_now);

   if(long_setup)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol, g_prev_day_high + buffer);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY_STOP, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY_STOP, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type               = QM_BUY_STOP;
      req.price              = entry;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "adx_weak_prevday_buystop";
      req.expiration_seconds = expiry;
      return true;
     }

   // short_setup
   const double entry = QM_StopRulesNormalizePrice(_Symbol, g_prev_day_low - buffer);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopFixedPips(_Symbol, QM_SELL_STOP, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, QM_SELL_STOP, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type               = QM_SELL_STOP;
   req.price              = entry;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = "adx_weak_prevday_sellstop";
   req.expiration_seconds = expiry;
   return true;
  }

// Move SL to break-even once price has run +be_trigger_pips in favour of the
// open position. Fixed SL/TP otherwise handle the exit.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, /*buffer_pips=*/0);
     }
  }

// No discretionary exit — fixed SL/TP and the broker-day pending expiry govern
// the trade lifecycle.
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
