#property strict
#property version   "5.0"
#property description "QM5_2005 NNFX Donchian Flow"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2005: The Donchian Flow
// -----------------------------------------------------------------------------
// Baseline: Donchian Channel Midline (20 period)
// Confirmation: Aroon Oscillator (14 period)
// Volume: Money Flow Index (MFI > 50)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2005;
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
input int    strategy_donchian_period   = 20;
input int    strategy_aroon_period      = 14;
input int    strategy_mfi_period        = 14;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_rr                 = 1.5;
input int    strategy_spread_cap_points  = 25;

// --- Donchian Midline Logic ---
double DonchianMidline(const int shift)
  {
   const double upper = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_donchian_period, shift));
   const double lower = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_donchian_period, shift));
   return (upper + lower) / 2.0;
  }

// --- Aroon Oscillator Logic ---
int AroonSignal(const int shift)
  {
   const int high_idx = iHighest(_Symbol, _Period, MODE_HIGH, strategy_aroon_period, shift);
   const int low_idx = iLowest(_Symbol, _Period, MODE_LOW, strategy_aroon_period, shift);
   if(high_idx < 0 || low_idx < 0) return 0;
   const double bars_since_high = (double)(high_idx - shift);
   const double bars_since_low = (double)(low_idx - shift);
   const double period = (double)MathMax(strategy_aroon_period, 1);
   const double aroon_up = 100.0 * (period - bars_since_high) / period;
   const double aroon_down = 100.0 * (period - bars_since_low) / period;
   const double osc = aroon_up - aroon_down;
   if(osc > 0.0) return 1;
   if(osc < 0.0) return -1;
   return 0;
  }

// --- MFI Volume Filter ---
double MfiValue(const int shift)
  {
   double positive_flow = 0.0;
   double negative_flow = 0.0;
   for(int i = 0; i < strategy_mfi_period; ++i)
     {
      const int bar = shift + i;
      const double typical = (iHigh(_Symbol, _Period, bar) + iLow(_Symbol, _Period, bar) + iClose(_Symbol, _Period, bar)) / 3.0;
      const double prev_typical = (iHigh(_Symbol, _Period, bar + 1) + iLow(_Symbol, _Period, bar + 1) + iClose(_Symbol, _Period, bar + 1)) / 3.0;
      const double flow = typical * (double)iVolume(_Symbol, _Period, bar);
      if(typical > prev_typical) positive_flow += flow;
      if(typical < prev_typical) negative_flow += flow;
     }
   if(negative_flow <= 0.0 && positive_flow <= 0.0) return 50.0;
   if(negative_flow <= 0.0) return 100.0;
   const double ratio = positive_flow / negative_flow;
   return 100.0 - (100.0 / (1.0 + ratio));
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
   const double mid_1 = DonchianMidline(1);
   const int aroon_1 = AroonSignal(1);
   const double mfi_1 = MfiValue(1);

   if(close_1 > mid_1 && aroon_1 > 0 && mfi_1 > 50)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_DONCHIAN_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(close_1 < mid_1 && aroon_1 < 0 && mfi_1 < 50)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_DONCHIAN_SHORT";
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
      const int aroon_1 = AroonSignal(1);

      if(ptype == POSITION_TYPE_BUY && aroon_1 < 0) return true;
      if(ptype == POSITION_TYPE_SELL && aroon_1 > 0) return true;
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
