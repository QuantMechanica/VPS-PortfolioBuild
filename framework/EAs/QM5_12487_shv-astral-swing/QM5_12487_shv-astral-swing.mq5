#property strict
#property version   "5.0"
#property description "QM5_12487 shv-astral-swing — Astral close-direction + 5-bar extension swing (symmetric, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12487 shv-astral-swing
// -----------------------------------------------------------------------------
// Source: shashankvemuri/Finance astral_timing_signals.py (function `astral`,
//   called as astral(data, 8, 1, 5, 'Close','High','Low', ...)).
// Card: artifacts/cards_approved/QM5_12487_shv-astral-swing.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads, evaluated once per D1 bar):
//   The source "astral" rule maps step=1, step_two=5 onto a single-bar
//   close-direction + N-bar extension test. The literal counting collapses to:
//     LONG  signal : Close[1] < Close[1+step]   AND  Low[1]  < Low[1+step_two]
//     SHORT signal : Close[1] > Close[1+step]   AND  High[1] > High[1+step_two]
//   (shift 1 = last fully closed bar; step=1 -> prior close; step_two=5 -> the
//    high/low five bars before the signal bar, i.e. shift 1+step_two = 6.)
//   Reaching the condition = the trigger EVENT for that bar; it is a STATE the
//   bar either is or is not in (no two-cross-same-bar dependency). A malformed
//   bar where BOTH long and short fire is skipped.
//
//   Entry        : open in the signalled direction (one position per magic).
//   Exit (signal): an opposite signal closes the open position.
//   Exit (time)  : close after hold_bars (source `completion` = 8) closed bars.
//   Stop         : 2.0 * ATR(20) from entry (source has no native stop).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12487;
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
input int    strategy_close_step        = 1;     // step: close compared to Close[1+step]
input int    strategy_extension_lookback = 5;    // step_two: low/high extension vs N bars back
input int    strategy_hold_bars         = 8;     // time exit: close after N closed bars (source completion)
input int    strategy_atr_period        = 20;    // ATR period for the emergency stop
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Astral signal: +1 long, -1 short, 0 none. Pure closed-bar OHLC comparison.
// Uses shift 1 as the last closed (signal) bar. step / step_two are bar offsets.
// Returns 0 when both directions fire on the same (malformed) bar.
// -----------------------------------------------------------------------------
int AstralSignal()
  {
   const int step      = (strategy_close_step       > 0 ? strategy_close_step       : 1);
   const int step_two  = (strategy_extension_lookback > 0 ? strategy_extension_lookback : 5);

   // perf-allowed: bounded fixed-shift closed-bar OHLC reads for bespoke
   // price-action math (no QM_* indicator equivalent for raw extremes).
   const double close_sig  = iClose(_Symbol, _Period, 1);
   const double close_prev = iClose(_Symbol, _Period, 1 + step);
   const double low_sig    = iLow(_Symbol, _Period, 1);
   const double low_ext    = iLow(_Symbol, _Period, 1 + step_two);
   const double high_sig   = iHigh(_Symbol, _Period, 1);
   const double high_ext   = iHigh(_Symbol, _Period, 1 + step_two);

   // Skip bars with missing / malformed OHLC.
   if(close_sig <= 0.0 || close_prev <= 0.0 ||
      low_sig   <= 0.0 || low_ext    <= 0.0 ||
      high_sig  <= 0.0 || high_ext   <= 0.0)
      return 0;

   const bool long_sig  = (close_sig < close_prev && low_sig  < low_ext);
   const bool short_sig = (close_sig > close_prev && high_sig > high_ext);

   // Both true on a malformed bar -> skip (card rule).
   if(long_sig && short_sig)
      return 0;
   if(long_sig)
      return +1;
   if(short_sig)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int sig = AstralSignal();
   if(sig == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(sig > 0)
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
      req.tp     = 0.0;   // no fixed target — exit on opposite signal or time stop
      req.reason = "astral_long";
      return true;
     }

   // sig < 0 -> short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = "astral_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Opposite-signal and
// time-stop exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: opposite astral signal OR time stop after hold_bars
// closed bars. Caller runs this every tick; reads are O(1) closed-bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Locate this EA's open position to read its side + open time.
   bool   have_pos   = false;
   long   pos_type   = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = (long)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // Opposite-signal exit.
   const int sig = AstralSignal();
   if(pos_type == POSITION_TYPE_BUY  && sig < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && sig > 0)
      return true;

   // Time stop: close after hold_bars completed bars since entry. Count closed
   // bars by comparing the entry bar-open time to the last closed bar-open time.
   if(strategy_hold_bars > 0)
     {
      // perf-allowed: single fixed-shift bar-open time reads. Count completed
      // bars by elapsed broker time between the entry bar open and the last
      // closed bar open, divided by the period length (robust on D1).
      const int entry_shift = iBarShift(_Symbol, _Period, open_time, true);
      const datetime entry_bar_open  = (entry_shift >= 0 ? (datetime)iTime(_Symbol, _Period, entry_shift) : open_time);
      const datetime last_closed_open = (datetime)iTime(_Symbol, _Period, 1);
      const int period_seconds = PeriodSeconds(_Period);
      if(period_seconds > 0 && last_closed_open > 0 && entry_bar_open > 0)
        {
         const int bars_held = (int)((last_closed_open - entry_bar_open) / period_seconds);
         if(bars_held >= strategy_hold_bars)
            return true;
        }
     }

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
