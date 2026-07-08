#property strict
#property version   "5.0"
#property description "QM5_1615 Alpha Architect 2/12-month breaktrend momentum blend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1615_aa-breaktrend-2-12
// Card: Alpha Architect Breaking-Bad-Trends 2-12 Momentum Blend
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1615;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_months          = 2;
input int    strategy_slow_months          = 12;
input int    strategy_trading_days_per_month = 21;
input int    strategy_min_completed_months = 15;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_median_mult   = 2.5;

int  g_last_rebalance_key = 0;
int  g_target_direction   = 0;
bool g_rebalance_due      = false;

int MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

int SignReturn(const double value)
  {
   if(value > 0.0)
      return 1;
   if(value < 0.0)
      return -1;
   return 0;
  }

int CurrentPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         return 1;
      if(pos_type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

bool ComputeMonthlyTarget(int &target, double &slow_return, double &fast_return)
  {
   target = 0;
   slow_return = 0.0;
   fast_return = 0.0;

   const int days_per_month = MaxInt(1, strategy_trading_days_per_month);
   const int fast_shift = MaxInt(1, strategy_fast_months * days_per_month);
   const int slow_shift = MaxInt(fast_shift + 1, strategy_slow_months * days_per_month);
   const int min_shift = MaxInt(slow_shift, strategy_min_completed_months * days_per_month);

   // perf-allowed: fixed D1 closed-bar reads execute only once per monthly rebalance.
   const double min_history_close = iClose(_Symbol, PERIOD_D1, min_shift); // perf-allowed
   const double recent_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double fast_base = iClose(_Symbol, PERIOD_D1, fast_shift + 1); // perf-allowed
   const double slow_base = iClose(_Symbol, PERIOD_D1, slow_shift + 1); // perf-allowed

   if(min_history_close <= 0.0 || recent_close <= 0.0 || fast_base <= 0.0 || slow_base <= 0.0)
      return false;

   fast_return = (recent_close / fast_base) - 1.0;
   slow_return = (recent_close / slow_base) - 1.0;

   const int fast_sign = SignReturn(fast_return);
   const int slow_sign = SignReturn(slow_return);
   if(fast_sign == 0 || slow_sign == 0)
     {
      target = 0;
      return true;
     }

   target = (fast_sign < 0 && slow_sign < 0) ? -1 : 1;
   return true;
  }

void RefreshMonthlyTarget()
  {
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0 || month_key == g_last_rebalance_key)
      return;

   int target = 0;
   double slow_ret = 0.0;
   double fast_ret = 0.0;
   if(!ComputeMonthlyTarget(target, slow_ret, fast_ret))
     {
      g_last_rebalance_key = month_key;
      g_target_direction = 0;
      g_rebalance_due = false;
      return;
     }

   g_last_rebalance_key = month_key;
   g_target_direction = target;
   g_rebalance_due = true;
  }

double MedianSpreadPrice()
  {
   const int lookback = MaxInt(1, strategy_spread_median_days);
   int spreads[];
   ArrayResize(spreads, lookback);
   const int copied = CopySpread(_Symbol, PERIOD_D1, 1, lookback, spreads); // perf-allowed
   if(copied <= 0)
      return 0.0;

   int positive[];
   ArrayResize(positive, copied);
   int positive_count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(spreads[i] <= 0)
         continue;
      positive[positive_count] = spreads[i];
      positive_count++;
     }

   if(positive_count <= 0)
      return 0.0;

   ArrayResize(positive, positive_count);
   ArraySort(positive);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   if((positive_count % 2) == 1)
      return (double)positive[positive_count / 2] * point;

   const int upper = positive_count / 2;
   const int lower = upper - 1;
   return ((double)positive[lower] + (double)positive[upper]) * 0.5 * point;
  }

bool CurrentSpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask < bid)
      return true;

   const double current_spread = ask - bid;
   if(!(current_spread > 0.0))
      return false;

   const double median_spread = MedianSpreadPrice();
   if(median_spread <= 0.0)
      return false;

   return current_spread > (strategy_spread_median_mult * median_spread);
  }

bool Strategy_NoTradeFilter()
  {
   RefreshMonthlyTarget();
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_rebalance_due)
      return false;

   if(g_target_direction == 0)
     {
      g_rebalance_due = false;
      return false;
     }

   const int current_direction = CurrentPositionDirection();
   if(current_direction == g_target_direction)
     {
      g_rebalance_due = false;
      return false;
     }
   if(current_direction != 0)
      return false;

   if(CurrentSpreadTooWide())
     {
      g_rebalance_due = false;
      return false;
     }

   const QM_OrderType side = (g_target_direction > 0) ? QM_BUY : QM_SELL;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double entry_price = (side == QM_BUY) ? ask : bid;
   const double stop_price = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(stop_price <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop_price;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "breaktrend_monthly_long" : "breaktrend_monthly_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_rebalance_due = false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Initial ATR stop plus monthly target flip is the full card-defined management.
  }

bool Strategy_ExitSignal()
  {
   if(!g_rebalance_due)
      return false;

   const int current_direction = CurrentPositionDirection();
   if(current_direction == 0)
      return false;
   if(g_target_direction == 0)
      return true;

   return current_direction != g_target_direction;
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
