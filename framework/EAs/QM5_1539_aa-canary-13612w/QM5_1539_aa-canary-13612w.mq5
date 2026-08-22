#property strict
#property version   "5.0"
#property description "QM5_1539 Alpha Architect Canary 13612W Breadth Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1539
// Alpha Architect Canary 13612W Breadth Momentum (D1)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1539_aa-canary-13612w.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1539;
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
input ENUM_TIMEFRAMES strategy_tf                       = PERIOD_D1;
input string          strategy_canary_risk_1_symbol    = "NDX.DWX";
input string          strategy_canary_risk_2_symbol    = "GDAXI.DWX";
input string          strategy_canary_stress_1_symbol  = "USDJPY.DWX";
input string          strategy_canary_stress_2_symbol  = "XAUUSD.DWX";
input string          strategy_risk_1_symbol           = "SP500.DWX";
input string          strategy_risk_2_symbol           = "NDX.DWX";
input string          strategy_risk_3_symbol           = "WS30.DWX";
input string          strategy_risk_4_symbol           = "GDAXI.DWX";
input string          strategy_defensive_1_symbol      = "XAUUSD.DWX";
input string          strategy_defensive_2_symbol      = "EURUSD.DWX";
input string          strategy_defensive_3_symbol      = "USDJPY.DWX";
input int             strategy_bad_canary_threshold    = 1;
input int             strategy_lookback_1_days         = 21;
input int             strategy_lookback_3_days         = 63;
input int             strategy_lookback_6_days         = 126;
input int             strategy_lookback_12_days        = 252;
input int             strategy_min_history_bars        = 260;
input int             strategy_atr_period              = 20;
input double          strategy_stop_atr                = 3.0;

int    g_h_atr_d1 = INVALID_HANDLE;
bool   g_selection_valid = false;
bool   g_risk_on = false;
int    g_bad_canary_count = 0;
string g_selected_symbol = "";

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

string Strategy_CanarySymbol(const int index)
{
   if(index == 0) return strategy_canary_risk_1_symbol;
   if(index == 1) return strategy_canary_risk_2_symbol;
   if(index == 2) return strategy_canary_stress_1_symbol;
   if(index == 3) return strategy_canary_stress_2_symbol;
   return "";
}

string Strategy_CandidateSymbol(const bool risk_on, const int index)
{
   if(risk_on)
   {
      if(index == 0) return strategy_risk_1_symbol;
      if(index == 1) return strategy_risk_2_symbol;
      if(index == 2) return strategy_risk_3_symbol;
      if(index == 3) return strategy_risk_4_symbol;
      return "";
   }

   if(index == 0) return strategy_defensive_1_symbol;
   if(index == 1) return strategy_defensive_2_symbol;
   if(index == 2) return strategy_defensive_3_symbol;
   return "";
}

bool Strategy_SelectReferenceSymbols()
{
   for(int i = 0; i < 4; ++i)
   {
      const string canary = Strategy_CanarySymbol(i);
      if(canary == "" || !SymbolSelect(canary, true))
         return false;
   }

   for(int i = 0; i < 4; ++i)
   {
      const string risk_symbol = Strategy_CandidateSymbol(true, i);
      if(risk_symbol == "" || !SymbolSelect(risk_symbol, true))
         return false;
   }

   for(int i = 0; i < 3; ++i)
   {
      const string defensive_symbol = Strategy_CandidateSymbol(false, i);
      if(defensive_symbol == "" || !SymbolSelect(defensive_symbol, true))
         return false;
   }

   return true;
}

bool Strategy_Init()
{
   if(strategy_tf != PERIOD_D1 ||
      strategy_bad_canary_threshold < 1 || strategy_bad_canary_threshold > 4 ||
      strategy_lookback_1_days <= 0 ||
      strategy_lookback_3_days <= strategy_lookback_1_days ||
      strategy_lookback_6_days <= strategy_lookback_3_days ||
      strategy_lookback_12_days <= strategy_lookback_6_days ||
      strategy_min_history_bars <= strategy_lookback_12_days ||
      strategy_atr_period <= 0 || strategy_stop_atr <= 0.0)
      return false;

   if(!Strategy_SelectReferenceSymbols())
      return false;

   g_h_atr_d1 = iATR(_Symbol, strategy_tf, strategy_atr_period);
   if(g_h_atr_d1 == INVALID_HANDLE)
      return false;

   return true;
}

