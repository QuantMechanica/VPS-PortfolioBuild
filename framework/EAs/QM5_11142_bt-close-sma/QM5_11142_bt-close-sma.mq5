#property strict
#property version   "5.0"
#property description "QM5_11142 bt-close-sma — Close/SMA cross flip (long-short or long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11142 bt-close-sma
// -----------------------------------------------------------------------------
// Source: Daniel Rodriguez / backtrader sample LongShortStrategy
//   (samples/analyzer-annualreturn/analyzer-annualreturn.py).
// Card: artifacts/cards_approved/QM5_11142_bt-close-sma.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads, D1 baseline):
//   SMA          : simple moving average of close, period strategy_sma_period.
//   Long  EVENT  : close crosses UPWARD through the SMA
//                  (close[2] <= sma[2]  AND  close[1] > sma[1]).
//   Short EVENT  : close crosses DOWNWARD through the SMA
//                  (close[2] >= sma[2]  AND  close[1] < sma[1]); suppressed when
//                  strategy_only_long is true.
//   Flip / exit  : an opposite cross closes the open position. In long-short
//                  mode the entry hook then opens the opposite side on the same
//                  closed bar (exit hook runs before the entry hook in OnTick).
//                  In long-only mode a downward cross just closes the long and
//                  stays flat until the next upward cross.
//   Stop         : emergency ATR stop at strategy_sl_atr_mult * ATR. No take
//                  profit — the opposite cross is the profit/loss exit, the ATR
//                  stop is only a disaster brake.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-OPEN on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11142;
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
input int    strategy_sma_period         = 15;     // simple moving average period on close
input bool   strategy_only_long          = false;  // true = long-only; false = long-short flip
input double strategy_sl_atr_mult        = 3.0;    // emergency stop = mult * ATR
input int    strategy_atr_period         = 14;     // ATR period for the emergency stop
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cross helpers — evaluated on closed bars. The trigger bar is shift 1; the bar
// before it is shift 2. One fresh cross EVENT per closed bar.
bool CrossedUp()
  {
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double sma1   = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma2   = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return false;
   return (close2 <= sma2 && close1 > sma1);
  }

bool CrossedDown()
  {
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double sma1   = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma2   = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return false;
   return (close2 >= sma2 && close1 < sma1);
  }

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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The exit
// hook (Strategy_ExitSignal) has already closed any opposite position earlier in
// the same OnTick, so a flip lands here as a clean new entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const bool up   = CrossedUp();
   const bool down = (!strategy_only_long) && CrossedDown();
   if(!up && !down)
      return false;

   const QM_OrderType side = up ? QM_BUY : QM_SELL;

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
   req.tp     = 0.0;   // no target — opposite cross is the exit
   req.reason = up ? "close_sma_cross_long" : "close_sma_cross_short";
   return true;
  }

// No active trade management beyond the emergency ATR stop. Flip/exit handled in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Close the open position when the close crosses the SMA against it. The opposite
// entry (in long-short mode) is then opened by Strategy_EntrySignal on the same
// closed bar.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
     }

   if(is_long && CrossedDown())
      return true;
   if(is_short && CrossedUp())
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
