#property strict
#property version   "5.0"
#property description "QM5_10013 Robot Wealth FX Weekend Gap"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10013;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period             = 14;
input double strategy_gap_threshold_atr      = 0.35;
input double strategy_gap_stop_mult          = 1.20;
input double strategy_gap_stop_min_atr       = 0.80;
input double strategy_gap_stop_max_atr       = 2.00;
input int    strategy_max_hold_hours         = 24;
input int    strategy_spread_median_bars     = 24;
input double strategy_spread_median_mult     = 2.00;
input bool   strategy_wait_wide_spread_bar   = true;

int SymbolSlot()
  {
   return qm_magic_slot_offset;
  }

int DayOfWeek(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool IsTuesdayNYCutoffOrLater(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   const datetime ny_time = utc + ny_offset_hours * 3600;

   MqlDateTime ny;
   TimeToStruct(ny_time, ny);
   return ((ny.day_of_week == 2 && ny.hour >= 17) || ny.day_of_week == 3);
  }

double MedianRecentSpread()
  {
   const int bars = MathMax(1, strategy_spread_median_bars);
   double spreads[];
   ArrayResize(spreads, bars);
   int n = 0;

   for(int shift = 1; shift <= bars; ++shift)
     {
      const long spread = iSpread(_Symbol, _Period, shift);
      if(spread <= 0)
         continue;
      spreads[n] = (double)spread;
      n++;
     }

   if(n <= 0)
      return 0.0;

   ArrayResize(spreads, n);
   ArraySort(spreads);
   return spreads[n / 2];
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): framework handles news and Friday close.
   // Monday timing and abnormal open spread are card entry conditions.
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = SymbolSlot();
   req.expiration_seconds = 0;

   static bool     pending_after_wide_spread = false;
   static datetime pending_bar_time = 0;
   static int      pending_direction = 0;
   static double   pending_friday_close = 0.0;
   static double   pending_gap_abs = 0.0;
   static double   pending_atr = 0.0;

   const datetime current_bar_time = iTime(_Symbol, _Period, 0);
   const datetime previous_bar_time = iTime(_Symbol, _Period, 1);
   if(current_bar_time <= 0 || previous_bar_time <= 0)
      return false;

   int direction = 0;
   double friday_close = 0.0;
   double gap_abs = 0.0;
   double atr = 0.0;
   bool delayed_entry = false;

   const bool first_monday_bar = (DayOfWeek(current_bar_time) == 1 && DayOfWeek(previous_bar_time) == 5);
   if(first_monday_bar)
     {
      const double monday_open = iOpen(_Symbol, _Period, 0);
      friday_close = iClose(_Symbol, _Period, 1);
      atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(monday_open <= 0.0 || friday_close <= 0.0 || atr <= 0.0)
         return false;

      const double normalized_gap = (monday_open - friday_close) / atr;
      if(normalized_gap <= -strategy_gap_threshold_atr)
         direction = 1;
      else if(normalized_gap >= strategy_gap_threshold_atr)
         direction = -1;
      else
         return false;

      gap_abs = MathAbs(monday_open - friday_close);

      if(strategy_wait_wide_spread_bar)
        {
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double spread_points = (point > 0.0 && ask > bid) ? ((ask - bid) / point) : 0.0;
         const double median_spread = MedianRecentSpread();
         if(median_spread > 0.0 && spread_points > strategy_spread_median_mult * median_spread)
           {
            pending_after_wide_spread = true;
            pending_bar_time = current_bar_time;
            pending_direction = direction;
            pending_friday_close = friday_close;
            pending_gap_abs = gap_abs;
            pending_atr = atr;
            return false;
           }
        }
     }
   else if(pending_after_wide_spread &&
           DayOfWeek(current_bar_time) == 1 &&
           current_bar_time > pending_bar_time &&
           current_bar_time <= pending_bar_time + 7200)
     {
      delayed_entry = true;
      direction = pending_direction;
      friday_close = pending_friday_close;
      gap_abs = pending_gap_abs;
      atr = pending_atr;
      pending_after_wide_spread = false;
     }
   else
     {
      return false;
     }

   if(direction == 0 || friday_close <= 0.0 || gap_abs <= 0.0 || atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(direction > 0 && bid >= friday_close)
      return false;
   if(direction < 0 && ask <= friday_close)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = (direction > 0) ? ask : bid;
   double stop_distance = strategy_gap_stop_mult * gap_abs;
   stop_distance = MathMax(stop_distance, strategy_gap_stop_min_atr * atr);
   stop_distance = MathMin(stop_distance, strategy_gap_stop_max_atr * atr);
   if(stop_distance <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry_price, stop_distance);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, friday_close);
   req.reason = delayed_entry ? "RW_FX_WEEKEND_GAP_DELAYED" : "RW_FX_WEEKEND_GAP_OPEN";

   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   static ulong    cached_ticket = 0;
   static datetime cached_open_time = 0;
   static bool     cached_friday_checked = false;
   static double   cached_friday_close = 0.0;

   if(ticket == 0)
     {
      cached_ticket = 0;
      cached_open_time = 0;
      cached_friday_checked = false;
      cached_friday_close = 0.0;
      return false;
     }

   if(cached_ticket != ticket || cached_open_time != open_time)
     {
      cached_ticket = ticket;
      cached_open_time = open_time;
      cached_friday_checked = false;
      cached_friday_close = 0.0;
     }

   if(!cached_friday_checked)
     {
      int open_shift = iBarShift(_Symbol, _Period, open_time, false);
      if(open_shift < 0)
         open_shift = 0;

      for(int shift = open_shift + 1; shift <= open_shift + 150; ++shift)
        {
         const datetime bar_time = iTime(_Symbol, _Period, shift);
         if(bar_time <= 0)
            break;
         if(DayOfWeek(bar_time) == 5)
           {
            cached_friday_close = iClose(_Symbol, _Period, shift);
            break;
           }
        }
      cached_friday_checked = true;
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(cached_friday_close > 0.0)
     {
      if(position_type == POSITION_TYPE_BUY && bid >= cached_friday_close)
         return true;
      if(position_type == POSITION_TYPE_SELL && ask <= cached_friday_close)
         return true;
     }

   const datetime now = TimeCurrent();
   if(strategy_max_hold_hours > 0 && now >= open_time + strategy_max_hold_hours * 3600)
      return true;

   if(IsTuesdayNYCutoffOrLater(now))
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: extraordinary political/election risk is delegated to the P8 news driver.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10013\",\"strategy\":\"rw-fx-weekend-gap\"}");
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
