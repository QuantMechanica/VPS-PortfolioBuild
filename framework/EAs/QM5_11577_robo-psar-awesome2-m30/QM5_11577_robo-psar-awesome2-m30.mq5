#property strict
#property version   "5.0"
#property description "QM5_11577 robo-psar-awesome2-m30 — Parabolic SAR trend + Awesome Oscillator zero-cross + EMA5 (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11577 robo-psar-awesome2-m30
// -----------------------------------------------------------------------------
// Source: RoboForex strategy collection, "Strategy Parabolic SAR & Awesome",
//   pages 48-49 (local PDF archive, source_id e78a9f1f-4e6a-563c-a080-915133d6ed28).
// Card: artifacts/cards_approved/QM5_11577_robo-psar-awesome2-m30.md (APPROVED).
//
// Mechanics (closed-bar signal reads at shift 1; M30):
//   Trend STATE  : Parabolic SAR(step, max) vs price.
//                  LONG state  = SAR below current price.
//                  SHORT state = SAR above current price.
//   AO definition: AO = SMA(fast=5, median price) - SMA(slow=34, median price),
//                  median price = (High+Low)/2 == PRICE_MEDIAN. Computed in-EA
//                  via QM_SMA(..., PRICE_MEDIAN) (no QM_AO helper exists).
//   AO colour    : card "green & above 0" = ao_now>0 AND rising (ao_now>ao_prev);
//                  "red & below 0" = ao_now<0 AND falling.
//   EMA5 STATE   : LONG needs EMA5 below current price; SHORT needs EMA5 above.
//   Stop / Take  : Fixed pip stops/takes per card by symbol:
//                  EURUSD TP 60 / SL 20, USDCHF TP 50 / SL 18, other FX TP 55 / SL 20.
//                  QM_StopFixedPips / QM_TakeFixedPips scale pips->price correctly.
//   Defensive exit: Parabolic SAR flips against the open trade -> close manually
//                  (card "Close early if Parabolic SAR flips against the position").
//   Filters      : one position per magic, spread cap 3 pips, London/New York
//                  session gate in broker time, plus the framework news hook.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11577;
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
input double strategy_sar_step          = 0.01;   // Parabolic SAR step (card source default 0.01)
input double strategy_sar_max           = 0.10;   // Parabolic SAR maximum (card source default 0.10)
input int    strategy_ema_period        = 5;      // fast EMA trend-line (card EMA5)
input int    strategy_ao_fast_period    = 5;      // Awesome Oscillator fast SMA (median price)
input int    strategy_ao_slow_period    = 34;     // Awesome Oscillator slow SMA (median price)
input int    strategy_eurusd_sl_pips    = 20;     // EURUSD stop loss from card
input int    strategy_eurusd_tp_pips    = 60;     // EURUSD take profit from card
input int    strategy_usdchf_sl_pips    = 18;     // USDCHF stop loss from card
input int    strategy_usdchf_tp_pips    = 50;     // USDCHF take profit from card
input int    strategy_other_sl_pips     = 20;     // other FX stop loss for P2 baseline
input int    strategy_other_tp_pips     = 55;     // other FX take profit for P2 baseline
input int    strategy_spread_cap_pips   = 3;      // skip genuinely wide spread (card spread cap 3 pips)
input int    strategy_london_start_hour_broker = 8;
input int    strategy_london_end_hour_broker   = 17;
input int    strategy_newyork_start_hour_broker = 13;
input int    strategy_newyork_end_hour_broker   = 23;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Keep exits reachable; entry-specific time/spread filters are applied in EntrySignal.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_sar_step <= 0.0 ||
      strategy_sar_max <= strategy_sar_step ||
      strategy_ema_period <= 0 ||
      strategy_ao_fast_period <= 0 ||
      strategy_ao_slow_period <= strategy_ao_fast_period ||
      strategy_spread_cap_pips <= 0)
      return false;

   int stop_pips = strategy_other_sl_pips;
   int take_pips = strategy_other_tp_pips;
   if(_Symbol == "EURUSD.DWX")
     {
      stop_pips = strategy_eurusd_sl_pips;
      take_pips = strategy_eurusd_tp_pips;
     }
   else if(_Symbol == "USDCHF.DWX")
     {
      stop_pips = strategy_usdchf_sl_pips;
      take_pips = strategy_usdchf_tp_pips;
     }
   if(stop_pips <= 0 || take_pips <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const bool london_wrap = (strategy_london_start_hour_broker > strategy_london_end_hour_broker);
   const bool newyork_wrap = (strategy_newyork_start_hour_broker > strategy_newyork_end_hour_broker);
   const bool in_london = (strategy_london_start_hour_broker == strategy_london_end_hour_broker) ||
                          (!london_wrap && dt.hour >= strategy_london_start_hour_broker && dt.hour < strategy_london_end_hour_broker) ||
                          (london_wrap && (dt.hour >= strategy_london_start_hour_broker || dt.hour < strategy_london_end_hour_broker));
   const bool in_newyork = (strategy_newyork_start_hour_broker == strategy_newyork_end_hour_broker) ||
                           (!newyork_wrap && dt.hour >= strategy_newyork_start_hour_broker && dt.hour < strategy_newyork_end_hour_broker) ||
                           (newyork_wrap && (dt.hour >= strategy_newyork_start_hour_broker || dt.hour < strategy_newyork_end_hour_broker));
   if(!in_london && !in_newyork)
      return false;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero modeled .DWX spread is tradeable.
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return false;

   // --- Trend STATE: Parabolic SAR side vs current price at the new bar. ---
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return false;
   const bool sar_long_state  = (sar1 < bid);
   const bool sar_short_state = (sar1 > ask);
   if(!sar_long_state && !sar_short_state)
      return false;

   // --- EMA5 STATE: current price side of the fast trend line. ---
   const double ema5 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema5 <= 0.0)
      return false;
   const bool ema_long_state  = (bid > ema5);
   const bool ema_short_state = (ask < ema5);

   // --- Awesome Oscillator at the last two closed bars ---
   const double ao_fast_now  = QM_SMA(_Symbol, _Period, strategy_ao_fast_period, 1, PRICE_MEDIAN);
   const double ao_slow_now  = QM_SMA(_Symbol, _Period, strategy_ao_slow_period, 1, PRICE_MEDIAN);
   const double ao_fast_prev = QM_SMA(_Symbol, _Period, strategy_ao_fast_period, 2, PRICE_MEDIAN);
   const double ao_slow_prev = QM_SMA(_Symbol, _Period, strategy_ao_slow_period, 2, PRICE_MEDIAN);
   if(ao_fast_now <= 0.0 || ao_slow_now <= 0.0 || ao_fast_prev <= 0.0 || ao_slow_prev <= 0.0)
      return false;
   const double ao_now  = ao_fast_now - ao_slow_now;
   const double ao_prev = ao_fast_prev - ao_slow_prev;

   // --- AO colour/sign STATE from the card: green and above zero, red and below zero. ---
   const bool ao_green_above_zero = (ao_now > 0.0 && ao_now > ao_prev);
   const bool ao_red_below_zero   = (ao_now < 0.0 && ao_now < ao_prev);

   QM_OrderType side;
   if(sar_long_state && ema_long_state && ao_green_above_zero)
      side = QM_BUY;
   else if(sar_short_state && ema_short_state && ao_red_below_zero)
      side = QM_SELL;
   else
      return false;

   // --- Entry price ---
   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0)
      return false;

   // --- Fixed-pip stop / take (pip-scale correct per symbol) ---
   const double sl = QM_StopFixedPips(_Symbol, side, entry, stop_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, take_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   // Stop must sit on the correct side of entry.
   if(side == QM_BUY  && !(sl < entry && tp > entry))
      return false;
   if(side == QM_SELL && !(sl > entry && tp < entry))
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "psar_ao_ema5_long" : "psar_ao_ema5_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management beyond the fixed pip stop / take.
// The defensive PSAR-flip exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: Parabolic SAR flips against the open trade. One event/bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return false;

   // Determine the open position's direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && sar1 > bid)
         return true;   // long but SAR flipped above price
      if(ptype == POSITION_TYPE_SELL && sar1 < ask)
         return true;   // short but SAR flipped below price
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
