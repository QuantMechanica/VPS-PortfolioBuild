#property strict
#property version   "5.0"
#property description "QM5_2007 NNFX RSI-MACD Synergy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2007: The RSI-MACD Synergy
// -----------------------------------------------------------------------------
// Baseline: EMA (50 period)
// Confirmation: MACD (12, 26, 9) Zero Line Cross
// Volume: Relative Volatility Index (RVI > 50)
// Exit: Parabolic SAR Flip
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2007;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_ema_period        = 50;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_rvi_period        = 10;
input double strategy_psar_step         = 0.02;
input double strategy_psar_max          = 0.2;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_rr                 = 1.5;
input int    strategy_spread_cap_points  = 25;

// --- RVI Volume Filter Logic ---
double RviValue(const int shift)
  {
   int handle = iRVI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rvi_period);
   if(handle == INVALID_HANDLE) return 0.0;
   double main[1];
   double result = 0.0;
   if(CopyBuffer(handle, 0, shift, 1, main) == 1) result = main[0];
   IndicatorRelease(handle);
   return result;
  }

// --- PSAR Logic ---
double PsarValue(const int shift)
  {
   int handle = iSAR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_psar_step, strategy_psar_max);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[1];
   double result = 0.0;
   if(CopyBuffer(handle, 0, shift, 1, buf) == 1) result = buf[0];
   IndicatorRelease(handle);
   return result;
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

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double ema_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double macd_main_1 = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double rvi_1 = RviValue(1);

   if(close_1 > ema_1 && macd_main_1 > 0 && rvi_1 > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_SYNERGY_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(close_1 < ema_1 && macd_main_1 < 0 && rvi_1 < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_SYNERGY_SHORT";
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double close_1 = iClose(_Symbol, _Period, 1);
      const double psar_1 = PsarValue(1);

      if(ptype == POSITION_TYPE_BUY && close_1 < psar_1) return true;
      if(ptype == POSITION_TYPE_SELL && close_1 > psar_1) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode, qm_friday_close_enabled, qm_friday_close_hour_broker))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   if(!QM_IsNewBar()) return;

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

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
