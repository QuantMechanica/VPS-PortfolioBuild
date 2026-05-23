#property strict
#property version   "5.0"
#property description "QM5_7001 Quantum Gold Sovereign Sweep"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_7001: The Gold Sovereign Sweep
// -----------------------------------------------------------------------------
// Logic:
// 1. Levels: Price around $XX50.00 or $XX00.00 psychological levels.
// 2. Window: London-NY crossover (13:00 - 17:00 UTC).
// 3. Rejection: H1 Wick > 2.0 * Body (Liquidity grab).
// 4. Volume: Volume > 2.0 * SMA(Volume, 20).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 7001;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_level_step        = 50;  // Every $50
input int    strategy_window_start_utc  = 13;
input int    strategy_window_end_utc    = 17;
input double strategy_wick_mult         = 2.0;
input double strategy_vol_mult          = 2.0;
input int    strategy_atr_period        = 14;
input double strategy_rr                = 2.0;

bool IsInWindow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_window_start_utc && dt.hour <= strategy_window_end_utc);
  }

bool IsAtPsychLevel(double price)
  {
   double rem = MathMod(price, (double)strategy_level_step);
   return (rem < 2.0 || rem > (strategy_level_step - 2.0)); // Within $2 of the level
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOpenPosition()) return false;
   if(!IsInWindow()) return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double open_1  = iOpen(_Symbol, _Period, 1);
   const double high_1  = iHigh(_Symbol, _Period, 1);
   const double low_1   = iLow(_Symbol, _Period, 1);
   const double body    = MathAbs(close_1 - open_1);

   // Volume Filter
   const long vol_1 = iVolume(_Symbol, _Period, 1);
   double vol_sum = 0;
   for(int i = 1; i <= 20; ++i) vol_sum += (double)iVolume(_Symbol, _Period, i);
   if((double)vol_1 < (vol_sum / 20.0) * strategy_vol_mult) return false;

   // Long Sweep (Bullish Rejection at level)
   if(IsAtPsychLevel(low_1))
     {
      double bottom_wick = MathMin(open_1, close_1) - low_1;
      if(bottom_wick > body * strategy_wick_mult)
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = low_1 - (50 * _Point);
         req.tp = QM_TakeRR(_Symbol, req.type, SymbolInfoDouble(_Symbol, SYMBOL_ASK), req.sl, strategy_rr);
         req.reason = "GOLD_SOV_SWEEP_LONG";
         return (req.sl > 0.0 && req.tp > 0.0);
        }
     }

   // Short Sweep (Bearish Rejection at level)
   if(IsAtPsychLevel(high_1))
     {
      double top_wick = high_1 - MathMax(open_1, close_1);
      if(top_wick > body * strategy_wick_mult)
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = high_1 + (50 * _Point);
         req.tp = QM_TakeRR(_Symbol, req.type, SymbolInfoDouble(_Symbol, SYMBOL_BID), req.sl, strategy_rr);
         req.reason = "GOLD_SOV_SWEEP_SHORT";
         return (req.sl > 0.0 && req.tp > 0.0);
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal() { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, QM_NEWS_OFF))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar()) return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
