#property strict
#property version   "5.0"
#property description "QM5_1289 donchian-vegas-hybrid — Vegas EMA144/169 tunnel BIAS state + Donchian(20) first-break EVENT (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1289 donchian-vegas-hybrid
// -----------------------------------------------------------------------------
// Source: ForexFactory Donchian-Vegas hybrid community cluster (named-handle
//         threads 2014-2021) + Donchian channel (1960s) + Vegas EMA144/169
//         tunnel + Joe Krutsinger "The Trading Systems Toolkit" (1994, Wiley).
//         source_id 6e967762-b26d-59a3-b076-35c17f2e7c36.
// Card: artifacts/cards_approved/QM5_1289_donchian-vegas-hybrid.md (g0 APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1+):
//   BIAS STATE   : the Vegas EMA(144)/EMA(169) tunnel.
//                  tunnel_high = max(EMA144[1], EMA169[1])
//                  tunnel_low  = min(EMA144[1], EMA169[1])
//                  Tunnel must have minimum thickness:
//                     tunnel_high - tunnel_low >= thickness_atr_mult * ATR[1]
//                  (filters degenerate-thin tunnels during EMA crossovers).
//                  LONG-only regime  : Close[1] > tunnel_high AND thick enough.
//                  SHORT-only regime : Close[1] < tunnel_low  AND thick enough.
//                  Inside tunnel OR too thin = no-trade.
//   TRIGGER EVENT: a SINGLE Donchian(20) first-break in the allowed direction.
//                  Donchian channel is computed in-EA via bounded iHigh/iLow
//                  loops EXCLUDING the current forming bar:
//                     upperDC[2] = max(High[2 .. donchian_period+1])
//                     upperDC[3] = max(High[3 .. donchian_period+2])
//                     lowerDC[2] = min(Low [2 .. donchian_period+1])
//                     lowerDC[3] = min(Low [3 .. donchian_period+2])
//                  LONG  event: Close[1] > upperDC[2]  AND  Close[2] <= upperDC[3]
//                  SHORT event: Close[1] < lowerDC[2]  AND  Close[2] >= lowerDC[3]
//                  The first-break second clause makes it ONE fresh break event
//                  per regime, never a re-entry — and the tunnel is a STATE, not
//                  a second crossing event (avoids the .DWX two-cross-same-bar
//                  zero-trade trap, invariant #4).
//   STOP LOSS    : opposite Donchian boundary at entry (LONG: lowerDC[2];
//                  SHORT: upperDC[2]), floored so the stop distance is at least
//                  sl_floor_atr_mult * ATR[1] (card: ATR*1.5 minimum).
//   TAKE PROFIT  : fixed RR multiple of the realised stop distance (card RR 2.0,
//                  P3 sweep {1.5, 2.0, 2.5, 3.0}).
//   EXITS (Strategy_ExitSignal, closed-bar):
//                  1) Tunnel re-entry: LONG Close[1] <= tunnel_high (back into
//                     the tunnel from above); SHORT Close[1] >= tunnel_low.
//                  2) Opposite Donchian break (trend reversal): LONG closes if
//                     Close[1] < lowerDC[2]; SHORT closes if Close[1] > upperDC[2].
//                  3) Time-stop: position open >= time_stop_bars H1 bars.
//   SPREAD GUARD : fail-OPEN on .DWX zero modeled spread (invariant #1); block
//                  only a genuinely WIDE spread > spread_cap_pips.
//
// One position per symbol per magic. Only the 5 Strategy_* hooks + Strategy
// inputs are EA-specific; everything else is framework wiring.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1289;
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
input int    strategy_ema_fast_period      = 144;   // Vegas tunnel fast EMA
input int    strategy_ema_slow_period      = 169;   // Vegas tunnel slow EMA
input int    strategy_donchian_period      = 20;    // Donchian channel lookback (bars)
input int    strategy_atr_period           = 14;    // ATR period (thickness floor / SL floor)
input double strategy_thickness_atr_mult   = 0.3;   // min tunnel thickness = mult * ATR
input double strategy_sl_floor_atr_mult    = 1.5;   // min SL distance = mult * ATR
input double strategy_rr                   = 2.0;   // take-profit RR multiple (P3 sweep)
input int    strategy_time_stop_bars       = 96;    // close after N H1 bars (4 trading days)
input double strategy_spread_cap_pips      = 25.0;  // skip only a genuinely WIDE spread

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Pip size for the current symbol (10 * point on 3/5-digit quotes, else point).
double DV_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

// Donchian upper boundary = highest High over `period` bars starting at
// `start_shift` (i.e. shifts start_shift .. start_shift+period-1), so the
// CURRENT forming bar (shift 0) is excluded. Bounded closed-bar scan.
double DV_UpperDonchian(const int start_shift, const int period)
  {
   double hi = 0.0;
   for(int s = start_shift; s < start_shift + period; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar Donchian scan
      if(h <= 0.0)
         continue;
      if(hi == 0.0 || h > hi)
         hi = h;
     }
   return hi;
  }