void Strategy_Shutdown()
{
   if(g_h_atr_d1 != INVALID_HANDLE)
   {
      IndicatorRelease(g_h_atr_d1);
      g_h_atr_d1 = INVALID_HANDLE;
   }
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

bool Strategy_IsMonthlyRebalance()
{
   MqlRates month_boundary[];
   ArraySetAsSeries(month_boundary, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, 2, month_boundary);
   if(copied < 2)
      return false;

   MqlDateTime current_bar = {};
   MqlDateTime prior_bar = {};
   if(!TimeToStruct(month_boundary[0].time, current_bar)) return false;
   if(!TimeToStruct(month_boundary[1].time, prior_bar)) return false;

   return (current_bar.year != prior_bar.year || current_bar.mon != prior_bar.mon);
}

bool Strategy_Momentum13612W(const string symbol, double &score)
{
   score = 0.0;
   int required = strategy_min_history_bars;
   if(strategy_lookback_12_days + 1 > required)
      required = strategy_lookback_12_days + 1;

   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   const int copied = CopyRates(symbol, strategy_tf, 1, required, daily);
   if(copied < required || ArraySize(daily) <= strategy_lookback_12_days)
      return false;

   const double latest = daily[0].close;
   const double close_1 = daily[strategy_lookback_1_days].close;
   const double close_3 = daily[strategy_lookback_3_days].close;
   const double close_6 = daily[strategy_lookback_6_days].close;
   const double close_12 = daily[strategy_lookback_12_days].close;
   if(latest <= 0.0 || close_1 <= 0.0 || close_3 <= 0.0 ||
      close_6 <= 0.0 || close_12 <= 0.0)
      return false;

   score = 12.0 * (latest / close_1 - 1.0)
         +  4.0 * (latest / close_3 - 1.0)
         +  2.0 * (latest / close_6 - 1.0)
         +        (latest / close_12 - 1.0);
   return true;
}

bool Strategy_PrepareMonthlySelection()
{
   g_selection_valid = false;
   g_selected_symbol = "";
   g_bad_canary_count = 0;
   g_risk_on = false;

   for(int i = 0; i < 4; ++i)
   {
      double canary_score = 0.0;
      if(!Strategy_Momentum13612W(Strategy_CanarySymbol(i), canary_score))
         return false;
      if(canary_score <= 0.0)
         g_bad_canary_count++;
   }

   g_risk_on = (g_bad_canary_count < strategy_bad_canary_threshold);
   const int candidate_count = g_risk_on ? 4 : 3;
   double best_positive_score = 0.0;

   for(int i = 0; i < candidate_count; ++i)
   {
      const string candidate = Strategy_CandidateSymbol(g_risk_on, i);
      double candidate_score = 0.0;
      if(!Strategy_Momentum13612W(candidate, candidate_score))
         return false;
      if(candidate_score > best_positive_score)
      {
         best_positive_score = candidate_score;
         g_selected_symbol = candidate;
      }
   }

   g_selection_valid = true;
   return true;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(!g_selection_valid || g_selected_symbol == "" || g_selected_symbol != _Symbol)
      return false;

   ulong existing = 0;
   if(Strategy_SelectOurPosition(existing))
      return false;

   double atr_value[1];
   const int atr_copied = CopyBuffer(g_h_atr_d1, 0, 1, 1, atr_value);
   if(atr_copied < 1)
      return false;
   if(atr_value[0] <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = QM_StopRulesNormalizePrice(_Symbol, ask);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - strategy_stop_atr * atr_value[0]);
   req.tp = 0.0;
   req.reason = g_risk_on ? "AA_CANARY_13612W_RISK" : "AA_CANARY_13612W_DEFENSIVE";
   req.symbol_slot = 0; // relative host slot already bound by framework init
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.sl < req.price);
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   if(!g_selection_valid || !Strategy_SelectOurPosition(ticket))
      return false;
   return (g_selected_symbol != _Symbol);
}

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

   if(!Strategy_Init())
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Strategy_Shutdown();
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   if(!Strategy_IsMonthlyRebalance()) return;
   if(!Strategy_PrepareMonthlySelection()) return;

   Strategy_ManageOpenPosition();

   ulong existing = 0;
   if(Strategy_SelectOurPosition(existing) && Strategy_ExitSignal())
   {
      if(!QM_TM_ClosePosition(existing, QM_EXIT_STRATEGY))
         return;
   }

   if(Strategy_SelectOurPosition(existing))
      return;

   QM_EntryRequest req = {};
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(!QM_TM_OpenPosition(req, out_ticket))
         PrintFormat("QM5_%d: monthly entry rejected for %s", qm_ea_id, g_selected_symbol);
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
