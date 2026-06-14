#property strict
#property version   "5.0"
#property description "QM5_10783 TradingView BOS Forex Swing Break"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10783;
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
input int    strategy_swing_lookback_bars = 10;
input int    strategy_swing_strength_bars = 2;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 1.5;
input double strategy_target_r_multiple   = 2.0;
input int    strategy_long_start_hour     = 7;
input int    strategy_long_end_hour       = 21;
input int    strategy_short_start_hour    = 7;
input int    strategy_short_end_hour      = 21;
input int    strategy_max_spread_points   = 35;
input bool   strategy_opposite_bos_exit   = false;
input bool   strategy_session_end_flat    = true;

int    g_last_bos_dir = 0;
double g_last_swing_high = 0.0;
double g_last_swing_low = 0.0;

int CurrentBrokerHour()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
  }

bool HourInWindow(const int hour_value, const int start_hour, const int end_hour)
  {
   const int h = (hour_value % 24 + 24) % 24;
   const int s = (start_hour % 24 + 24) % 24;
   const int e = (end_hour % 24 + 24) % 24;
   if(s == e)
      return true;
   if(s < e)
      return (h >= s && h < e);
   return (h >= s || h < e);
  }

bool LongSessionOpen()
  {
   return HourInWindow(CurrentBrokerHour(), strategy_long_start_hour, strategy_long_end_hour);
  }

bool ShortSessionOpen()
  {
   return HourInWindow(CurrentBrokerHour(), strategy_short_start_hour, strategy_short_end_hour);
  }

bool AnySessionOpen()
  {
   return (LongSessionOpen() || ShortSessionOpen());
  }

double NormalizeSymbolPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool HasOurPosition(ENUM_POSITION_TYPE &position_type)
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool IsSwingHighAtShift(const int shift, const int strength)
  {
   const double center = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
   if(center <= 0.0)
      return false;

   for(int k = 1; k <= strength; ++k)
     {
      const double newer = iHigh(_Symbol, _Period, shift - k); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
      const double older = iHigh(_Symbol, _Period, shift + k); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(center <= newer || center <= older)
         return false;
     }
   return true;
  }

bool IsSwingLowAtShift(const int shift, const int strength)
  {
   const double center = iLow(_Symbol, _Period, shift); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
   if(center <= 0.0)
      return false;

   for(int k = 1; k <= strength; ++k)
     {
      const double newer = iLow(_Symbol, _Period, shift - k); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
      const double older = iLow(_Symbol, _Period, shift + k); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
      if(newer <= 0.0 || older <= 0.0)
         return false;
      if(center >= newer || center >= older)
         return false;
     }
   return true;
  }

bool FindMostRecentSwingHigh(double &out_price)
  {
   out_price = 0.0;
   const int strength = MathMax(1, strategy_swing_strength_bars);
   const int lookback = MathMax(strength + 2, strategy_swing_lookback_bars);

   for(int shift = strength + 1; shift <= lookback; ++shift)
     {
      if(IsSwingHighAtShift(shift, strength))
        {
         out_price = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
         return (out_price > 0.0);
        }
     }
   return false;
  }

bool FindMostRecentSwingLow(double &out_price)
  {
   out_price = 0.0;
   const int strength = MathMax(1, strategy_swing_strength_bars);
   const int lookback = MathMax(strength + 2, strategy_swing_lookback_bars);

   for(int shift = strength + 1; shift <= lookback; ++shift)
     {
      if(IsSwingLowAtShift(shift, strength))
        {
         out_price = iLow(_Symbol, _Period, shift); // perf-allowed: bounded structural BOS swing scan inside closed-bar hook
         return (out_price > 0.0);
        }
     }
   return false;
  }

bool UpdateBosState()
  {
   g_last_bos_dir = 0;
   g_last_swing_high = 0.0;
   g_last_swing_low = 0.0;

   double swing_high = 0.0;
   double swing_low = 0.0;
   if(!FindMostRecentSwingHigh(swing_high) || !FindMostRecentSwingLow(swing_low))
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: close-confirmed BOS structural trigger
   const double close_2 = iClose(_Symbol, _Period, 2); // perf-allowed: close-confirmed BOS structural trigger
   if(close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   g_last_swing_high = swing_high;
   g_last_swing_low = swing_low;
   if(close_1 > swing_high && close_2 <= swing_high)
      g_last_bos_dir = 1;
   else if(close_1 < swing_low && close_2 >= swing_low)
      g_last_bos_dir = -1;

   return true;
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildMarketEntry(QM_EntryRequest &req, const QM_OrderType side, const double swing_stop)
  {
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(entry <= 0.0 || swing_stop <= 0.0 || atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   const double atr_stop = (side == QM_BUY) ? (entry - atr * strategy_atr_stop_mult)
                                           : (entry + atr * strategy_atr_stop_mult);
   double sl = (side == QM_BUY) ? MathMin(swing_stop, atr_stop)
                                : MathMax(swing_stop, atr_stop);
   sl = NormalizeSymbolPrice(sl);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_r_multiple);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if(side == QM_BUY && (sl >= entry || tp <= entry))
      return false;
   if(side == QM_SELL && (sl <= entry || tp >= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "BOS_CLOSE_ABOVE_PREVIOUS_SWING_HIGH"
                                 : "BOS_CLOSE_BELOW_PREVIOUS_SWING_LOW";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   ENUM_POSITION_TYPE position_type;
   if(HasOurPosition(position_type))
      return false;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   if(!AnySessionOpen())
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   if(!UpdateBosState())
      return false;

   ENUM_POSITION_TYPE position_type;
   if(HasOurPosition(position_type))
      return false;

   if(g_last_bos_dir > 0 && LongSessionOpen())
      return BuildMarketEntry(req, QM_BUY, g_last_swing_low);
   if(g_last_bos_dir < 0 && ShortSessionOpen())
      return BuildMarketEntry(req, QM_SELL, g_last_swing_high);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!HasOurPosition(position_type))
      return false;

   if(strategy_session_end_flat)
     {
      if(position_type == POSITION_TYPE_BUY && !LongSessionOpen())
         return true;
      if(position_type == POSITION_TYPE_SELL && !ShortSessionOpen())
         return true;
     }

   if(strategy_opposite_bos_exit)
     {
      if(position_type == POSITION_TYPE_BUY && g_last_bos_dir < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_last_bos_dir > 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10783_tv_bos_forex\"}");
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
