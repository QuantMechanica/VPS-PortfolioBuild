#property strict
#property version   "5.0"
#property description "QM5_11102 basing-breakout — Basing-candle compression + next-bar breakout (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11102 basing-breakout
// -----------------------------------------------------------------------------
// Source: EarnForex "Basing Candlesticks" (GitHub Basing-Candlesticks repo).
// Card: artifacts/cards_approved/QM5_11102_basing-breakout.md (g0_status APPROVED).
//
// Mechanics (H4, closed-bar reads at shift 1; the "basing" candle is shift 1):
//   Basing candle (prior CLOSED bar, shift 1):
//     body/range ratio  : abs(open1-close1)/(high1-low1) < basing_ratio_max (0.50)
//     range band        : basing_atr_lo*ATR <= (high1-low1) <= basing_atr_hi*ATR
//   Breakout EVENT (the just-closed bar broke out of the basing candle):
//     LONG  : close1 > basing_high + breakout_atr_mult*ATR  AND the basing
//             reference is the bar at shift 2 (the candle being broken).
//     SHORT : close1 < basing_low  - breakout_atr_mult*ATR.
//   To keep "previous candle is basing, current closes through it" exactly:
//     basing candle = shift 2; breakout bar = shift 1 (the just-closed bar).
//   If BOTH long and short break on the same bar -> skip.
//   Stop : opposite side of the basing candle, capped at sl_atr_cap_mult*ATR.
//   Exit : opposite basing-candle breakout (handled by entry-of-opposite) OR
//          time stop after max_hold_bars closed H4 bars.
//
// .DWX invariants honoured:
//   - Gapless CFD: breakout keyed off prior CLOSE (close1), not range/gap.
//   - Spread guard fails OPEN on zero modeled spread.
//   - No swap gate, no external macro CSV, no per-EA IsNewBar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11102;
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
input int    strategy_atr_period         = 14;    // ATR period (band filter / stop / breakout buffer)
input double strategy_basing_ratio_max   = 0.50;  // basing if abs(o-c)/(h-l) < this
input double strategy_basing_atr_lo      = 0.35;  // basing range >= this * ATR
input double strategy_basing_atr_hi      = 1.50;  // basing range <= this * ATR
input double strategy_breakout_atr_mult  = 0.05;  // breakout buffer beyond basing hi/lo, in ATR
input double strategy_sl_atr_cap_mult    = 2.0;   // stop capped at this * ATR from entry
input int    strategy_max_hold_bars      = 10;    // time-stop: close after N closed H4 bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

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
      return false; // no ATR yet — defer to entry gate, do not block

   const double stop_distance = strategy_sl_atr_cap_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Detect a basing candle at the given shift. Returns true and fills the
// candle's high/low via the out params. Uses closed bars only (shift >= 1).
bool BasingCandleAt(const int shift, const double atr_value,
                    double &out_high, double &out_low)
  {
   const double o = iOpen(_Symbol, _Period, shift);   // perf-allowed: single closed-bar reads
   const double c = iClose(_Symbol, _Period, shift);
   const double h = iHigh(_Symbol, _Period, shift);
   const double l = iLow(_Symbol, _Period, shift);
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return false;

   const double range = h - l;
   if(range <= 0.0)
      return false;

   // Body/range compression test.
   if((MathAbs(o - c) / range) >= strategy_basing_ratio_max)
      return false;

   // Range band relative to ATR (compression filter).
   if(range < strategy_basing_atr_lo * atr_value)
      return false;
   if(range > strategy_basing_atr_hi * atr_value)
      return false;

   out_high = h;
   out_low  = l;
   return true;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// One position per symbol/magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Basing candle = bar at shift 2 (the "previous completed candle").
   // Breakout bar = the just-closed bar at shift 1.
   double basing_high = 0.0;
   double basing_low  = 0.0;
   if(!BasingCandleAt(2, atr_value, basing_high, basing_low))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double buffer = strategy_breakout_atr_mult * atr_value;
   const bool broke_up   = (close1 > basing_high + buffer);
   const bool broke_down = (close1 < basing_low  - buffer);

   // Ambiguous: both sides broke on the same bar -> skip.
   if(broke_up && broke_down)
      return false;
   if(!broke_up && !broke_down)
      return false;

   const double entry = (broke_up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   // Stop = opposite side of the basing candle, capped at sl_atr_cap_mult*ATR.
   const double cap = strategy_sl_atr_cap_mult * atr_value;
   double sl = 0.0;
   if(broke_up)
     {
      double raw_sl = basing_low;                 // opposite side for a long
      double capped = entry - cap;                // furthest allowed stop
      if(raw_sl < capped)
         raw_sl = capped;                         // cap the distance
      if(raw_sl >= entry)
         return false;                            // degenerate stop
      sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
      req.type = QM_BUY;
     }
   else
     {
      double raw_sl = basing_high;                // opposite side for a short
      double capped = entry + cap;                // furthest allowed stop
      if(raw_sl > capped)
         raw_sl = capped;                         // cap the distance
      if(raw_sl <= entry)
         return false;                            // degenerate stop
      sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
      req.type = QM_SELL;
     }

   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — exits via opposite breakout or time stop
   req.reason = (broke_up ? "basing_breakout_long" : "basing_breakout_short");
   return true;
  }

// No active trade management beyond the fixed stop. Exits in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: (a) time stop after max_hold_bars closed H4 bars, OR
//       (b) an opposite basing-candle breakout against the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Locate this EA's open position to read direction + open time.
   bool   have_pos = false;
   bool   is_long  = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // (a) Time stop: how many closed bars since entry. iBarShift on the open
   // time gives the shift of the bar the position opened in; once that shift
   // reaches max_hold_bars the hold window has elapsed.
   const int open_shift = iBarShift(_Symbol, _Period, open_time, false);
   if(open_shift >= strategy_max_hold_bars)
      return true;

   // (b) Opposite basing-candle breakout: a fresh basing candle at shift 2 and
   // the just-closed bar (shift 1) breaks it AGAINST the open position.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   double basing_high = 0.0;
   double basing_low  = 0.0;
   if(!BasingCandleAt(2, atr_value, basing_high, basing_low))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 <= 0.0)
      return false;

   const double buffer = strategy_breakout_atr_mult * atr_value;
   const bool broke_up   = (close1 > basing_high + buffer);
   const bool broke_down = (close1 < basing_low  - buffer);

   // Close a long on a fresh downside breakout; a short on a fresh upside one.
   if(is_long  && broke_down && !broke_up)
      return true;
   if(!is_long && broke_up   && !broke_down)
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
