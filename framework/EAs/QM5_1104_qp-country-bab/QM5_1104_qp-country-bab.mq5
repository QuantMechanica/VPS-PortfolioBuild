#property strict
#property version   "5.0"
#property description "QM5_1104 Quantpedia Country Index Betting Against Beta"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1104;
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
input int    strategy_beta_lookback_d1   = 252;
input int    strategy_min_bars_d1        = 270;
input int    strategy_bucket_size        = 2;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 4.0;
input double strategy_beta_abs_max       = 3.0;

#define QM5_1104_SYMBOL_COUNT 5

string g_symbols[QM5_1104_SYMBOL_COUNT] = {"NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "SP500.DWX"};
int    g_slots[QM5_1104_SYMBOL_COUNT]   = {0, 1, 2, 3, 4};

datetime g_last_entry_rebalance_day = 0;

int SymbolIndex(const string symbol)
  {
   for(int i = 0; i < QM5_1104_SYMBOL_COUNT; ++i)
     {
      if(g_symbols[i] == symbol)
         return i;
     }
   return -1;
  }

datetime LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool IsMonthEndD1(const datetime day)
  {
   if(day <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(day, dt);
   const int month = dt.mon;
   dt.day += 1;
   const datetime next_day = StructToTime(dt);
   if(next_day <= 0)
      return false;

   MqlDateTime ndt;
   TimeToStruct(next_day, ndt);
   return (ndt.mon != month);
  }

bool HasSufficientBars(const string symbol)
  {
   return (iBars(symbol, PERIOD_D1) >= strategy_min_bars_d1);
  }

bool ComputeRollingBeta(const string symbol, const string benchmark, double &out_beta)
  {
   out_beta = 0.0;
   if(symbol == benchmark)
      return false;
   if(strategy_beta_lookback_d1 < 2 || !HasSufficientBars(symbol) || !HasSufficientBars(benchmark))
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_x2 = 0.0;
   int n = 0;

   for(int shift = 1; shift <= strategy_beta_lookback_d1; ++shift)
     {
      const double b0 = iClose(benchmark, PERIOD_D1, shift);
      const double b1 = iClose(benchmark, PERIOD_D1, shift + 1);
      const double s0 = iClose(symbol, PERIOD_D1, shift);
      const double s1 = iClose(symbol, PERIOD_D1, shift + 1);
      if(b0 <= 0.0 || b1 <= 0.0 || s0 <= 0.0 || s1 <= 0.0)
         return false;

      const double x = (b0 / b1) - 1.0;
      const double y = (s0 / s1) - 1.0;
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
      n++;
     }

   if(n < strategy_beta_lookback_d1)
      return false;

   const double mean_x = sum_x / n;
   const double mean_y = sum_y / n;
   const double cov = sum_xy - ((double)n * mean_x * mean_y);
   const double var_x = sum_x2 - ((double)n * mean_x * mean_x);

   if(var_x <= 0.0)
      return false;

   out_beta = cov / var_x;
   if(MathAbs(out_beta) > strategy_beta_abs_max)
      return false;

   return true;
  }

void SortByBeta(double &betas[], int &indexes[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
     {
      for(int j = i + 1; j < count; ++j)
        {
         if(betas[j] < betas[i])
           {
            const double tb = betas[i];
            betas[i] = betas[j];
            betas[j] = tb;

            const int ti = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = ti;
           }
        }
     }
  }

int CurrentSymbolBucketSide()
  {
   const int current_idx = SymbolIndex(_Symbol);
   if(current_idx < 0 || _Symbol == "SP500.DWX")
      return 0;

   double betas[QM5_1104_SYMBOL_COUNT];
   int indexes[QM5_1104_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_1104_SYMBOL_COUNT; ++i)
     {
      if(g_symbols[i] == "SP500.DWX")
         continue;

      double beta = 0.0;
      if(!ComputeRollingBeta(g_symbols[i], "SP500.DWX", beta))
         continue;

      betas[count] = beta;
      indexes[count] = i;
      count++;
     }

   if(count < strategy_bucket_size * 2)
      return 0;

   SortByBeta(betas, indexes, count);

   for(int i = 0; i < strategy_bucket_size; ++i)
     {
      if(indexes[i] == current_idx)
         return 1;
      if(indexes[count - 1 - i] == current_idx)
         return -1;
     }

   return 0;
  }

bool HasOurPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const datetime rebalance_day = LastClosedD1Time();
   if(!IsMonthEndD1(rebalance_day))
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime rebalance_day = LastClosedD1Time();
   if(!IsMonthEndD1(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(HasOurPosition(ticket, opened_at))
      return false;

   const int side = CurrentSymbolBucketSide();
   if(side == 0)
      return false;

   const double entry = (side > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const QM_OrderType order_type = (side > 0) ? QM_BUY : QM_SELL;
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, order_type, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side > 0) ? "QM5_1104_MONTHLY_LOW_BETA_LONG" : "QM5_1104_MONTHLY_HIGH_BETA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   const datetime rebalance_day = LastClosedD1Time();
   if(!IsMonthEndD1(rebalance_day))
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(!HasOurPosition(ticket, opened_at))
      return false;

   return (opened_at < rebalance_day);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1104_qp-country-bab\"}");
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
