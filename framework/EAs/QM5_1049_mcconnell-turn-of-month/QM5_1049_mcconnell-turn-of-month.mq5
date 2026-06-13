#property strict
#property version   "5.0"
#property description "QM5_1049 McConnell-Xu Turn-of-the-Month Equity Index"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy card: QM5_1049 mcconnell-turn-of-month, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1049;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 3.0;
input int    strategy_exit_trading_day    = 3;
input bool   strategy_regime_filter       = false;
input int    strategy_regime_sma_period   = 200;
input int    strategy_max_spread_points   = 0;
input bool   strategy_require_d1          = true;

#define STRATEGY_UNIVERSE_SIZE 4

string g_strategy_symbols[STRATEGY_UNIVERSE_SIZE] = {"NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"};
int    g_strategy_slots[STRATEGY_UNIVERSE_SIZE]   = {0, 1, 2, 3};

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_require_d1 && _Period != PERIOD_D1)
      return true;

   bool symbol_allowed = false;
   int expected_slot = -1;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      if(g_strategy_symbols[i] == _Symbol)
        {
         symbol_allowed = true;
         expected_slot = g_strategy_slots[i];
         break;
        }
     }

   if(!symbol_allowed)
      return true;
   if(expected_slot != qm_magic_slot_offset)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
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
   req.reason = "QM5_1049_TOM_T_MINUS_1_TO_T_PLUS_3";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_require_d1 && _Period != PERIOD_D1)
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   datetime d1_times[];
   ArraySetAsSeries(d1_times, true);
   if(CopyTime(_Symbol, PERIOD_D1, 0, 2, d1_times) != 2) // perf-allowed: two D1 timestamps inside framework new-bar gate.
      return false;

   MqlDateTime current_dt;
   MqlDateTime prior_dt;
   TimeToStruct(d1_times[0], current_dt);
   TimeToStruct(d1_times[1], prior_dt);

   if(current_dt.year == prior_dt.year && current_dt.mon == prior_dt.mon)
      return false;

   if(strategy_regime_filter)
     {
      const int p = MathMax(2, strategy_regime_sma_period);
      const double sma_recent = QM_SMA(_Symbol, PERIOD_D1, p, 1);
      const double sma_prior = QM_SMA(_Symbol, PERIOD_D1, p, 2);
      if(sma_recent <= 0.0 || sma_prior <= 0.0 || sma_recent < sma_prior)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0 || sl >= ask)
      return false;

   req.price = ask;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = 0.0;
   return ((ask - req.sl) / point > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Baseline card has no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(strategy_require_d1 && _Period != PERIOD_D1)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   datetime d1_times[];
   ArraySetAsSeries(d1_times, true);
   const int copied = CopyTime(_Symbol, PERIOD_D1, 0, 12, d1_times); // perf-allowed: bounded D1 session count while a monthly position is open.
   if(copied < 2)
      return false;

   MqlDateTime current_dt;
   TimeToStruct(d1_times[0], current_dt);

   int ordinal = 0;
   for(int i = 0; i < copied; ++i)
     {
      MqlDateTime bar_dt;
      TimeToStruct(d1_times[i], bar_dt);
      if(bar_dt.year != current_dt.year || bar_dt.mon != current_dt.mon)
         break;
      ordinal++;
     }

   const int exit_day = MathMax(1, strategy_exit_trading_day);
   return (ordinal > exit_day);
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1049\",\"ea\":\"mcconnell-turn-of-month\"}");
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
