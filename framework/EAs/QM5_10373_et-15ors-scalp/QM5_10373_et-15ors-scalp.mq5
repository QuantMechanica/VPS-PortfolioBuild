#property strict
#property version   "5.0"
#property description "QM5_10373 Elite Trader 15-minute opening range scalp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10373;
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
input int    strategy_range_start_hhmm    = 930;
input int    strategy_range_end_hhmm      = 945;
input int    strategy_entry_cutoff_hhmm   = 1600;
input int    strategy_atr_period          = 14;
input double strategy_target_atr_mult     = 0.15;
input double strategy_entry_offset_ticks  = 1.0;
input double strategy_spread_max_frac     = 0.15;
input double strategy_be_trigger_r        = 0.60;
input double strategy_be_buffer_ticks     = 1.0;
input int    strategy_time_stop_seconds   = 60;
input int    strategy_reentry_cutoff_hhmm = 1000;

int      g_trade_day_key = 0;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
bool     g_or_ready = false;
int      g_entries_today = 0;
int      g_last_entry_dir = 0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

double Strategy_TickSize()
  {
   const double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick > 0.0)
      return tick;
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  }

bool Strategy_HaveOpenPosition()
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

void Strategy_ResetDayIfNeeded(const datetime broker_now)
  {
   const int day_key = Strategy_DateKey(broker_now);
   if(day_key == g_trade_day_key)
      return;

   g_trade_day_key = day_key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_ready = false;
   g_entries_today = 0;
   g_last_entry_dir = 0;
  }

bool Strategy_NoTradeFilter()
  {
   const double tick = Strategy_TickSize();
   if(tick <= 0.0)
      return true;

   const int hhmm = Strategy_Hhmm(TimeCurrent());
   if(hhmm < strategy_range_start_hhmm || hhmm > strategy_entry_cutoff_hhmm)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "et_15ors_scalp";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   Strategy_ResetDayIfNeeded(broker_now);

   const datetime bar_t = iTime(_Symbol, _Period, 1);
   if(bar_t <= 0)
      return false;

   const int bar_hhmm = Strategy_Hhmm(bar_t);
   if(bar_hhmm >= strategy_range_start_hhmm && bar_hhmm < strategy_range_end_hhmm)
     {
      const double h1 = iHigh(_Symbol, _Period, 1);
      const double l1 = iLow(_Symbol, _Period, 1);
      if(h1 > 0.0 && l1 > 0.0)
        {
         g_or_high = (g_or_high <= 0.0) ? h1 : MathMax(g_or_high, h1);
         g_or_low = (g_or_low <= 0.0) ? l1 : MathMin(g_or_low, l1);
        }
     }

   const int now_hhmm = Strategy_Hhmm(broker_now);
   if(now_hhmm >= strategy_range_end_hhmm && g_or_high > 0.0 && g_or_low > 0.0)
      g_or_ready = true;

   if(!g_or_ready || now_hhmm < strategy_range_end_hhmm || now_hhmm > strategy_entry_cutoff_hhmm)
      return false;
   if(Strategy_HaveOpenPosition())
      return false;
   if(g_entries_today >= 2)
      return false;
   if(g_entries_today == 1 && now_hhmm > strategy_reentry_cutoff_hhmm)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double tick = Strategy_TickSize();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || tick <= 0.0 || ask <= 0.0 || bid <= 0.0 || strategy_target_atr_mult <= 0.0)
      return false;

   const double target_dist = atr * strategy_target_atr_mult;
   const double spread = ask - bid;
   if(target_dist <= tick || spread > target_dist * strategy_spread_max_frac)
      return false;

   const double long_trigger = g_or_high + tick * strategy_entry_offset_ticks;
   const double short_trigger = g_or_low - tick * strategy_entry_offset_ticks;
   const double c1 = iClose(_Symbol, _Period, 1);
   if(c1 <= 0.0)
      return false;

   int dir = 0;
   if(c1 >= long_trigger)
      dir = 1;
   else if(c1 <= short_trigger)
      dir = -1;

   if(dir == 0)
      return false;
   if(g_entries_today == 1 && dir == g_last_entry_dir)
      return false;

   if(dir > 0)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = ask - target_dist;
      req.tp = ask + target_dist;
      req.reason = "or_breakout_long";
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = bid + target_dist;
      req.tp = bid - target_dist;
      req.reason = "or_breakout_short";
     }

   g_entries_today++;
   g_last_entry_dir = dir;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double tick = Strategy_TickSize();
   if(tick <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || current_sl <= 0.0 || current_tp <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk_dist = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(risk_dist <= 0.0 || moved < risk_dist * strategy_be_trigger_r)
         continue;

      const double be_sl = is_buy ? (open_price + tick * strategy_be_buffer_ticks)
                                  : (open_price - tick * strategy_be_buffer_ticks);
      const bool improves = is_buy ? (be_sl > current_sl + tick * 0.5)
                                   : (be_sl < current_sl - tick * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, be_sl, "be_plus_one_tick_after_0_6r");
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && now - open_time >= strategy_time_stop_seconds)
         return true;
     }
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
