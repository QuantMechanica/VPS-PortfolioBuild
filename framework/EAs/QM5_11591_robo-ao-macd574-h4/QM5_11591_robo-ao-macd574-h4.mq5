#property strict
#property version   "5.0"
#property description "QM5_11591 robo-ao-macd574-h4 — Awesome Oscillator zero-cross + MACD(5,7,4) filter (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11591 robo-ao-macd574-h4
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, 2020, p.106 ("Strategy Awesome and
//   MACD"). source_id ed246754-1f4d-5bed-8dd3-3b5cbf1b420d.
// Card: artifacts/cards_approved/QM5_11591_robo-ao-macd574-h4.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H4):
//   AO definition: AO = SMA(fast=5, median) - SMA(slow=34, median), where the
//                  median price = (High+Low)/2 == PRICE_MEDIAN. Computed in-EA
//                  via QM_SMA(..., PRICE_MEDIAN) (no QM_AO helper exists).
//   Trigger EVENT: a fresh AO zero-line cross (ONE event per bar).
//                  LONG : AO crossed UP   through 0 (ao_prev <= 0, ao_now > 0).
//                  SHORT: AO crossed DOWN through 0 (ao_prev >= 0, ao_now < 0).
//   Confirm STATE: MACD(fast,slow,signal) main line agrees with the AO cross
//                  direction at the SAME closed bar (shift 1). The card's
//                  "MACD_histogram > 0 / < 0" maps to QM_MACD_Main MODE_MAIN.
//                  MACD is a STATE, not a second EVENT, so we never require two
//                  fresh crosses on the same bar (the two-cross zero-trade trap).
//   Stop         : entry -/+ sl_atr_mult * ATR(atr_period) (card: 2 x ATR(14)).
//   Take profit  : RR multiple of the stop distance (card P2 default 1R).
//   Defensive exit: opposite AO zero-line cross -> close the open position.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11591;
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
input int    strategy_ao_fast_period    = 5;      // Awesome Oscillator fast SMA (median price)
input int    strategy_ao_slow_period    = 34;     // Awesome Oscillator slow SMA (median price)
input int    strategy_macd_fast         = 5;      // MACD fast EMA period   (card default 5; sweep 3,5,8)
input int    strategy_macd_slow         = 7;      // MACD slow EMA period   (card default 7; sweep 5,7,10)
input int    strategy_macd_signal       = 4;      // MACD signal EMA period (card default 4; sweep 3,4,5)
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR (card 2 x ATR)
input double strategy_tp_rr             = 1.0;    // take-profit as RR multiple of stop distance
input double strategy_spread_cap_pips   = 3.0;    // skip a genuinely wide spread (fail-open on .DWX)

// -----------------------------------------------------------------------------
// AO helper — Awesome Oscillator on the median price at a given closed-bar shift.
// AO = SMA(fast, median) - SMA(slow, median). PRICE_MEDIAN == (High+Low)/2.
// -----------------------------------------------------------------------------
double AO_Value(const int shift)
  {
   const double fast = QM_SMA(_Symbol, _Period, strategy_ao_fast_period, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, _Period, strategy_ao_slow_period, shift, PRICE_MEDIAN);
   return fast - slow;
  }

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

   const double spread = ask - bid;
   const double cap    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Awesome Oscillator at the last two closed bars ---
   const double ao_now  = AO_Value(1);
   const double ao_prev = AO_Value(2);

   // --- Trigger EVENT: fresh AO zero-line cross (one event per bar) ---
   const bool ao_cross_up   = (ao_prev <= 0.0 && ao_now > 0.0);
   const bool ao_cross_down = (ao_prev >= 0.0 && ao_now < 0.0);
   if(!ao_cross_up && !ao_cross_down)
      return false;

   // --- Confirm STATE: MACD main line direction at the same closed bar.
   //     The card's "MACD_histogram > 0 / < 0" maps to MODE_MAIN of MACD(5,7,4).
   //     STATE only — never a second event, so no two-cross zero-trade trap. ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);

   QM_OrderType side;
   if(ao_cross_up && macd_main > 0.0)
      side = QM_BUY;
   else if(ao_cross_down && macd_main < 0.0)
      side = QM_SELL;
   else
      return false;

   // --- Entry price ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- ATR stop (card: 2 x ATR(14)) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   // Stop must sit on the correct side of entry.
   if(side == QM_BUY && !(sl < entry))
      return false;
   if(side == QM_SELL && !(sl > entry))
      return false;

   // --- Take profit: RR multiple of the stop distance ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ao_macd574_long" : "ao_macd574_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop / RR target.
// The defensive opposite-AO-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite AO zero-line cross against the open trade.
// One event/bar; the held direction selects which cross closes the trade.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ao_now  = AO_Value(1);
   const double ao_prev = AO_Value(2);
   const bool ao_cross_up   = (ao_prev <= 0.0 && ao_now > 0.0);
   const bool ao_cross_down = (ao_prev >= 0.0 && ao_now < 0.0);
   if(!ao_cross_up && !ao_cross_down)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && ao_cross_down)
         return true;   // long but AO crossed down -> exit
      if(ptype == POSITION_TYPE_SELL && ao_cross_up)
         return true;   // short but AO crossed up -> exit
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
