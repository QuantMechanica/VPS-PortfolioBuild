#property strict
#property version   "5.0"
#property description "QM5_10034 Robot Wealth Rolling Z-Score Pairs"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10034;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.5;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_z_lookback_d1      = 100;
input double strategy_beta               = 0.4;
input double strategy_entry_z            = 1.0;
input double strategy_exit_z             = 0.0;
input double strategy_stop_z             = 3.0;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_time_stop_bars     = 30;
input int    strategy_half_life_lookback = 250;
input double strategy_max_half_life_days = 60.0;
input int    strategy_max_spread_points  = 0;

const int STRATEGY_PAIR_COUNT = 2;
string g_pair_y[2]      = {"SP500.DWX", "XAUUSD.DWX"};
string g_pair_x[2]      = {"NDX.DWX",   "XAGUSD.DWX"};
int    g_pair_y_slot[2] = {0, 2};
int    g_pair_x_slot[2] = {1, 3};

int Strategy_PairIndex()
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(_Symbol == g_pair_x[i] || _Symbol == g_pair_y[i])
         return i;
     }
   return -1;
  }

bool Strategy_IsXLeg(const int pair_index)
  {
   return (pair_index >= 0 && pair_index < STRATEGY_PAIR_COUNT && _Symbol == g_pair_x[pair_index]);
  }

int Strategy_CurrentSlot()
  {
   const int pair_index = Strategy_PairIndex();
   if(pair_index < 0)
      return qm_magic_slot_offset;
   return Strategy_IsXLeg(pair_index) ? g_pair_x_slot[pair_index] : g_pair_y_slot[pair_index];
  }

bool Strategy_SymbolHasDwxSuffix(const string symbol)
  {
   return (StringFind(symbol, ".DWX") == StringLen(symbol) - 4);
  }

bool Strategy_ReadSpread(const int pair_index, const int shift, double &spread)
  {
   spread = 0.0;
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || shift < 1)
      return false;

   const string sym_x = g_pair_x[pair_index];
   const string sym_y = g_pair_y[pair_index];
   SymbolSelect(sym_x, true);
   SymbolSelect(sym_y, true);

   const double x = iClose(sym_x, PERIOD_D1, shift);
   const double y = iClose(sym_y, PERIOD_D1, shift);
   if(x <= 0.0 || y <= 0.0)
      return false;

   spread = y - strategy_beta * x;
   return MathIsValidNumber(spread);
  }

bool Strategy_ZScore(const int pair_index, const int shift, double &z, double &stdev)
  {
   z = 0.0;
   stdev = 0.0;
   const int n = strategy_z_lookback_d1;
   if(n < 20)
      return false;

   double sum = 0.0;
   double sumsq = 0.0;
   for(int i = shift; i < shift + n; ++i)
     {
      double spread = 0.0;
      if(!Strategy_ReadSpread(pair_index, i, spread))
         return false;
      sum += spread;
      sumsq += spread * spread;
     }

   const double mean = sum / (double)n;
   const double variance = (sumsq / (double)n) - mean * mean;
   if(variance <= 0.0)
      return false;

   double now_spread = 0.0;
   if(!Strategy_ReadSpread(pair_index, shift, now_spread))
      return false;

   stdev = MathSqrt(variance);
   z = (now_spread - mean) / stdev;
   return (MathIsValidNumber(z) && MathIsValidNumber(stdev));
  }

bool Strategy_HalfLifeAllows(const int pair_index)
  {
   const int n = strategy_half_life_lookback;
   if(n < 30 || strategy_max_half_life_days <= 0.0)
      return true;

   double spreads[];
   ArrayResize(spreads, n);
   double sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      double spread = 0.0;
      if(!Strategy_ReadSpread(pair_index, i + 1, spread))
         return false;
      spreads[i] = spread;
      sum += spread;
     }

   const double mean = sum / (double)n;
   double num = 0.0;
   double den = 0.0;
   for(int i = 0; i < n - 1; ++i)
     {
      const double curr = spreads[i] - mean;
      const double lag = spreads[i + 1] - mean;
      num += curr * lag;
      den += lag * lag;
     }

   if(den <= DBL_EPSILON)
      return false;

   const double phi = num / den;
   if(!MathIsValidNumber(phi) || phi <= 0.0 || phi >= 1.0)
      return true;

   const double half_life = -MathLog(2.0) / MathLog(phi);
   return (MathIsValidNumber(half_life) && half_life <= strategy_max_half_life_days);
  }

