#property strict
#property version   "5.0"
#property description "QM5_1149 Unger DAX ADX-Low Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1149;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_adx_period         = 5;
input double strategy_adx_threshold      = 20.0;
input int    strategy_atr_period_m5      = 14;
input double strategy_buffer_atr_mult    = 0.05;
input double strategy_sl_atr_mult        = 2.0;
input int    strategy_session_open_hhmm  = 900;
input int    strategy_session_close_hhmm = 1725;
input int    strategy_entry_window_min   = 10;
input int    strategy_max_spread_points  = 200;
input int    strategy_daily_atr_period   = 14;
input int    strategy_atr_percentile_bars = 252;
input double strategy_min_atr_percentile = 20.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }

   if(has_position)
      return false;

   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return true;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   const int hhmm = now.hour * 100 + now.min;
   if(hhmm < strategy_session_open_hhmm || hhmm >= strategy_session_close_hhmm)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   static int placed_day_key = 0;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   const int day_key = now.year * 10000 + now.mon * 100 + now.day;
   const int now_min = now.hour * 60 + now.min;
   const int open_min = (strategy_session_open_hhmm / 100) * 60 + (strategy_session_open_hhmm % 100);
   const int close_min = (strategy_session_close_hhmm / 100) * 60 + (strategy_session_close_hhmm % 100);
   if(day_key == placed_day_key)
      return false;
   if(now_min < open_min || now_min > open_min + strategy_entry_window_min)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   datetime day_start = TimeCurrent() - (now.hour * 3600 + now.min * 60 + now.sec);
   if(HistorySelect(day_start, TimeCurrent()))
     {
      for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
        {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
            continue;
         if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
            return false;
        }
     }

   const double adx = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   if(adx <= 0.0 || adx >= strategy_adx_threshold)
      return false;

   const double current_daily_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_daily_atr_period, 1);
   if(current_daily_atr <= 0.0)
      return false;

   if(strategy_atr_percentile_bars > 0 && strategy_min_atr_percentile > 0.0)
     {
      double atr_values[];
      ArrayResize(atr_values, strategy_atr_percentile_bars);
      int samples = 0;
      for(int shift = 1; shift <= strategy_atr_percentile_bars; ++shift)
        {
         const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_daily_atr_period, shift);
         if(atr <= 0.0)
            continue;
         atr_values[samples] = atr;
         samples++;
        }
      if(samples < 20)
         return false;
      ArrayResize(atr_values, samples);
      ArraySort(atr_values);
      int idx = (int)MathFloor((strategy_min_atr_percentile / 100.0) * (samples - 1));
      idx = MathMax(0, MathMin(samples - 1, idx));
      if(current_daily_atr < atr_values[idx])
         return false;
     }

   const double pdh = iHigh(_Symbol, PERIOD_D1, 1);
   const double pdl = iLow(_Symbol, PERIOD_D1, 1);
   const double atr_m5 = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period_m5, 1);
   if(pdh <= 0.0 || pdl <= 0.0 || pdh <= pdl || atr_m5 <= 0.0)
      return false;

   const double entry = NormalizeDouble(pdh + atr_m5 * strategy_buffer_atr_mult, _Digits);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0 || ask <= 0.0 || ask >= entry)
      return false;

   req.type = QM_BUY_STOP;
   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_m5, strategy_sl_atr_mult);
   req.tp = 0.0;
   req.reason = "ADX_LOW_PDH_BUY_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(300, (close_min - now_min) * 60);
   if(req.sl <= 0.0 || req.expiration_seconds <= 0)
      return false;

   placed_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or take-profit logic.
  }

bool Strategy_ExitSignal()
  {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   const int hhmm = now.hour * 100 + now.min;
   return (hhmm >= strategy_session_close_hhmm);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1149\",\"ea\":\"unger-dax-adx-low-breakout\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
