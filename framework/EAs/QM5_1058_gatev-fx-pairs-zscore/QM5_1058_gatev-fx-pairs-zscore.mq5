#property strict
#property version   "5.0"
#property description "QM5_1058 Gatev FX Pairs Z-Score Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1058;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_lookback_bars      = 60;
input double strategy_entry_z            = 2.0;
input double strategy_exit_z             = 0.5;
input double strategy_hard_stop_z        = 4.0;
input double strategy_min_corr           = 0.6;
input int    strategy_time_stop_bars     = 20;
input int    strategy_max_spread_points  = 50;

const int STRATEGY_PAIR_COUNT = 2;
string g_pair_a[2] = {"EURUSD.DWX", "AUDUSD.DWX"};
string g_pair_b[2] = {"GBPUSD.DWX", "NZDUSD.DWX"};
int    g_pair_slot_a[2] = {0, 2};
int    g_pair_slot_b[2] = {1, 3};

int Strategy_PairIndex()
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(_Symbol == g_pair_a[i] || _Symbol == g_pair_b[i])
         return i;
     }
   return -1;
  }

bool Strategy_IsLegA(const int pair_index)
  {
   return (pair_index >= 0 && pair_index < STRATEGY_PAIR_COUNT && _Symbol == g_pair_a[pair_index]);
  }

int Strategy_CurrentSlot()
  {
   const int pair_index = Strategy_PairIndex();
   if(pair_index < 0)
      return qm_magic_slot_offset;
   return Strategy_IsLegA(pair_index) ? g_pair_slot_a[pair_index] : g_pair_slot_b[pair_index];
  }

bool Strategy_HasOpenPosition()
  {
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
      return true;
     }
   return false;
  }

int Strategy_PairSlot(const int pair_index, const bool leg_a)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   return leg_a ? g_pair_slot_a[pair_index] : g_pair_slot_b[pair_index];
  }

bool Strategy_IsPairLegPosition(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int magic = (int)PositionGetInteger(POSITION_MAGIC);
   if(symbol == g_pair_a[pair_index] && magic == QM_Magic(qm_ea_id, Strategy_PairSlot(pair_index, true)))
      return true;
   if(symbol == g_pair_b[pair_index] && magic == QM_Magic(qm_ea_id, Strategy_PairSlot(pair_index, false)))
      return true;
   return false;
  }

int Strategy_OpenPairLegCount(const int pair_index)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairLegPosition(pair_index))
         ++count;
     }
   return count;
  }

void Strategy_CloseOpenPairLegs(const int pair_index)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairLegPosition(pair_index))
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_ReadLogPrices(const string sym_a,
                            const string sym_b,
                            const int shift,
                            double &log_a,
                            double &log_b)
  {
   const double close_a = iClose(sym_a, _Period, shift);
   const double close_b = iClose(sym_b, _Period, shift);
   if(close_a <= 0.0 || close_b <= 0.0)
      return false;

   log_a = MathLog(close_a);
   log_b = MathLog(close_b);
   return (MathIsValidNumber(log_a) && MathIsValidNumber(log_b));
  }

