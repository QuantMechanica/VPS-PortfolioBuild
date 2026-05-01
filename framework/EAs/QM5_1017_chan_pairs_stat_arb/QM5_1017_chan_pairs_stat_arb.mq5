#property strict
#property version   "5.0"
#property description "QM5_1017 Chan Pairs Stat-Arb Scaffold (SRC02_S01)"
// Strategy Card: SRC02_S01 (chan-pairs-stat-arb), CEO-approved per governance update 2026-05-01.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1017;
input int    qm_magic_slot_offset         = 0;    // Leg-1 slot; leg-2 convention is slot+1 (Card §7 / §12).

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false; // Card §6/§12 + CEO waiver note (2026-04-28): friday-close disabled for this family.
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input string pair_symbol_1                = "AUDUSD.DWX"; // Card §3: deploy on Darwinex cadf-eligible pair, not GLD/GDX.
input string pair_symbol_2                = "NZDUSD.DWX"; // Card §3 candidate pair mapping for P1 scaffold.
input bool   cadf_gate_enabled            = true;          // Card §4/§6: deploy only when cadf significance gate passes.
input double cointegration_significance   = 0.05;          // Card §4/§8: default 5% cadf level.
input int    training_lookback            = 252;           // Card §4/§8: trainset lookback.
input int    ols_hedge_lookback           = 252;           // Card §4: OLS hedge ratio fit window.
input double entry_z                      = 2.0;           // Card §4/§8: entry threshold.
input double exit_z                       = 1.0;           // Card §5/§8: mean-reach exit band.
input int    ou_halflife_cap_days         = 30;            // Card §6/§8: deployment half-life cap.
input double time_stop_multiplier         = 1.0;           // Card §5/§8: OU half-life time-stop multiplier.

datetime g_last_bar_time = 0;

double StrategyPrimaryMagic()
  {
   return (double)QM_Magic(qm_ea_id, qm_magic_slot_offset);
  }

double StrategyHedgeMagic()
  {
   // Card §7 / §12: two-symbol pair; hedge leg uses adjacent slot by convention.
   return (double)QM_Magic(qm_ea_id, qm_magic_slot_offset + 1);
  }

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0 || t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

bool ReadPairCloses(const int shift, double &c1, double &c2)
  {
   c1 = iClose(pair_symbol_1, _Period, shift);
   c2 = iClose(pair_symbol_2, _Period, shift);
   return (c1 > 0.0 && c2 > 0.0);
  }

bool ComputeScaffoldZScore(double &z)
  {
   z = 0.0;
   if(training_lookback < 30 || ols_hedge_lookback < 30)
      return false;

   const int bars1 = Bars(pair_symbol_1, _Period);
   const int bars2 = Bars(pair_symbol_2, _Period);
   const int required = MathMax(training_lookback + 5, ols_hedge_lookback + 5);
   if(bars1 < required || bars2 < required)
      return false;

   // Card §4 structure: spread_t = asset1 - hedgeRatio * asset2. P1 scaffold uses fixed beta=1.0 placeholder.
   const double hedge_ratio = 1.0;
   double sum = 0.0;
   double sumsq = 0.0;
   int n = 0;
   for(int i = 1; i <= training_lookback; ++i)
     {
      double c1 = 0.0;
      double c2 = 0.0;
      if(!ReadPairCloses(i, c1, c2))
         return false;
      const double spread = c1 - hedge_ratio * c2;
      sum += spread;
      sumsq += spread * spread;
      ++n;
     }

   if(n < 30)
      return false;

   const double mean = sum / (double)n;
   const double var = (sumsq / (double)n) - mean * mean;
   if(var <= 0.0)
      return false;

   double now1 = 0.0;
   double now2 = 0.0;
   if(!ReadPairCloses(1, now1, now2))
      return false;

   const double spread_now = now1 - hedge_ratio * now2;
   z = (spread_now - mean) / MathSqrt(var);
   return MathIsValidNumber(z);
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

   if(!cadf_gate_enabled)
      return false;

   // Card §4/§6: cadf pass is required before live entry. P1 scaffold keeps entries disabled until cadf/2-leg executor is wired.
   double z = 0.0;
   if(!ComputeScaffoldZScore(z))
      return false;

   if(z <= -entry_z)
      req.reason = "SRC02_S01_LONG_SPREAD_SIGNAL";
   else if(z >= entry_z)
      req.reason = "SRC02_S01_SHORT_SPREAD_SIGNAL";

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card §7: two-leg synchronized management required. P1 scaffold intentionally leaves management inert.
  }

bool Strategy_ExitSignal()
  {
   // Card §5: mean-reach (|z| <= exit_z) OR OU half-life time-stop. P1 scaffold keeps close module inert.
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

   const int leg1_magic = (int)StrategyPrimaryMagic();
   const int leg2_magic = (int)StrategyHedgeMagic();
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"card\":\"SRC02_S01\",\"ea\":\"QM5_1017_chan_pairs_stat_arb\",\"leg1_magic\":%d,\"leg2_magic\":%d}",
                            leg1_magic,
                            leg2_magic));
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
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!IsNewBar())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
