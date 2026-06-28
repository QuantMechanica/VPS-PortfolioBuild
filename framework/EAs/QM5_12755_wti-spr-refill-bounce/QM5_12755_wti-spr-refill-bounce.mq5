#property strict
#property version   "5.0"
#property description "QM5_12755 WTI SPR Refill-Zone Reclaim Bounce"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12755 - WTI SPR Refill-Zone Reclaim Bounce
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - trades only XTIUSD.DWX
//   - buys completed D1 reclaim bars after a probe of the SPR refill zone
//   - exits on rebound, failed reclaim, stale hold, framework Friday close, or SL
// Runtime uses MT5 OHLC only; no DOE, EIA, SPR, tender, news, API, or CSV feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12755;
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
input double strategy_refill_zone_price     = 79.00;
input double strategy_zone_buffer_price     = 1.50;
input double strategy_max_entry_price       = 81.00;
input double strategy_rebound_exit_price    = 85.00;
input double strategy_failed_reclaim_price  = 76.00;
input double strategy_min_close_location    = 0.60;
input double strategy_min_reclaim_atr       = 0.25;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 2.75;
input int    strategy_max_hold_days         = 12;
input int    strategy_cooldown_days         = 10;
input int    strategy_max_spread_points     = 1000;

int g_last_signal_day_key = 0;
datetime g_last_entry_signal_time = 0;

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

bool Strategy_LoadClosedState(double &bar_open,
                              double &bar_high,
                              double &bar_low,
                              double &bar_close,
                              double &atr_last,
                              int &signal_day_key,
                              datetime &signal_time)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, rates) < 1) // perf-allowed: prior D1 SPR refill-zone state, new-bar gated.
      return false;

   bar_open = rates[0].open;
   bar_high = rates[0].high;
   bar_low = rates[0].low;
   bar_close = rates[0].close;
   signal_time = rates[0].time;
   signal_day_key = Strategy_DayKey(signal_time);

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;
   if(bar_high <= bar_low || atr_last <= 0.0)
      return false;
   if(signal_day_key <= 0 || signal_time <= 0)
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double bar_open = 0.0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   double atr_last = 0.0;
   int signal_day_key = 0;
   datetime signal_time = 0;
   const bool have_state = Strategy_LoadClosedState(bar_open, bar_high, bar_low, bar_close,
                                                    atr_last, signal_day_key, signal_time);
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_days = MathMax(1, strategy_max_hold_days);
   const long hold_seconds = (long)hold_days * 86400;

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
      bool should_close = (opened > 0 && now - opened >= hold_seconds);
      if(have_state)
        {
         if(bar_close >= strategy_rebound_exit_price)
            should_close = true;
         if(bar_close < strategy_failed_reclaim_price)
            should_close = true;
        }

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
   if(strategy_refill_zone_price <= 0.0 || strategy_zone_buffer_price < 0.0)
      return true;
   if(strategy_max_entry_price <= strategy_refill_zone_price)
      return true;
   if(strategy_rebound_exit_price <= strategy_max_entry_price)
      return true;
   if(strategy_failed_reclaim_price <= 0.0 || strategy_failed_reclaim_price >= strategy_refill_zone_price)
      return true;
   if(strategy_min_close_location <= 0.0 || strategy_min_close_location > 1.0)
      return true;
   if(strategy_min_reclaim_atr <= 0.0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0 || strategy_cooldown_days < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12755_WTI_SPR_REFILL_BOUNCE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double bar_open = 0.0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   double atr_last = 0.0;
   int signal_day_key = 0;
   datetime signal_time = 0;
   if(!Strategy_LoadClosedState(bar_open, bar_high, bar_low, bar_close,
                                atr_last, signal_day_key, signal_time))
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;

   const int cooldown_days = MathMax(0, strategy_cooldown_days);
   const long cooldown_seconds = (long)cooldown_days * 86400;
   if(g_last_entry_signal_time > 0 && signal_time > g_last_entry_signal_time &&
      signal_time - g_last_entry_signal_time < cooldown_seconds)
      return false;

   const double bar_range = bar_high - bar_low;
   const double close_location = (bar_close - bar_low) / bar_range;
   const double reclaim_atr = (bar_close - bar_low) / atr_last;

   if(bar_low > strategy_refill_zone_price + strategy_zone_buffer_price)
      return false;
   if(bar_close < strategy_refill_zone_price)
      return false;
   if(bar_close > strategy_max_entry_price)
      return false;
   if(bar_close <= bar_open)
      return false;
   if(close_location < strategy_min_close_location)
      return false;
   if(reclaim_atr < strategy_min_reclaim_atr)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "WTI_SPR_REFILL_RECLAIM_LONG";
   g_last_signal_day_key = signal_day_key;
   g_last_entry_signal_time = signal_time;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12755\",\"ea\":\"wti-spr-refill-bounce\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
