#property strict
#property version   "5.01"
#property description "QM5_1099 DAX Weekly Donchian-50 Breakout V2"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1099;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_donchian_high_bars = 50;
input int    strategy_donchian_low_bars  = 25;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 3.0;
input bool   strategy_long_only          = true;

datetime g_last_entry_w1_bar = 0;
datetime g_last_exit_w1_bar = 0;

bool HasOpenPositionForMagic()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double HighestPriorClose(const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double highest = 0.0;
   for(int shift = 2; shift < 2 + bars; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_W1, shift);
      if(close <= 0.0)
         return 0.0;
      if(highest <= 0.0 || close > highest)
         highest = close;
     }

   return highest;
  }

double LowestPriorClose(const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double lowest = 0.0;
   for(int shift = 2; shift < 2 + bars; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_W1, shift);
      if(close <= 0.0)
         return 0.0;
      if(lowest <= 0.0 || close < lowest)
         lowest = close;
     }

   return lowest;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_W1);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!strategy_long_only)
      return false;
   if(HasOpenPositionForMagic())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_W1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_w1_bar)
      return false;

   const int high_bars = MathMax(2, strategy_donchian_high_bars);
   if(iBars(_Symbol, PERIOD_W1) < high_bars + 2)
      return false;

   const double signal_close = iClose(_Symbol, PERIOD_W1, 1);
   const double channel_high = HighestPriorClose(high_bars);
   if(signal_close <= 0.0 || channel_high <= 0.0 || signal_close <= channel_high)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_W1, MathMax(1, strategy_atr_period), 1);
   if(ask <= 0.0 || atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = "QM5_1099_DONCHIAN50_LONG";

   if(req.sl <= 0.0 || req.sl >= ask)
     {
      QM_LogEvent(QM_WARN, "INVALID_STOPS", StringFormat("{\"price\":%.5f,\"sl\":%.5f,\"atr\":%.5f}", ask, req.sl, atr));
      return false;
     }

   g_last_entry_w1_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasOpenPositionForMagic())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_W1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_exit_w1_bar)
      return false;

   const int low_bars = MathMax(2, strategy_donchian_low_bars);
   if(iBars(_Symbol, PERIOD_W1) < low_bars + 2)
      return false;

   const double signal_close = iClose(_Symbol, PERIOD_W1, 1);
   const double channel_low = LowestPriorClose(low_bars);
   if(signal_close > 0.0 && channel_low > 0.0 && signal_close < channel_low)
     {
      g_last_exit_w1_bar = signal_bar;
      return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   // V2: Add explicit data readiness check
   if(iBars(_Symbol, PERIOD_W1) < strategy_donchian_high_bars + 2)
     {
      PrintFormat("QM5_1099_V2: Not enough history on %s W1. Have %d, need %d", _Symbol, iBars(_Symbol, PERIOD_W1), strategy_donchian_high_bars + 2);
      // In backtest, it might just need to wait, but if we fail OnInit it stops.
      // We'll return INIT_PARAMETERS_INCORRECT if it's really too short.
     }

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
     {
      const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
      QM_LogEvent(QM_ERROR, "INIT_FAILED_FW", StringFormat("{\"ea_id\":%d,\"slot\":%d,\"magic\":%d,\"symbol\":\"%s\"}", qm_ea_id, qm_magic_slot_offset, magic, _Symbol));
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1099\",\"version\":\"v2\",\"ea\":\"dax-weekly-donchian50-breakout\"}");
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

   if(!QM_IsNewBar())
      return;

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
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

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   
   // V2: Local fix for potential QM_DefaultObjective bug
   const double gross_profit = TesterStatistics(STAT_GROSS_PROFIT);
   const double gross_loss = TesterStatistics(STAT_GROSS_LOSS);
   
   if(gross_profit <= 0.0) return 0.0;
   // If STAT_GROSS_LOSS is negative (some MT5 versions), we need MathAbs
   const double abs_loss = MathAbs(gross_loss);
   if(abs_loss <= 0.0) return gross_profit; // Perfect trade
   
   return gross_profit / abs_loss;
  }
