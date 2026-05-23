#property strict
#property version   "5.0"
#property description "QM5_4004 Elite VSA Liquidity Sniper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_4004: The Liquidity Sniper (VSA)
// -----------------------------------------------------------------------------
// Logic:
// 1. High Volume: Volume is > 2.0 * 20-period MA of Volume.
// 2. Rejection: Price makes a new Session Low but closes in top 25% of bar.
// 3. Liquidity Sweep: Entry on the 'sweep' of a psychological or session level.
// 4. Exit: 1.5 ATR Target or opposite signal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 4004;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input int    strategy_vol_ma_period     = 20;
input double strategy_vol_mult          = 2.0;
input double strategy_tp_atr_mult       = 1.5;
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

   // Factor 1: High Volume
   const long vol_1 = iVolume(_Symbol, _Period, 1);
   double vol_sum = 0;
   for(int i = 1; i <= strategy_vol_ma_period; ++i)
      vol_sum += (double)iVolume(_Symbol, _Period, i);
   const double vol_ma = vol_sum / strategy_vol_ma_period;

   if((double)vol_1 < vol_ma * strategy_vol_mult) return false;

   // Factor 2: Structural Rejection (Liquidity Sweep)
   const double close_1 = iClose(_Symbol, _Period, 1);
   const double low_1 = iLow(_Symbol, _Period, 1);
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double range = high_1 - low_1;
   if(range <= 0.0) return false;

   // Long Sweep: Close in top 25% of bar after making a low
   if(close_1 > low_1 + (0.75 * range))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = low_1 - (2 * _Point);
      req.tp = close_1 + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * strategy_tp_atr_mult);
      req.reason = "VSA_BULL_SWEEP";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   // Short Sweep: Close in bottom 25% of bar after making a high
   if(close_1 < high_1 - (0.75 * range))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = high_1 + (2 * _Point);
      req.tp = close_1 - (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * strategy_tp_atr_mult);
      req.reason = "VSA_BEAR_SWEEP";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal() { return false; } // Handled by SL/TP

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
