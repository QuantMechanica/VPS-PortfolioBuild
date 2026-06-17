#property strict
#property version   "5.0"
#property description "QM5_11083 dots-two-color — EarnForex Dots two-same-color trend swing (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11083 dots-two-color
// -----------------------------------------------------------------------------
// Source: EarnForex "Dots" indicator (based on NonLagDOT by TrendLaboratory).
//   GitHub https://github.com/EarnForex/Dots ; article
//   https://www.earnforex.com/metatrader-indicators/Dots/
// Card: artifacts/cards_approved/QM5_11083_dots-two-color.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1+, H1):
//   The Dots indicator plots a smoothed (low-lag) moving average and colors each
//   dot by the SLOPE of that line: rising line -> bullish dot, falling -> bearish.
//   The source's "simple strategy" is: enter when TWO same-color dots appear.
//
//   We mechanize the low-lag MA with the framework LWMA(length) reader (the
//   nearest framework primitive to NonLagMA; gives less lag than SMA). The dot
//   color at closed shift s is the sign of the slope:
//       bullish dot @s  <=>  LWMA[s]  >  LWMA[s+1]
//       bearish dot @s  <=>  LWMA[s]  <  LWMA[s+1]
//
//   Long  : dots @1 AND @2 are bullish, AND the dot @3 was NOT bullish
//           (i.e. a fresh transition into a two-bullish-dot state — this is the
//           EVENT, not a standing state, so it fires once per swing).
//   Short : dots @1 AND @2 are bearish, AND the dot @3 was NOT bearish.
//
//   Exit  : opposite-color dot appears at the latest closed bar.
//             long  closes on a bearish dot @1 (LWMA[1] < LWMA[2]);
//             short closes on a bullish dot @1 (LWMA[1] > LWMA[2]).
//   Stop  : catastrophic ATR(atr_period) stop at sl_atr_mult * ATR (card P2
//           baseline = ATR(14) @ 2.5). No fixed TP (exit is dot-driven).
//
//   .DWX invariants honored: spread guard fails OPEN on zero modeled spread;
//   no swap gate; single QM_IsNewBar consume per tick; one position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11083;
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
input int    strategy_dots_length        = 10;    // Dots/NonLagMA smoothing length (card Length=10)
input int    strategy_atr_period         = 14;    // ATR period for the catastrophic stop
input double strategy_sl_atr_mult        = 2.5;   // catastrophic stop = mult * ATR (card P2 baseline)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Dot-color helper. Returns +1 for a bullish dot (rising low-lag MA), -1 for a
// bearish dot (falling), 0 for flat / not-yet-warm. shift = closed bar index.
// -----------------------------------------------------------------------------
int DotColorAt(const int shift)
  {
   const double ma_now  = QM_LWMA(_Symbol, _Period, strategy_dots_length, shift);
   const double ma_prev = QM_LWMA(_Symbol, _Period, strategy_dots_length, shift + 1);
   if(ma_now <= 0.0 || ma_prev <= 0.0)
      return 0;
   if(ma_now > ma_prev)
      return +1;
   if(ma_now < ma_prev)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dot1 = DotColorAt(1);
   const int dot2 = DotColorAt(2);
   const int dot3 = DotColorAt(3);
   if(dot1 == 0 || dot2 == 0)
      return false;

   // Long: two consecutive bullish dots (@1,@2) AFTER a non-bullish prior dot @3.
   const bool long_signal  = (dot1 > 0 && dot2 > 0 && dot3 <= 0);
   // Short: two consecutive bearish dots (@1,@2) AFTER a non-bearish prior dot @3.
   const bool short_signal = (dot1 < 0 && dot2 < 0 && dot3 >= 0);

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — exit is opposite-color-dot driven
   req.reason = long_signal ? "dots_two_bullish" : "dots_two_bearish";
   return true;
  }

// No active management beyond the fixed ATR catastrophic stop.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: an opposite-color dot appears at the latest closed bar.
//   long  closes on a bearish dot @1; short closes on a bullish dot @1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dot1 = DotColorAt(1);
   if(dot1 == 0)
      return false;

   // Determine the direction of the open position for this magic.
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

   if(have_long && dot1 < 0)   // bearish dot closes a long
      return true;
   if(have_short && dot1 > 0)  // bullish dot closes a short
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
