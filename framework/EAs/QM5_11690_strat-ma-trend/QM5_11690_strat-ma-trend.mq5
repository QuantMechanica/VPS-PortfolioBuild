#property strict
#property version   "5.0"
#property description "QM5_11690 strat-ma-trend — Stratestic single-MA close-vs-MA trend, reverse-on-cross (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11690 strat-ma-trend
// -----------------------------------------------------------------------------
// Source: Diogo Matos Chaves / diogomatoschaves, stratestic,
//   stratestic/strategies/moving_average/ma.py
//   https://github.com/diogomatoschaves/stratestic/blob/main/stratestic/strategies/moving_average/ma.py
// Card: artifacts/cards_approved/QM5_11690_strat-ma-trend.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1/2, H1):
//   ONE moving average on close (SMA or EMA, selectable; seed SMA(50)).
//   Source rule: long when close > MA, short when close < MA, reverse when
//   close crosses to the opposite side of the MA.
//
//   The MA implementation here uses the CROSS as the single trigger EVENT so a
//   fresh signal fires exactly once per side change (no two-cross trap — there
//   is only ONE cross series: price vs the single MA):
//     Long  EVENT : close crosses from <= MA (bar 2) to >  MA (bar 1).
//     Short EVENT : close crosses from >= MA (bar 2) to <  MA (bar 1).
//   Reverse-on-cross: the opposite cross both closes the current position
//   (Strategy_ExitSignal) and arms the new entry (Strategy_EntrySignal).
//   With one position per magic, the close+reopen happen on the same closed bar.
//
//   Stop  : ATR catastrophic stop (source has none; V5 adds it).
//           Long  sl = entry - sl_atr_mult * ATR ; Short sl = entry + ...
//   Take  : RR-multiple TP off the same ATR-derived stop distance.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11690;
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
input bool   strategy_use_ema           = false;  // false = SMA (seed), true = EMA
input int    strategy_ma_period         = 50;     // single MA period on close
input int    strategy_atr_period        = 14;     // ATR period for catastrophic stop
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr             = 3.0;    // take-profit = tp_rr * stop distance
input double strategy_spread_pct_of_stop = 15.0;  // block if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Single MA on close at the given closed-bar shift (SMA or EMA per input).
double MA_AtShift(const int shift)
  {
   if(strategy_use_ema)
      return QM_EMA(_Symbol, _Period, strategy_ma_period, shift, PRICE_CLOSE);
   return QM_SMA(_Symbol, _Period, strategy_ma_period, shift, PRICE_CLOSE);
  }

// Direction of a fresh close-vs-MA cross between bar 2 and bar 1.
// Returns +1 for an up-cross (long), -1 for a down-cross (short), 0 otherwise.
int CrossDirection()
  {
   const double ma_now  = MA_AtShift(1);
   const double ma_prev = MA_AtShift(2);
   if(ma_now <= 0.0 || ma_prev <= 0.0)
      return 0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return 0;

   const bool crossed_up   = (close2 <= ma_prev && close1 > ma_now);
   const bool crossed_down = (close2 >= ma_prev && close1 < ma_now);
   if(crossed_up && !crossed_down)
      return 1;
   if(crossed_down && !crossed_up)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
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

// Entry / reversal. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// Reverse-on-cross: a fresh cross arms a new entry. One position per magic; if a
// same-direction position is already open we hold (no pyramiding). The opposite
// position is closed first by Strategy_ExitSignal on this same bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic — no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = CrossDirection(); // single trigger EVENT
   if(dir == 0)
      return false;

   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType otype = (dir > 0) ? QM_BUY : QM_SELL;
   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir > 0) ? "ma_trend_long" : "ma_trend_short";
   return true;
  }

// No active management beyond the fixed ATR stop / RR target.
void Strategy_ManageOpenPosition()
  {
  }

// Reverse-on-cross exit: close the open position when a fresh cross fires in the
// OPPOSITE direction to the position's side. The same cross then arms the new
// entry in Strategy_EntrySignal on this same closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir = CrossDirection();
   if(dir == 0)
      return false;

   // Determine the side of the currently-open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      // Up-cross while short, or down-cross while long → reverse/close.
      if(dir > 0 && ptype == POSITION_TYPE_SELL)
         return true;
      if(dir < 0 && ptype == POSITION_TYPE_BUY)
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
