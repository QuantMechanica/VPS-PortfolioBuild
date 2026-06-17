#property strict
#property version   "5.0"
#property description "QM5_10620 — 3 White Soldiers / 3 Black Crows + RSI reversal (MQL5 CodeBase #288)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10620 mql5-crows-rsi
// -----------------------------------------------------------------------------
// Source: MQL5 Wizard "3 Black Crows / 3 White Soldiers + RSI" (CodeBase #288).
// Card: artifacts/cards_approved/QM5_10620_mql5-crows-rsi.md
//
// Mechanics (closed-bar reads only, shift>=1):
//   LONG  : 3 White Soldiers pattern on bars [3,2,1] AND RSI[1] < rsi_long_max
//   SHORT : 3 Black Crows   pattern on bars [3,2,1] AND RSI[1] > rsi_short_min
//   EXIT  : close SHORT if RSI crosses UP through 30 or 70;
//           close LONG  if RSI crosses DOWN through 70 or 30.
//   STOP  : beyond the three-candle pattern extreme, capped at atr_sl_mult*ATR.
//   TP    : tp_rr * R (risk distance).
//   One position per symbol/magic; framework sizes lots from SL distance.
//
// .DWX backtest invariants honoured:
//   - Pattern is the TRIGGER, RSI a confirming STATE (no two simultaneous events).
//   - Gapless CFDs: candle bodies compared against the prior bar's body (CLOSE/
//     OPEN), never against a price GAP. "Soldier/crow" uses body-direction +
//     monotone closes + opens within the prior real body — fires on gapless data.
//   - QM_IsNewBar() consumed ONCE by the framework wiring (entry gate). Exit/RSI
//     reads here use closed-bar shifts via pooled QM_RSI; no second new-bar gate.
//   - Pattern-extreme stop read via iLow/iHigh at fixed closed-bar shifts only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10620;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// RSI confirmation
input int    strategy_rsi_period        = 14;     // RSI period
input double strategy_rsi_long_max      = 40.0;   // long requires RSI[1] below this
input double strategy_rsi_short_min     = 60.0;   // short requires RSI[1] above this
// RSI cross-exit levels (close on cross through either level)
input double strategy_rsi_exit_inner    = 30.0;   // first exit level
input double strategy_rsi_exit_outer    = 70.0;   // second exit level
// Stop / target
input int    strategy_atr_period        = 14;     // ATR period for SL cap
input double strategy_atr_sl_mult       = 2.0;    // SL distance cap = mult * ATR
input double strategy_tp_rr             = 1.5;    // TP as R-multiple of SL distance

// -----------------------------------------------------------------------------
// Candle-pattern detection — gapless-CFD safe.
// Bars are read at fixed closed-bar shifts: 3 = oldest, 1 = most recent closed.
// A "white soldier" sequence: three consecutive bullish bodies (close>open),
// each closing higher than the prior close, each opening inside the prior real
// body (between prior open and prior close). On gapless .DWX data open[k]≈close[k+1]
// so the open-inside-body test reduces to open>prior_open with open<=prior_close,
// which holds for a healthy rising soldier sequence.
// -----------------------------------------------------------------------------

bool Pattern_ThreeWhiteSoldiers(const string sym, const ENUM_TIMEFRAMES tf)
  {
   const double o3 = iOpen(sym, tf, 3), c3 = iClose(sym, tf, 3);
   const double o2 = iOpen(sym, tf, 2), c2 = iClose(sym, tf, 2);
   const double o1 = iOpen(sym, tf, 1), c1 = iClose(sym, tf, 1);
   if(o3 <= 0.0 || o2 <= 0.0 || o1 <= 0.0)
      return false;

   // three bullish bodies
   if(!(c3 > o3 && c2 > o2 && c1 > o1))
      return false;
   // monotone rising closes
   if(!(c2 > c3 && c1 > c2))
      return false;
   // each open advances within / above the prior body (no large overshoot)
   if(!(o2 > o3 && o2 <= c3))
      return false;
   if(!(o1 > o2 && o1 <= c2))
      return false;
   return true;
  }

