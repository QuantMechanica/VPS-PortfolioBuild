#property strict
#property version   "5.0"
#property description "QM5_10710 TradingView Asian Range Breakout Retest _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_10710_v2
// Logic: Asian Range Breakout with Retest.
// Fixes: Increased news stale tolerance to avoid ONINIT_FAILED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10710;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 1.0;
input double RISK_FIXED                 = 0.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 8760;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_session1_start_hour = 20;
input int    strategy_session1_start_min  = 0;
input int    strategy_session1_end_hour   = 23;
input int    strategy_session1_end_min    = 59;
input int    strategy_session2_start_hour = 0;
input int    strategy_session2_start_min  = 0;
input int    strategy_session2_end_hour   = 8;
input int    strategy_session2_end_min    = 0;
input int    strategy_atr_period          = 14;
input double strategy_tp_r                = 3.0;
input double strategy_buf_min_points      = 2.0;
input double strategy_buf_atr_frac        = 0.10;
input double strategy_max_stop_atr        = 2.5;
input double strategy_max_spread_stop     = 0.15;
input double strategy_retest_tolerance_pts = 2.0;
input int    strategy_max_hold_bars       = 48;
input bool   strategy_one_per_session     = true;

// Internal state
int    g_session_key = 0;
double g_range_high = 0.0;
double g_range_low = 0.0;
bool   g_range_ready = false;
bool   g_bull_breakout = false;
bool   g_bear_breakout = false;
bool   g_trade_taken_this_session = false;

// -----------------------------------------------------------------------------
// Helper logic
// -----------------------------------------------------------------------------

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_InAsianSession(const datetime t)
  {
   int m = Strategy_MinutesOfDay(t);
   int s1 = strategy_session1_start_hour * 60 + strategy_session1_start_min;
   int e1 = strategy_session1_end_hour * 60 + strategy_session1_end_min;
   int s2 = strategy_session2_start_hour * 60 + strategy_session2_start_min;
   int e2 = strategy_session2_end_hour * 60 + strategy_session2_end_min;

   // S1 to E1
   if(m >= s1 && m <= e1) return true;
   // S2 to E2
   if(m >= s2 && m < e2) return true;
   
   return false;
  }

int Strategy_SessionKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int m = dt.hour * 60 + dt.min;
   int s1 = strategy_session1_start_hour * 60 + strategy_session1_start_min;
   datetime key_day = t - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   if(m >= s1) key_day += 86400;
   TimeToStruct(key_day, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void Strategy_ResetSession(const int session_key)
  {
   g_session_key = session_key;
   g_range_high = 0.0;
   g_range_low = 0.0;
   g_range_ready = false;
   g_bull_breakout = false;
   g_bear_breakout = false;
   g_trade_taken_this_session = false;
  }

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework Hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15) return true;
   
   datetime bar_time = iTime(_Symbol, _Period, 1);
   double bar_high = iHigh(_Symbol, _Period, 1);
   double bar_low = iLow(_Symbol, _Period, 1);
   
   int key = Strategy_SessionKey(bar_time);
   if(key != g_session_key) Strategy_ResetSession(key);

   if(Strategy_InAsianSession(bar_time))
     {
      if(!g_range_ready) { g_range_high = bar_high; g_range_low = bar_low; g_range_ready = true; }
      else { g_range_high = MathMax(g_range_high, bar_high); g_range_low = MathMin(g_range_low, bar_low); }
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_range_ready || g_range_high <= g_range_low || HasOurPosition()) return false;
   if(strategy_one_per_session && g_trade_taken_this_session) return false;

   datetime bar_time = iTime(_Symbol, _Period, 1);
   if(Strategy_InAsianSession(bar_time)) return false;

   double close_1 = iClose(_Symbol, _Period, 1);
   double low_1 = iLow(_Symbol, _Period, 1);
   double high_1 = iHigh(_Symbol, _Period, 1);
   double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(!g_bull_breakout && close_1 > g_range_high) g_bull_breakout = true;
   if(!g_bear_breakout && close_1 < g_range_low) g_bear_breakout = true;

   double buffer = MathMax(strategy_buf_min_points * point, strategy_buf_atr_frac * atr);
   double retest_tol = strategy_retest_tolerance_pts * point;

   if(g_bull_breakout && low_1 <= g_range_high + retest_tol && close_1 > g_range_high)
     {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = NormalizeDouble(low_1 - buffer, _Digits);
      double risk = entry - sl;
      if(risk > 0 && risk <= strategy_max_stop_atr * atr)
        {
         req.type = QM_BUY; req.sl = sl; req.tp = NormalizeDouble(entry + strategy_tp_r * risk, _Digits);
         req.reason = "ASIAN_RETBRK_LONG"; g_trade_taken_this_session = true; return true;
        }
     }

   if(g_bear_breakout && high_1 >= g_range_low - retest_tol && close_1 < g_range_low)
     {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = NormalizeDouble(high_1 + buffer, _Digits);
      double risk = sl - entry;
      if(risk > 0 && risk <= strategy_max_stop_atr * atr)
        {
         req.type = QM_SELL; req.sl = sl; req.tp = NormalizeDouble(entry - strategy_tp_r * risk, _Digits);
         req.reason = "ASIAN_RETBRK_SHORT"; g_trade_taken_this_session = true; return true;
        }
     }
   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   datetime now = TimeCurrent();
   if(Strategy_InAsianSession(now)) return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic)
        {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if((now - opened) >= strategy_max_hold_bars * 900) return true;
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework Wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE) news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || QM_FrameworkHandleFridayClose() || Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic) QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res) { QM_FrameworkOnTradeTransaction(t, r, res); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
