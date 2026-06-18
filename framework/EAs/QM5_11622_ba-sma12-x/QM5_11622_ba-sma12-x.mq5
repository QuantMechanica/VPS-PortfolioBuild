#property strict
#property version   "5.0"
#property description "QM5_11622 ba-sma12-x — Basana SMA(12) price-cross trend follower (D1, long/short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11622 ba-sma12-x
// -----------------------------------------------------------------------------
// Source: Gabriel Martin Becedillas Ruiz / gbeced, Basana SMA sample strategy
//   https://github.com/gbeced/basana/blob/develop/samples/strategies/sma.py
// Card: artifacts/cards_approved/QM5_11622_ba-sma12-x.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1/2, D1):
//   Trigger EVENT (long) : close[2] <= sma12[2]  AND  close[1] > sma12[1]
//                          (a fresh bullish close/SMA cross — ONE event/bar).
//   Trigger EVENT (short): close[2] >= sma12[2]  AND  close[1] < sma12[1]
//                          (a fresh bearish close/SMA cross — ONE event/bar).
//   Reversal exit        : a fresh opposite cross closes the open position and
//                          opens the reverse side (signal-reversal). The cross
//                          is the single event; the open-side is a STATE.
//   Emergency stop       : entry -/+ sma_stop_atr_mult * ATR(sma_atr_period).
//                          No take-profit; the opposite cross is the planned exit.
//   Warmup STATE         : require >= sma_min_warmup_bars closed D1 bars.
//   Spread guard         : skip only a genuinely wide spread (fail-open on the
//                          .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11622;
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
input int    sma_period                 = 12;    // SMA period on close (card default 12; sweep 8/12/20)
input int    sma_atr_period             = 20;    // ATR period for the emergency stop
input double sma_stop_atr_mult          = 3.0;   // emergency stop distance = mult * ATR (sweep 2.5/3.0/3.5)
input int    sma_min_warmup_bars        = 30;    // minimum closed D1 bars before trading
input double sma_spread_pct_of_stop     = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path. Fail-open on the .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, sma_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = sma_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (sma_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Detect a fresh close/SMA cross on the last closed bar.
//   returns +1 bullish cross (close[2]<=sma[2] && close[1]>sma[1])
//   returns -1 bearish cross (close[2]>=sma[2] && close[1]<sma[1])
//   returns  0 no fresh cross
int Sma_CrossSignal()
  {
   const double sma1 = QM_SMA(_Symbol, _Period, sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, _Period, sma_period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0)
      return 0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return 0;

   if(close2 <= sma2 && close1 > sma1)
      return 1;   // bullish cross
   if(close2 >= sma2 && close1 < sma1)
      return -1;  // bearish cross
   return 0;
  }

// Entry on a fresh SMA cross. Caller guarantees QM_IsNewBar() == true.
// A reversal (cross opposite to an existing position) is handled by
// Strategy_ExitSignal closing the old position first on the same tick; this
// hook then opens the new side. One position per symbol/magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Warmup STATE: need enough closed bars for SMA + ATR.
   if(Bars(_Symbol, _Period) < sma_min_warmup_bars)
      return false;

   // One open position per symbol/magic. If a position is still open here, the
   // reverse will be taken on the NEXT tick after the exit hook flattens it.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int signal = Sma_CrossSignal();
   if(signal == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, sma_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, sma_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — opposite SMA cross is the exit
   req.reason = (side == QM_BUY) ? "sma12_cross_long" : "sma12_cross_short";
   return true;
  }

// No active trade management beyond the fixed ATR emergency stop. The
// signal-reversal exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit: a fresh cross OPPOSITE to the open position closes it.
// The opposite entry is then taken on the following tick (one-position-per-magic
// avoids close+open colliding on the same tick). One event at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int signal = Sma_CrossSignal();
   if(signal == 0)
      return false;

   // Determine the open side; close only on the opposite fresh cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && signal < 0)
         return true;  // bearish cross against a long
      if(ptype == POSITION_TYPE_SELL && signal > 0)
         return true;  // bullish cross against a short
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
