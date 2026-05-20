#property strict
#property version   "5.0"
#property description "QM5_2006 NNFX Ichimoku Core"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2006: The Ichimoku Core (Simplified)
// -----------------------------------------------------------------------------
// Baseline: Kumo Cloud (Span A/B)
// Confirmation: Tenkan-sen / Kijun-sen Cross
// Volume: ADX (Trend Strength > 25)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2006;
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
input int    strategy_tenkan           = 9;
input int    strategy_kijun            = 26;
input int    strategy_senkou           = 52;
input int    strategy_adx_period       = 14;
input double strategy_adx_min          = 25.0;
input int    strategy_atr_period       = 14;
input double strategy_atr_sl_mult      = 1.5;
input double strategy_rr                = 1.5;
input int    strategy_spread_cap_points = 25;

// --- Ichimoku Logic ---
double MidpointRange(const int period, const int shift)
  {
   const int safe_period = MathMax(period, 1);
   const int high_idx = iHighest(_Symbol, _Period, MODE_HIGH, safe_period, shift);
   const int low_idx = iLowest(_Symbol, _Period, MODE_LOW, safe_period, shift);
   if(high_idx < 0 || low_idx < 0) return 0.0;
   return (iHigh(_Symbol, _Period, high_idx) + iLow(_Symbol, _Period, low_idx)) / 2.0;
  }

int IchimokuSignal(const int shift)
  {
   const double tenkan = MidpointRange(strategy_tenkan, shift);
   const double kijun = MidpointRange(strategy_kijun, shift);
   const double span_a = (tenkan + kijun) / 2.0;
   const double span_b = MidpointRange(strategy_senkou, shift);
   const double close = iClose(_Symbol, _Period, shift);
   const double cloud_top = MathMax(span_a, span_b);
   const double cloud_bottom = MathMin(span_a, span_b);

   if(close > cloud_top && tenkan > kijun) return 1;
   if(close < cloud_bottom && tenkan < kijun) return -1;
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

   const int ichi_1 = IchimokuSignal(1);
   const double adx_1 = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);

   if(adx_1 < strategy_adx_min) return false;

   if(ichi_1 > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_ICHI_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(ichi_1 < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_ICHI_SHORT";
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
      
      const double tenkan = MidpointRange(strategy_tenkan, 1);
      const double kijun = MidpointRange(strategy_kijun, 1);
      const double span_a = (tenkan + kijun) / 2.0;
      const double span_b = MidpointRange(strategy_senkou, 1);
      const double close = iClose(_Symbol, _Period, 1);
      const double cloud_top = MathMax(span_a, span_b);
      const double cloud_bottom = MathMin(span_a, span_b);

      if(ptype == POSITION_TYPE_BUY && close < cloud_top) return true;
      if(ptype == POSITION_TYPE_SELL && close > cloud_bottom) return true;
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
