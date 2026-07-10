#property strict
#property version   "5.0"
#property description "QM5_13107 WTI July-December trading-time seasonal short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13107 - WTI July-to-December Trading-Time Seasonal Short
// -----------------------------------------------------------------------------
// Peer-reviewed structural energy seasonality translated to a continuous CFD:
//   - source WTI futures prices peak when traded in July and bottom in December
//   - first tradable D1 bar of each week from July through November: short
//   - framework Friday close creates non-overlapping weekly risk tranches
//   - ATR hard stop plus seven-day stale guard
// Runtime is Darwinex-native: MT5 calendar, OHLC, ATR, spread, framework state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 13107;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_start_month          = 7;
input int    strategy_end_month            = 11;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_max_hold_days         = 7;
input int    strategy_max_spread_points     = 1500;

int g_last_entry_week_key = 0;
int g_candidate_week_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_WeekKey(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.year * 100 + (parts.day_of_year / 7);
  }

bool Strategy_IsFirstTradingBarOfWeek()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 weekly calendar gate.
   const datetime previous_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: prior completed D1 calendar gate.
   if(current_bar <= 0 || previous_bar <= 0)
      return false;
   return Strategy_WeekKey(current_bar) != Strategy_WeekKey(previous_bar);
  }

bool Strategy_ValidWindow()
  {
   if(strategy_start_month < 1 || strategy_start_month > 12)
      return false;
   if(strategy_end_month < 1 || strategy_end_month > 12)
      return false;
   return strategy_start_month <= strategy_end_month;
  }

bool Strategy_InSeason(const datetime value)
  {
   if(value <= 0 || !Strategy_ValidWindow())
      return false;

   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.mon >= strategy_start_month && parts.mon <= strategy_end_month;
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

void Strategy_CloseInvalidOrStalePositions()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: new-D1 management calendar gate.
   if(current_bar <= 0)
      return;

   const bool in_season = Strategy_InSeason(current_bar);
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int max_hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const bool wrong_side = position_type != POSITION_TYPE_SELL;
      const bool stale = opened_at > 0 && now - opened_at >= max_hold_seconds;
      if(!in_season || wrong_side || stale)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(!Strategy_ValidWindow())
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0 || strategy_max_hold_days > 14)
      return true;
   if(strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13107_WTI_JULDEC_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_candidate_week_key = 0;

   if(!Strategy_IsFirstTradingBarOfWeek())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 seasonal entry gate.
   if(!Strategy_InSeason(current_bar))
      return false;

   const int week_key = Strategy_WeekKey(current_bar);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= entry_price)
      return false;

   req.reason = "WTI_TRADING_TIME_WEEKLY_SHORT";
   g_candidate_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseInvalidOrStalePositions();
  }

bool Strategy_ExitSignal()
  {
   return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13107\",\"ea\":\"wti-juldec-short\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_ManageOpenPosition();
     }

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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || !is_new_bar)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)
         g_last_entry_week_key = g_candidate_week_key;
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
