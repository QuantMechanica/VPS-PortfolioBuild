#property strict
#property version   "5.0"
#property description "QM5_10908 Carter Multi-EMA Stack + RSI trigger/exit (H1, EURUSD)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10908 carter-ema-stack-rsi
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
// Strategy #7. Trend-following EMA stack with an EMA(3)/EMA(5) cross trigger,
// RSI(21) directional gate, signal/time exits and a fixed 25-pip stop.
//
// Mechanics are mapped to the .DWX tester invariants:
//   - The EMA-stack hierarchy (13/21 vs 80) and the fast-pair-above-slow-pair
//     alignment are STATES; the only fresh-cross EVENT required is EMA(3) over
//     EMA(5). RSI(21) is a level GATE, not a same-bar cross. (Invariant #4.)
//   - Alignment "or crossed within the last 3 closed bars" is honoured with a
//     short lookback so the state need not hold on the exact trigger bar.
//   - Fixed stop uses pip->price scaling via QM_StopFixedPips (Invariant #14).
//   - No spread/swap gating; framework handles lots, news, Friday-close.
// Only the five Strategy_* hooks below are filled. Framework wiring untouched.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10908;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// EMA stack periods (Carter Strategy #7). fast/signal = cross trigger pair;
// mid pair = stack alignment reference; trend = slow regime filter.
input int    strategy_ema_fast          = 3;     // EMA(3) — cross trigger fast leg
input int    strategy_ema_signal        = 5;     // EMA(5) — cross trigger slow leg
input int    strategy_ema_mid_a         = 13;    // EMA(13) — stack mid leg A
input int    strategy_ema_mid_b         = 21;    // EMA(21) — stack mid leg B
input int    strategy_ema_trend         = 80;    // EMA(80) — slow trend regime
input int    strategy_rsi_period        = 21;    // RSI(21) directional gate
input double strategy_rsi_level         = 50.0;  // RSI midline gate
input int    strategy_align_lookback    = 3;     // bars to allow fast-pair alignment
input int    strategy_sl_pips           = 25;    // fixed stop, midpoint 20-30 pips
input int    strategy_hold_bars         = 72;    // fallback time-stop (H1 bars)

// -----------------------------------------------------------------------------
// Helpers — closed-bar EMA-stack evaluation (all reads at shift>=1).
// -----------------------------------------------------------------------------

// Fast pair (EMA fast & signal) both above the mid pair (EMA mid_a & mid_b)
// at the given closed-bar shift.
bool FastPairAbove(const int shift)
  {
   const double ef = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast,   shift);
   const double es = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, shift);
   const double ma = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_mid_a,  shift);
   const double mb = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_mid_b,  shift);
   return (ef > ma && ef > mb && es > ma && es > mb);
  }

bool FastPairBelow(const int shift)
  {
   const double ef = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast,   shift);
   const double es = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, shift);
   const double ma = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_mid_a,  shift);
   const double mb = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_mid_b,  shift);
   return (ef < ma && ef < mb && es < ma && es < mb);
  }

// Alignment is satisfied if the fast pair sits above the mid pair on the
// trigger bar, OR established that alignment within the last N closed bars
// (i.e. it is above now and was not above on some bar inside the window).
bool AlignedAboveWithin(const int lookback)
  {
   if(FastPairAbove(1))
      return true;
   for(int s = 2; s <= lookback + 1; ++s)
      if(FastPairAbove(s))
         return true;     // alignment held recently within the window
   return false;
  }

bool AlignedBelowWithin(const int lookback)
  {
   if(FastPairBelow(1))
      return true;
   for(int s = 2; s <= lookback + 1; ++s)
      if(FastPairBelow(s))
         return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Only one position per magic (card: one active position per magic number).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // EMA(3)/EMA(5) cross trigger: state on the prior bar vs the trigger bar.
   const double ef1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast,   1);
   const double es1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 1);
   const double ef2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast,   2);
   const double es2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 2);

   const bool cross_up   = (ef2 <= es2 && ef1 > es1);
   const bool cross_down = (ef2 >= es2 && ef1 < es1);

   // Slow-trend stack state (EMA13 & EMA21 vs EMA80) on the trigger bar.
   const double mid_a = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_mid_a, 1);
   const double mid_b = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_mid_b, 1);
   const double trend = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_trend, 1);

   const bool stack_up   = (mid_a > trend && mid_b > trend);
   const bool stack_down = (mid_a < trend && mid_b < trend);

   // RSI(21) directional gate (level, not a cross).
   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);

   bool go_long  = false;
   bool go_short = false;

   if(cross_up && stack_up && AlignedAboveWithin(strategy_align_lookback) && rsi > strategy_rsi_level)
      go_long = true;
   else
      if(cross_down && stack_down && AlignedBelowWithin(strategy_align_lookback) && rsi < strategy_rsi_level)
         go_short = true;

   if(!go_long && !go_short)
      return false;

   req.type   = go_long ? QM_BUY : QM_SELL;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_StopFixedPips(_Symbol, req.type, 0.0, strategy_sl_pips);
   req.tp     = 0.0;   // no fixed target; signal/time exits manage the trade
   req.reason = go_long ? "CARTER_EMASTACK_LONG" : "CARTER_EMASTACK_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card has no trailing / break-even / partial logic — fixed SL + signal/time exits.
  }

// Long exits when EMA(3) crosses below EMA(5) or RSI(21) falls below 50.
// Short exits when EMA(3) crosses above EMA(5) or RSI(21) rises above 50.
// Fallback time-stop: close after `strategy_hold_bars` H1 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ulong active_ticket = 0;
   ENUM_POSITION_TYPE active_type = POSITION_TYPE_BUY;
   datetime open_time = 0;

   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      active_ticket = ticket;
      active_type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time     = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(active_ticket == 0)
      return false;

   // Fallback time-stop: close after strategy_hold_bars closed H1 bars.
   const int tf_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(tf_seconds > 0 && (TimeCurrent() - open_time) >= (long)strategy_hold_bars * tf_seconds)
      return true;

   // Closed-bar EMA(3)/EMA(5) cross + RSI(21) midline exit.
   const double ef1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast,   1);
   const double es1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 1);
   const double ef2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast,   2);
   const double es2 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_signal, 2);
   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);

   const bool cross_down = (ef2 >= es2 && ef1 < es1);
   const bool cross_up   = (ef2 <= es2 && ef1 > es1);

   if(active_type == POSITION_TYPE_BUY && (cross_down || rsi < strategy_rsi_level))
      return true;
   if(active_type == POSITION_TYPE_SELL && (cross_up || rsi > strategy_rsi_level))
      return true;

   return false;
  }

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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
