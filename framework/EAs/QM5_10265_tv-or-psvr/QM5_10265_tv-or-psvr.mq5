#property strict
#property version   "5.0"
#property description "QM5_10265 TV ORB PSVR Confirmed Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10265;
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
enum ORB_StopMode
  {
   Opposite_Range = 0,
   ATR = 1,
   Fixed_Percent = 2
  };

input int          or_duration_minutes       = 15;
input int          consecutive_closes        = 2;
input int          psvr_volume_sma           = 20;
input double       psvr_min_volume_ratio     = 1.5;
input ORB_StopMode stop_mode                 = Opposite_Range;
input double       tp1_close_fraction        = 0.50;
input double       tp2_r_multiple            = 2.0;
input int          atr_filter_period         = 14;
input double       min_or_atr_multiple       = 0.25;
input double       max_or_atr_multiple       = 2.50;
input int          london_open_hour_broker   = 10;
input int          london_open_minute_broker = 0;
input int          ny_open_hour_broker       = 16;
input int          ny_open_minute_broker     = 30;
input int          eod_close_hhmm_broker     = 2230;
input bool         trade_monday              = true;
input bool         trade_tuesday             = true;
input bool         trade_wednesday           = true;
input bool         trade_thursday            = true;
input bool         trade_friday              = false;

struct ORB_State
  {
   bool     ready;
   double   high;
   double   low;
   datetime session_start;
   datetime or_end;
   int      last_closed_index;
  };

int HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime TodayAtBroker(const datetime now, const int hour, const int minute)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = MathMax(0, MathMin(23, hour));
   dt.min = MathMax(0, MathMin(59, minute));
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime BrokerDayStart(const datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool IsWeekdayEnabled(const datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   if(dt.day_of_week == 1) return trade_monday;
   if(dt.day_of_week == 2) return trade_tuesday;
   if(dt.day_of_week == 3) return trade_wednesday;
   if(dt.day_of_week == 4) return trade_thursday;
   if(dt.day_of_week == 5) return trade_friday;
   return false;
  }

bool IsIndexSymbol()
  {
   return (StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0);
  }

bool GetSessionStart(const datetime now, datetime &session_start)
  {
   if(IsIndexSymbol())
     {
      session_start = TodayAtBroker(now, ny_open_hour_broker, ny_open_minute_broker);
      return true;
     }

   if(StringFind(_Symbol, "GBP") >= 0 || StringFind(_Symbol, "EUR") >= 0 ||
      StringFind(_Symbol, "USD") >= 0)
     {
      session_start = TodayAtBroker(now, london_open_hour_broker, london_open_minute_broker);
      return true;
     }

   session_start = 0;
   return false;
  }

int OurOpenPositionCount()
  {
   int count = 0;
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
      ++count;
     }
   return count;
  }

double NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool LoadTodayRates(MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   ArraySetAsSeries(rates, false);
   const datetime now = TimeCurrent();
   const datetime from_time = BrokerDayStart(now) - (psvr_volume_sma + 4) * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, from_time, now, rates); // perf-allowed: closed-bar OR/volume window, called only after QM_IsNewBar()
   return (copied > psvr_volume_sma + consecutive_closes + 2);
  }

bool VolumeRatioPass(MqlRates &rates[], const int index)
  {
   if(psvr_volume_sma <= 0 || index - psvr_volume_sma < 0)
      return false;

   double volume_sum = 0.0;
   for(int i = index - psvr_volume_sma; i < index; ++i)
      volume_sum += (double)rates[i].tick_volume;

   const double avg_volume = volume_sum / (double)psvr_volume_sma;
   if(avg_volume <= 0.0)
      return false;

   return ((double)rates[index].tick_volume >= avg_volume * psvr_min_volume_ratio);
  }

