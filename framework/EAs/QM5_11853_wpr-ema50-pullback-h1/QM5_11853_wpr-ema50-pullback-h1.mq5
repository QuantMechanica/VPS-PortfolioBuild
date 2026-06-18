#property strict
#property version   "5.0"
#property description "QM5_11853 wpr-ema50-pullback-h1 — WPR + EMA50 trend pullback (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11853 wpr-ema50-pullback-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Secret to Winning Forex — The Continuation Method" (~2014).
// Card: artifacts/cards_approved/QM5_11853_wpr-ema50-pullback-h1.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1 base timeframe):
//   Trend STATE (D1) : EMA(50) on D1 sloped over `strategy_d1_slope_lookback`
//                      daily bars. Up-slope => bullish bias; down => bearish.
//   Pullback STATE   : within the last `strategy_pullback_lookback` H1 bars
//                      BEFORE the trigger bar, price closed on the far side of
//                      the H1 EMA(50) against the trend (bull: a close BELOW
//                      EMA50; bear: a close ABOVE EMA50).
//   Trigger EVENT    : Williams %R recovers out of the extreme in the trend
//                      direction — the SINGLE fresh cross.
//                        Long : WPR[2] < -wpr_os  AND WPR[1] >= -wpr_os
//                        Short: WPR[2] > -wpr_ob  AND WPR[1] <= -wpr_ob
//   Entry            : market on the closed signal bar (framework single-entry
//                      path; the card's BuyStop/SellStop pending is approximated
//                      by a market fill at the confirmed resume — see flags).
//   Stop             : entry -/+ sl_atr_mult * ATR(14)  (card: 2xATR factory SL).
//   Take profit      : RR-multiple of the stop (card: 2:1, then Money-Line trail).
//   Money-Line trail : once unrealised >= rr_activate * risk, move SL to the
//                      extreme of the last two H1 bars that BOTH closed on the
//                      far side of SMA(5) (bull: below; bear: above).
//
// Two-cross trap avoided: the WPR recovery is the ONLY fresh cross/event. The
// D1 slope and the H1 pullback-close are STATES (slope sign / lookback touch),
// never required to fire on the same bar as the WPR cross.
//
// Only the five Strategy_* hooks + Strategy inputs are EA-specific. Everything
// below the wiring line is framework boilerplate and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11853;
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
input int    strategy_ema_period          = 50;    // EMA period (D1 trend + H1 pullback ref)
input int    strategy_d1_slope_lookback   = 10;    // D1 bars over which the EMA50 slope is measured
input int    strategy_wpr_period          = 14;    // Williams %R lookback
input double strategy_wpr_oversold        = 80.0;  // OS magnitude; long trigger crosses up through -80
input double strategy_wpr_overbought      = 20.0;  // OB magnitude; short trigger crosses down through -20
input int    strategy_pullback_lookback   = 6;     // H1 bars to scan for the EMA50 pullback touch
input int    strategy_atr_period          = 14;    // ATR period (stop distance)
input double strategy_sl_atr_mult         = 2.0;   // stop distance = mult * ATR
input double strategy_tp_rr               = 2.0;   // initial take-profit reward:risk
input int    strategy_sma_trail_period    = 5;     // SMA period for the Money-Line trail
input double strategy_trail_activate_rr    = 2.0;  // activate Money-Line trail once unrealised >= this * risk
input double strategy_spread_pct_of_stop  = 15.0;  // skip only if spread > this % of stop distance

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

// Returns +1 bullish / -1 bearish / 0 flat for the D1 EMA50 slope STATE.
int TrendBias()
  {
   const double ema_now = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double ema_old = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period,
                                 1 + strategy_d1_slope_lookback);
   if(ema_now <= 0.0 || ema_old <= 0.0)
      return 0;
   if(ema_now > ema_old)
      return 1;
   if(ema_now < ema_old)
      return -1;
   return 0;
  }

// Pullback STATE: did price close on the far side of the H1 EMA50 within the
// lookback window that PRECEDES the trigger bar (shifts 2 .. lookback+1)?
// dir = +1 bullish (look for a close BELOW EMA50), dir = -1 bearish (ABOVE).
bool PullbackTouched(const int dir)
  {
   const int first_shift = 2;
   const int last_shift  = strategy_pullback_lookback + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double close_s = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      const double ema_s   = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
      if(close_s <= 0.0 || ema_s <= 0.0)
         continue;
      if(dir > 0 && close_s < ema_s)
         return true;
      if(dir < 0 && close_s > ema_s)
         return true;
     }
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE (D1 EMA50 slope) ---
   const int bias = TrendBias();
   if(bias == 0)
      return false;

   // --- Trigger EVENT: WPR recovers out of the extreme (single fresh cross) ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // WPR range [-100, 0]; -100 is a valid extreme, so guard only the upper edge.
   if(wpr_now > 0.0 || wpr_prev > 0.0)
      return false;

   const double os_level = -strategy_wpr_oversold;   // e.g. -80
   const double ob_level = -strategy_wpr_overbought;  // e.g. -20

   bool long_trigger  = false;
   bool short_trigger = false;
   if(bias > 0)
      long_trigger  = (wpr_prev < os_level && wpr_now >= os_level);
   else
      short_trigger = (wpr_prev > ob_level && wpr_now <= ob_level);

   if(!long_trigger && !short_trigger)
      return false;

   // --- Pullback STATE: prior close on the far side of the H1 EMA50 ---
   if(!PullbackTouched(bias))
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(long_trigger)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "wpr_ema50_pb_long";
      return true;
     }

   // short_trigger
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   const double tp_s = QM_TakeRR(_Symbol, QM_SELL, entry_s, sl_s, strategy_tp_rr);
   if(tp_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = tp_s;
   req.reason = "wpr_ema50_pb_short";
   return true;
  }

// Money-Line trail: once unrealised >= activate_rr * risk, move SL to the
// extreme of the last two H1 bars that BOTH closed on the far side of SMA(5).
// Runs per tick, but all the indicator math is closed-bar (shift 1/2) reads.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double sma1 = QM_SMA(_Symbol, _Period, strategy_sma_trail_period, 1);
   const double sma2 = QM_SMA(_Symbol, _Period, strategy_sma_trail_period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0)
      return;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long   pos_type   = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      const double risk       = MathAbs(open_price - cur_sl);
      if(risk <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         // Activation: unrealised reward >= activate_rr * risk.
         if(bid - open_price < strategy_trail_activate_rr * risk)
            continue;
         // Both of the last two bars must have CLOSED below SMA5.
         if(!(close1 < sma1 && close2 < sma2))
            continue;
         const double new_sl = MathMin(close1, close2);
         if(new_sl > cur_sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "money_line_trail_long");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if(open_price - ask < strategy_trail_activate_rr * risk)
            continue;
         // Both of the last two bars must have CLOSED above SMA5.
         if(!(close1 > sma1 && close2 > sma2))
            continue;
         const double new_sl = MathMax(close1, close2);
         if(new_sl < cur_sl && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "money_line_trail_short");
        }
     }
  }

// No discretionary exit beyond the ATR stop / RR target / Money-Line trail.
bool Strategy_ExitSignal()
  {
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
