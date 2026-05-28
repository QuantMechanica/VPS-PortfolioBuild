#property strict
#property version   "5.0"
#property description "QM5_1155 Unger Nasdaq ATR Spike Short"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1155;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                = 336;
input string qm_news_min_impact                     = "high";
input QM_NewsMode qm_news_mode_legacy               = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_start_hour_ny      = 9;
input int    strategy_entry_start_minute_ny    = 45;
input int    strategy_entry_end_hour_ny        = 15;
input int    strategy_entry_end_minute_ny      = 15;
input int    strategy_session_close_hour_ny    = 16;
input int    strategy_session_close_minute_ny  = 0;
input int    strategy_preclose_flatten_minutes = 5;
input int    strategy_atr_period_m5            = 14;
input int    strategy_body_lookback_bars       = 20;
input double strategy_body_mult                = 1.8;
input double strategy_atr_body_mult            = 0.8;
input double strategy_sl_atr_mult              = 1.5;
input double strategy_tp_atr_mult              = 2.5;
input int    strategy_daily_atr_period         = 14;
input int    strategy_daily_atr_percentile_bars = 252;
input double strategy_min_daily_atr_percentile = 30.0;
input bool   strategy_use_ema_exit             = true;
input int    strategy_ema_exit_period          = 20;
input int    strategy_max_spread_points        = 0;

const string SYMBOL_SLOT_0 = "NDX.DWX";
const string SYMBOL_SLOT_1 = "WS30.DWX";
const string SYMBOL_SLOT_2 = "SP500.DWX";

int      g_day_key = 0;
bool     g_trade_taken_today = false;
datetime g_last_signal_bar = 0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

int NyUtcOffsetHours(const datetime utc)
  {
   return QM_IsUSDSTUTC(utc) ? -4 : -5;
  }

datetime BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + NyUtcOffsetHours(utc) * 3600;
  }

datetime NYLocalToBroker(const datetime ny_now, const int hour, const int minute)
  {
   MqlDateTime dt;
   TimeToStruct(ny_now, dt);
   dt.hour = ClampInt(hour, 0, 23);
   dt.min = ClampInt(minute, 0, 59);
   dt.sec = 0;

   const datetime ny_stamp = StructToTime(dt);
   datetime utc_guess = ny_stamp + 5 * 3600;
   if(QM_IsUSDSTUTC(utc_guess))
      utc_guess = ny_stamp + 4 * 3600;
   return QM_UTCToBroker(utc_guess);
  }

int DayKeyFromTime(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool IsWeekdayNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

void ResetSessionIfNeeded()
  {
   const int today = DayKeyFromTime(BrokerToNY(TimeCurrent()));
   if(today == g_day_key)
      return;

   g_day_key = today;
   g_trade_taken_today = false;
   g_last_signal_bar = 0;
  }

string ExpectedSymbolForSlot()
  {
   if(qm_magic_slot_offset == 0)
      return SYMBOL_SLOT_0;
   if(qm_magic_slot_offset == 1)
      return SYMBOL_SLOT_1;
   if(qm_magic_slot_offset == 2)
      return SYMBOL_SLOT_2;
   return "";
  }

bool SymbolSlotAllowed()
  {
   const string expected = ExpectedSymbolForSlot();
   return (expected != "" && _Symbol == expected);
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

bool SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool InEntryWindowNY(const datetime ny_now)
  {
   const datetime start_broker = NYLocalToBroker(ny_now,
                                                 strategy_entry_start_hour_ny,
                                                 strategy_entry_start_minute_ny);
   const datetime end_broker = NYLocalToBroker(ny_now,
                                               strategy_entry_end_hour_ny,
                                               strategy_entry_end_minute_ny);
   const datetime now_broker = TimeCurrent();
   return (now_broker >= start_broker && now_broker <= end_broker);
  }

bool PastSessionFlattenTime()
  {
   const datetime ny_now = BrokerToNY(TimeCurrent());
   const datetime close_broker = NYLocalToBroker(ny_now,
                                                 strategy_session_close_hour_ny,
                                                 strategy_session_close_minute_ny);
   const datetime flatten_broker = close_broker - MathMax(0, strategy_preclose_flatten_minutes) * 60;
   return (TimeCurrent() >= flatten_broker);
  }

double AverageBody(const int lookback)
  {
   const int bars = MathMax(1, lookback);
   double sum = 0.0;
   int samples = 0;
   for(int shift = 2; shift < 2 + bars; ++shift)
     {
      const double open = iOpen(_Symbol, PERIOD_M5, shift);
      const double close = iClose(_Symbol, PERIOD_M5, shift);
      if(open <= 0.0 || close <= 0.0)
         continue;
      sum += MathAbs(close - open);
      ++samples;
     }
   if(samples < MathMin(10, bars))
      return 0.0;
   return sum / (double)samples;
  }

double DailyAtrPercentileRank()
  {
   const double current = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_daily_atr_period), 1);
   if(current <= 0.0)
      return -1.0;

   const int lookback = MathMax(20, strategy_daily_atr_percentile_bars);
   int samples = 0;
   int below_or_equal = 0;
   for(int shift = 2; shift < 2 + lookback; ++shift)
     {
      const double sample = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_daily_atr_period), shift);
      if(sample <= 0.0)
         continue;
      ++samples;
      if(sample <= current)
         ++below_or_equal;
     }

   if(samples < 20)
      return -1.0;
   return 100.0 * (double)below_or_equal / (double)samples;
  }

