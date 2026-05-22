#property strict
#property version   "5.0"
#property description "QM5_10718 Edge Lab regime-filtered FX carry basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

#define FX8_SYMBOL_COUNT 28
#define FX8_CCY_COUNT 8

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10718;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_FTMO_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_vol_days           = 20;
input int    strategy_vol_median_days    = 252;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.0;
input int    strategy_rebalance_hour     = 1;
input int    strategy_deviation_points   = 20;

string g_symbols[FX8_SYMBOL_COUNT] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX","USDJPY.DWX","USDCHF.DWX","USDCAD.DWX",
   "EURGBP.DWX","EURJPY.DWX","EURCHF.DWX","EURAUD.DWX","EURNZD.DWX","EURCAD.DWX",
   "GBPJPY.DWX","GBPCHF.DWX","GBPAUD.DWX","GBPNZD.DWX","GBPCAD.DWX",
   "AUDJPY.DWX","AUDCHF.DWX","AUDNZD.DWX","AUDCAD.DWX",
   "NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
   "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
  };

string g_ccy[FX8_CCY_COUNT] = {"USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD"};
datetime g_last_rebalance_bar = 0;
bool g_regime_was_red = false;

struct CurrencyRank
  {
   string ccy;
   double score;
  };

string PairRoot(const string symbol) { return StringSubstr(symbol, 0, 6); }
string BaseCurrency(const string symbol) { return StringSubstr(PairRoot(symbol), 0, 3); }
string QuoteCurrency(const string symbol) { return StringSubstr(PairRoot(symbol), 3, 3); }

int PairIndexForCurrencies(const string a, const string b)
  {
   for(int i = 0; i < FX8_SYMBOL_COUNT; ++i)
     {
      const string base = BaseCurrency(g_symbols[i]);
      const string quote = QuoteCurrency(g_symbols[i]);
      if((base == a && quote == b) || (base == b && quote == a))
         return i;
     }
   return -1;
  }

double BasketRealizedVol(const int shift)
  {
   const int days = MathMax(5, strategy_vol_days);
   double sum_var = 0.0;
   int valid_symbols = 0;
   for(int i = 0; i < FX8_SYMBOL_COUNT; ++i)
     {
      double mean = 0.0;
      double sq = 0.0;
      int n = 0;
      for(int b = shift; b < shift + days; ++b)
        {
         const double c0 = iClose(g_symbols[i], PERIOD_D1, b);
         const double c1 = iClose(g_symbols[i], PERIOD_D1, b + 1);
         if(c0 <= 0.0 || c1 <= 0.0)
            continue;
         const double r = (c0 / c1) - 1.0;
         mean += r;
         sq += r * r;
         n++;
        }
      if(n < days / 2)
         continue;
      mean /= (double)n;
      const double variance = MathMax(0.0, (sq / (double)n) - mean * mean);
      sum_var += variance;
      valid_symbols++;
     }
   if(valid_symbols < FX8_SYMBOL_COUNT / 2)
      return 0.0;
   return MathSqrt(sum_var / (double)valid_symbols);
  }

bool RegimeRed()
  {
   const double current = BasketRealizedVol(1);
   if(current <= 0.0)
      return true;
   const int window = MathMax(60, strategy_vol_median_days);
   double vols[];
   ArrayResize(vols, window);
   int samples = 0;
   for(int shift = 2; shift < 2 + window; ++shift)
     {
      const double v = BasketRealizedVol(shift);
      if(v <= 0.0)
         continue;
      vols[samples] = v;
      samples++;
     }
   if(samples < 40)
      return true;
   ArrayResize(vols, samples);
   ArraySort(vols);
   const double median = (samples % 2 == 1) ? vols[samples / 2] : (vols[samples / 2 - 1] + vols[samples / 2]) * 0.5;
   return (current > median);
  }

