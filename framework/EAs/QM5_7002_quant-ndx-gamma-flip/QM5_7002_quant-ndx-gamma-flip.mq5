#property strict
#property version   "5.0"
#property description "QM5_7002 Quantum NDX Gamma Sniper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_7002: The NDX Gamma Sniper
// -----------------------------------------------------------------------------
// Logic:
// 1. Levels: Concentration of 0DTE options at 100-point levels (e.g., 18500).
// 2. Volatility: ATR(5) spike (> 1.5 * MA).
// 3. Execution: Breakout of the round-number cluster with momentum confirmation.
// 4. Target: Aggressive intraday scalping.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 7002;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_level_step        = 100;
input double strategy_vol_mult          = 1.5;
input int    strategy_ma_filter         = 20;
input double strategy_rr                = 2.5;

bool IsAtPsychLevel(double price)
  {
   double rem = MathMod(price, (double)strategy_level_step);
   return (rem < 5.0 || rem > (strategy_level_step - 5.0)); // Within 5 points of 100-pt level
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

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 5, 1);

   // ATR Spike check
   double atr_sum = 0;
   for(int i = 1; i <= 20; ++i) atr_sum += QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 5, i);
   if(atr < (atr_sum / 20.0) * strategy_vol_mult) return false;

   const double sma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_filter, 1);

   // Long Breakout at Gamma Level
   if(bid > sma && IsAtPsychLevel(bid))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = bid - (atr * 2.0);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "NDX_GAMMA_BREAK_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   // Short Breakout at Gamma Level
   if(ask < sma && IsAtPsychLevel(ask))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = ask + (atr * 2.0);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "NDX_GAMMA_BREAK_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
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
