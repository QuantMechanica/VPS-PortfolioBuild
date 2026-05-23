#property strict
#property version   "5.0"
#property description "QM5_8001 Quantum VIX Macro Rotator"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_8001: The VIX Macro Rotator
// -----------------------------------------------------------------------------
// Logic:
// 1. Regime Detection: Uses VIX (Symbol: VIX.DWX or VOLX.DWX) to detect risk.
// 2. Risk-On (VIX < 20): Trade NDX (Nasdaq) or SP500.
// 3. Risk-Off (VIX > 25 for 48h): Rotate into Gold (XAUUSD).
// 4. Protection: Immediate exit of all tech if VIX spikes > 30.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 8001;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input string strategy_vix_symbol        = "VIX.DWX";
input double strategy_vix_threshold_low  = 20.0;
input double strategy_vix_threshold_high = 25.0;
input int    strategy_atr_period        = 14;
input double strategy_rr                = 2.0;

enum ENUM_REGIME { REGIME_RISK_ON, ENUM_REGIME_RISK_OFF, REGIME_NEUTRAL };

ENUM_REGIME GetMarketRegime()
  {
   double vix = iClose(strategy_vix_symbol, PERIOD_D1, 0);
   if(vix == 0) vix = iClose("VOLX.DWX", PERIOD_D1, 0); // Fallback

   if(vix < strategy_vix_threshold_low) return REGIME_RISK_ON;
   if(vix > strategy_vix_threshold_high) return ENUM_REGIME_RISK_OFF;
   return REGIME_NEUTRAL;
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

   ENUM_REGIME regime = GetMarketRegime();
   string sym = _Symbol;

   // Logic: Trade only the appropriate asset for the regime
   if(regime == REGIME_RISK_ON && (StringFind(sym, "NDX") >= 0 || StringFind(sym, "SP500") >= 0))
     {
      req.type = QM_BUY;
      req.reason = "REGIME_RISK_ON_EQUITY";
     }
   else if(regime == ENUM_REGIME_RISK_OFF && StringFind(sym, "XAU") >= 0)
     {
      req.type = QM_BUY;
      req.reason = "REGIME_RISK_OFF_GOLD";
     }
   else
     {
      return false;
     }

   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, 2.0);
   req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);

   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_REGIME regime = GetMarketRegime();
      string sym = _Symbol;

      // Force exit Tech if VIX surges
      if(regime == ENUM_REGIME_RISK_OFF && (StringFind(sym, "NDX") >= 0 || StringFind(sym, "SP500") >= 0)) return true;

      // Force exit Gold if VIX drops (normalization)
      if(regime == REGIME_RISK_ON && StringFind(sym, "XAU") >= 0) return true;
     }
   return false;
  }

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

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
