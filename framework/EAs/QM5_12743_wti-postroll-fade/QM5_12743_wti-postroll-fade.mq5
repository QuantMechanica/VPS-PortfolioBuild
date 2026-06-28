#property strict
#property version   "5.0"
#property description "QM5_12743 WTI Post-Roll Impulse Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12743 - WTI Post-Roll Impulse Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - approximates the monthly CME WTI expiry day from the broker calendar
//   - trades only after the immediate expiry-breakout window has passed
//   - fades stretched D1 post-roll impulses back toward a short D1 mean
// Runtime uses MT5 OHLC/broker calendar only; no CME feed, API, CSV, volume,
// open interest, futures curve, or external expiry calendar.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12743;
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
input int    strategy_post_start_days     = 3;
input int    strategy_post_end_days       = 7;
input int    strategy_impulse_days        = 3;
input double strategy_min_abs_return_pct  = 2.0;
input int    strategy_reversion_sma       = 10;
input double strategy_close_location      = 0.65;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 5;
input int    strategy_max_spread_points   = 1000;

int g_last_signal_day_key = 0;

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

int Strategy_DaysInMonth(const int year, const int month)
  {
   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0));
      return leap ? 29 : 28;
     }
   if(month == 4 || month == 6 || month == 9 || month == 11)
      return 30;
   return 31;
  }

datetime Strategy_DateAtMidnight(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsBusinessDay(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_DateAtMidnight(year, month, day), dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

int Strategy_ExpiryDayApprox(const int year, const int month)
  {
   const int days_in_month = Strategy_DaysInMonth(year, month);
   int anchor_day = MathMin(25, days_in_month);

   if(!Strategy_IsBusinessDay(year, month, anchor_day))
     {
      do
        {
         --anchor_day;
        }
      while(anchor_day > 1 && !Strategy_IsBusinessDay(year, month, anchor_day));
     }

   int count = 0;
   for(int day = anchor_day - 1; day >= 1; --day)
     {
      if(!Strategy_IsBusinessDay(year, month, day))
         continue;
      ++count;
      if(count == 3)
         return day;
     }

   return MathMax(1, anchor_day - 3);
  }

bool Strategy_DateInPostRollWindow(const datetime t)
  {
   if(t <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int expiry_day = Strategy_ExpiryDayApprox(dt.year, dt.mon);
   const int start_day = MathMin(Strategy_DaysInMonth(dt.year, dt.mon), expiry_day + strategy_post_start_days);
   const int end_day = MathMin(Strategy_DaysInMonth(dt.year, dt.mon), expiry_day + strategy_post_end_days);
   return (dt.day >= start_day && dt.day <= end_day);
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

bool Strategy_LoadClosedState(double &close_last,
                              double &impulse_return_pct,
                              double &sma_last,
                              double &atr_last,
                              double &range_last,
                              double &close_location,
                              datetime &signal_time,
                              int &signal_day_key)
  {
   const int impulse = MathMax(1, strategy_impulse_days);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, impulse + 1, rates) < impulse + 1) // perf-allowed: D1 post-roll impulse state, new-bar gated.
      return false;

   signal_time = rates[0].time;
   signal_day_key = Strategy_DayKey(signal_time);
   close_last = rates[0].close;
   const double close_past = rates[impulse].close;
   const double high_last = rates[0].high;
   const double low_last = rates[0].low;
   range_last = high_last - low_last;
   if(close_last <= 0.0 || close_past <= 0.0 || range_last <= 0.0 || signal_day_key <= 0)
      return false;

   impulse_return_pct = ((close_last / close_past) - 1.0) * 100.0;
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_reversion_sma, 1, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_last <= 0.0 || atr_last <= 0.0)
      return false;

   close_location = (close_last - low_last) / range_last;
   return (MathIsValidNumber(impulse_return_pct) && MathIsValidNumber(close_location));
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const datetime current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 post-roll exit window gate.
   const bool in_post_window = Strategy_DateInPostRollWindow(current_bar_time);

   double close_last = 0.0;
   double impulse_return_pct = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   double range_last = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   const bool have_state = Strategy_LoadClosedState(close_last, impulse_return_pct, sma_last,
                                                    atr_last, range_last, close_location,
                                                    signal_time, signal_day_key);

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
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
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = (!in_post_window);

      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_BUY && close_last >= sma_last)
         should_close = true;
      else if(have_state && pos_type == POSITION_TYPE_SELL && close_last <= sma_last)
         should_close = true;
      else if(pos_type != POSITION_TYPE_BUY && pos_type != POSITION_TYPE_SELL)
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
   if(strategy_post_start_days < 1 || strategy_post_end_days < strategy_post_start_days)
      return true;
   if(strategy_post_end_days > 12)
      return true;
   if(strategy_impulse_days <= 0 || strategy_min_abs_return_pct <= 0.0)
      return true;
   if(strategy_reversion_sma <= 1 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_close_location <= 0.5 || strategy_close_location >= 1.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12743_WTI_POSTROLL_FADE";
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

   double close_last = 0.0;
   double impulse_return_pct = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   double range_last = 0.0;
   double close_location = 0.0;
   datetime signal_time = 0;
   int signal_day_key = 0;
   if(!Strategy_LoadClosedState(close_last, impulse_return_pct, sma_last, atr_last,
                                range_last, close_location, signal_time, signal_day_key))
      return false;
   if(signal_day_key <= 0 || signal_day_key == g_last_signal_day_key)
      return false;
   if(!Strategy_DateInPostRollWindow(signal_time))
      return false;

   int direction = 0;
   if(impulse_return_pct >= strategy_min_abs_return_pct &&
      close_last > sma_last &&
      close_location >= strategy_close_location)
      direction = -1;
   else if(impulse_return_pct <= -strategy_min_abs_return_pct &&
           close_last < sma_last &&
           close_location <= (1.0 - strategy_close_location))
      direction = 1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "WTI_POSTROLL_NEG_IMPULSE_LONG_FADE"
                                : "WTI_POSTROLL_POS_IMPULSE_SHORT_FADE";
   g_last_signal_day_key = signal_day_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12743\",\"ea\":\"wti-postroll-fade\"}");
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
