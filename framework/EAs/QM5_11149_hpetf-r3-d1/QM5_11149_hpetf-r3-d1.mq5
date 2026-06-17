#property strict
#property version   "5.0"
#property description "QM5_11149 hpetf-r3-d1 — Connors R3 RSI(2) sequence mean-reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11149 hpetf-r3-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "High Probability ETF Trading" (2009),
//   R3 = RSI(2) three-step sequence exhaustion. Card:
//   artifacts/cards_approved/QM5_11149_hpetf-r3-d1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads; the last CLOSED bar t == shift 1,
//   t-1 == shift 2, t-2 == shift 3):
//   Trend filter : Close[t] > SMA(trend_period)   (long)  / below (short).
//   RSI sequence (long):
//     RSI(2)[t-2] < seq_start_long (60)
//     RSI(2)[t-1] < RSI(2)[t-2]                 (decreasing)
//     RSI(2)[t]   < trigger_long (10)  AND  RSI(2)[t] < RSI(2)[t-1]
//   RSI sequence (short, mirror):
//     RSI(2)[t-2] > seq_start_short (40)
//     RSI(2)[t-1] > RSI(2)[t-2]                 (increasing)
//     RSI(2)[t]   > trigger_short (90) AND  RSI(2)[t] > RSI(2)[t-1]
//   Exit         : long closes when RSI(2)[t] > exit_long (70);
//                  short closes when RSI(2)[t] < exit_short (30).
//   Time-stop    : exit after time_stop_bars (10) closed D1 bars in position.
//   Stop loss    : source has no hard stop; QM bounded-risk adaptation
//                  SL = sl_atr_mult (3.0) * ATR(atr_period, 14) from entry.
//   No take-profit price; exits are RSI-revert or time-stop (or the ATR SL).
//   Spread guard : skip only a genuinely wide spread > spread_atr_mult * ATR
//                  (fail-open on .DWX zero modeled spread).
//   Warm-up      : require >= warmup_bars (220) closed D1 bars (SMA200 needs it).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11149;
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
input int    strategy_rsi_period        = 2;      // Connors cumulative-RSI period (RSI(2))
input int    strategy_trend_period      = 200;    // SMA trend filter period
input double strategy_seq_start_long    = 60.0;   // RSI(2)[t-2] must be below this (long)
input double strategy_trigger_long      = 10.0;   // RSI(2)[t] must be below this (long)
input double strategy_exit_long         = 70.0;   // close long when RSI(2)[t] > this
input double strategy_seq_start_short   = 40.0;   // RSI(2)[t-2] must be above this (short)
input double strategy_trigger_short     = 90.0;   // RSI(2)[t] must be above this (short)
input double strategy_exit_short        = 30.0;   // close short when RSI(2)[t] < this
input int    strategy_atr_period        = 14;     // ATR period for stop / spread cap
input double strategy_sl_atr_mult       = 3.0;    // stop distance = mult * ATR
input int    strategy_time_stop_bars    = 10;     // exit after this many closed D1 bars
input int    strategy_warmup_bars       = 220;    // require this many closed bars before trading
input double strategy_spread_atr_mult   = 0.25;   // skip if spread > this * ATR

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — sequence work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double cap = strategy_spread_atr_mult * atr_value;
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// RSI(2) three-step sequence entry (long + short mirror). Caller guarantees
// QM_IsNewBar() == true (closed-bar gate). Closed bar t == shift 1.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Warm-up: SMA(200) needs a deep history before it is meaningful.
   if(Bars(_Symbol, _Period) < strategy_warmup_bars)
      return false;

   // Trend filter reference (closed bar t == shift 1).
   const double sma_trend = QM_SMA(_Symbol, _Period, strategy_trend_period, 1);
   if(sma_trend <= 0.0)
      return false;

   const double close_t = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close_t <= 0.0)
      return false;

   // RSI(2) at t (shift 1), t-1 (shift 2), t-2 (shift 3).
   const double rsi_t  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_t1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_t2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 3);
   if(rsi_t <= 0.0 || rsi_t1 <= 0.0 || rsi_t2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   bool go_long  = false;
   bool go_short = false;

   // --- Long sequence: price above trend, decreasing RSI into the trigger ---
   if(close_t > sma_trend &&
      rsi_t2 < strategy_seq_start_long &&
      rsi_t1 < rsi_t2 &&
      rsi_t  < strategy_trigger_long &&
      rsi_t  < rsi_t1)
      go_long = true;

   // --- Short mirror: price below trend, increasing RSI into the trigger ---
   if(close_t < sma_trend &&
      rsi_t2 > strategy_seq_start_short &&
      rsi_t1 > rsi_t2 &&
      rsi_t  > strategy_trigger_short &&
      rsi_t  > rsi_t1)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;

   const double entry = (go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; RSI-revert / time-stop / ATR SL handle exit
   req.reason = (go_long ? "r3_rsi2_seq_long" : "r3_rsi2_seq_short");
   return true;
  }

// No active trade management beyond the fixed ATR stop. RSI-revert and the
// time-stop are handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: RSI(2) mean-reverts past the exit level, OR the position
// has been held >= time_stop_bars closed D1 bars. One event at the closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi_t = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_t <= 0.0)
      return false;

   // Inspect this EA's open position to decide direction + age. Bounded scan.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);

      // RSI-revert exit.
      if(pos_type == POSITION_TYPE_BUY && rsi_t > strategy_exit_long)
         return true;
      if(pos_type == POSITION_TYPE_SELL && rsi_t < strategy_exit_short)
         return true;

      // Time-stop: count closed D1 bars elapsed since the open bar.
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, _Period, open_time, false);
      // open_shift is the bar index of the open bar relative to current bar 0.
      // Bars held (closed) = open_shift; trigger when it reaches the limit.
      if(open_shift >= strategy_time_stop_bars)
         return true;
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
