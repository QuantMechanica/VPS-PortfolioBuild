#property strict
#property version   "5.0"
#property description "QM5_10035 Robot Wealth index stat arb"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10035;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.25;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_return_lookback_days     = 5;
input double strategy_entry_z                  = 0.75;
input double strategy_exit_z                   = 0.10;
input int    strategy_atr_period               = 20;
input double strategy_atr_sl_mult              = 2.0;
input int    strategy_hold_days                = 5;
input int    strategy_dispersion_lookback_days = 60;
input double strategy_min_dispersion_fraction  = 0.25;
input int    strategy_min_eligible_symbols     = 4;
input int    strategy_max_spread_points        = 250;
input double strategy_portfolio_stop_r         = 1.5;

#define STRATEGY_BASKET_COUNT 5

string g_strategy_basket[STRATEGY_BASKET_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
  };

double LogReturnForShift(const string symbol, const int shift, const int lookback)
  {
   if(lookback < 1 || shift < 1)
      return 0.0;

   const double c0 = iClose(symbol, PERIOD_D1, shift);
   const double c1 = iClose(symbol, PERIOD_D1, shift + lookback);
   if(c0 <= 0.0 || c1 <= 0.0)
      return 0.0;

   return MathLog(c0 / c1);
  }

bool SymbolFreshForShift(const string symbol, const int shift, const datetime ref_time)
  {
   const datetime t = iTime(symbol, PERIOD_D1, shift);
   if(t <= 0)
      return false;
   if(ref_time <= 0)
      return true;

   return (MathAbs((long)(ref_time - t)) <= 3L * 86400L);
  }

bool BasketStatsForShift(const int shift,
                         const int lookback,
                         double &mean,
                         double &sd,
                         int &eligible)
  {
   mean = 0.0;
   sd = 0.0;
   eligible = 0;

   const datetime ref_time = iTime(_Symbol, PERIOD_D1, shift);
   double returns[STRATEGY_BASKET_COUNT];
   ArrayInitialize(returns, 0.0);

   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      const string symbol = g_strategy_basket[i];
      if(!SymbolFreshForShift(symbol, shift, ref_time))
         continue;

      const double r = LogReturnForShift(symbol, shift, lookback);
      if(r == 0.0)
         continue;

      returns[eligible] = r;
      mean += r;
      ++eligible;
     }

   if(eligible < strategy_min_eligible_symbols)
      return false;

   mean /= (double)eligible;
   for(int i = 0; i < eligible; ++i)
      sd += MathPow(returns[i] - mean, 2.0);

   sd = MathSqrt(sd / (double)eligible);
   return (sd > 0.0);
  }

double MedianRecentDispersion()
  {
   const int n = MathMax(1, strategy_dispersion_lookback_days);
   double values[];
   ArrayResize(values, n);
   int used = 0;

   for(int shift = 1; shift <= n; ++shift)
     {
      double mean = 0.0;
      double sd = 0.0;
      int eligible = 0;
      if(!BasketStatsForShift(shift, strategy_return_lookback_days, mean, sd, eligible))
         continue;
      values[used] = sd;
      ++used;
     }

   if(used <= 0)
      return 0.0;

   ArrayResize(values, used);
   ArraySort(values);
   const int mid = used / 2;
   if((used % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

bool CurrentZScore(const string symbol, double &z, double &dispersion)
  {
   z = 0.0;
   dispersion = 0.0;

   double mean = 0.0;
   int eligible = 0;
   if(!BasketStatsForShift(1, strategy_return_lookback_days, mean, dispersion, eligible))
      return false;

   const double median_dispersion = MedianRecentDispersion();
   if(median_dispersion <= 0.0)
      return false;
   if(dispersion < strategy_min_dispersion_fraction * median_dispersion)
      return false;

   const double r = LogReturnForShift(symbol, 1, strategy_return_lookback_days);
   if(r == 0.0)
      return false;

   z = (r - mean) / dispersion;
   return true;
  }

bool CurrentBasketZScores(double &z_values[], bool &eligible_values[])
  {
   ArrayResize(z_values, STRATEGY_BASKET_COUNT);
   ArrayResize(eligible_values, STRATEGY_BASKET_COUNT);
   ArrayInitialize(z_values, 0.0);
   ArrayInitialize(eligible_values, false);

   double mean = 0.0;
   double dispersion = 0.0;
   int eligible = 0;
   if(!BasketStatsForShift(1, strategy_return_lookback_days, mean, dispersion, eligible))
      return false;

   const double median_dispersion = MedianRecentDispersion();
   if(median_dispersion <= 0.0 || dispersion < strategy_min_dispersion_fraction * median_dispersion)
      return false;

   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      const string symbol = g_strategy_basket[i];
      const double r = LogReturnForShift(symbol, 1, strategy_return_lookback_days);
      if(r == 0.0)
         continue;

      z_values[i] = (r - mean) / dispersion;
      eligible_values[i] = true;
     }

   return true;
  }

int BasketIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      if(g_strategy_basket[i] == symbol)
         return i;
     }
   return -1;
  }