bool DailyAtrFilterPass()
  {
   if(strategy_min_daily_atr_percentile <= 0.0)
      return true;
   const double rank = DailyAtrPercentileRank();
   if(rank < 0.0)
      return false;
   return (rank >= strategy_min_daily_atr_percentile);
  }

void InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   ResetSessionIfNeeded();
   if(!SymbolSlotAllowed())
      return true;
   if(_Period != PERIOD_M5)
      return true;
   if(strategy_atr_period_m5 <= 0 || strategy_body_lookback_bars <= 0)
      return true;
   if(strategy_body_mult <= 0.0 || strategy_atr_body_mult <= 0.0)
      return true;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
      return true;
   if(strategy_ema_exit_period <= 1)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitRequest(req);
   ResetSessionIfNeeded();

   if(g_trade_taken_today || HasOurOpenPosition())
      return false;
   if(!SpreadAllowsEntry())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_M5, 1);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;
   g_last_signal_bar = signal_bar;

   const datetime ny_now = BrokerToNY(TimeCurrent());
   if(!IsWeekdayNY(ny_now) || !InEntryWindowNY(ny_now))
      return false;
   if(!DailyAtrFilterPass())
      return false;

   const double open1 = iOpen(_Symbol, PERIOD_M5, 1);
   const double close1 = iClose(_Symbol, PERIOD_M5, 1);
   const double low2 = iLow(_Symbol, PERIOD_M5, 2);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(open1 <= 0.0 || close1 <= 0.0 || low2 <= 0.0 || bid <= 0.0)
      return false;
   if(close1 >= open1 || close1 >= low2)
      return false;

   const double body = MathAbs(close1 - open1);
   const double avg_body = AverageBody(strategy_body_lookback_bars);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, MathMax(1, strategy_atr_period_m5), 1);
   if(body <= 0.0 || avg_body <= 0.0 || atr <= 0.0)
      return false;
   if(body <= strategy_body_mult * avg_body)
      return false;
   if(body <= strategy_atr_body_mult * atr)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr, strategy_sl_atr_mult);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, bid, atr * strategy_tp_atr_mult);
   req.reason = "UNGER_ATR_SPIKE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   if(req.sl <= bid || req.tp >= bid || req.tp <= 0.0)
      return false;

   g_trade_taken_today = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;
   if(PastSessionFlattenTime())
      return true;

   if(!strategy_use_ema_exit)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_M5, MathMax(2, strategy_ema_exit_period), 1);
   return (close1 > 0.0 && ema > 0.0 && close1 > ema);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1155\",\"ea\":\"unger-nasdaq-atr-spike-short\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_M5))
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
