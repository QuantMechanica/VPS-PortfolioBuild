#property strict
#property version   "5.0"
#property description "QM5_12483 shv-ema20-price — Price vs EMA20 trend state (symmetric long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12483 shv-ema20-price
// -----------------------------------------------------------------------------
// Source: shashankvemuri/Finance ema_crossover_strategy.py
//   https://github.com/shashankvemuri/Finance/blob/master/portfolio_strategies/ema_crossover_strategy.py
// Card: artifacts/cards_approved/QM5_12483_shv-ema20-price.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1, D1):
//   Position STATE : sign(Close[1] - EMA20[1]).
//                      Close > EMA20  -> desired LONG.
//                      Close < EMA20  -> desired SHORT.
//                      Close == EMA20 -> flat (do nothing).
//   The source sets position sign from the price-vs-EMA state and shifts it one
//   bar to simulate next-bar execution. We replicate that as a STATE entry: when
//   flat, open in the direction of the current closed-bar state. One position per
//   magic prevents per-bar pile-on, so an entry fires only on a state flip after
//   a flat/exit — never two cross EVENTS on the same bar (DWX two-cross trap).
//   Entry   : flat AND state != 0 -> open that direction next completed bar.
//   Exit    : open position's state flips (long: Close <= EMA20; short:
//             Close >= EMA20) -> close manually; the next bar re-enters the
//             opposite direction via the entry hook (state-flip reversal).
//   Emergency stop : entry -/+ 2.5 * ATR(20)  (source defines no hard stop).
//   Time stop      : close after time_stop_bars D1 bars without a state flip.
//   No TP — the strategy is a trend-follower exited by the EMA20 state flip.
//
//   Filters (STATE, cheap): warmup >= 120 bars; skip wide spread only
//   (fail-open on .DWX zero modeled spread); skip non-positive close.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12483;
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
input int    strategy_ema_period         = 20;     // price-vs-EMA trend state length
input int    strategy_atr_period         = 20;     // ATR period (emergency stop)
input double strategy_sl_atr_mult        = 2.5;    // emergency stop = mult * ATR
input int    strategy_time_stop_bars     = 30;     // close after N bars without a state flip
input int    strategy_warmup_bars        = 120;    // minimum closed bars before trading
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// File-scope: bar-open time of the bar on which the open position was entered.
// Used to count D1 bars held for the time stop. Reset whenever flat.
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Helper: current closed-bar price-vs-EMA20 state. +1 long, -1 short, 0 flat/invalid.
// -----------------------------------------------------------------------------
int PriceVsEmaState()
  {
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return 0;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return 0;
   if(close1 > ema)
      return +1;
   if(close1 < ema)
      return -1;
   return 0; // exactly on the EMA -> do nothing
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

   // Warmup: require enough closed bars for a stable EMA20.
   if(Bars(_Symbol, _Period) < strategy_warmup_bars)
      return false;

   // Position STATE from the last closed bar.
   const int state = PriceVsEmaState();
   if(state == 0)
      return false;

   // Emergency stop sized off ATR at the current fill price.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(state > 0)
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
      req.tp     = 0.0;   // no take-profit; EMA-state flip is the exit
      req.reason = "ema20_state_long";
     }
   else
     {
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
      req.reason = "ema20_state_short";
     }

   // Stamp the entry bar for the time stop (current forming bar's open time).
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
   return true;
  }

// No active trade management beyond the fixed ATR emergency stop. The EMA-state
// flip and the time stop both live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Manual exit: (a) the open position's price-vs-EMA20 state has flipped against
// it, or (b) the time stop is hit. One event per closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_entry_bar_time = 0; // flat — reset the hold clock
      return false;
     }

   // Determine the direction of the open position for this magic.
   int pos_dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      pos_dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   // (a) State flip against the open position.
   //   Long  exits when Close <= EMA20 (state <= 0).
   //   Short exits when Close >= EMA20 (state >= 0).
   const int state = PriceVsEmaState();
   if(pos_dir > 0 && state <= 0)
      return true;
   if(pos_dir < 0 && state >= 0)
      return true;

   // (b) Time stop: close after strategy_time_stop_bars D1 bars without a flip.
   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const int bars_held = Bars(_Symbol, _Period, g_entry_bar_time, iTime(_Symbol, _Period, 0));
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
      g_entry_bar_time = 0; // flat after the manual close — reset the hold clock
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