bool Strategy_PairStats(double &z, double &corr)
  {
   z = 0.0;
   corr = 0.0;

   const int pair_index = Strategy_PairIndex();
   if(pair_index < 0 || strategy_lookback_bars < 20)
      return false;

   const string sym_a = g_pair_a[pair_index];
   const string sym_b = g_pair_b[pair_index];
   SymbolSelect(sym_a, true);
   SymbolSelect(sym_b, true);

   const int bars_a = Bars(sym_a, _Period);
   const int bars_b = Bars(sym_b, _Period);
   const int n = strategy_lookback_bars;
   if(bars_a < n + 3 || bars_b < n + 3)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int shift = 1; shift <= n; ++shift)
     {
      double y = 0.0;
      double x = 0.0;
      if(!Strategy_ReadLogPrices(sym_a, sym_b, shift, y, x))
         return false;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double denom = (double)n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) <= DBL_EPSILON)
      return false;
   const double beta = ((double)n * sum_xy - sum_x * sum_y) / denom;
   if(!MathIsValidNumber(beta))
      return false;

   double spread_sum = 0.0;
   double spread_sumsq = 0.0;
   for(int shift = 1; shift <= n; ++shift)
     {
      double y = 0.0;
      double x = 0.0;
      if(!Strategy_ReadLogPrices(sym_a, sym_b, shift, y, x))
         return false;
      const double spread = y - beta * x;
      spread_sum += spread;
      spread_sumsq += spread * spread;
     }

   const double mean = spread_sum / (double)n;
   const double variance = (spread_sumsq / (double)n) - mean * mean;
   if(variance <= 0.0)
      return false;

   double y_now = 0.0;
   double x_now = 0.0;
   if(!Strategy_ReadLogPrices(sym_a, sym_b, 1, y_now, x_now))
      return false;
   z = (y_now - beta * x_now - mean) / MathSqrt(variance);
   if(!MathIsValidNumber(z))
      return false;

   double sum_ra = 0.0;
   double sum_rb = 0.0;
   double sum_raa = 0.0;
   double sum_rbb = 0.0;
   double sum_rab = 0.0;
   int rn = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      double a0 = 0.0;
      double b0 = 0.0;
      double a1 = 0.0;
      double b1 = 0.0;
      if(!Strategy_ReadLogPrices(sym_a, sym_b, shift, a0, b0))
         return false;
      if(!Strategy_ReadLogPrices(sym_a, sym_b, shift + 1, a1, b1))
         return false;
      const double ra = a0 - a1;
      const double rb = b0 - b1;
      sum_ra += ra;
      sum_rb += rb;
      sum_raa += ra * ra;
      sum_rbb += rb * rb;
      sum_rab += ra * rb;
      ++rn;
     }

   const double corr_denom = MathSqrt(((double)rn * sum_raa - sum_ra * sum_ra) *
                                      ((double)rn * sum_rbb - sum_rb * sum_rb));
   if(corr_denom <= DBL_EPSILON)
      return false;
   corr = ((double)rn * sum_rab - sum_ra * sum_rb) / corr_denom;
   return MathIsValidNumber(corr);
  }

int Strategy_PositionBarsHeld()
  {
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int shift = iBarShift(_Symbol, _Period, open_time, false);
      return (shift < 0) ? 0 : shift;
     }
   return 0;
  }

bool Strategy_RolloverWindow(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   return (minute_of_day >= 1410 || minute_of_day < 30);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_PairIndex() < 0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   if(Strategy_RolloverWindow(TimeCurrent()))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1058_GATEV_FX_PAIR";
   req.symbol_slot = Strategy_CurrentSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   double z = 0.0;
   double corr = 0.0;
   if(!Strategy_PairStats(z, corr))
      return false;
   if(corr <= strategy_min_corr)
      return false;

   const int pair_index = Strategy_PairIndex();
   const bool is_leg_a = Strategy_IsLegA(pair_index);
   int spread_direction = 0;
   if(z < -strategy_entry_z)
      spread_direction = 1;
   else if(z > strategy_entry_z)
      spread_direction = -1;
   else
      return false;

   const int leg_direction = is_leg_a ? spread_direction : -spread_direction;
   req.type = (leg_direction > 0) ? QM_BUY : QM_SELL;

   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = 0.0;
   req.reason = (spread_direction > 0) ? "QM5_1058_LONG_PAIR_Z_LT_NEG2" : "QM5_1058_SHORT_PAIR_Z_GT_POS2";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or add-on logic.
  }

bool Strategy_ExitSignal()
  {
   const int pair_index = Strategy_PairIndex();
   const int open_legs = Strategy_OpenPairLegCount(pair_index);
   if(open_legs == 1)
      return true;
   if(open_legs <= 0)
      return false;

   double z = 0.0;
   double corr = 0.0;
   if(!Strategy_PairStats(z, corr))
      return false;

   if(MathAbs(z) < strategy_exit_z)
      return true;
   if(MathAbs(z) > strategy_hard_stop_z)
      return true;
   if(strategy_time_stop_bars > 0 && Strategy_PositionBarsHeld() >= strategy_time_stop_bars)
      return true;
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

   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      SymbolSelect(g_pair_a[i], true);
      SymbolSelect(g_pair_b[i], true);
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1058\",\"ea\":\"gatev-fx-pairs-zscore\"}");
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
      Strategy_CloseOpenPairLegs(Strategy_PairIndex());
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
   return QM_DefaultObjective();
  }