bool Pattern_ThreeBlackCrows(const string sym, const ENUM_TIMEFRAMES tf)
  {
   const double o3 = iOpen(sym, tf, 3), c3 = iClose(sym, tf, 3);
   const double o2 = iOpen(sym, tf, 2), c2 = iClose(sym, tf, 2);
   const double o1 = iOpen(sym, tf, 1), c1 = iClose(sym, tf, 1);
   if(o3 <= 0.0 || o2 <= 0.0 || o1 <= 0.0)
      return false;

   // three bearish bodies
   if(!(c3 < o3 && c2 < o2 && c1 < o1))
      return false;
   // monotone falling closes
   if(!(c2 < c3 && c1 < c2))
      return false;
   // each open steps down within / below the prior body
   if(!(o2 < o3 && o2 >= c3))
      return false;
   if(!(o1 < o2 && o1 >= c2))
      return false;
   return true;
  }

// Lowest low / highest high across the three pattern bars (shift 1..3).
double Pattern_LowestLow(const string sym, const ENUM_TIMEFRAMES tf)
  {
   double lo = iLow(sym, tf, 1);
   for(int s = 2; s <= 3; ++s)
     {
      const double l = iLow(sym, tf, s);
      if(l > 0.0 && (lo <= 0.0 || l < lo))
         lo = l;
     }
   return lo;
  }

double Pattern_HighestHigh(const string sym, const ENUM_TIMEFRAMES tf)
  {
   double hi = iHigh(sym, tf, 1);
   for(int s = 2; s <= 3; ++s)
     {
      const double h = iHigh(sym, tf, s);
      if(h > hi)
         hi = h;
     }
   return hi;
  }

// True if RSI crossed UP through `level` between the two most recent closed bars.
bool RSI_CrossUp(const double rsi_prev, const double rsi_now, const double level)
  {
   return (rsi_prev < level && rsi_now >= level);
  }

// True if RSI crossed DOWN through `level` between the two most recent closed bars.
bool RSI_CrossDown(const double rsi_prev, const double rsi_now, const double level)
  {
   return (rsi_prev > level && rsi_now <= level);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false; // baseline carries no extra filter; framework news/Friday guard only
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double rsi1 = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   const bool soldiers = Pattern_ThreeWhiteSoldiers(_Symbol, tf);
   const bool crows    = Pattern_ThreeBlackCrows(_Symbol, tf);

   if(soldiers && rsi1 < strategy_rsi_long_max)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double pat_low = Pattern_LowestLow(_Symbol, tf);
      if(pat_low <= 0.0 || pat_low >= entry)
         return false;
      // Structure stop = pattern extreme; cap the DISTANCE at atr_sl_mult*ATR.
      double sl = pat_low;
      const double atr_sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
      if(atr_sl > 0.0 && atr_sl > sl) // ATR-cap closer than the pattern extreme -> tighten
         sl = atr_sl;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0; // market
      req.sl     = sl;
      req.tp     = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      req.reason = "three_white_soldiers_rsi";
      return true;
     }

   if(crows && rsi1 > strategy_rsi_short_min)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double pat_high = Pattern_HighestHigh(_Symbol, tf);
      if(pat_high <= entry)
         return false;
      double sl = pat_high;
      const double atr_sl = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_atr_sl_mult);
      if(atr_sl > 0.0 && atr_sl < sl) // ATR-cap closer than the pattern extreme -> tighten
         sl = atr_sl;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0; // market
      req.sl     = sl;
      req.tp     = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      req.reason = "three_black_crows_rsi";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No active trade management beyond SL/TP; RSI cross handled in Strategy_ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double rsi_now  = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, tf, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   // Determine our open position direction.
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Close SHORT if RSI crosses UP through inner or outer level.
   if(have_short &&
      (RSI_CrossUp(rsi_prev, rsi_now, strategy_rsi_exit_inner) ||
       RSI_CrossUp(rsi_prev, rsi_now, strategy_rsi_exit_outer)))
      return true;

   // Close LONG if RSI crosses DOWN through outer or inner level.
   if(have_long &&
      (RSI_CrossDown(rsi_prev, rsi_now, strategy_rsi_exit_outer) ||
       RSI_CrossDown(rsi_prev, rsi_now, strategy_rsi_exit_inner)))
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
