#property strict
#property version   "5.0"
#property description "QM5_11027 atc-lr-slope — Linear-Regression Slope Trend Basket (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11027 atc-lr-slope
// -----------------------------------------------------------------------------
// Source: Andrey Barinov, Interview ATC 2012, MQL5 Articles
//         https://www.mql5.com/en/articles/562
// Card: artifacts/cards_approved/QM5_11027_atc-lr-slope.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads, evaluated once per new H1 bar):
//   Slope signal : ordinary-least-squares linear-regression slope over the last
//                  lr_period closed bars (shifts 1..lr_period). The raw slope is
//                  price-per-bar; we normalise it by ATR so the threshold is
//                  scale-invariant across FX pairs, then express it as a slope
//                  ANGLE in degrees: angle = atan(slope_per_bar / atr) in deg.
//   Long entry   : slope_angle >= long_slope_threshold   AND  no open position.
//   Short entry  : slope_angle <= short_slope_threshold  AND  no open position.
//   Optional ADX : require ADX(adx_period) >= adx_min when adx_min > 0.
//   Stop         : entry -/+ sl_atr_mult * ATR (QM_StopATRFromValue).
//   Breakeven    : move SL to entry once price has moved breakeven_atr * ATR.
//   Trailing     : ATR trail once price has moved trail_start_atr * ATR.
//   Opposite sig : when the slope flips to the opposite side past its threshold,
//                  close at market (the card's "tighten/close on opposite slope"
//                  realised as a deterministic flat-on-flip).
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-OPEN on .DWX zero modeled spread).
//
// One open position per symbol/magic. RISK_FIXED in tester, RISK_PERCENT live.
// The LR slope is a bounded, deterministic closed-bar OLS computation: a single
// loop of lr_period (<=96) iterations of single closed-bar iClose reads, run
// only on the new-bar path. No ML, no martingale, no grid, no external feed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11027;
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
input int    strategy_lr_period          = 48;    // bars in the LR regression window
input double strategy_long_slope_thresh  = 10.0;  // long if slope angle >= this (deg)
input double strategy_short_slope_thresh = -10.0; // short if slope angle <= this (deg)
input int    strategy_atr_period         = 14;    // ATR period (normaliser / stop / trail)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_breakeven_atr      = 1.0;   // move SL to entry after this many ATR
input double strategy_trail_start_atr    = 1.5;   // start ATR trail after this many ATR
input double strategy_trail_atr_mult     = 2.0;   // ATR trail distance multiple
input double strategy_adx_min            = 0.0;   // optional ADX trend filter (0 = off)
input int    strategy_adx_period         = 14;    // ADX period when adx_min > 0
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// Ordinary-least-squares slope (price units per bar) over the last `period`
// CLOSED bars, oldest-first x-axis. Bounded loop (period <= 96), single
// closed-bar iClose reads, called only on the new-bar path. Returns false if
// not enough history yet.
bool LRSlopePerBar(const string sym, const ENUM_TIMEFRAMES tf, const int period, double &slope_out)
  {
   if(period < 2)
      return false;
   if(Bars(sym, tf) < period + 2) // perf-allowed: bounded LR warmup check for bespoke regression signal
      return false;

   // x = 0..period-1 (oldest..newest among the closed bars). Closed bars are at
   // chart shifts period..1 (shift 1 = most recent closed bar = newest x).
   const double n = (double)period;
   double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_xx = 0.0;
   for(int x = 0; x < period; ++x)
     {
      const int shift = period - x;                       // shift period..1
      const double y = iClose(sym, tf, shift);            // perf-allowed: bounded LR closed-bar read
      if(y <= 0.0)
         return false;
      sum_x  += (double)x;
      sum_y  += y;
      sum_xy += (double)x * y;
      sum_xx += (double)x * (double)x;
     }
   const double denom = n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12)
      return false;
   slope_out = (n * sum_xy - sum_x * sum_y) / denom;       // price per bar
   return true;
  }

// Convert a price distance to whole pips for the framework's pip-based trade
// helpers (inverse of QM_StopRulesPipsToPriceDistance; the framework only ships
// the forward direction). Scale-correct on 3/5-digit and JPY symbols.
int PriceDistanceToPips(const string sym, const double distance)
  {
   if(distance <= 0.0)
      return 0;
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0)
      return 0;
   const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return (int)MathFloor(distance / (point * pip_factor));
  }

// Slope angle in degrees, ATR-normalised so the threshold is scale-invariant
// across FX pairs. Returns false if slope/ATR unavailable.
bool LRSlopeAngleDeg(const string sym, const ENUM_TIMEFRAMES tf, double &angle_out)
  {
   double slope_per_bar = 0.0;
   if(!LRSlopePerBar(sym, tf, strategy_lr_period, slope_per_bar))
      return false;
   const double atr = QM_ATR(sym, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   angle_out = MathArctan(slope_per_bar / atr) * 180.0 / M_PI;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer, do not block

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// LR-slope trend entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double angle = 0.0;
   if(!LRSlopeAngleDeg(_Symbol, _Period, angle))
      return false;

   // Optional ADX trend-strength filter.
   if(strategy_adx_min > 0.0)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx <= 0.0 || adx < strategy_adx_min)
         return false;
     }

   const bool go_long  = (angle >= strategy_long_slope_thresh);
   const bool go_short = (angle <= strategy_short_slope_thresh);
   if(!go_long && !go_short)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(go_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;     // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;     // no fixed TP; managed by trail / opposite-signal
      req.reason = "lr_slope_long";
      return true;
     }

   // go_short
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
   req.reason = "lr_slope_short";
   return true;
  }

// Break-even shift then ATR trail once sufficiently in profit. Both helpers are
// monotone (only improve the SL) and self-gate on their trigger distance.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   // Convert ATR-multiple triggers to pip-based triggers for the framework helper.
   const double be_distance    = strategy_breakeven_atr   * atr_value;
   const double trail_distance = strategy_trail_start_atr * atr_value;
   const int    be_trigger_pips    = PriceDistanceToPips(_Symbol, be_distance);

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
      const bool is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0 || open_price <= 0.0)
         continue;
      const double moved = is_buy ? (market - open_price) : (open_price - market);

      // Move to break-even first.
      if(be_trigger_pips > 0)
         QM_TM_MoveToBreakEven(ticket, be_trigger_pips, 0);

      // Then ATR-trail once the trail-start threshold is reached.
      if(moved >= trail_distance)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Opposite-signal exit: close when the slope flips to the opposite side past
// its threshold relative to the open position's direction. One state read on
// the closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double angle = 0.0;
   if(!LRSlopeAngleDeg(_Symbol, _Period, angle))
      return false;

   // Determine the direction of the open position for this symbol/magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const bool is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(is_buy && angle <= strategy_short_slope_thresh)
         return true;   // long open, slope flipped short -> close
      if(!is_buy && angle >= strategy_long_slope_thresh)
         return true;   // short open, slope flipped long -> close
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
