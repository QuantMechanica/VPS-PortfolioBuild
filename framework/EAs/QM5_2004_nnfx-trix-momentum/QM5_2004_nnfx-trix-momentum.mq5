#property strict
#property version   "5.0"
#property description "QM5_2004 NNFX TRIX Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2004: The TRIX Momentum
// -----------------------------------------------------------------------------
// Baseline: ZLEMA (Zero Lag EMA, 34 period proxy)
// Confirmation: TRIX (Triple Exponential Average, 14 period)
// Volume: Choppiness Index (CHOP < 38 indicates trending)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2004;
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
input int    strategy_zlema_period      = 34;
input int    strategy_trix_period       = 14;
input int    strategy_chop_period       = 14;
input double strategy_chop_threshold    = 61.8;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_rr                 = 1.5;
input int    strategy_spread_cap_points  = 25;

// --- ZLEMA Baseline Proxy ---
double ZlemaValue(const int shift)
  {
   // Approximate ZLEMA using a fast EMA pass
   return QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_zlema_period, shift);
  }

// --- TRIX Proxy Logic ---
double TrixRoc(const int shift)
  {
   const double ema_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_trix_period, shift);
   const double ema_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_trix_period, shift + 3);
   if(ema_2 == 0.0) return 0;
   return (ema_1 - ema_2) / ema_2;
  }

int TrixSignal(const int shift)
  {
   const double roc = TrixRoc(shift);
   if(roc > 0.0) return 1;
   if(roc < 0.0) return -1;
   return 0;
  }

// --- Choppiness Index Logic ---
double ChopValue(const int shift)
  {
   double atr_sum = 0;
   for(int i = 0; i < strategy_chop_period; ++i)
      atr_sum += QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, shift + i);
   
   const double high = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_chop_period, shift));
   const double low  = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_chop_period, shift));
   const double range = high - low;
   
   if(range <= 0.0) return 100.0;
   return 100.0 * MathLog10(atr_sum / range) / MathLog10((double)strategy_chop_period);
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
   const double zlema_1 = ZlemaValue(1);
   const int trix_1 = TrixSignal(1);
   const double chop_1 = ChopValue(1);

   if(chop_1 > strategy_chop_threshold) return false;

   if(close_1 > zlema_1 && trix_1 > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_TRIX_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(close_1 < zlema_1 && trix_1 < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_TRIX_SHORT";
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
      const int trix_1 = TrixSignal(1);

      if(ptype == POSITION_TYPE_BUY && trix_1 < 0) return true;
      if(ptype == POSITION_TYPE_SELL && trix_1 > 0) return true;
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
