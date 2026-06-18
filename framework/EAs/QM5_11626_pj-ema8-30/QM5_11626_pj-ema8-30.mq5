#property strict
#property version   "5.0"
#property description "QM5_11626 pj-ema8-30 — PyJuque EMA(8/30) Intraday Cross (symmetric long/short, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11626 pj-ema8-30
// -----------------------------------------------------------------------------
// Source: Tudor Elu / tudorelu, PyJuque EMA cross backtest example
//   github.com/tudorelu/pyjuque/blob/master/examples/Backtest_Strategy.py
// Card: artifacts/cards_approved/QM5_11626_pj-ema8-30.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1/2, baseline M5):
//   Fast EMA = EMA(8) close, Slow EMA = EMA(30) close.
//
//   LONG entry (the low crossing UP through the slow EMA is the single EVENT,
//   gated by the bullish fast/slow STATE):
//     EVENT  : low[2] < ema30[2]  AND  low[1] > ema30[1]   (one fresh up-cross)
//     STATE  : low[1] > ema8[1]   AND  ema8[1] > ema30[1]   (bullish stack)
//
//   SHORT entry / LONG exit (the close crossing DOWN through the EMAs is the
//   single EVENT, gated by the bearish STATE; the "was-above" clause is a
//   prior-bar STATE, not a second cross event):
//     EVENT  : close[1] < ema30[1]  AND  close[1] < ema8[1]
//     STATE  : (low[2] > ema30[2] OR ema8[2] > ema30[2])  AND  ema8[1] < ema30[1]
//
//   Exit-on-signal: a LONG is closed on the short signal; a SHORT is closed on
//   the long signal (signal-reversal exit). EnableShorts ablates short entries
//   but the short signal still closes longs.
//   Stop  : QM_StopATR(type, entry, atr_period, sl_atr_mult).
//   Take  : QM_TakeRR(type, entry, sl, tp_rr)  (RR derived from ATR mults).
//   Spread: skip only a genuinely wide spread (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11626;
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
input int    strategy_ema_fast_period   = 8;     // fast EMA (PyJuque fast_ma_len)
input int    strategy_ema_slow_period   = 30;    // slow EMA (PyJuque slow_ma_len)
input int    strategy_atr_period        = 20;    // ATR period for stop / target
input double strategy_sl_atr_mult       = 3.0;   // stop distance = mult * ATR (source 20% emergency baseline)
input double strategy_tp_atr_mult       = 2.0;   // take-profit distance = mult * ATR (source 10% map)
input bool   strategy_enable_shorts     = true;  // ablatable symmetric shorts
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Signal helpers — both read closed bars only (shift 1 = last closed bar).
// -----------------------------------------------------------------------------

// Long EVENT+STATE: low crosses up through ema30 (one event), bullish stack.
bool LongSignal()
  {
   const double ema8_1  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema30_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema30_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema8_1 <= 0.0 || ema30_1 <= 0.0 || ema30_2 <= 0.0)
      return false;

   const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low2 = iLow(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(low1 <= 0.0 || low2 <= 0.0)
      return false;

   // EVENT: low crosses up through the slow EMA between bar 2 and bar 1.
   if(!(low2 < ema30_2 && low1 > ema30_1))
      return false;
   // STATE: low above fast EMA and bullish fast/slow stack.
   if(!(low1 > ema8_1 && ema8_1 > ema30_1))
      return false;
   return true;
  }

// Short EVENT+STATE: close crosses down through both EMAs, bearish stack.
bool ShortSignal()
  {
   const double ema8_1  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema8_2  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema30_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema30_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema8_1 <= 0.0 || ema8_2 <= 0.0 || ema30_1 <= 0.0 || ema30_2 <= 0.0)
      return false;

   const double low2   = iLow(_Symbol, _Period, 2);   // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(low2 <= 0.0 || close1 <= 0.0)
      return false;

   // STATE: prior bar was on the bullish side (was above slow EMA / fast>slow).
   if(!(low2 > ema30_2 || ema8_2 > ema30_2))
      return false;
   // EVENT: close drops below both EMAs.
   if(!(close1 < ema30_1 && close1 < ema8_1))
      return false;
   // STATE: bearish fast/slow stack.
   if(!(ema8_1 < ema30_1))
      return false;
   return true;
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

// Symmetric entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // RR multiple from the configured ATR mults (tp_dist / sl_dist).
   double tp_rr = 0.0;
   if(strategy_sl_atr_mult > 0.0)
      tp_rr = strategy_tp_atr_mult / strategy_sl_atr_mult;

   if(LongSignal())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = (tp_rr > 0.0) ? QM_TakeRR(_Symbol, QM_BUY, entry, sl, tp_rr) : 0.0;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "pj_ema8_30_long";
      return true;
     }

   if(strategy_enable_shorts && ShortSignal())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = (tp_rr > 0.0) ? QM_TakeRR(_Symbol, QM_SELL, entry, sl, tp_rr) : 0.0;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "pj_ema8_30_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop/target. Signal-reversal
// exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit: close a LONG on the short signal, close a SHORT on the
// long signal. The OnTick wiring closes every position of this magic when this
// returns true, so resolve the held direction here.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve current held direction for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && ShortSignal())
      return true;
   if(have_short && LongSignal())
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
