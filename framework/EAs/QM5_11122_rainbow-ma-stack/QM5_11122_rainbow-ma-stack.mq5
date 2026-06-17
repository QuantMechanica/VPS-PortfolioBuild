#property strict
#property version   "5.0"
#property description "QM5_11122 rainbow-ma-stack — EarnForex Rainbow MA stack trend (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11122 rainbow-ma-stack
// -----------------------------------------------------------------------------
// Source: EarnForex "Rainbow-Multiple-Moving-Average" (EarnForex / Akuma99).
// Card: artifacts/cards_approved/QM5_11122_rainbow-ma-stack.md (g0_status APPROVED).
//
// Mechanics (long & short, EMA method, close price, closed-bar reads at shift 1):
//   STACK STATE (reduced 7-line ribbon, source defaults 2/7/14/25/50/100/200):
//     Bullish stack: EMA(2) > EMA(7) > EMA(14) > EMA(25) > EMA(50) > EMA(100) > EMA(200)
//     Bearish stack: EMA(2) < EMA(7) < EMA(14) < EMA(25) < EMA(50) < EMA(100) < EMA(200)
//   ENTRY EVENT  : a false->true transition of the stack STATE. The stack is the
//                  STATE; the single alignment transition (not-stacked@2 ->
//                  stacked@1) is the EVENT. This avoids the two-cross-same-bar
//                  zero-trade trap: we never require two crossings to coincide —
//                  one ribbon-ordering transition is the trigger.
//   EXIT         : stack no longer fully ordered in the trade direction (reduced
//                  ribbon stack lost), OR 30 H4 bars elapsed since entry.
//   STOP         : long  = entry - sl_atr_mult * ATR(atr_period)
//                  short = entry + sl_atr_mult * ATR(atr_period)   (no fixed TP)
//   No same-bar re-entry: a fresh false->true stack transition is required, which
//   inherently cannot fire on the same bar the prior position closed by stack-loss.
//   One open position per symbol/magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11122;
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
// Reduced 7-line rainbow ribbon (source RMMA defaults, subset of 200..2).
input int    strategy_ema_p1            = 2;      // fastest ribbon line
input int    strategy_ema_p2            = 7;
input int    strategy_ema_p3            = 14;
input int    strategy_ema_p4            = 25;
input int    strategy_ema_p5            = 50;
input int    strategy_ema_p6            = 100;
input int    strategy_ema_p7            = 200;    // slowest ribbon line
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_sl_atr_mult       = 3.0;    // stop distance = mult * ATR
input int    strategy_max_hold_bars     = 30;     // time exit: close after N H4 bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar EMA stack evaluation)
// -----------------------------------------------------------------------------

// Returns +1 if the 7-line ribbon is fully bullish-ordered at `shift`,
// -1 if fully bearish-ordered, 0 otherwise. Reads closed bars only.
int StackStateAt(const int shift)
  {
   const double e1 = QM_EMA(_Symbol, _Period, strategy_ema_p1, shift);
   const double e2 = QM_EMA(_Symbol, _Period, strategy_ema_p2, shift);
   const double e3 = QM_EMA(_Symbol, _Period, strategy_ema_p3, shift);
   const double e4 = QM_EMA(_Symbol, _Period, strategy_ema_p4, shift);
   const double e5 = QM_EMA(_Symbol, _Period, strategy_ema_p5, shift);
   const double e6 = QM_EMA(_Symbol, _Period, strategy_ema_p6, shift);
   const double e7 = QM_EMA(_Symbol, _Period, strategy_ema_p7, shift);
   if(e1 <= 0.0 || e2 <= 0.0 || e3 <= 0.0 || e4 <= 0.0 ||
      e5 <= 0.0 || e6 <= 0.0 || e7 <= 0.0)
      return 0;

   if(e1 > e2 && e2 > e3 && e3 > e4 && e4 > e5 && e5 > e6 && e6 > e7)
      return 1;
   if(e1 < e2 && e2 < e3 && e3 < e4 && e4 < e5 && e5 < e6 && e6 < e7)
      return -1;
   return 0;
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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short entry on a fresh ribbon-stack alignment EVENT. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Stack STATE on the just-closed bar (shift 1) and the prior bar (shift 2).
   const int state_now  = StackStateAt(1);
   const int state_prev = StackStateAt(2);
   if(state_now == 0)
      return false;
   // EVENT = false->true transition: stacked now, NOT stacked the same way before.
   if(state_now == state_prev)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(state_now > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — exit via stack-loss or time stop
      req.reason = "rainbow_stack_long";
      return true;
     }

   // state_now < 0 : short
   const double sentry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sentry <= 0.0)
      return false;
   const double ssl = QM_StopATRFromValue(_Symbol, QM_SELL, sentry, atr_value, strategy_sl_atr_mult);
   if(ssl <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = ssl;
   req.tp     = 0.0;
   req.reason = "rainbow_stack_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exits live in
// Strategy_ExitSignal (stack-loss + time stop).
void Strategy_ManageOpenPosition()
  {
  }

// Exit when the ribbon stack is no longer ordered in the trade direction, or
// after strategy_max_hold_bars H4 bars have elapsed since entry.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve THIS EA's open position direction + open time.
   long  pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(pos_type < 0)
      return false;

   // Time stop: bars elapsed since entry on the current timeframe.
   const int    tf_seconds = PeriodSeconds(_Period);
   const datetime bar0_time = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
   if(tf_seconds > 0 && open_time > 0 && bar0_time > 0)
     {
      const int bars_elapsed = (int)((bar0_time - open_time) / tf_seconds);
      if(bars_elapsed >= strategy_max_hold_bars)
         return true;
     }

   // Stack-loss exit: stack no longer fully ordered in the trade direction.
   const int state_now = StackStateAt(1);
   if(pos_type == POSITION_TYPE_BUY  && state_now != 1)
      return true;
   if(pos_type == POSITION_TYPE_SELL && state_now != -1)
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
