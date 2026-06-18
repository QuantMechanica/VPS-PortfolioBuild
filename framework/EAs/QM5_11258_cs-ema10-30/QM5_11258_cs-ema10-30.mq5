#property strict
#property version   "5.0"
#property description "QM5_11258 cs-ema10-30 — CryptoSignal EMA(10/30) crossover (symmetric long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11258 cs-ema10-30
// -----------------------------------------------------------------------------
// Source: Abenezer Mamo / CryptoSignal contributors, Crypto-Signal
//         docs/config.md EMA crossover example (std_crossover, EMA index 0 vs 1).
// Card: artifacts/cards_approved/QM5_11258_cs-ema10-30.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1/2):
//   Trigger EVENT : EMA(fast) crosses EMA(slow) on the closed D1 bar.
//                   Up cross  -> LONG ; down cross -> SHORT. This is the ONE
//                   event per bar — never require two crosses on the same bar.
//   Separation STATE (chop filter): at the trigger bar, |EMA(fast)-EMA(slow)|
//                   must be >= sep_atr_mult * ATR(period). State observed at the
//                   trigger, NOT a second event.
//   Reversal exit : an opposite EMA cross closes the open position (and the
//                   same new-bar entry path re-opens in the new direction).
//   Stop          : entry -/+ sl_atr_mult * ATR(period) (hard ATR stop).
//   Trailing      : optional ATR trail (trail_atr_mult) once price has moved
//                   +1R in favour. Off by default (trail_enabled=false).
//   Spread guard  : skip only a genuinely WIDE spread > spread_pct_of_stop of
//                   the stop distance. Fail-OPEN on .DWX zero modeled spread.
//
// .DWX invariants honoured: fail-open spread guard, no swap gate, EMA crossover
// is a single event (separation is a state), closed-bar reads at shift 1/2, no
// external-macro CSV, no broker-time session window (D1 trend rule). News +
// Friday-close handled centrally by the framework.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11258;
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
input int    strategy_ema_fast_period    = 10;    // fast EMA (CryptoSignal index 0)
input int    strategy_ema_slow_period    = 30;    // slow EMA (CryptoSignal index 1)
input int    strategy_atr_period         = 14;    // ATR period (separation / stop / trail)
input double strategy_sep_atr_mult       = 0.15;  // min |EMA_fast-EMA_slow| in ATR; 0 = off
input double strategy_sl_atr_mult        = 3.0;   // hard stop distance = mult * ATR
input bool   strategy_trail_enabled      = false; // optional ATR trail after +1R
input double strategy_trail_atr_mult     = 2.5;   // ATR trail distance once armed
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
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

   // Closed-bar EMA values: shift 1 = last closed bar, shift 2 = prior bar.
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   // --- Trigger EVENT: a single EMA crossover on the closed bar ---
   const bool crossed_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);
   if(!crossed_up && !crossed_down)
      return false;

   // --- Separation STATE (chop filter) at the trigger bar ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   if(strategy_sep_atr_mult > 0.0)
     {
      const double separation = MathAbs(fast_now - slow_now);
      if(separation < strategy_sep_atr_mult * atr_value)
         return false; // too flat — skip the chop
     }

   const QM_OrderType side = crossed_up ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target; exit via opposite cross or ATR stop/trail
   req.reason = crossed_up ? "ema10_30_cross_long" : "ema10_30_cross_short";
   return true;
  }

// Optional ATR trailing stop, armed once price has moved +1R (one stop distance)
// in favour. Off by default (strategy_trail_enabled=false).
void Strategy_ManageOpenPosition()
  {
   if(!strategy_trail_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double r_distance = strategy_sl_atr_mult * atr_value; // initial 1R in price
   if(r_distance <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const long   pos_type   = PositionGetInteger(POSITION_TYPE);
      const double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(pos_type == POSITION_TYPE_BUY)
        {
         if(bid - open_price >= r_distance) // armed: +1R reached
            QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(open_price - ask >= r_distance) // armed: +1R reached
            QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
        }
     }
  }

// Reversal exit: an opposite EMA crossover closes the open position. The new-bar
// entry path then re-opens in the new direction (one event per bar).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);
   if(!crossed_up && !crossed_down)
      return false;

   // Close if the cross direction opposes the held position.
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
      if(pos_type == POSITION_TYPE_BUY && crossed_down)
         return true;
      if(pos_type == POSITION_TYPE_SELL && crossed_up)
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