bool CurrencyCarry(const string ccy, double &score)
  {
   score = 0.0;
   int samples = 0;
   for(int i = 0; i < FX8_SYMBOL_COUNT; ++i)
     {
      if(!SymbolSelect(g_symbols[i], true))
         continue;
      const string base = BaseCurrency(g_symbols[i]);
      const string quote = QuoteCurrency(g_symbols[i]);
      if(base != ccy && quote != ccy)
         continue;
      const double swap_long = SymbolInfoDouble(g_symbols[i], SYMBOL_SWAP_LONG);
      const double swap_short = SymbolInfoDouble(g_symbols[i], SYMBOL_SWAP_SHORT);
      const double carry = swap_long - swap_short;
      score += (base == ccy) ? carry : -carry;
      samples++;
     }
   if(samples < 4)
      return false;
   score /= (double)samples;
   return true;
  }

bool RankCurrencies(CurrencyRank &ranks[])
  {
   ArrayResize(ranks, FX8_CCY_COUNT);
   for(int i = 0; i < FX8_CCY_COUNT; ++i)
     {
      ranks[i].ccy = g_ccy[i];
      if(!CurrencyCarry(g_ccy[i], ranks[i].score))
         return false;
     }
   for(int i = 0; i < FX8_CCY_COUNT - 1; ++i)
      for(int j = i + 1; j < FX8_CCY_COUNT; ++j)
         if(ranks[j].score > ranks[i].score)
           {
            CurrencyRank tmp = ranks[i];
            ranks[i] = ranks[j];
            ranks[j] = tmp;
           }
   return true;
  }

void CloseBasketPositions()
  {
   const int min_magic = qm_ea_id * 10000;
   const int max_magic = min_magic + FX8_SYMBOL_COUNT - 1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic < min_magic || magic > max_magic)
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool OpenCurrencyPair(const string long_ccy, const string short_ccy)
  {
   const int idx = PairIndexForCurrencies(long_ccy, short_ccy);
   if(idx < 0)
      return false;
   const string symbol = g_symbols[idx];
   const bool buy_base = (BaseCurrency(symbol) == long_ccy);
   const QM_OrderType order_type = buy_base ? QM_BUY : QM_SELL;
   const double price = QM_BasketMarketPrice(symbol, order_type);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period, 1);
   if(price <= 0.0 || atr <= 0.0)
      return false;
   const double sl = buy_base ? price - strategy_atr_sl_mult * atr : price + strategy_atr_sl_mult * atr;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.lots = 0.0;
   req.reason = "QM5_10718_weekly_regime_carry";
   req.symbol_slot = idx;
   req.expiration_seconds = 0;
   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode, strategy_deviation_points, req, ticket);
  }

bool IsWeeklyRebalanceBar()
  {
   const datetime bar = iTime(_Symbol, PERIOD_D1, 0);
   if(bar <= 0 || bar == g_last_rebalance_bar)
      return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != 1 || dt.hour < strategy_rebalance_hour)
      return false;
   g_last_rebalance_bar = bar;
   return true;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode, qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;
   for(int i = 0; i < FX8_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10718\",\"logical_symbol\":\"FX8_BASKET_D1\",\"carry_source\":\"broker_swap_proxy\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;

   const bool red = RegimeRed();
   if(red && !g_regime_was_red)
      CloseBasketPositions();
   g_regime_was_red = red;
   if(red || !IsWeeklyRebalanceBar())
      return;

   CloseBasketPositions();
   CurrencyRank ranks[];
   if(!RankCurrencies(ranks))
      return;

   OpenCurrencyPair(ranks[0].ccy, ranks[FX8_CCY_COUNT - 1].ccy);
   OpenCurrencyPair(ranks[0].ccy, ranks[FX8_CCY_COUNT - 2].ccy);
   OpenCurrencyPair(ranks[1].ccy, ranks[FX8_CCY_COUNT - 1].ccy);
   OpenCurrencyPair(ranks[1].ccy, ranks[FX8_CCY_COUNT - 2].ccy);
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
