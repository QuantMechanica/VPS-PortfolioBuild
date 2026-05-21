#property strict
#property version   "5.0"
#property description "QM5_3003 Alpha Quant's Hook (Statistical Reversion)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_3003: The Quant's Hook
// -----------------------------------------------------------------------------
// Paradigm: Statistical Mean Reversion
// Baseline: Z-Score of Price (20-period). Trigger at > 2.0 or < -2.0.
// Confirmation: MACD Histogram Divergence (Proxy: MACD Hist sign flip or direction change)
// Exit: Z-Score mean reversion (Score returns to 0)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 3003;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Strategy"
input int    strategy_z_period          = 20;
input double strategy_z_threshold       = 2.0;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;
input int    strategy_spread_cap_points  = 25;

// --- Z-Score Logic ---
double GetZScore(const int shift)
  {
   const double close = iClose(_Symbol, _Period, shift);

   // Handle calculation manually to avoid non-existent wrapper
   int hSma = iMA(_Symbol, _Period, strategy_z_period, 0, MODE_SMA, PRICE_CLOSE);
   int hStd = iStdDev(_Symbol, _Period, strategy_z_period, 0, MODE_SMA, PRICE_CLOSE);

   double sma[1], stdev[1];
   if(CopyBuffer(hSma, 0, shift, 1, sma) != 1) return 0.0;
   if(CopyBuffer(hStd, 0, shift, 1, stdev) != 1) return 0.0;

   if(stdev[0] <= 0.0) return 0.0;
   return (close - sma[0]) / stdev[0];
  }

// --- MACD Trend Confirmation ---
int MacdTrend(const int shift)
  {
   const double hist_1 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double hist_2 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);

   if(hist_1 > hist_2) return 1;  // Momentum turning up
   if(hist_1 < hist_2) return -1; // Momentum turning down
   return 0;
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

bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread > strategy_spread_cap_points) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOpenPosition()) return false;

   const double z_1 = GetZScore(1);
   const int m_1 = MacdTrend(1);

   // Long: Price statistical oversold + Momentum recovery
   if(z_1 < -strategy_z_threshold && m_1 > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0; // Target is mean (Z=0)
      req.reason = "ALPHA_QUANT_HOOK_LONG";
      return (req.sl > 0.0);
     }

   // Short: Price statistical overbought + Momentum exhaustion
   if(z_1 > strategy_z_threshold && m_1 < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "ALPHA_QUANT_HOOK_SHORT";
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
      const double z_0 = GetZScore(0);

      // Exit when price returns to the mean
      if(ptype == POSITION_TYPE_BUY && z_0 >= 0.0) return true;
      if(ptype == POSITION_TYPE_SELL && z_0 <= 0.0) return true;
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
