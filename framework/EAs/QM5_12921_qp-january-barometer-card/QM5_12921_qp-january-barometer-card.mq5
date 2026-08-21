#property strict
#property version   "5.0"
#property description "QM5_12921 Quantpedia January Barometer SP500"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12921
// Strategy card: QM5_12921 qp-january-barometer-card, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12921;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period         = 20;
input double strategy_atr_stop_mult      = 3.0;
input bool   strategy_require_d1         = true;

int    g_strategy_last_day_key           = 0;
int    g_strategy_last_month_key         = 0;
int    g_strategy_current_year           = 0;
double g_strategy_jan_open               = 0.0;
double g_strategy_jan_close              = 0.0;
bool   g_strategy_entry_due              = false;

void Strategy_AdvanceCalendarState()
  {
   const int day_key = QM_CalendarPeriodKey(PERIOD_D1);
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(day_key == 0 || month_key == 0)
      return;

   if(day_key == g_strategy_last_day_key)
      return;

   const int current_month = month_key % 100;
   const int current_year = month_key / 100;
   const int prior_month = (g_strategy_last_month_key > 0) ? (g_strategy_last_month_key % 100) : 0;

   if(current_month == 1)
     {
      if(prior_month != 1 || g_strategy_current_year != current_year)
        {
         g_strategy_current_year = current_year;
         g_strategy_jan_open = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_OPEN);
        }
      g_strategy_jan_close = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
     }
   else if(current_month == 2 && prior_month == 1)
     {
      if(g_strategy_jan_open > 0.0 && g_strategy_jan_close > 0.0)
        {
         const double jan_return = (g_strategy_jan_close - g_strategy_jan_open) / g_strategy_jan_open;
         if(jan_return > 0.0)
            g_strategy_entry_due = true;
        }
     }

   g_strategy_last_day_key = day_key;
   g_strategy_last_month_key = month_key;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_require_d1 && _Period != PERIOD_D1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "JANUARY_BAROMETER_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_strategy_entry_due)
      return false;
   g_strategy_entry_due = false;

   if(strategy_require_d1 && _Period != PERIOD_D1)
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double stop = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
   if(stop <= 0.0 || stop >= ask)
      return false;

   req.price = ask;
   req.sl = NormalizeDouble(stop, _Digits);
   req.tp = 0.0;
   return ((ask - req.sl) / point > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // No intra-trade trailing or partial management in baseline card.
  }

bool Strategy_ExitSignal()
  {
   if(strategy_require_d1 && _Period != PERIOD_D1)
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1);
   if(month_key == 0)
      return false;
   const int current_month = month_key % 100;

   if(current_month == 1)
      return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);

   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12921\",\"ea\":\"qp-january-barometer-card\"}");
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   Strategy_AdvanceCalendarState();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
