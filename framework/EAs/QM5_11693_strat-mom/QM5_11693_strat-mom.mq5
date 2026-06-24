#property strict
#property version   "5.0"
#property description "QM5_11693 strat-mom — Stratestic Rolling-Return Momentum (long/short, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11693 strat-mom
// -----------------------------------------------------------------------------
// Source: Diogo Matos Chaves / diogomatoschaves, stratestic,
//   stratestic/strategies/trend/momentum.py
//   https://github.com/diogomatoschaves/stratestic/blob/main/stratestic/strategies/trend/momentum.py
// Card: artifacts/cards_approved/QM5_11693_strat-mom.md (g0_status APPROVED).
//
// Mechanics (long/short, closed-bar reads at shift 1, H1):
//   Signal STATE : rolling average of single-bar returns over `window` closed
//                  bars. return[i] = close[i]/close[i+1] - 1, averaged over
//                  shifts 1..window. mom = mean(return[1..window]).
//     mom > 0  -> bullish state (want long)
//     mom < 0  -> bearish state (want short)
//     mom == 0 -> flat (no edge; close any open position)
//   Entry        : when flat and the state is non-zero, open in the state's
//                  direction. The SIGN is a persistent STATE, not a one-bar
//                  cross EVENT, so there is no two-cross zero-trade trap — an
//                  entry fires on the first closed bar after going flat.
//   Exit/Reverse : sign change of the rolling average return closes the open
//                  position (the framework re-evaluates entry on the next closed
//                  bar, opening the opposite side — i.e. reverse on sign flip).
//                  A zero reading also flattens.
//   Stop         : source has no protective stop. V5 adds an ATR catastrophic
//                  stop at entry +/- sl_atr_mult * ATR. No fixed take-profit:
//                  the position rides until the momentum sign flips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11693;
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
input int    strategy_mom_window        = 30;    // rolling-return window (bars)
input int    strategy_atr_period        = 14;    // ATR period for the catastrophic stop
input double strategy_sl_atr_mult       = 3.0;   // catastrophic stop = mult * ATR

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Rolling average of single-bar returns over `window` closed bars.
// return at shift s = close[s]/close[s+1] - 1. Averaged over s = 1..window.
// Reads are bounded (window+1 deep) and only run on the closed-bar path
// (gated by QM_IsNewBar upstream), so the single-shift iClose reads are
// perf-allowed bespoke math (no QM rolling-return helper exists).
bool MomentumRollingReturn(double &mom_out)
  {
   const int window = (strategy_mom_window > 1 ? strategy_mom_window : 2);
   double sum = 0.0;
   int    n   = 0;
   for(int s = 1; s <= window; ++s)
     {
      const double c_now  = iClose(_Symbol, _Period, s);     // perf-allowed: bounded closed-bar read
      const double c_prev = iClose(_Symbol, _Period, s + 1); // perf-allowed: bounded closed-bar read
      if(c_now <= 0.0 || c_prev <= 0.0)
         return false; // history not warm enough yet
      sum += (c_now / c_prev) - 1.0;
      ++n;
     }
   if(n <= 0)
      return false;
   mom_out = sum / (double)n;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No per-tick blocking filter. Momentum is a closed-bar STATE evaluated in
// Strategy_EntrySignal; there is no session/spread gating in this system.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Long/short momentum entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double mom = 0.0;
   if(!MomentumRollingReturn(mom))
      return false;

   // Flat state: no edge, do not enter.
   if(mom == 0.0)
      return false;

   const bool go_long = (mom > 0.0);

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const QM_OrderType otype = (go_long ? QM_BUY : QM_SELL);
   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target; momentum sign-flip is the exit
   req.reason = (go_long ? "mom_long" : "mom_short");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active management beyond the ATR catastrophic stop; the exit is the
// momentum sign-flip handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit / reverse: the rolling-return sign no longer agrees with the open
// position's direction (sign flip), or the reading is exactly flat (zero).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double mom = 0.0;
   if(!MomentumRollingReturn(mom))
      return false;

   // Determine the side of the currently open position for this magic.
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

   // Flat momentum flattens any position.
   if(mom == 0.0)
      return (have_long || have_short);

   // Sign flip against the held direction triggers the exit (reverse).
   if(have_long && mom < 0.0)
      return true;
   if(have_short && mom > 0.0)
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
