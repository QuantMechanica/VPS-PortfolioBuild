#property strict
#property version   "5.0"
#property description "QM5_2002 NNFX QQE Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2002: The QQE Trend
// -----------------------------------------------------------------------------
// Baseline: HMA (20 period)
// Confirmation: QQE (RSI 14 vs EMA 5 of RSI)
// Volume: Chaikin Money Flow (CMF > 0)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2002;
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
input int    strategy_hma_period        = 20;
input int    strategy_rsi_period        = 14;
input int    strategy_qqe_ema           = 5;
input int    strategy_cmf_period        = 20;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_rr                 = 1.5;
input int    strategy_spread_cap_points  = 25;

// --- HMA Baseline ---
double HmaBaseline(const int shift) { return QM_HMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_hma_period, shift); }

// --- QQE Confirmation ---
int QqeSignal(const int shift)
  {
   const double rsi_1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift);
   double alpha = 2.0 / ((double)MathMax(strategy_qqe_ema, 1) + 1.0);
   double rsi_ema_1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift + strategy_qqe_ema);
   for(int i = strategy_qqe_ema - 1; i >= 0; --i)
     {
      const double rsi_i = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift + i);
      rsi_ema_1 = (alpha * rsi_i) + ((1.0 - alpha) * rsi_ema_1);
     }
   
   if(rsi_1 > 50 && rsi_1 > rsi_ema_1) return 1;
   if(rsi_1 < 50 && rsi_1 < rsi_ema_1) return -1;
   return 0;
  }

// --- CMF Volume Filter ---
double CmfValue(const int shift)
  {
   double mfv_sum = 0.0;
   double volume_sum = 0.0;
   for(int i = 0; i < strategy_cmf_period; ++i)
     {
      const int bar = shift + i;
      const double high = iHigh(_Symbol, _Period, bar);
      const double low = iLow(_Symbol, _Period, bar);
      const double close = iClose(_Symbol, _Period, bar);
      const double volume = (double)iVolume(_Symbol, _Period, bar);
      if(high <= low || volume <= 0.0) continue;
      const double mfm = ((close - low) - (high - close)) / (high - low);
      mfv_sum += mfm * volume;
      volume_sum += volume;
     }
   if(volume_sum <= 0.0) return 0.0;
   return mfv_sum / volume_sum;
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
   const double hma_1 = HmaBaseline(1);
   const int qqe_1 = QqeSignal(1);
   const double cmf_1 = CmfValue(1);

   if(close_1 > hma_1 && qqe_1 > 0 && cmf_1 > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_QQE_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(close_1 < hma_1 && qqe_1 < 0 && cmf_1 < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_QQE_SHORT";
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
      const int qqe_1 = QqeSignal(1);

      if(ptype == POSITION_TYPE_BUY && qqe_1 < 0) return true;
      if(ptype == POSITION_TYPE_SELL && qqe_1 > 0) return true;
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