// Donchian lower boundary = lowest Low over `period` bars starting at
// `start_shift`. Bounded closed-bar scan.
double DV_LowerDonchian(const int start_shift, const int period)
  {
   double lo = 0.0;
   for(int s = start_shift; s < start_shift + period; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed: bounded closed-bar Donchian scan
      if(l <= 0.0)
         continue;
      if(lo == 0.0 || l < lo)
         lo = l;
     }
   return lo;
  }

// Cheap O(1) wide-spread guard, fail-OPEN on .DWX zero modeled spread.
bool DV_WideSpread()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                 // no valid quote — never block on it
   const double pip = DV_PipSize();
   if(pip <= 0.0)
      return false;
   const double spread = ask - bid;
   // Only a genuinely wide positive spread blocks; zero/negative passes.
   return (spread > 0.0 && spread > strategy_spread_cap_pips * pip);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: wide-spread guard only. Bias/trigger work is on the
// closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   if(DV_WideSpread())
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// The Vegas tunnel is the BIAS STATE; the Donchian first-break is the single
// EVENT in the allowed direction.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   // One position per symbol per magic.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // --- Vegas tunnel BIAS state (closed bar) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1); // EMA144
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1); // EMA169
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double tunnel_high = MathMax(ema_fast, ema_slow);
   const double tunnel_low  = MathMin(ema_fast, ema_slow);

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Tunnel must have minimum thickness — filters degenerate crossovers.
   if((tunnel_high - tunnel_low) < strategy_thickness_atr_mult * atr_value)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Donchian boundaries excluding the current forming bar (start at shift 2/3).
   const double upperDC2 = DV_UpperDonchian(2, strategy_donchian_period);
   const double upperDC3 = DV_UpperDonchian(3, strategy_donchian_period);
   const double lowerDC2 = DV_LowerDonchian(2, strategy_donchian_period);
   const double lowerDC3 = DV_LowerDonchian(3, strategy_donchian_period);
   if(upperDC2 <= 0.0 || upperDC3 <= 0.0 || lowerDC2 <= 0.0 || lowerDC3 <= 0.0)
      return false;

   const double sl_floor = strategy_sl_floor_atr_mult * atr_value;

   // --- LONG: long-only regime + Donchian first-break up (single event) ---
   if(close1 > tunnel_high &&
      close1 > upperDC2 && close2 <= upperDC3)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Stop = opposite Donchian boundary, floored to the ATR-minimum distance.
      double sl = lowerDC2;
      if(entry - sl < sl_floor)
         sl = entry - sl_floor;
      if(!(sl < entry))
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "donchian_vegas_long";
      return true;
     }

   // --- SHORT: short-only regime + Donchian first-break down (single event) ---
   if(close1 < tunnel_low &&
      close1 < lowerDC2 && close2 >= lowerDC3)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = upperDC2;
      if(sl - entry < sl_floor)
         sl = entry + sl_floor;
      if(!(sl > entry))
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "donchian_vegas_short";
      return true;
     }

   return false;
  }

// No active SL/TP modification — exits are the fixed Donchian SL, the RR TP, and
// the discretionary closes in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary closed-bar exits: tunnel re-entry, opposite Donchian break, and
// the H1 time-stop. Returns TRUE to close the EA's open position now.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Identify this EA's open position direction + open time.
   long   pos_type = -1;
   datetime pos_open = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = PositionGetInteger(POSITION_TYPE);
      pos_open = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(pos_type < 0)
      return false;

   // Time-stop: position has been open for >= N H1 bars.
   const int    period_secs = PeriodSeconds(_Period);
   if(period_secs > 0 && pos_open > 0)
     {
      const int bars_held = (int)((TimeCurrent() - pos_open) / period_secs);
      if(bars_held >= strategy_time_stop_bars)
         return true;
     }

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   const double tunnel_high = MathMax(ema_fast, ema_slow);
   const double tunnel_low  = MathMin(ema_fast, ema_slow);

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
     {
      // Tunnel re-entry from above.
      if(close1 <= tunnel_high)
         return true;
      // Opposite Donchian break (trend reversal).
      const double lowerDC2 = DV_LowerDonchian(2, strategy_donchian_period);
      if(lowerDC2 > 0.0 && close1 < lowerDC2)
         return true;
     }
   else if(pos_type == POSITION_TYPE_SELL)
     {
      if(close1 >= tunnel_low)
         return true;
      const double upperDC2 = DV_UpperDonchian(2, strategy_donchian_period);
      if(upperDC2 > 0.0 && close1 > upperDC2)
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
