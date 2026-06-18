#property strict
#property version   "5.0"
#property description "QM5_11592 robo-3candle-fade-h4 — RoboForex Three-Candle Fade (mean-reversion, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11592 robo-3candle-fade-h4
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection 2020, p.107 "Strategy Three Candles".
// Card: artifacts/cards_approved/QM5_11592_robo-3candle-fade-h4.md (g0_status APPROVED).
//
// Mechanics (mean-reversion, closed-bar reads at shift 1; PERIOD_H4):
//   Exhaustion run STATE : N consecutive closed H4 candles each closing in the
//                          same direction relative to the prior close.
//     N-bar DECLINE : close[k] < close[k+1] for k = 1..N   -> fade with a BUY.
//     N-bar RALLY   : close[k] > close[k+1] for k = 1..N   -> fade with a SELL.
//   Trigger EVENT  : the run completes on the just-closed bar (shift 1). The run
//                    is a persistent STATE; one-position-per-magic + the opposite
//                    direction of the run prevent double/conflicting entries, so
//                    there is NO two-cross-same-bar zero-trade trap (a single run
//                    can never be both up AND down).
//   Stop           : 2 x ATR(14) from entry (card adaptation of the fixed 40-pip SL).
//   Take profit    : strategy_tp_atr_mult x ATR (RR target; card's 50/40 ~ 1.25R).
//   Exit           : opposite N-bar run appears (opposite-signal exit) OR ATR trail.
//   Spread guard   : block only a genuinely wide spread (fail-open on .DWX zero
//                    modeled spread).
//
// Symbols: EURUSD.DWX, GBPUSD.DWX (both present in dwx_symbol_matrix.csv; the
// card names no GER40/OIL/out-of-matrix symbols, so no porting was required).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11592;
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
input int    strategy_run_length         = 3;     // N consecutive same-direction closes to fade (sweep 2,3,4,5)
input int    strategy_atr_period         = 14;    // ATR period (stop / target / trail)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 2.5;   // target distance = mult * ATR
input bool   strategy_use_atr_trail      = true;  // enable ATR trailing stop on the open position
input double strategy_trail_atr_mult     = 2.0;   // ATR multiple for the trailing stop
input bool   strategy_use_opposite_exit  = true;  // close when the opposite N-bar run appears
input double strategy_spread_pct_of_stop = 15.0;  // skip only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Detect an N-bar run on closed bars. dir = +1 -> N consecutive RALLY closes
// (each close higher than the prior, shifts 1..N), dir = -1 -> N consecutive
// DECLINE closes. Compares N consecutive close pairs: shift k vs shift k+1.
// Bounded loop (<= N iterations; N small per the card sweep 2..5).
bool RunComplete(const int dir, const int n)
  {
   if(n < 1)
      return false;
   for(int k = 1; k <= n; ++k)
     {
      const double c_k  = iClose(_Symbol, _Period, k);     // perf-allowed: single closed-bar read
      const double c_k1 = iClose(_Symbol, _Period, k + 1); // perf-allowed: single closed-bar read
      if(c_k <= 0.0 || c_k1 <= 0.0)
         return false;
      if(dir > 0 && !(c_k > c_k1))   // rally requires strictly higher closes
         return false;
      if(dir < 0 && !(c_k < c_k1))   // decline requires strictly lower closes
         return false;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; the run/entry math is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
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

// Fade entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
//   N-bar DECLINE completed -> BUY (fade the drop).
//   N-bar RALLY   completed -> SELL (fade the rise).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const bool n_down = RunComplete(-1, strategy_run_length); // N consecutive lower closes
   const bool n_up   = RunComplete(+1, strategy_run_length); // N consecutive higher closes
   // A run can never be both directions, so at most one of these is true.
   if(!n_down && !n_up)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   QM_OrderType side;
   double entry;
   string reason;
   if(n_down)
     {
      side   = QM_BUY;                                    // fade the decline
      entry  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      reason = "fade_3candle_decline_buy";
     }
   else
     {
      side   = QM_SELL;                                   // fade the rally
      entry  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      reason = "fade_3candle_rally_sell";
     }
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// Optional ATR trailing stop on the open position.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_use_atr_trail)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Opposite-signal exit: an N-bar run in the SAME direction the position faded
// closes it (long faded a decline -> exit when an N-bar rally appears; short
// faded a rally -> exit when an N-bar decline appears).
bool Strategy_ExitSignal()
  {
   if(!strategy_use_opposite_exit)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pt = PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY)  have_long  = true;
      if(pt == POSITION_TYPE_SELL) have_short = true;
     }

   const bool n_down = RunComplete(-1, strategy_run_length);
   const bool n_up   = RunComplete(+1, strategy_run_length);

   // Long faded a decline -> a fresh rally run signals reversal -> exit.
   if(have_long && n_up)
      return true;
   // Short faded a rally -> a fresh decline run signals reversal -> exit.
   if(have_short && n_down)
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