int LongRank(const double &z_values[], const bool &eligible_values[], const int index)
  {
   int rank = 1;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      if(!eligible_values[i] || i == index)
         continue;
      if(z_values[i] < z_values[index])
         ++rank;
     }
   return rank;
  }

int ShortRank(const double &z_values[], const bool &eligible_values[], const int index)
  {
   int rank = 1;
   for(int i = 0; i < STRATEGY_BASKET_COUNT; ++i)
     {
      if(!eligible_values[i] || i == index)
         continue;
      if(z_values[i] > z_values[index])
         ++rank;
     }
   return rank;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at, double &profit)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;
   profit = 0.0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      profit = PositionGetDouble(POSITION_PROFIT);
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int index = BasketIndexForSymbol(_Symbol);
   if(index < 0)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int index = BasketIndexForSymbol(_Symbol);
   if(index < 0)
      return false;

   double z_values[];
   bool eligible_values[];
   if(!CurrentBasketZScores(z_values, eligible_values))
      return false;
   if(!eligible_values[index])
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_dist = strategy_atr_sl_mult * atr;
   const double z = z_values[index];

   if(z <= -strategy_entry_z && LongRank(z_values, eligible_values, index) <= 2)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - stop_dist;
      req.tp = 0.0;
      req.reason = "RW_STAT_ARB_LONG_Z";
      return true;
     }

   if(z >= strategy_entry_z && ShortRank(z_values, eligible_values, index) <= 2)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + stop_dist;
      req.tp = 0.0;
      req.reason = "RW_STAT_ARB_SHORT_Z";
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR stop, no trailing, no break-even, no partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   double profit;
   if(!GetOurPosition(ptype, opened_at, profit))
      return false;

   const double risk_money = (RISK_FIXED > 0.0)
                             ? RISK_FIXED * PORTFOLIO_WEIGHT
                             : AccountInfoDouble(ACCOUNT_EQUITY) * (RISK_PERCENT / 100.0) * PORTFOLIO_WEIGHT;
   if(risk_money > 0.0 && profit <= -strategy_portfolio_stop_r * risk_money)
      return true;

   const int open_shift = iBarShift(_Symbol, PERIOD_D1, opened_at, false);
   if(open_shift >= strategy_hold_days)
      return true;

   double z = 0.0;
   double dispersion = 0.0;
   if(!CurrentZScore(_Symbol, z, dispersion))
      return false;

   if(ptype == POSITION_TYPE_BUY && z > -strategy_exit_z)
      return true;
   if(ptype == POSITION_TYPE_SELL && z < strategy_exit_z)
      return true;

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10035\",\"ea\":\"QM5_10035_rw-stat-arb\"}");
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
