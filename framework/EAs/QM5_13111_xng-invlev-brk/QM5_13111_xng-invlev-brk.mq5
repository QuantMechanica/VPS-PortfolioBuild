#property strict
#property version   "5.0"
#property description "QM5_13111 XNG Inverse-Leverage Range Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13111 - XNG Inverse-Leverage Range Breakout
// -----------------------------------------------------------------------------
// Structural natural-gas volatility sleeve:
//   - a completed positive same-session impulse identifies the volatility state
//   - the following completed H4 bar must break the impulse range
//   - the break, not the original positive return, chooses long or short
//   - one accepted entry per broker week; structural SL, fixed-R TP, time exit
// Runtime is native OHLC/ATR/calendar only; no DCCA/DMCA, GARCH, feed, API, ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                              = 13111;
input int    qm_magic_slot_offset                  = 0;
input uint   qm_rng_seed                           = 42;

input group "Risk"
input double RISK_PERCENT                          = 0.0;
input double RISK_FIXED                            = 1000.0;
input double PORTFOLIO_WEIGHT                      = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_atr_period                   = 20;
input double strategy_min_impulse_atr              = 0.75;
input double strategy_min_setup_range_atr          = 0.35;
input double strategy_max_setup_range_atr          = 2.50;
input double strategy_min_setup_close_location     = 0.65;
input double strategy_break_buffer_atr             = 0.05;
input double strategy_min_confirm_close_location   = 0.60;
input double strategy_stop_buffer_atr              = 0.10;
input double strategy_rr_target                    = 1.50;
input int    strategy_max_hold_hours               = 24;
input int    strategy_max_spread_points            = 2500;

int g_last_entry_week_key = 0;

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_WeekKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   const int days_since_monday = (dt.day_of_week + 6) % 7;
   return dt.year * 1000 + dt.day_of_year - days_since_monday;
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

bool Strategy_LoadState(MqlRates &setup_h4,
                        MqlRates &confirm_h4,
                        MqlRates &current_h4,
                        MqlRates &current_d1,
                        double &atr_d1)
  {
   MqlRates h4[];
   ArraySetAsSeries(h4, true);
   if(CopyRates(_Symbol, PERIOD_H4, 0, 3, h4) < 3) // perf-allowed: new-H4-bar entry path only.
      return false;

   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, d1) < 1) // perf-allowed: new-H4-bar entry path only.
      return false;

   current_h4 = h4[0];
   confirm_h4 = h4[1];
   setup_h4 = h4[2];
   current_d1 = d1[0];
   atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(current_h4.time <= 0 || confirm_h4.time <= 0 || setup_h4.time <= 0 ||
      current_d1.time <= 0 || atr_d1 <= 0.0)
      return false;
   if(setup_h4.high <= setup_h4.low || confirm_h4.high <= confirm_h4.low)
      return false;
   if(setup_h4.open <= 0.0 || setup_h4.close <= 0.0 ||
      confirm_h4.open <= 0.0 || confirm_h4.close <= 0.0 || current_d1.open <= 0.0)
      return false;

   const int day_key = Strategy_DayKey(current_d1.time);
   if(Strategy_DayKey(setup_h4.time) != day_key ||
      Strategy_DayKey(confirm_h4.time) != day_key ||
      Strategy_DayKey(current_h4.time) != day_key)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "XNGUSD.DWX" || _Period != PERIOD_H4)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_max_hold_hours <= 0)
      return true;
   if(strategy_min_impulse_atr <= 0.0 || strategy_min_setup_range_atr <= 0.0 ||
      strategy_max_setup_range_atr <= strategy_min_setup_range_atr)
      return true;
   if(strategy_min_setup_close_location <= 0.5 || strategy_min_setup_close_location >= 1.0)
      return true;
   if(strategy_min_confirm_close_location <= 0.5 || strategy_min_confirm_close_location >= 1.0)
      return true;
   if(strategy_break_buffer_atr < 0.0 || strategy_stop_buffer_atr < 0.0)
      return true;
   if(strategy_rr_target <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13111_XNG_INVLEV_BRK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   MqlRates setup_h4;
   MqlRates confirm_h4;
   MqlRates current_h4;
   MqlRates current_d1;
   double atr_d1 = 0.0;
   if(!Strategy_LoadState(setup_h4, confirm_h4, current_h4, current_d1, atr_d1))
      return false;

   const int week_key = Strategy_WeekKey(confirm_h4.time);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   const double setup_range = setup_h4.high - setup_h4.low;
   if(setup_range < strategy_min_setup_range_atr * atr_d1 ||
      setup_range > strategy_max_setup_range_atr * atr_d1)
      return false;

   const double setup_close_location = (setup_h4.close - setup_h4.low) / setup_range;
   const double positive_impulse = setup_h4.close - current_d1.open;
   if(setup_h4.close <= setup_h4.open ||
      positive_impulse < strategy_min_impulse_atr * atr_d1 ||
      setup_close_location < strategy_min_setup_close_location)
      return false;

   const double confirm_range = confirm_h4.high - confirm_h4.low;
   if(confirm_range <= _Point)
      return false;
   const double confirm_close_location = (confirm_h4.close - confirm_h4.low) / confirm_range;
   const double break_buffer = strategy_break_buffer_atr * atr_d1;

   int direction = 0;
   if(confirm_h4.close > setup_h4.high + break_buffer &&
      confirm_h4.close > confirm_h4.open &&
      confirm_close_location >= strategy_min_confirm_close_location)
      direction = 1;
   else if(confirm_h4.close < setup_h4.low - break_buffer &&
           confirm_h4.close < confirm_h4.open &&
           confirm_close_location <= 1.0 - strategy_min_confirm_close_location)
      direction = -1;
   else
      return false;

   req.type = (direction > 0 ? QM_BUY : QM_SELL);
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = (direction > 0
             ? setup_h4.low - strategy_stop_buffer_atr * atr_d1
             : setup_h4.high + strategy_stop_buffer_atr * atr_d1);

   const double risk_distance = (direction > 0 ? entry_price - req.sl : req.sl - entry_price);
   if(risk_distance <= _Point)
      return false;

   req.tp = (direction > 0
             ? entry_price + strategy_rr_target * risk_distance
             : entry_price - strategy_rr_target * risk_distance);
   req.reason = (direction > 0 ? "XNG_INVLEV_BREAK_LONG" : "XNG_INVLEV_BREAK_SHORT");
   g_last_entry_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_hours) * 3600;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13111\",\"ea\":\"xng-invlev-brk\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
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

