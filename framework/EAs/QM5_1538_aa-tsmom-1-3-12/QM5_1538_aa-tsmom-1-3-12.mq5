#property strict
#property version   "5.0"
#property description "QM5_1538 Alpha Architect 1/3/12 Time-Series Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1538
// Alpha Architect Multi-Horizon 1/3/12 Time-Series Momentum (D1)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1538_aa-tsmom-1-3-12.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1538;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf                 = PERIOD_D1;
input int             strategy_atr_period         = 20;
input int             strategy_lookback_1_days    = 21;
input int             strategy_lookback_3_days    = 63;
input int             strategy_lookback_12_days   = 252;
input int             strategy_min_history_bars   = 260;
input double          strategy_stop_atr            = 3.0;

int g_monthly_signal = 0;
int g_monthly_signal_key = 0;
int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
{
   if(_Period != strategy_tf || strategy_tf != PERIOD_D1)
      return true;
   if(strategy_atr_period <= 0 || strategy_stop_atr <= 0.0)
      return true;
   if(strategy_lookback_1_days <= 0 ||
      strategy_lookback_3_days <= strategy_lookback_1_days ||
      strategy_lookback_12_days <= strategy_lookback_3_days)
      return true;
   if(strategy_min_history_bars < strategy_lookback_12_days + 1)
      return true;
   return false;
}

bool Strategy_SelectOurPosition(ulong &ticket)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ticket = candidate;
      return true;
   }
   return false;
}

int Strategy_ReturnSign(const double newest_close, const double old_close)
{
   if(newest_close <= 0.0 || old_close <= 0.0) return 0;
   const double value = newest_close / old_close - 1.0;
   if(value > 0.0) return 1;
   if(value < 0.0) return -1;
   return 0;
}

bool Strategy_PrepareMonthlySignal(int &month_key)
{
   month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0)
      return false;
   if(g_monthly_signal_key == month_key)
      return true;

   int largest_lookback = strategy_lookback_1_days;
   if(strategy_lookback_3_days > largest_lookback) largest_lookback = strategy_lookback_3_days;
   if(strategy_lookback_12_days > largest_lookback) largest_lookback = strategy_lookback_12_days;
   int history_shift = strategy_min_history_bars;
   if(largest_lookback + 1 > history_shift) history_shift = largest_lookback + 1;

   // SMA(1) is the exact closed price while keeping all series reads inside
   // the framework's pooled indicator layer.
   const double history_guard = QM_SMA(_Symbol, strategy_tf, 1, history_shift);
   const double latest = QM_SMA(_Symbol, strategy_tf, 1, 1);
   const double close_1m = QM_SMA(_Symbol, strategy_tf, 1, 1 + strategy_lookback_1_days);
   const double close_3m = QM_SMA(_Symbol, strategy_tf, 1, 1 + strategy_lookback_3_days);
   const double close_12m = QM_SMA(_Symbol, strategy_tf, 1, 1 + strategy_lookback_12_days);
   if(history_guard <= 0.0 || latest <= 0.0 || close_1m <= 0.0 ||
      close_3m <= 0.0 || close_12m <= 0.0)
      return false;

   g_monthly_signal =
      Strategy_ReturnSign(latest, close_1m) +
      Strategy_ReturnSign(latest, close_3m) +
      Strategy_ReturnSign(latest, close_12m);
   g_monthly_signal_key = month_key;
   return true;
}

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   int month_key = 0;
   if(!Strategy_PrepareMonthlySignal(month_key)) return false;
   if(g_last_entry_rebalance_key == month_key) return false;
   g_last_entry_rebalance_key = month_key;

   ulong existing = 0;
   if(Strategy_SelectOurPosition(existing)) return false;
   if(g_monthly_signal < 2 && g_monthly_signal > -2) return false;

   if(g_monthly_signal >= 2)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      req.type = QM_BUY;
      req.price = QM_StopRulesNormalizePrice(_Symbol, ask);
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_stop_atr);
      req.reason = "AA_TSMOM_132_LONG";
      return (req.sl > 0.0 && req.sl < req.price);
   }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0) return false;
   req.type = QM_SELL;
   req.price = QM_StopRulesNormalizePrice(_Symbol, bid);
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_stop_atr);
   req.reason = "AA_TSMOM_132_SHORT";
   return (req.sl > req.price);
}

// Trade Management
void Strategy_ManageOpenPosition() {}

// Trade Close
bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket)) return false;

   int month_key = 0;
   if(!Strategy_PrepareMonthlySignal(month_key)) return false;
   if(g_last_exit_rebalance_key == month_key) return false;
   g_last_exit_rebalance_key = month_key;

   const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(type == POSITION_TYPE_BUY) return (g_monthly_signal < 2);
   if(type == POSITION_TYPE_SELL) return (g_monthly_signal > -2);
   return true;
}

// News Filter Hook (callable for Q09 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "CARD_HAS_NO_FRIDAY_RULE_FRAMEWORK_SAFETY_OVERRIDE"))
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
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   // News blocks entries only; monthly exits and risk management remain live.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(!QM_TM_OpenPosition(req, out_ticket))
         PrintFormat("QM5_%d: monthly entry rejected for signal %d", qm_ea_id, g_monthly_signal);
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
