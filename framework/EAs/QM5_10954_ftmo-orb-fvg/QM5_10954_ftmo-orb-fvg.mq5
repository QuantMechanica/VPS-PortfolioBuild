#property strict
#property version   "5.0"
#property description "QM5_10954 FTMO US opening-range FVG breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10954;
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
// Card states the US-session schedule in CET (15:30-15:45 opening range, 17:00
// cancel, 21:00 time-exit). The tester runs in Darwinex NY-Close BROKER time
// (GMT+2 winter / GMT+3 US-DST). The US cash open 09:30 ET maps to 16:30 broker
// year-round, i.e. broker = CET + 1h. All four anchors below are therefore the
// CET card values converted to broker time (+1h). See SPEC.md §1 / §4.
input int    strategy_or_start_hhmm       = 1630;   // 15:30 CET US cash open
input int    strategy_or_end_hhmm         = 1645;   // 15:45 CET (15-min OR)
input int    strategy_cancel_hhmm         = 1800;   // 17:00 CET cancel unfilled
input int    strategy_time_exit_hhmm      = 2200;   // 21:00 CET time exit
input int    strategy_atr_period          = 14;
input double strategy_max_or_atr_mult     = 1.8;
input double strategy_min_stop_or_mult    = 0.35;
input double strategy_tp_rr               = 2.0;
input double strategy_max_spread_stop_frac = 0.08;
input int    strategy_session_lookback_bars = 96;

int      g_or_day_key = -1;
double   g_or_high = 0.0;
double   g_or_low = 0.0;
double   g_session_vwap = 0.0;
int      g_attempt_day_key = -1;
int      g_cancel_day_key = -1;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime TodayAtHhmm(const datetime now, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = hhmm / 100;
   dt.min = hhmm % 100;
   dt.sec = 0;
   return StructToTime(dt);
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

void CancelOurPendingOrders(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_LIMIT && order_type != ORDER_TYPE_SELL_LIMIT)
         continue;

      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool RefreshSessionState(MqlRates &rates[], const int copied, const datetime latest_closed)
  {
   const int today = DayKey(latest_closed);
   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;
   int range_bars = 0;
   double pv_sum = 0.0;
   double vol_sum = 0.0;

   for(int i = 0; i < copied; ++i)
     {
      if(DayKey(rates[i].time) != today)
         continue;
      const int bar_hhmm = Hhmm(rates[i].time);
      if(bar_hhmm >= strategy_or_start_hhmm && bar_hhmm < strategy_or_end_hhmm)
        {
         range_high = MathMax(range_high, rates[i].high);
         range_low = MathMin(range_low, rates[i].low);
         range_bars++;
        }
      if(bar_hhmm >= strategy_or_start_hhmm && bar_hhmm <= Hhmm(latest_closed))
        {
         const double vol = (rates[i].tick_volume > 0) ? (double)rates[i].tick_volume : 1.0;
         const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
         pv_sum += typical * vol;
         vol_sum += vol;
        }
     }

   if(range_bars < 3 || range_high <= range_low || vol_sum <= 0.0)
      return false;

   g_or_day_key = today;
   g_or_high = range_high;
   g_or_low = range_low;
   g_session_vwap = pv_sum / vol_sum;
   return true;
  }

int PendingExpirationSeconds(const datetime now)
  {
   const datetime cancel_time = TodayAtHhmm(now, strategy_cancel_hhmm);
   const int seconds = (int)(cancel_time - now);
   if(seconds <= 0)
      return 0;
   return seconds;
  }

bool SpreadAllowsEntry(const double stop_distance)
  {
   if(stop_distance <= 0.0 || strategy_max_spread_stop_frac <= 0.0)
      return false;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   return ((ask - bid) <= stop_distance * strategy_max_spread_stop_frac);
  }

bool Strategy_NoTradeFilter()
  {
   const datetime now = TimeCurrent();
   const int today = DayKey(now);
   if(Hhmm(now) >= strategy_cancel_hhmm && g_cancel_day_key != today)
     {
      CancelOurPendingOrders("cancel_at_1700");
      g_cancel_day_key = today;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime now = TimeCurrent();
   const int now_hhmm = Hhmm(now);
   const int today = DayKey(now);
   if(now_hhmm < strategy_or_end_hhmm || now_hhmm >= strategy_cancel_hhmm)
      return false;
   if(g_attempt_day_key == today || HasOurPosition() || HasOurPendingOrder())
      return false;

   const int lookback = MathMax(16, strategy_session_lookback_bars);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // bounded M5 session snapshot for OR/FVG/VWAP structure, called only from the framework new-bar gate.
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, lookback, rates); // perf-allowed: one bounded CopyRates per closed bar (post-QM_IsNewBar gate)
   if(copied < 16)
      return false;

   const datetime latest_closed = rates[0].time;
   if(Hhmm(latest_closed) < strategy_or_end_hhmm || DayKey(latest_closed) != today)
      return false;
   if(!RefreshSessionState(rates, copied, latest_closed))
      return false;

   const double opening_range_width = g_or_high - g_or_low;
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(opening_range_width <= 0.0 || atr_m15 <= 0.0)
      return false;
   if(opening_range_width > atr_m15 * strategy_max_or_atr_mult)
      return false;

   if(copied < 3)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const MqlRates latest = rates[0];
   const MqlRates middle = rates[1];
   const MqlRates older = rates[2];
   const double min_stop_distance = opening_range_width * strategy_min_stop_or_mult;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(latest.close > g_or_high && latest.close > g_session_vwap && latest.low > older.high)
     {
      const double entry = NormalizeStrategyPrice(latest.low);
      if(entry <= 0.0 || entry >= ask)
         return false;
      double sl = MathMin(middle.low - point, entry - min_stop_distance);
      sl = NormalizeStrategyPrice(sl);
      const double stop_distance = entry - sl;
      if(sl <= 0.0 || stop_distance <= 0.0 || !SpreadAllowsEntry(stop_distance))
         return false;

      req.type = QM_BUY_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = NormalizeStrategyPrice(entry + stop_distance * strategy_tp_rr);
      req.reason = "FTMO_ORB_FVG_LONG";
      req.expiration_seconds = PendingExpirationSeconds(now);
      g_attempt_day_key = today;
      return true;
     }

   if(latest.close < g_or_low && latest.close < g_session_vwap && latest.high < older.low)
     {
      const double entry = NormalizeStrategyPrice(latest.high);
      if(entry <= 0.0 || entry <= bid)
         return false;
      double sl = MathMax(middle.high + point, entry + min_stop_distance);
      sl = NormalizeStrategyPrice(sl);
      const double stop_distance = sl - entry;
      if(sl <= 0.0 || stop_distance <= 0.0 || !SpreadAllowsEntry(stop_distance))
         return false;

      req.type = QM_SELL_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = NormalizeStrategyPrice(entry - stop_distance * strategy_tp_rr);
      req.reason = "FTMO_ORB_FVG_SHORT";
      req.expiration_seconds = PendingExpirationSeconds(now);
      g_attempt_day_key = today;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card marks 1R partial exits as optional and gives no fixed fraction; no management overlay is added.
  }

bool Strategy_ExitSignal()
  {
   return (Hhmm(TimeCurrent()) >= strategy_time_exit_hhmm && HasOurPosition());
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
