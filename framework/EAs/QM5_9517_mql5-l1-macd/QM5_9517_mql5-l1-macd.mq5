#property strict
#property version   "5.0"
#property description "QM5_9517: H1 MACD crossover with L1 TV-denoising exit filter"

#include <QM/QM_Common.mqh>

// ─── L1 total-variation denoising state ──────────────────────────────────────
// ADMM algorithm for: min (1/2)||y-x||^2 + lambda*||Dx||_1
// Solved with Thomas tridiagonal algorithm; updated once per new H1 bar.

#define L1_MAX_WIN 60

int    g_l1_trend_sign = 0;       // +1 up / -1 down / 0 flat; updated per bar
double g_l1_y[L1_MAX_WIN];        // input close prices, oldest at [0]
double g_l1_x[L1_MAX_WIN];        // trend solution
double g_l1_z[L1_MAX_WIN];        // split variable z = Dx (n-1 used)
double g_l1_u[L1_MAX_WIN];        // dual variable (n-1 used)
double g_l1_c[L1_MAX_WIN];        // Thomas forward super-diagonal (n-1 used)
double g_l1_d[L1_MAX_WIN];        // Thomas forward modified RHS

// ─── Framework inputs ─────────────────────────────────────────────────────────

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9517;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_macd_fast           = 12;    // MACD fast EMA period
input int    strategy_macd_slow           = 26;    // MACD slow EMA period
input int    strategy_macd_sig_period     = 9;     // MACD signal EMA period
input int    strategy_atr_period          = 14;    // ATR period for catastrophic SL
input double strategy_atr_sl_mult         = 2.0;   // ATR multiplier for SL distance
input int    strategy_l1_window           = 30;    // bars in L1 TV rolling window
input double strategy_l1_lambda_coef      = 0.2;   // lambda = coef * lambda_max

// ─── L1 TV denoising via ADMM ─────────────────────────────────────────────────

void L1_UpdateTrendSign()
  {
   const int win = (strategy_l1_window < 3)        ? 3 :
                   (strategy_l1_window > L1_MAX_WIN - 1) ? L1_MAX_WIN - 1 :
                   strategy_l1_window;

   // perf-allowed: L1 filter requires raw close array; called once per new H1 bar (QM_IsNewBar gated)
   for(int i = 0; i < win; i++)
      g_l1_y[i] = iClose(_Symbol, PERIOD_H1, win - i); // perf-allowed

   // Guard: any zero means history not yet loaded
   for(int i = 0; i < win; i++)
      if(g_l1_y[i] <= 0.0) { g_l1_trend_sign = 0; return; }

   // lambda_max = max absolute first difference (practical approximation)
   double lmax = 0.0;
   for(int i = 0; i < win - 1; i++)
      lmax = MathMax(lmax, MathAbs(g_l1_y[i + 1] - g_l1_y[i]));
   if(lmax < 1e-12) { g_l1_trend_sign = 0; return; }

   const double lambda = strategy_l1_lambda_coef * lmax;
   const double rho    = 1.0;
   const double thresh = lambda / rho;
   const int    nm1    = win - 1;
   // Tridiagonal coefficients for (I + rho*D^T*D):
   //   diagonal: b[0]=b[n-1]=1+rho, b[i]=1+2*rho interior
   //   off-diagonal: a = c = -rho
   const double b0 = 1.0 + rho;
   const double bm = 1.0 + 2.0 * rho;
   const double a  = -rho;

   for(int i = 0; i < win; i++) g_l1_x[i] = g_l1_y[i];
   for(int i = 0; i < nm1;  i++) { g_l1_z[i] = 0.0; g_l1_u[i] = 0.0; }

   for(int iter = 0; iter < 50; iter++)
     {
      // z-update: z[i] = SoftThresh(x[i+1]-x[i]+u[i], thresh)
      for(int i = 0; i < nm1; i++)
        {
         double v = g_l1_x[i + 1] - g_l1_x[i] + g_l1_u[i];
         g_l1_z[i] = (v >  thresh) ? v - thresh :
                     (v < -thresh) ? v + thresh : 0.0;
        }

      // Build RHS = y + rho * D^T * (z - u)
      // D^T*v: [0]= -v[0], [i]=v[i-1]-v[i] (0<i<n-1), [n-1]=v[n-2]
      for(int i = 0; i < win; i++) g_l1_d[i] = g_l1_y[i];
      g_l1_d[0] += rho * (-(g_l1_z[0] - g_l1_u[0]));
      for(int i = 1; i < nm1; i++)
         g_l1_d[i] += rho * ((g_l1_z[i-1]-g_l1_u[i-1]) - (g_l1_z[i]-g_l1_u[i]));
      g_l1_d[nm1] += rho * (g_l1_z[nm1-1] - g_l1_u[nm1-1]);

      // Thomas forward sweep (in-place into g_l1_d)
      g_l1_c[0] = a / b0;
      g_l1_d[0] = g_l1_d[0] / b0;
      for(int i = 1; i < win; i++)
        {
         double bi    = (i == nm1) ? b0 : bm;
         double denom = bi - a * g_l1_c[i - 1];
         if(i < nm1)
            g_l1_c[i] = a / denom;
         g_l1_d[i] = (g_l1_d[i] - a * g_l1_d[i - 1]) / denom;
        }
      // Back substitution into g_l1_x
      g_l1_x[nm1] = g_l1_d[nm1];
      for(int i = nm1 - 1; i >= 0; i--)
         g_l1_x[i] = g_l1_d[i] - g_l1_c[i] * g_l1_x[i + 1];

      // u-update
      for(int i = 0; i < nm1; i++)
         g_l1_u[i] += g_l1_x[i + 1] - g_l1_x[i] - g_l1_z[i];
     }

   // Trend direction from last two trend values
   const double slope = g_l1_x[nm1] - g_l1_x[nm1 - 1];
   g_l1_trend_sign = (slope >  1e-12) ? 1 : (slope < -1e-12 ? -1 : 0);
  }

