#property strict
#property version   "5.0"
#property description "QM5_12753 WTI Thursday Pullback Friday Bounce"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12753 - WTI Thursday Pullback Friday Bounce
// -----------------------------------------------------------------------------
// D1 structural petroleum day-of-week sleeve:
//   - buy XTIUSD.DWX only on Friday
//   - require the prior Thursday close-to-close return to be below threshold
//   - flatten on Friday close / first non-Friday D1 bar / stale guard
// Runtime uses MT5 OHLC/broker calendar only; no external energy data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12753;
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
input double strategy_min_thu_drop_pct   = 1.00;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.25;
input int    strategy_max_hold_days      = 2;
input int    strategy_max_spread_points  = 1000;

int g_last_entry_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
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

void Strategy_CloseTimeExpiredPositions()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const datetime current_d1_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 exit calendar gate, O(1) read.
   const int current_dow = (current_d1_bar > 0) ? Strategy_DayOfWeek(current_d1_bar) : Strategy_DayOfWeek(now);
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

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
      bool should_close = (current_dow != 5);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_min_thu_drop_pct <= 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_LoadThursdayPullbackState(datetime &friday_time,
                                        datetime &thursday_time,
                                        double &thursday_return_pct)
  {
   friday_time = iTime(_Symbol, PERIOD_D1, 0);    // perf-allowed: D1 Friday calendar gate, O(1) read.
   thursday_time = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior D1 bar calendar gate, O(1) read.
   const datetime wednesday_time = iTime(_Symbol, PERIOD_D1, 2); // perf-allowed: validates prior bar sequence.
   const double thursday_close = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: one closed D1 close for Thursday return.
   const double wednesday_close = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: one closed D1 close for Thursday return.

   if(friday_time <= 0 || thursday_time <= 0 || wednesday_time <= 0)
      return false;
   if(thursday_close <= 0.0 || wednesday_close <= 0.0)
      return false;
   if(Strategy_DayOfWeek(friday_time) != 5)
      return false;
   if(Strategy_DayOfWeek(thursday_time) != 4)
      return false;

   thursday_return_pct = ((thursday_close / wednesday_close) - 1.0) * 100.0;
   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12753_WTI_THU_PB_FRI_BOUNCE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseTimeExpiredPositions();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   datetime friday_time = 0;
   datetime thursday_time = 0;
   double thursday_return_pct = 0.0;
   if(!Strategy_LoadThursdayPullbackState(friday_time, thursday_time, thursday_return_pct))
      return false;

   const int day_key = Strategy_DayKey(friday_time);
   if(day_key <= 0 || day_key == g_last_entry_day_key)
      return false;
   if(thursday_return_pct > -strategy_min_thu_drop_pct)
      return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = "WTI_THU_PULLBACK_FRI_BOUNCE_LONG";
   g_last_entry_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseTimeExpiredPositions();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12753\",\"ea\":\"wti-thu-pb-fri-bounce\"}");
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
