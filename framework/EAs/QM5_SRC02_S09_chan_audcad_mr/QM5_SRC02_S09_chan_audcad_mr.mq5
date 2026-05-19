#property strict
#property version   "5.0"
#property description "QM5_SRC02_S09 chan-audcad-mr (SRC02_S09)"

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 4320;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
enum QM5_RiskModeInput
  {
   QM5_RISK_MODE_AUTO = 0,
   QM5_RISK_MODE_FIXED = 1,
   QM5_RISK_MODE_PERCENT = 2
  };
input QM5_RiskModeInput qm_risk_mode      = QM5_RISK_MODE_AUTO;
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    LOOKBACK                     = 252;
input double ENTRY_Z                      = 2.0;
input double EXIT_Z                       = 0.5;
input int    HALF_LIFE_BARS               = 10;
input double hard_stop_sigma_mult         = 5.0;
input double cadf_tstat_threshold         = -3.343;
input int    cadf_refresh_weekday         = 1;

CTrade   g_trade;
datetime g_last_bar_time = 0;
bool     g_regime_active = false;
int      g_last_cadf_yday = -1;

int StrategyMagic()
  {
   return QM_Magic(qm_ea_id, qm_magic_slot_offset);
  }

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

bool ComputeMeanStd(const int lookback, const int shift, double &mu, double &sigma)
  {
   if(lookback < 20)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, _Period, shift, lookback, closes);
   if(copied != lookback)
      return false;

   mu = 0.0;
   for(int i = 0; i < lookback; ++i)
      mu += closes[i];
   mu /= lookback;

   double var = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double d = closes[i] - mu;
      var += d * d;
     }
   var /= (lookback - 1);
   sigma = MathSqrt(MathMax(var, 0.0));
   return (sigma > 0.0);
  }

// ADF-like gate on single series: delta(y_t) = a + g*y_{t-1} + e. Returns t-stat(g).
bool ComputeCadfTStat(const int lookback, double &t_stat)
  {
   if(lookback < 50)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, _Period, 1, lookback + 1, closes);
   if(copied != lookback + 1)
      return false;

   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   int n = 0;
   for(int i = lookback - 1; i >= 0; --i)
     {
      const double y_prev = closes[i + 1];
      const double dy = closes[i] - y_prev;
      sx += y_prev;
      sy += dy;
      sxx += y_prev * y_prev;
      sxy += y_prev * dy;
      ++n;
     }
   if(n < 10)
      return false;

   const double den = (n * sxx - sx * sx);
   if(MathAbs(den) < 1e-12)
      return false;

   const double gamma = (n * sxy - sx * sy) / den;
   const double alpha = (sy - gamma * sx) / n;

   double sse = 0.0;
   for(int i = lookback - 1; i >= 0; --i)
     {
      const double y_prev = closes[i + 1];
      const double dy = closes[i] - y_prev;
      const double err = dy - (alpha + gamma * y_prev);
      sse += err * err;
     }

   const double dof = n - 2.0;
   if(dof <= 0.0)
      return false;

   const double sigma2 = sse / dof;
   const double se_gamma = MathSqrt((sigma2 * n) / den);
   if(se_gamma <= 0.0)
      return false;

   t_stat = gamma / se_gamma;
   return true;
  }

bool RefreshCadfRegime(const bool force)
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);

   if(!force)
     {
      if(now_dt.day_of_week != cadf_refresh_weekday)
         return true;
      if(g_last_cadf_yday == now_dt.day_of_year)
         return true;
     }

   double t_stat = 0.0;
   if(!ComputeCadfTStat(LOOKBACK, t_stat))
      return false;

   g_regime_active = (t_stat <= cadf_tstat_threshold);
   g_last_cadf_yday = now_dt.day_of_year;
   return true;
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = StrategyMagic();
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

bool OpenPosition(const ENUM_ORDER_TYPE type, const double sigma)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || price <= 0.0 || sigma <= 0.0)
      return false;

   const double stop_distance_points = (hard_stop_sigma_mult * sigma) / point;
   const double lots = QM_LotsForRisk(_Symbol, stop_distance_points);
   if(lots <= 0.0)
      return false;

   const double sl = (type == ORDER_TYPE_BUY)
      ? price - hard_stop_sigma_mult * sigma
      : price + hard_stop_sigma_mult * sigma;

   g_trade.SetExpertMagicNumber(StrategyMagic());
   g_trade.SetDeviationInPoints(20);

   if(type == ORDER_TYPE_BUY)
      return g_trade.Buy(lots, _Symbol, 0.0, sl, 0.0, "SRC02_S09");
   return g_trade.Sell(lots, _Symbol, 0.0, sl, 0.0, "SRC02_S09");
  }

int BarsHeld(const datetime opened_at)
  {
   const int open_shift = iBarShift(_Symbol, _Period, opened_at, false);
   if(open_shift < 0)
      return 0;
   return open_shift;
  }

void ManagePosition(const double zscore)
  {
   ulong ticket;
   if(!GetOurPosition(ticket) || !PositionSelectByTicket(ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
   const int held_bars = BarsHeld(opened_at);
   const int max_hold = MathMax(1, HALF_LIFE_BARS * 2);

   bool exit_now = false;

   if(ptype == POSITION_TYPE_BUY && zscore >= -EXIT_Z)
      exit_now = true;
   if(ptype == POSITION_TYPE_SELL && zscore <= EXIT_Z)
      exit_now = true;

   if(!exit_now && held_bars >= max_hold)
      exit_now = true;

   if(exit_now)
     {
      g_trade.SetExpertMagicNumber(StrategyMagic());
      g_trade.PositionClose(ticket, 20);
     }
  }

int OnInit()
  {
   if(_Period != PERIOD_D1)
     {
      Print("SRC02_S09 requires D1 timeframe.");
      return INIT_FAILED;
     }

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   if(!RefreshCadfRegime(true))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(_Symbol != "AUDCAD.DWX")
      return;

   if(!QM_KillSwitchCheck())
      return;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!IsNewBar())
      return;

   if(!RefreshCadfRegime(false))
      return;

   double mu = 0.0, sigma = 0.0;
   if(!ComputeMeanStd(LOOKBACK, 1, mu, sigma))
      return;

   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 <= 0.0)
      return;

   const double z = (close1 - mu) / sigma;

   ManagePosition(z);

   ulong ticket;
   if(GetOurPosition(ticket))
      return;

   if(!g_regime_active)
      return;

   if(z <= -ENTRY_Z)
      OpenPosition(ORDER_TYPE_BUY, sigma);
   else if(z >= ENTRY_Z)
      OpenPosition(ORDER_TYPE_SELL, sigma);
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   return QM_DefaultObjective();
  }
