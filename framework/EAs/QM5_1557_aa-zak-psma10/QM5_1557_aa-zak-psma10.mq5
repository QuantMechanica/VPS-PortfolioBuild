#property strict
#property version   "5.0"
#property description "QM5_1557 Alpha Architect Zakamulin price minus SMA(10) monthly timing"

// Long/cash monthly trend timing from Valeriy Zakamulin's Alpha Architect
// exposition of the price-minus-moving-average rule. DWX custom symbols do
// not reliably expose native MN1 bars in the tester, so the ten completed
// monthly closes are reconstructed from closed D1 bars at the month rollover.
// Mechanical, deterministic, no ML, no grid, no martingale.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1557;
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
input int    strategy_sma_period_months    = 10;
input int    strategy_min_completed_months = 11;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 3.0;

bool   g_month_rollover = false;
bool   g_month_signal_ready = false;
double g_last_completed_month_close = 0.0;
double g_last_completed_month_sma = 0.0;

// Locked-card guard. Framework-owned stochastic, news and Friday inputs are
// deliberately not pinned; stress remains independently variable in [0,1].
bool Strategy_InputsValid()
  {
   if(qm_ea_id != 1557)
      return false;
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset > 12)
      return false;
   if(RISK_FIXED <= 0.0 || RISK_PERCENT != 0.0)
      return false;
   if(strategy_sma_period_months != 10 ||
      strategy_min_completed_months != 11 ||
      strategy_atr_period_d1 != 20 ||
      strategy_atr_sl_mult != 3.0)
      return false;
   if(!MathIsValidNumber(qm_stress_reject_probability) ||
      qm_stress_reject_probability < 0.0 ||
      qm_stress_reject_probability > 1.0)
      return false;
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

// Reconstruct the most recent completed calendar-month closes from D1 bars.
// Called only once at a D1 month rollover. Array-size checks immediately
// precede every dynamic-array read/write used by the monthly aggregation.
bool Strategy_CompletedMonthlyCloses(double &month_closes[])
  {
   const int requested_months = strategy_min_completed_months;
   if(requested_months <= 0 || ArrayResize(month_closes, requested_months) != requested_months)
      return false;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 420, rates); // perf-allowed: one bounded closed-D1 history scan per calendar month rollover.
   const int rates_count = ArraySize(rates);
   if(copied <= 0 || rates_count != copied)
      return false;
   ArraySetAsSeries(rates, true);

   int month_count = 0;
   int previous_month_key = 0;
   for(int i = 0; i < rates_count && month_count < requested_months; ++i)
     {
      if(i < 0 || i >= ArraySize(rates))
         return false;
      MqlDateTime parts;
      if(!TimeToStruct(rates[i].time, parts))
         return false;
      const int month_key = parts.year * 100 + parts.mon;
      if(month_key <= 0 || month_key == previous_month_key)
         continue;
      if(month_count < 0 || month_count >= ArraySize(month_closes))
         return false;
      month_closes[month_count] = rates[i].close;
      if(month_closes[month_count] <= 0.0)
         return false;
      previous_month_key = month_key;
      month_count++;
     }
   return (month_count >= requested_months);
  }

// Refresh only on the first D1 bar of a new calendar month. The newest
// closed D1 bar is then the prior month-end close.
bool Strategy_RefreshMonthlySignal()
  {
   g_month_rollover = false;
   g_month_signal_ready = false;
   g_last_completed_month_close = 0.0;
   g_last_completed_month_sma = 0.0;

   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int previous_bar_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month <= 0 || previous_bar_month <= 0 || current_month == previous_bar_month)
      return true;
   g_month_rollover = true;

   double month_closes[];
   if(!Strategy_CompletedMonthlyCloses(month_closes))
      return false;
   if(ArraySize(month_closes) < strategy_min_completed_months ||
      ArraySize(month_closes) < strategy_sma_period_months)
      return false;

   double sum = 0.0;
   for(int i = 0; i < strategy_sma_period_months; ++i)
     {
      if(i < 0 || i >= ArraySize(month_closes))
         return false;
      sum += month_closes[i];
     }
   if(month_closes[0] <= 0.0 || sum <= 0.0)
      return false;

   g_last_completed_month_close = month_closes[0];
   g_last_completed_month_sma = sum / (double)strategy_sma_period_months;
   g_month_signal_ready = (g_last_completed_month_sma > 0.0);
   return g_month_signal_ready;
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_WeekendEntryBlocked()
  {
   MqlDateTime broker_parts;
   if(!TimeToStruct(TimeCurrent(), broker_parts))
      return true;
   // Card rule: no new entry during the final two trading hours before the
   // standard 21:00 broker-time weekend cutoff. Monthly positions are held.
   return (broker_parts.day_of_week == 5 && broker_parts.hour >= 19);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1557_MONTH_CLOSE_ABOVE_SMA10";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   if(!g_month_rollover || !g_month_signal_ready || Strategy_HasOpenPosition())
      return false;
   if(g_last_completed_month_close <= g_last_completed_month_sma)
      return false;
   if(Strategy_WeekendEntryBlocked())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry,
                       strategy_atr_period_d1, strategy_atr_sl_mult);
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Fixed initial ATR stop and monthly signal exit; no trailing or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   return (Strategy_HasOpenPosition() &&
           g_month_rollover &&
           g_month_signal_ready &&
           g_last_completed_month_close <= g_last_completed_month_sma);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_DISABLED,
                                             "CARD_MONTHLY_LONG_CASH_HOLD"))
      return INIT_FAILED;

   string warmup_symbols[1] = {_Symbol};
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols, PERIOD_D1, 420);
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_1557\",\"ea\":\"aa-zak-psma10\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   Strategy_ManageOpenPosition();
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;
   QM_EquityStreamOnNewBar();
   if(!Strategy_RefreshMonthlySignal())
      return;
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(Strategy_NoTradeFilter() || Strategy_NewsFilterHook(TimeCurrent()))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, TimeCurrent(),
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
