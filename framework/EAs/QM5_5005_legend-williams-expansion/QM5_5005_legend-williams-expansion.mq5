#property strict
#property version   "5.0"
#property description "QM5_5005 Legend Williams Expansion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_5005: The Williams Expansion (Larry Williams)
// -----------------------------------------------------------------------------
// Logic:
// 1. Panic/Euphoria: 3 consecutive lower closes (Long) or higher closes (Short).
// 2. Reversal: Bullish/Bearish Engulfing pattern.
// 3. Trend Cross: Close crosses 10-period SMA.
// 4. Exit: Parabolic SAR flip.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 5005;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_sma_period        = 10;
input double strategy_psar_step         = 0.02;
input double strategy_psar_max          = 0.2;
input int    strategy_atr_period        = 14;
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

   const double c1 = iClose(_Symbol, _Period, 1);
   const double c2 = iClose(_Symbol, _Period, 2);
   const double c3 = iClose(_Symbol, _Period, 3);
   const double c4 = iClose(_Symbol, _Period, 4);

   const double o1 = iOpen(_Symbol, _Period, 1);
   const double o2 = iOpen(_Symbol, _Period, 2);

   const double sma_1 = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_sma_period, 1);

   // Long: 3 Lower Closes + Bullish Engulfing (C1 > O1 and O1 < C2) + Close > SMA
   if(c2 < c3 && c3 < c4 && c1 > o1 && o1 <= c2 && c1 > sma_1)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = iLow(_Symbol, _Period, 1) - (5 * _Point);
      if(req.sl >= SymbolInfoDouble(_Symbol, SYMBOL_BID)) req.sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * 2.0);
      req.tp = 0.0; // PSAR Exit
      req.reason = "WILLIAMS_PANIC_BUY";
      return (req.sl > 0.0);
     }

   // Short: 3 Higher Closes + Bearish Engulfing + Close < SMA
   if(c2 > c3 && c3 > c4 && c1 < o1 && o1 >= c2 && c1 < sma_1)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = iHigh(_Symbol, _Period, 1) + (5 * _Point);
      if(req.sl <= SymbolInfoDouble(_Symbol, SYMBOL_ASK)) req.sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * 2.0);
      req.tp = 0.0;
      req.reason = "WILLIAMS_EU_SELL";
      return (req.sl > 0.0);
     }

   return false;
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      int handle = iSAR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_psar_step, strategy_psar_max);
      double psar[1];
      if(CopyBuffer(handle, 0, 1, 1, psar) != 1) return false;

      if(ptype == POSITION_TYPE_BUY && iClose(_Symbol, _Period, 1) < psar[0]) return true;
      if(ptype == POSITION_TYPE_SELL && iClose(_Symbol, _Period, 1) > psar[0]) return true;
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
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

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
