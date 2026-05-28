#property strict
#property version   "5.0"
#property description "QM5_1162 Unger Nasdaq Close Channel"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1162;
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
input int    strategy_entry_start_minute_ny    = 30;
input int    strategy_entry_end_hour_ny        = 16;
input int    strategy_entry_end_minute_ny      = 0;
input int    strategy_close_lookback_bars      = 24;
input int    strategy_ema_fast_period          = 50;
input int    strategy_ema_slow_period          = 200;
input int    strategy_atr_period_h1            = 14;
input double strategy_sl_atr_mult              = 2.5;
input double strategy_be_trigger_atr_mult      = 2.0;
input int    strategy_be_buffer_points         = 0;
input int    strategy_max_hold_bars            = 120;
input int    strategy_max_spread_points        = 0;

const string SYMBOL_SLOT_0 = "NDX.DWX";
const string SYMBOL_SLOT_1 = "WS30.DWX";
const string SYMBOL_SLOT_2 = "SP500.DWX";

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

bool IsWeekdayNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
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

double HighestCompletedClose(const int lookback)
  {
   const int bars = MathMax(1, lookback);
   double highest = -DBL_MAX;
   int samples = 0;
   for(int shift = 2; shift < 2 + bars; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_H1, shift);
      if(close <= 0.0)
         continue;
      highest = MathMax(highest, close);
      ++samples;
     }
   return (samples == bars) ? highest : 0.0;
  }

double LowestCompletedClose(const int lookback)
  {
   const int bars = MathMax(1, lookback);
   double lowest = DBL_MAX;
   int samples = 0;
   for(int shift = 2; shift < 2 + bars; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_H1, shift);
      if(close <= 0.0)
         continue;
      lowest = MathMin(lowest, close);
      ++samples;
     }
   return (samples == bars) ? lowest : 0.0;
  }

int AtrToPoints(const double atr_value, const double mult)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr_value <= 0.0 || mult <= 0.0 || point <= 0.0)
      return 0;
   return (int)MathMax(1.0, MathRound((atr_value * mult) / point));
  }

bool Strategy_NoTradeFilter()
  {
   if(!SymbolSlotAllowed())
      return true;
   if(_Period != PERIOD_H1)
      return true;
   return false;
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

   if(HasOurOpenPosition() || !SpreadAllowsEntry())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_H1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;
   g_last_signal_bar = signal_bar;

   const datetime ny_now = BrokerToNY(TimeCurrent());
   if(!IsWeekdayNY(ny_now) || !InEntryWindowNY(ny_now))
      return false;

   const int lookback = MathMax(2, strategy_close_lookback_bars);
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double hh_close = HighestCompletedClose(lookback);
   const double ll_close = LowestCompletedClose(lookback);
   const double ema_fast = QM_EMA(_Symbol, PERIOD_H1, MathMax(1, strategy_ema_fast_period), 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_H1, MathMax(1, strategy_ema_slow_period), 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, MathMax(1, strategy_atr_period_h1), 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close1 <= 0.0 || hh_close <= 0.0 || ll_close <= 0.0 ||
      ema_fast <= 0.0 || ema_slow <= 0.0 || atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > hh_close && ema_fast > ema_slow)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - atr * strategy_sl_atr_mult, _Digits);
      req.reason = "H1_CLOSE_CHANNEL_LONG";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(close1 < ll_close && ema_fast < ema_slow)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + atr * strategy_sl_atr_mult, _Digits);
      req.reason = "H1_CLOSE_CHANNEL_SHORT";
      return (req.sl > req.price);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int trigger_points = AtrToPoints(QM_ATR(_Symbol, PERIOD_H1, MathMax(1, strategy_atr_period_h1), 1),
                                          strategy_be_trigger_atr_mult);
   if(trigger_points <= 0)
      return;

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
      QM_TM_MoveToBreakEven(ticket, trigger_points, MathMax(0, strategy_be_buffer_points));
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double ema_fast = QM_EMA(_Symbol, PERIOD_H1, MathMax(1, strategy_ema_fast_period), 1);
   if(close1 <= 0.0 || ema_fast <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_bars = (int)MathFloor((TimeCurrent() - open_time) / PeriodSeconds(PERIOD_H1));
      if(held_bars >= MathMax(1, strategy_max_hold_bars))
         return true;
      if(position_type == POSITION_TYPE_BUY && close1 < ema_fast)
         return true;
      if(position_type == POSITION_TYPE_SELL && close1 > ema_fast)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1162\",\"ea\":\"unger-nasdaq-close-channel\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
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
