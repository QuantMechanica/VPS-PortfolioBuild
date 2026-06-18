#property strict
#property version   "5.0"
#property description "QM5_11261 cs-mom-zero — CryptoSignal Momentum Zero-Line (H1, symmetric L/S)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11261 cs-mom-zero
// -----------------------------------------------------------------------------
// Source: Abenezer Mamo / CryptoSignal contributors, Crypto-Signal momentum
//   config examples (docs/config.md, momentum hot:0/cold:0, H1 period 12,
//   D1 period 10). Card: artifacts/cards_approved/QM5_11261_cs-mom-zero.md
//   (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1):
//   Trigger EVENT  : H1 Momentum(mom_h1) crosses the zero-line (one event/bar,
//                    measured shift2 -> shift1). Long on cross UP, short on
//                    cross DOWN. This is the SINGLE trigger event.
//   Confirm STATE  : D1 Momentum(mom_d1) is on the SAME side of the zero-line
//                    (a STATE, not a second cross — avoids the two-cross trap).
//                    Toggleable via mom_d1_confirm.
//   Exit EVENT     : H1 Momentum crosses BACK through the zero-line (opposite
//                    direction) -> close. Plus a hard time stop of N H1 bars.
//   Stop           : ATR(atr_period) hard stop at sl_atr_mult * ATR.
//   Trail          : after +trail_after_r * R favourable, ATR trailing stop at
//                    trail_atr_mult * ATR (ratchet-only via QM_TM_TrailATR).
//   Spread guard   : skip only a genuinely wide spread (fail-OPEN on .DWX zero
//                    modeled spread).
//
// ZERO-LINE CONVENTION (important): the framework QM_Momentum reader wraps the
// MT5 iMomentum oscillator, which is a RATIO centred at 100.0
// (close/close[period]*100), NOT a difference centred at 0.0. The card's
// CryptoSignal "zero-line / hot:0 cold:0" maps to the iMomentum NEUTRAL line,
// which is 100.0 here. We therefore expose `mom_zero_level` (default 100.0) so
// the "zero-line cross" is matched to the reader's actual scale. A literal 0.0
// threshold on this reader would never be crossed -> 0 trades (DWX invariant #4
// adjacent). mom_zero_level is a STATE/threshold parameter, not a degenerate
// placeholder.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11261;
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
input int    strategy_mom_h1_period     = 12;     // H1 momentum period (trigger TF)
input int    strategy_mom_d1_period     = 10;     // D1 momentum period (confirm TF)
input double strategy_mom_zero_level    = 100.0;  // iMomentum neutral line (=card "zero")
input bool   strategy_mom_d1_confirm    = true;   // require D1 same-side confirmation
input int    strategy_atr_period        = 14;     // ATR period (stop / trail)
input double strategy_sl_atr_mult       = 2.5;    // hard stop = mult * ATR
input double strategy_trail_atr_mult    = 2.0;    // trailing stop = mult * ATR
input double strategy_trail_after_r     = 1.0;    // start trailing after +R favourable
input int    strategy_time_stop_bars    = 72;     // hard time stop in H1 bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric long/short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: H1 Momentum crosses the zero-line (shift2 -> shift1) ---
   const double mom_now  = QM_Momentum(_Symbol, _Period, strategy_mom_h1_period, 1);
   const double mom_prev = QM_Momentum(_Symbol, _Period, strategy_mom_h1_period, 2);
   if(mom_now == 0.0 || mom_prev == 0.0)
      return false; // reader not warmed up yet

   const double lvl = strategy_mom_zero_level;
   const bool crossed_up   = (mom_prev <= lvl && mom_now > lvl);
   const bool crossed_down = (mom_prev >= lvl && mom_now < lvl);
   if(!crossed_up && !crossed_down)
      return false;

   // --- Confirm STATE: D1 Momentum on the SAME side (state, not a cross) ---
   if(strategy_mom_d1_confirm)
     {
      const double mom_d1 = QM_Momentum(_Symbol, PERIOD_D1, strategy_mom_d1_period, 1);
      if(mom_d1 == 0.0)
         return false;
      if(crossed_up   && !(mom_d1 > lvl))
         return false;
      if(crossed_down && !(mom_d1 < lvl))
         return false;
     }

   // --- ATR for stop sizing ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

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
   req.tp     = 0.0;   // no fixed TP — exit on opposite cross / time stop / trail
   req.reason = crossed_up ? "mom_zero_long" : "mom_zero_short";
   return true;
  }

// ATR trailing stop once the trade is at least +trail_after_r * R favourable.
// QM_TM_TrailATR only ratchets the stop tighter, so calling it past the trigger
// is safe and one-directional.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price    = PositionGetDouble(POSITION_SL);
      if(entry_price <= 0.0 || sl_price <= 0.0)
         continue;

      const double risk_dist = MathAbs(entry_price - sl_price);
      if(risk_dist <= 0.0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double favourable = is_buy ? (market - entry_price)
                                       : (entry_price - market);
      if(favourable >= strategy_trail_after_r * risk_dist)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Discretionary exit: H1 Momentum crosses BACK through the zero-line opposite to
// the open position's direction, OR the hard time stop of N H1 bars elapsed.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine direction + age of the open position for this magic.
   bool is_buy = false;
   datetime open_time = 0;
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_buy    = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found     = true;
      break;
     }
   if(!found)
      return false;

   // --- Hard time stop: N H1 bars elapsed since entry ---
   const int bar_seconds = PeriodSeconds(_Period);
   if(bar_seconds > 0 && open_time > 0)
     {
      const long elapsed_bars = (long)((TimeCurrent() - open_time) / bar_seconds);
      if(elapsed_bars >= (long)strategy_time_stop_bars)
         return true;
     }

   // --- Opposite zero-line cross (one event, shift2 -> shift1) ---
   const double mom_now  = QM_Momentum(_Symbol, _Period, strategy_mom_h1_period, 1);
   const double mom_prev = QM_Momentum(_Symbol, _Period, strategy_mom_h1_period, 2);
   if(mom_now == 0.0 || mom_prev == 0.0)
      return false;

   const double lvl = strategy_mom_zero_level;
   if(is_buy)
      return (mom_prev >= lvl && mom_now < lvl);   // long exits on cross DOWN
   else
      return (mom_prev <= lvl && mom_now > lvl);   // short exits on cross UP
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