bool BuildORBState(ORB_State &state, MqlRates &rates[])
  {
   state.ready = false;
   state.high = 0.0;
   state.low = 0.0;
   state.session_start = 0;
   state.or_end = 0;
   state.last_closed_index = -1;

   if(or_duration_minutes <= 0 || !LoadTodayRates(rates))
      return false;

   const datetime now = TimeCurrent();
   if(!GetSessionStart(now, state.session_start))
      return false;

   state.or_end = state.session_start + or_duration_minutes * 60;
   if(now < state.or_end)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      return false;

   double or_high = -DBL_MAX;
   double or_low = DBL_MAX;
   int or_bars = 0;
   const int total = ArraySize(rates);
   for(int i = 0; i < total; ++i)
     {
      if(rates[i].time + period_seconds > now)
         continue;

      state.last_closed_index = i;
      if(rates[i].time >= state.session_start && rates[i].time < state.or_end)
        {
         if(rates[i].high > or_high)
            or_high = rates[i].high;
         if(rates[i].low < or_low)
            or_low = rates[i].low;
         ++or_bars;
        }
     }

   if(or_bars <= 0 || state.last_closed_index < 0 || or_high <= or_low)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, atr_filter_period, 1);
   if(atr <= 0.0)
      return false;

   const double range_width = or_high - or_low;
   if(range_width < min_or_atr_multiple * atr || range_width > max_or_atr_multiple * atr)
      return false;

   state.high = or_high;
   state.low = or_low;
   state.ready = true;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(OurOpenPositionCount() > 0)
      return false;

   const datetime now = TimeCurrent();
   if(!IsWeekdayEnabled(now))
      return true;
   if(HHMM(now) >= eod_close_hhmm_broker)
      return true;

   datetime session_start = 0;
   if(!GetSessionStart(now, session_start))
      return true;

   const datetime first_entry_time = session_start + MathMax(1, or_duration_minutes) * 60;
   return (now < first_entry_time);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(stop_mode != Opposite_Range)
      return false;
   if(!IsWeekdayEnabled(TimeCurrent()) || HHMM(TimeCurrent()) >= eod_close_hhmm_broker)
      return false;

   MqlRates rates[];
   ORB_State state;
   if(!BuildORBState(state, rates) || !state.ready)
      return false;

   const int confirms = MathMax(1, consecutive_closes);
   const int first_confirm_index = state.last_closed_index - confirms + 1;
   if(first_confirm_index < 0)
      return false;

   bool long_ok = true;
   bool short_ok = true;
   bool volume_ok = false;
   for(int i = first_confirm_index; i <= state.last_closed_index; ++i)
     {
      if(rates[i].time < state.or_end)
        {
         long_ok = false;
         short_ok = false;
         break;
        }

      if(rates[i].close <= state.high)
         long_ok = false;
      if(rates[i].close >= state.low)
         short_ok = false;
      if(VolumeRatioPass(rates, i))
         volume_ok = true;
     }

   if(!volume_ok || (!long_ok && !short_ok))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(long_ok)
     {
      const double entry = ask;
      const double sl = NormalizePrice(state.low);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = NormalizePrice(entry + MathAbs(entry - sl) * tp2_r_multiple);
      req.reason = "TV_OR_PSVR_LONG";
      return true;
     }

   const double entry = bid;
   const double sl = NormalizePrice(state.high);
   if(sl <= 0.0 || sl <= entry)
      return false;
   req.type = QM_SELL;
   req.sl = sl;
   req.tp = NormalizePrice(entry - MathAbs(sl - entry) * tp2_r_multiple);
   req.reason = "TV_OR_PSVR_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || current_tp <= 0.0 || volume <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const bool already_be = (current_sl > 0.0) &&
                              (is_buy ? (current_sl >= open_price - point * 0.5)
                                      : (current_sl <= open_price + point * 0.5));
      if(already_be)
         continue;

      const double risk_distance = MathAbs(current_tp - open_price) / MathMax(1.0, tp2_r_multiple);
      if(risk_distance <= 0.0)
         continue;

      const double trigger = is_buy ? (open_price + risk_distance) : (open_price - risk_distance);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      if((is_buy && market < trigger) || (!is_buy && market > trigger))
         continue;

      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * tp1_close_fraction);
      if(partial_lots <= 0.0 || volume - partial_lots < min_lot)
         continue;

      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
         QM_TM_MoveSL(ticket, NormalizePrice(open_price), "tp1_move_to_breakeven");
     }
  }

bool Strategy_ExitSignal()
  {
   if(HHMM(TimeCurrent()) < eod_close_hhmm_broker)
      return false;
   return (OurOpenPositionCount() > 0);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10265_tv-or-psvr\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
