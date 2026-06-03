#property strict
#property version   "5.0_v2"
#property description "QM5_10028 Robot Wealth Risk Premia Harvesting (v2: basket-aware)"

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
input int    strategy_vol_lookback_days     = 63;
input int    strategy_momentum_days         = 126;
input int    strategy_gold_momentum_days    = 63;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 4.0;
input int    strategy_min_eligible          = 2;
input double strategy_max_symbol_weight     = 0.35;
input double strategy_portfolio_stop_pct    = 8.0;
input double strategy_max_spread_points     = 0.0;

double g_month_start_equity = 0.0;
int    g_month_key          = 0;
bool   g_portfolio_stop     = false;

// FW7: basket symbols for Symbol Guard and Warmup
string g_basket_symbols[] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "XAUUSD.DWX", "XTIUSD.DWX"};

string StrategySymbolBySlot(const int slot)
  {
   if(slot < 0 || slot >= ArraySize(g_basket_symbols))
      return "";
   return g_basket_symbols[slot];
  }

bool StrategySymbolInBasket(const string symbol)
  {
   for(int i = 0; i < ArraySize(g_basket_symbols); ++i)
      if(symbol == g_basket_symbols[i])
         return true;
   return false;
  }

int StrategyCurrentMonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

void StrategyUpdatePortfolioStop()
  {
   const int key = StrategyCurrentMonthKey();
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(key != g_month_key || g_month_start_equity <= 0.0)
     {
      g_month_key = key;
      g_month_start_equity = equity;
      g_portfolio_stop = false;
     }

   if(strategy_portfolio_stop_pct <= 0.0 || g_month_start_equity <= 0.0)
      return;

   const double dd_pct = 100.0 * (g_month_start_equity - equity) / g_month_start_equity;
   if(dd_pct >= strategy_portfolio_stop_pct)
      g_portfolio_stop = true;
  }

double StrategyReturn(const string symbol, const int lookback_days)
  {
   if(lookback_days <= 0)
      return 0.0;
   
   // FW7: Assert symbol is allowed before accessing data
   if(!QM_SymbolAssertOrLog(symbol))
      return 0.0;

   if(Bars(symbol, PERIOD_D1) < lookback_days + 2)
      return 0.0;

   const double recent = iClose(symbol, PERIOD_D1, 1);
   const double past = iClose(symbol, PERIOD_D1, 1 + lookback_days);
   if(recent <= 0.0 || past <= 0.0)
      return 0.0;
   return (recent / past) - 1.0;
  }

double StrategyRealizedVol(const string symbol, const int lookback_days)
  {
   if(lookback_days < 2)
      return 0.0;

   // FW7: Assert symbol is allowed before accessing data
   if(!QM_SymbolAssertOrLog(symbol))
      return 0.0;

   double sum = 0.0;
   double sumsq = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= lookback_days; ++shift)
     {
      const double close_now = iClose(symbol, PERIOD_D1, shift);
      const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return 0.0;

      const double r = MathLog(close_now / close_prev);
      sum += r;
      sumsq += r * r;
      samples++;
     }

   if(samples < 2)
      return 0.0;
   const double mean = sum / samples;
   const double variance = (sumsq / samples) - (mean * mean);
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

bool StrategySymbolEligible(const string symbol, double &out_inv_vol)
  {
   out_inv_vol = 0.0;
   if(!StrategySymbolInBasket(symbol))
      return false;
   
   // SymbolSelect is already handled by QM_BasketWarmupHistory in OnInit,
   // but we keep it here for safety and live-switching.
   if(!SymbolSelect(symbol, true))
      return false;

   const double vol = StrategyRealizedVol(symbol, strategy_vol_lookback_days);
   if(vol <= 0.0)
      return false;

   const bool positive_momentum = (symbol == "XAUUSD.DWX")
      ? (StrategyReturn(symbol, strategy_gold_momentum_days) > 0.0)
      : (StrategyReturn(symbol, strategy_momentum_days) > 0.0);
   if(!positive_momentum)
      return false;

   out_inv_vol = 1.0 / vol;
   return true;
  }

int StrategyEligibleSet(bool &eligible[], double &inv_vol[])
  {
   ArrayResize(eligible, 5);
   ArrayResize(inv_vol, 5);

   int count = 0;
   for(int i = 0; i < 5; ++i)
     {
      eligible[i] = false;
      inv_vol[i] = 0.0;

      double score = 0.0;
      if(StrategySymbolEligible(StrategySymbolBySlot(i), score))
        {
         eligible[i] = true;
         inv_vol[i] = score;
         count++;
        }
     }
   return count;
  }

int StrategyCurrentSlot()
  {
   for(int i = 0; i < 5; ++i)
      if(_Symbol == StrategySymbolBySlot(i))
         return i;
   return -1;
  }

bool StrategyCurrentSymbolPassesWeightCap()
  {
   bool eligible[];
   double inv_vol[];
   if(StrategyEligibleSet(eligible, inv_vol) < strategy_min_eligible)
      return false;

   const int current_slot = StrategyCurrentSlot();
   if(current_slot < 0 || !eligible[current_slot])
      return false;

   double total = 0.0;
   for(int i = 0; i < 5; ++i)
      if(eligible[i])
         total += inv_vol[i];
   if(total <= 0.0)
      return false;

   const double raw_weight = inv_vol[current_slot] / total;
   return (MathMin(raw_weight, strategy_max_symbol_weight) > 0.0);
  }

bool StrategyHasOpenPosition()
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

// No Trade Filter: symbol and optional spread gate. Framework handles time,
// news, kill-switch, and Friday close before this hook.
bool Strategy_NoTradeFilter()
  {
   if(!StrategySymbolInBasket(_Symbol))
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(point <= 0.0 || spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry: first D1 bar of a new month, long-only, positive-momentum
// eligible symbols, inverse-vol basket membership, 4 ATR catastrophic SL.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "RW_RISK_PREMIA_MONTHLY_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_portfolio_stop)
      return false;
   if(StrategyHasOpenPosition())
      return false;
   if(!StrategyCurrentSymbolPassesWeightCap())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management: card specifies no trailing, break-even, partial close, or
// pyramiding. Portfolio stop only blocks new entries until the next month.
void Strategy_ManageOpenPosition()
  {
   StrategyUpdatePortfolioStop();
  }

// Trade Close: monthly rebalance exits symbols that lose eligibility, and exits
// all symbols when fewer than two risk-premia proxies are eligible.
bool Strategy_ExitSignal()
  {
   if(!StrategyHasOpenPosition())
      return false;

   bool eligible[];
   double inv_vol[];
   if(StrategyEligibleSet(eligible, inv_vol) < strategy_min_eligible)
      return true;

   const int current_slot = StrategyCurrentSlot();
   if(current_slot < 0)
      return true;

   return !eligible[current_slot];
  }

// News Filter Hook: defer to framework P8-compatible news implementation.
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

   // FW7: Initialize Symbol Guard for basket symbols
   QM_SymbolGuardInit(g_basket_symbols);
   // FW7/FW9: Pre-load history for basket symbols to prevent tester hangs/sync issues
   QM_BasketWarmupHistory(g_basket_symbols, PERIOD_D1, 300);

   StrategyUpdatePortfolioStop();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10028\",\"ea\":\"QM5_10028_rw-risk-premia_v2\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_MN1))
      return;

   QM_EquityStreamOnNewBar();

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
