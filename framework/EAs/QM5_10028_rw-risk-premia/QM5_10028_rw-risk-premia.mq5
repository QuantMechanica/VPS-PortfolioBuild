#property strict
#property version   "5.0"
#property description "QM5_10028 Robot Wealth Risk Premia Harvesting"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10028;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vol_lookback_days    = 63;
input int    strategy_momentum_days        = 126;
input int    strategy_gold_momentum_days   = 63;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult         = 4.0;
input int    strategy_min_eligible        = 2;
input double strategy_max_symbol_weight   = 0.35;
input double strategy_portfolio_stop_pct  = 8.0;
input double strategy_max_spread_points   = 0.0;

// Basket definition (5 risk-premia proxies)
string g_basket[5];

// Monthly eligibility cache (refreshed once at start of each new calendar month)
int    g_last_rebalance_month = 0;
bool   g_eligible[5];
double g_inv_vol[5];
int    g_eligible_count       = 0;

// Per-month equity tracking for portfolio stop
double g_month_start_equity = 0.0;
int    g_month_key          = 0;
bool   g_portfolio_stop     = false;

int CurrentMonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

// Compute N-day price return from CopyRates array (rates[0]=shift-1, rates[N-1]=oldest)
double ComputeReturn(const MqlRates &rates[], const int lookback)
  {
   if(ArraySize(rates) < lookback + 1)
      return 0.0;
   const double recent = rates[0].close;
   const double past   = rates[lookback - 1].close;
   if(recent <= 0.0 || past <= 0.0)
      return 0.0;
   return (recent / past) - 1.0;
  }

// Compute N-day realized volatility (daily stddev of log returns)
double ComputeRealizedVol(const MqlRates &rates[], const int lookback)
  {
   if(ArraySize(rates) < lookback + 1)
      return 0.0;
   double sum   = 0.0;
   double sumsq = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double c0 = rates[i].close;
      const double c1 = rates[i + 1].close;
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double r = MathLog(c0 / c1);
      sum   += r;
      sumsq += r * r;
     }
   if(lookback < 2)
      return 0.0;
   const double mean     = sum / lookback;
   const double variance = (sumsq / lookback) - (mean * mean);
   return (variance > 0.0) ? MathSqrt(variance) : 0.0;
  }

// Refresh eligibility + inverse-vol cache for all basket symbols.
// Called once per new calendar month (after QM_IsNewBar D1 gate).
void StrategyRefreshEligibilityCache()
  {
   const int bars_needed = strategy_momentum_days + 2;
   g_eligible_count = 0;
   for(int i = 0; i < 5; ++i)
     {
      g_eligible[i] = false;
      g_inv_vol[i]  = 0.0;

      const string sym = g_basket[i];
      if(sym == "")
         continue;

      MqlRates rates[];
      // CopyRates called once per month per symbol — bounded compute, results cached below
      const int copied = CopyRates(sym, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: called once per month after QM_IsNewBar gate, cached in g_eligible/g_inv_vol
      if(copied < strategy_vol_lookback_days + 1)
         continue;

      const double vol = ComputeRealizedVol(rates, strategy_vol_lookback_days);
      if(vol <= 0.0)
         continue;

      const int mom_lb = (sym == "XAUUSD.DWX") ? strategy_gold_momentum_days : strategy_momentum_days;
      if(copied < mom_lb + 1)
         continue;
      if(ComputeReturn(rates, mom_lb) <= 0.0)
         continue;

      g_eligible[i] = true;
      g_inv_vol[i]  = 1.0 / vol;
      ++g_eligible_count;
     }
  }

int CurrentSlot()
  {
   for(int i = 0; i < 5; ++i)
      if(_Symbol == g_basket[i])
         return i;
   return -1;
  }

bool CurrentSymbolPassesWeightCap()
  {
   if(g_eligible_count < strategy_min_eligible)
      return false;
   const int slot = CurrentSlot();
   if(slot < 0 || !g_eligible[slot])
      return false;
   double total = 0.0;
   for(int i = 0; i < 5; ++i)
      if(g_eligible[i])
         total += g_inv_vol[i];
   if(total <= 0.0)
      return false;
   const double raw_weight = g_inv_vol[slot] / total;
   return (MathMin(raw_weight, strategy_max_symbol_weight) > 0.0);
  }

void UpdatePortfolioStop()
  {
   const int key = CurrentMonthKey();
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(key != g_month_key || g_month_start_equity <= 0.0)
     {
      g_month_key          = key;
      g_month_start_equity = equity;
      g_portfolio_stop     = false;
     }
   if(strategy_portfolio_stop_pct <= 0.0 || g_month_start_equity <= 0.0)
      return;
   const double dd_pct = 100.0 * (g_month_start_equity - equity) / g_month_start_equity;
   if(dd_pct >= strategy_portfolio_stop_pct)
      g_portfolio_stop = true;
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
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

// No Trade Filter — block if symbol not in basket, optional spread gate.
bool Strategy_NoTradeFilter()
  {
   if(CurrentSlot() < 0)
      return true;
   if(strategy_max_spread_points > 0.0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > (int)strategy_max_spread_points)
         return true;
     }
   return false;
  }

// Trade Entry — long only on first D1 bar of new month, inverse-vol basket.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "RW_RISK_PREMIA_MONTHLY_LONG";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_portfolio_stop)
      return false;
   if(HasOpenPosition())
      return false;
   if(!CurrentSymbolPassesWeightCap())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management — update portfolio drawdown stop each tick.
void Strategy_ManageOpenPosition()
  {
   UpdatePortfolioStop();
  }

// Trade Close — exit if symbol dropped from eligible basket at monthly rebalance.
bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition())
      return false;
   if(g_eligible_count < strategy_min_eligible)
      return true;
   const int slot = CurrentSlot();
   if(slot < 0)
      return true;
   return !g_eligible[slot];
  }

// News Filter Hook — defer to framework two-axis news implementation.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — modified OnTick gates on D1 new-bar + calendar month
// change because PERIOD_MN1 generates 0 bars in the MT5 tester.
// -----------------------------------------------------------------------------

int OnInit()
  {
   g_basket[0] = "SP500.DWX";
   g_basket[1] = "NDX.DWX";
   g_basket[2] = "WS30.DWX";
   g_basket[3] = "XAUUSD.DWX";
   g_basket[4] = "XTIUSD.DWX";

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

   QM_SymbolGuardInit(g_basket);
   QM_BasketWarmupHistory(g_basket, PERIOD_D1, strategy_momentum_days + 10);

   UpdatePortfolioStop();
   StrategyRefreshEligibilityCache();
   g_last_rebalance_month = CurrentMonthKey();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10028\",\"ea\":\"QM5_10028_rw-risk-premia\"}");
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

   // D1 new-bar gate — monthly strategy acts once per closed D1 bar.
   // PERIOD_MN1 generates 0 bars in MT5 tester; month boundary is detected
   // via calendar month-key comparison on D1 bars instead.
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   // Refresh eligibility cache on first D1 bar of each new calendar month
   const int month_key = CurrentMonthKey();
   if(month_key != g_last_rebalance_month)
     {
      g_last_rebalance_month = month_key;
      StrategyRefreshEligibilityCache();
     }

   // Monthly exit check
   if(Strategy_ExitSignal())
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Monthly entry check
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
