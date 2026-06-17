#property strict
#property version   "5.0"
#property description "QM5_11152 hpetf-rsi106-9094-d1 — Connors HPETF RSI(2) extreme mean reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11152 hpetf-rsi106-9094-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "High Probability ETF Trading" (2009).
// Card: artifacts/cards_approved/QM5_11152_hpetf-rsi106-9094-d1.md (g0 APPROVED).
//
// Mechanics (long+short symmetric, closed-bar reads at shift 1, D1):
//   Long  entry : Close[1] > SMA(200)[1]  AND  RSI(2)[1] < rsi_long_thresh (10).
//   Short entry : Close[1] < SMA(200)[1]  AND  RSI(2)[1] > rsi_short_thresh (90).
//   Long  exit  : Close[1] > SMA(5)[1].
//   Short exit  : Close[1] < SMA(5)[1].
//   Time-stop   : exit after time_stop_bars (10) closed D1 bars in position.
//   Stop loss   : entry -/+ sl_atr_mult (3.0) * ATR(14)  (source has no hard
//                 stop; QM5 bounded-risk adaptation).
//   Spread guard: skip only a genuinely wide spread > spread_atr_frac * ATR(14)
//                 (fail-open on .DWX zero modeled spread).
//
// One position per magic (P2 baseline). The card's P3-optional second-unit
// add (RSI<6 long / >94 short) is reviewer-gated under HR14 slot allocation and
// is DISABLED here to preserve one-position-per-magic, exactly as the card's
// Mechanik section states for the P2 baseline.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11152;
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
input int    strategy_rsi_period         = 2;      // Connors RSI(2)
input double strategy_rsi_long_thresh    = 10.0;   // long if RSI(2) < this
input double strategy_rsi_short_thresh   = 90.0;   // short if RSI(2) > this
input int    strategy_sma_trend_period   = 200;    // major-trend regime SMA
input int    strategy_sma_exit_period    = 5;      // SMA(5) recovery exit
input int    strategy_atr_period         = 14;     // ATR period (stop + spread)
input double strategy_sl_atr_mult        = 3.0;    // stop distance = mult * ATR
input int    strategy_time_stop_bars     = 10;     // max D1 bars in position
input double strategy_spread_atr_frac    = 0.25;   // skip if spread > frac * ATR

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double cap = strategy_spread_atr_frac * atr_value;
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Long+short symmetric entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (P2 baseline; no add-unit).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1     = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double sma_trend  = QM_SMA(_Symbol, _Period, strategy_sma_trend_period, 1);
   const double rsi_now    = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double atr_value  = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(close1 <= 0.0 || sma_trend <= 0.0 || rsi_now <= 0.0 || atr_value <= 0.0)
      return false;

   bool go_long  = false;
   bool go_short = false;

   // Long: price above the major-trend SMA, RSI(2) at a short-term low extreme.
   if(close1 > sma_trend && rsi_now < strategy_rsi_long_thresh)
      go_long = true;
   // Short: price below the major-trend SMA, RSI(2) at a short-term high extreme.
   else if(close1 < sma_trend && rsi_now > strategy_rsi_short_thresh)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;

   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target; exit on SMA(5) recovery or time-stop
   req.reason = go_long ? "hpetf_rsi2_long" : "hpetf_rsi2_short";
   return true;
  }

// No active SL/TP management — fixed ATR stop + discretionary exits only.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: SMA(5) recovery in the trade direction OR time-stop.
// Closed-bar reads at shift 1. The framework loops magic-matched positions
// and closes them when this returns true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double sma_exit = QM_SMA(_Symbol, _Period, strategy_sma_exit_period, 1);
   if(close1 <= 0.0 || sma_exit <= 0.0)
      return false;

   // Find this EA's open position direction + open time (single pass, O(positions)).
   bool   is_long    = false;
   bool   have_pos   = false;
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
      is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // SMA(5) recovery exit, per source: long exits when close > SMA(5);
   // short exits when close < SMA(5).
   if(is_long && close1 > sma_exit)
      return true;
   if(!is_long && close1 < sma_exit)
      return true;

   // Time-stop: exit after strategy_time_stop_bars closed D1 bars in position.
   // Count closed bars between the entry bar and the last closed bar (shift 1).
   const datetime last_closed = iTime(_Symbol, _Period, 1); // perf-allowed: bar-open time read
   if(open_time > 0 && last_closed > 0 && strategy_time_stop_bars > 0)
     {
      const int bars_held = iBarShift(_Symbol, _Period, open_time, false) - 1;
      if(bars_held >= strategy_time_stop_bars)
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
