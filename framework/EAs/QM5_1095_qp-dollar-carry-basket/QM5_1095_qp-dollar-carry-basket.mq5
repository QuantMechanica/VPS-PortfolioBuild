#property strict
#property version   "5.0"
#property description "QM5_1095 Quantpedia Dollar Carry Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1095;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.142857142857;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 5.0;
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;
input int    strategy_rebalance_hour     = 1;
input string strategy_rate_csv_path      = "QM5_1095_dollar_carry_rates.csv";
input double strategy_us_3m_rate         = 5.25;
input double strategy_basket_3m_rate     = 3.78;
input int    strategy_basket_legs        = 7;

int      g_last_entry_rebalance_ym = 0;
int      g_last_exit_rebalance_ym = 0;
datetime g_last_kill_check_bar = 0;
bool     g_basket_kill_active = false;

int RebalanceYm()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   return (now_dt.year * 100 + now_dt.mon);
  }

datetime MonthStart()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool IsMonthEndRebalanceBar()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.hour < strategy_rebalance_hour)
      return false;

   datetime tomorrow = TimeCurrent() + 86400;
   MqlDateTime next_dt;
   TimeToStruct(tomorrow, next_dt);
   return (next_dt.mon != now_dt.mon || next_dt.year != now_dt.year);
  }

int SymbolSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "USDJPY.DWX") return 2;
   if(_Symbol == "AUDUSD.DWX") return 3;
   if(_Symbol == "USDCAD.DWX") return 4;
   if(_Symbol == "USDCHF.DWX") return 5;
   if(_Symbol == "NZDUSD.DWX") return 6;
   return -1;
  }

int UsdPairSign()
  {
   if(_Symbol == "USDJPY.DWX" || _Symbol == "USDCAD.DWX" || _Symbol == "USDCHF.DWX")
      return 1;
   if(_Symbol == "EURUSD.DWX" || _Symbol == "GBPUSD.DWX" || _Symbol == "AUDUSD.DWX" || _Symbol == "NZDUSD.DWX")
      return -1;
   return 0;
  }

bool ReadRateSpreadFromCsv(double &out_spread)
  {
   out_spread = 0.0;
   if(strategy_rate_csv_path == "")
      return false;

   int handle = FileOpen(strategy_rate_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_rate_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   bool found = false;
   while(!FileIsEnding(handle))
     {
      string date_field = FileReadString(handle);
      string us_field = FileReadString(handle);
      string basket_field = FileReadString(handle);
      if(us_field == "" || basket_field == "")
         continue;

      double us_rate = StringToDouble(us_field);
      double basket_rate = StringToDouble(basket_field);
      if(us_rate == 0.0 && basket_rate == 0.0)
         continue;

      out_spread = us_rate - basket_rate;
      found = true;
     }

   FileClose(handle);
   return found;
  }

double CurrentRateSpread()
  {
   double spread = 0.0;
   if(ReadRateSpreadFromCsv(spread))
      return spread;
   return strategy_us_3m_rate - strategy_basket_3m_rate;
  }

bool SpreadAllowsEntry()
  {
   if(strategy_spread_days <= 0 || strategy_spread_mult <= 0.0)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_days, rates); // perf-allowed: closed-bar month-end entry filter only.
   if(copied <= 0)
      return true;

   int spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[count] = rates[i].spread;
         count++;
        }
     }
   if(count <= 0)
      return true;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   const double median = (count % 2 == 1)
                         ? (double)spreads[count / 2]
                         : ((double)spreads[(count / 2) - 1] + (double)spreads[count / 2]) / 2.0;
   const double current = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (median <= 0.0 || current <= strategy_spread_mult * median);
  }

int MonthlyStoppedLegCount()
  {
   const datetime from_time = MonthStart();
   if(!HistorySelect(from_time, TimeCurrent()))
      return 0;

   bool stopped[7];
   ArrayInitialize(stopped, false);
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;

      const long magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(magic < 10950000 || magic > 10950006)
         continue;

      const long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      const long reason = HistoryDealGetInteger(deal_ticket, DEAL_REASON);
      if(entry == DEAL_ENTRY_OUT && reason == DEAL_REASON_SL)
        {
         const int slot = (int)(magic - 10950000);
         if(slot >= 0 && slot < 7)
            stopped[slot] = true;
        }
     }

   int count = 0;
   for(int slot = 0; slot < 7; ++slot)
      if(stopped[slot])
         count++;
   return count;
  }

bool BasketKillSwitchActive()
  {
   const datetime bar = iTime(_Symbol, _Period, 0);
   if(bar > 0 && bar == g_last_kill_check_bar)
      return g_basket_kill_active;

   g_last_kill_check_bar = bar;
   const int legs = (strategy_basket_legs > 0) ? strategy_basket_legs : 7;
   const int threshold = (int)MathCeil((double)legs * 0.5);
   g_basket_kill_active = (MonthlyStoppedLegCount() >= threshold);
   return g_basket_kill_active;
  }

bool Strategy_NoTradeFilter()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.hour < strategy_rebalance_hour)
      return true;

   return false;
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

   if(BasketKillSwitchActive())
      return false;

   if(!IsMonthEndRebalanceBar())
      return false;

   const int ym = RebalanceYm();
   if(ym == g_last_entry_rebalance_ym)
      return false;

   const int slot = SymbolSlot();
   const int pair_sign = UsdPairSign();
   if(slot < 0 || pair_sign == 0 || !SpreadAllowsEntry())
      return false;

   const double spread = CurrentRateSpread();
   if(spread == 0.0)
      return false;

   const int usd_direction = (spread > 0.0) ? 1 : -1;
   const int trade_direction = usd_direction * pair_sign;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   req.symbol_slot = slot;
   req.type = (trade_direction > 0) ? QM_BUY : QM_SELL;
   req.price = (trade_direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (usd_direction > 0) ? "QP_DOLLAR_CARRY_LONG_USD" : "QP_DOLLAR_CARRY_SHORT_USD";
   if(req.sl <= 0.0)
      return false;

   g_last_entry_rebalance_ym = ym;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!BasketKillSwitchActive())
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_KILLSWITCH);
     }
  }

bool Strategy_ExitSignal()
  {
   if(!IsMonthEndRebalanceBar())
      return false;

   const int ym = RebalanceYm();
   if(ym == g_last_exit_rebalance_ym)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      g_last_exit_rebalance_ym = ym;
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
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
