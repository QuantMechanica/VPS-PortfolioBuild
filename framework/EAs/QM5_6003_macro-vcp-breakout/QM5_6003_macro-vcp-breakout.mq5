#property strict
#property version   "5.0"
#property description "QM5_6003 Macro VCP Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_6003: The VCP Breakout (Mark Minervini)
// -----------------------------------------------------------------------------
// Logic:
// 1. Contraction: ATR(14) < SMA(ATR, 20). Volatility is tightening.
// 2. Breakout: Price crosses the High of the last 10 bars.
// 3. Target: High RR (1:3).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 6003;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_vcp_period        = 10;
input int    strategy_atr_period        = 14;
input int    strategy_atr_ma_period     = 20;
input double strategy_rr                = 3.0;
input int    strategy_spread_cap_points  = 25;

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

bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread > strategy_spread_cap_points) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOpenPosition()) return false;

   // Volatility Contraction Check
   const double atr_now = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   double atr_sum = 0;
   for(int i = 1; i <= strategy_atr_ma_period; ++i)
      atr_sum += QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, i);
   const double atr_ma = atr_sum / strategy_atr_ma_period;

   if(atr_now >= atr_ma) return false;

   const double channel_high = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_vcp_period, 1));
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(bid > channel_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_vcp_period, 1));
      if(req.sl >= bid) req.sl = bid - (atr_now * 1.5);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "VCP_BREAKOUT_LONG";
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
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

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
