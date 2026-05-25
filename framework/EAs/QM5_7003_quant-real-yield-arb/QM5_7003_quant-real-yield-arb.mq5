#property strict
#property version   "5.0"
#property description "QM5_7003 Quantum Real-Yield Divergence"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_7003: The Real-Yield Divergence
// -----------------------------------------------------------------------------
// Logic:
// 1. Asset: Gold (XAUUSD).
// 2. Proxy: US 10Y Real Yield (Symbol: US10Y.DWX or TNOTE.DWX).
// 3. Signal: Fade technical breakouts in Gold if Yields are surging.
// 4. Mean Reversion: Target the 20 SMA.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 7003;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy Parameters"
input string strategy_yield_symbol      = "US10Y.DWX";
input double strategy_yield_threshold   = 0.05; // 5 basis points surge
input int    strategy_ma_period         = 20;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;

bool IsYieldSurging()
  {
   double y_now = iClose(strategy_yield_symbol, PERIOD_D1, 0);
   double y_prev = iClose(strategy_yield_symbol, PERIOD_D1, 1);
   if(y_now == 0) return false;
   return (y_now > y_prev + strategy_yield_threshold);
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
   if(StringFind(_Symbol, "XAU") < 0) return false;

   const double close = iClose(_Symbol, _Period, 1);
   const double sma   = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 1);

   // Condition: Bullish extension in Gold while Yields are surging (Divergence)
   if(close > sma * 1.02 && IsYieldSurging())
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = close + (QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1) * strategy_atr_sl_mult);
      req.tp = sma;
      req.reason = "REAL_YIELD_FADE";
      return (req.sl > 0.0 && req.tp > 0.0);
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

      const double sma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, 0);
      if(iClose(_Symbol, _Period, 0) <= sma) return true;
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