// ─── Strategy hooks ───────────────────────────────────────────────────────────

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called after QM_IsNewBar() == true. Updates L1 state then checks entry crossover.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   L1_UpdateTrendSign();

   const double main1 = QM_MACD_Main(_Symbol, PERIOD_H1,
                                     strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_sig_period, 1);
   const double sig1  = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_sig_period, 1);
   const double main2 = QM_MACD_Main(_Symbol, PERIOD_H1,
                                     strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_sig_period, 2);
   const double sig2  = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_sig_period, 2);

   if(main1 == 0.0 && sig1 == 0.0)
      return false;

   // Bullish crossover: main crossed above signal between bar[2] and bar[1]
   const bool bullish = (main2 < sig2) && (main1 > sig1);
   // Bearish crossover: main crossed below signal
   const bool bearish = (main2 > sig2) && (main1 < sig1);
   if(!bullish && !bearish)
      return false;

   const QM_OrderType side = bullish ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type              = side;
   req.price             = 0.0;
   req.sl                = sl;
   req.tp                = 0.0;
   req.symbol_slot       = qm_magic_slot_offset;
   req.reason            = bullish ? "L1MACD_LONG" : "L1MACD_SHORT";
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline: ATR stop set at entry; no trailing or partial-close management
  }

// Called every tick. Exits on opposite MACD crossover confirmed by L1 trend sign.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_long = false, has_short = false;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         has_long = true;
      else
         has_short = true;
     }
   if(!has_long && !has_short)
      return false;

   // Read two most-recent closed bars for crossover detection
   const double main1 = QM_MACD_Main(_Symbol, PERIOD_H1,
                                     strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_sig_period, 1);
   const double sig1  = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_sig_period, 1);
   const double main2 = QM_MACD_Main(_Symbol, PERIOD_H1,
                                     strategy_macd_fast, strategy_macd_slow,
                                     strategy_macd_sig_period, 2);
   const double sig2  = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                       strategy_macd_fast, strategy_macd_slow,
                                       strategy_macd_sig_period, 2);

   if(main1 == 0.0 && sig1 == 0.0)
      return false;

   // L1-confirmed bearish crossover → exit long
   if(has_long && (main2 > sig2) && (main1 < sig1) && g_l1_trend_sign < 0)
      return true;
   // L1-confirmed bullish crossover → exit short
   if(has_short && (main2 < sig2) && (main1 > sig1) && g_l1_trend_sign > 0)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ─── Framework wiring ─────────────────────────────────────────────────────────

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