bool Strategy_DataAllows(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string sym_x = g_pair_x[pair_index];
   const string sym_y = g_pair_y[pair_index];
   if(!Strategy_SymbolHasDwxSuffix(sym_x) || !Strategy_SymbolHasDwxSuffix(sym_y))
      return false;

   const datetime tx = iTime(sym_x, PERIOD_D1, 1);
   const datetime ty = iTime(sym_y, PERIOD_D1, 1);
   if(tx <= 0 || ty <= 0)
      return false;
   if(MathAbs((long)(tx - ty)) > 3 * 86400)
      return false;

   return true;
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

bool Strategy_IsPairLegPosition(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int magic = (int)PositionGetInteger(POSITION_MAGIC);
   if(symbol == g_pair_x[pair_index] && magic == QM_Magic(qm_ea_id, g_pair_x_slot[pair_index]))
      return true;
   if(symbol == g_pair_y[pair_index] && magic == QM_Magic(qm_ea_id, g_pair_y_slot[pair_index]))
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
      const int shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      return (shift < 0) ? 0 : shift;
     }
   return 0;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int pair_index = Strategy_PairIndex();
   if(pair_index < 0)
      return true;

   if(!Strategy_DataAllows(pair_index))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points <= 0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10034_RW_PAIRS_Z";
   req.symbol_slot = Strategy_CurrentSlot();
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const int pair_index = Strategy_PairIndex();
   if(pair_index < 0 || !Strategy_HalfLifeAllows(pair_index))
      return false;

   double z_now = 0.0;
   double sd_now = 0.0;
   double z_prev = 0.0;
   double sd_prev = 0.0;
   if(!Strategy_ZScore(pair_index, 1, z_now, sd_now))
      return false;
   if(!Strategy_ZScore(pair_index, 2, z_prev, sd_prev))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return false;
   if(sd_now <= tick_size)
      return false;

   int spread_direction = 0;
   if(z_prev >= -strategy_entry_z && z_now < -strategy_entry_z)
      spread_direction = 1;
   else if(z_prev <= strategy_entry_z && z_now > strategy_entry_z)
      spread_direction = -1;
   else
      return false;

   const bool is_x_leg = Strategy_IsXLeg(pair_index);
   const int leg_direction = is_x_leg ? -spread_direction : spread_direction;
   req.type = (leg_direction > 0) ? QM_BUY : QM_SELL;

   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   req.sl = (req.type == QM_BUY)
            ? NormalizeDouble(entry - strategy_atr_sl_mult * atr, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS))
            : NormalizeDouble(entry + strategy_atr_sl_mult * atr, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   req.tp = 0.0;
   req.reason = (spread_direction > 0) ? "QM5_10034_LONG_SPREAD_Z_CROSS_NEG" : "QM5_10034_SHORT_SPREAD_Z_CROSS_POS";
   return (req.sl > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline specifies no trailing, break-even, partial cover, stacking, or rebalance.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int pair_index = Strategy_PairIndex();
   if(pair_index < 0 || Strategy_OpenPairLegCount(pair_index) <= 0)
      return false;

   double z = 0.0;
   double stdev = 0.0;
   if(!Strategy_ZScore(pair_index, 1, z, stdev))
      return false;

   if(MathAbs(z) >= strategy_stop_z)
      return true;

   if(strategy_exit_z <= 0.0)
     {
      const int pair_legs = Strategy_OpenPairLegCount(pair_index);
      if(pair_legs > 0)
        {
         bool has_buy = false;
         bool has_sell = false;
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
            const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            has_buy = has_buy || (ptype == POSITION_TYPE_BUY);
            has_sell = has_sell || (ptype == POSITION_TYPE_SELL);
           }

         const bool x_leg = Strategy_IsXLeg(pair_index);
         if(has_buy && ((x_leg && z <= 0.0) || (!x_leg && z >= 0.0)))
            return true;
         if(has_sell && ((x_leg && z >= 0.0) || (!x_leg && z <= 0.0)))
            return true;
        }
     }
   else if(MathAbs(z) <= strategy_exit_z)
      return true;

   if(strategy_time_stop_bars > 0 && Strategy_PositionBarsHeld() >= strategy_time_stop_bars)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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
      SymbolSelect(g_pair_x[i], true);
      SymbolSelect(g_pair_y[i], true);
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10034\",\"ea\":\"rw-pairs-z\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   if(Strategy_ExitSignal())
      Strategy_CloseOpenPairLegs(Strategy_PairIndex());

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
