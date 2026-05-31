#property strict
#property version   "5.0"
#property description "QM5_10670 TradingView Liquidity Sweep BOS Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10670;
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
input int    strategy_pivot_left             = 3;
input int    strategy_pivot_right            = 3;
input int    strategy_pivot_lookback         = 48;
input int    strategy_setup_timeout_bars     = 16;
input double strategy_displacement_body_min  = 0.55;
input double strategy_displacement_edge_max  = 0.30;
input double strategy_retest_edge_max        = 0.35;
input int    strategy_atr_period             = 14;
input double strategy_atr_stop_buffer_mult   = 0.10;
input double strategy_max_stop_atr           = 2.50;
input double strategy_rr_target              = 2.00;
input bool   strategy_session_filter_enabled = true;
input int    strategy_session_start_minute   = 990;  // 16:30 broker time
input int    strategy_session_end_minute     = 1080; // 18:00 broker time
input int    strategy_max_spread_points      = 200;

int MinuteOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

bool IsInSession(const datetime value)
  {
   if(!strategy_session_filter_enabled)
      return true;

   int start_minute = strategy_session_start_minute;
   int end_minute = strategy_session_end_minute;
   if(start_minute < 0)
      start_minute = 0;
   if(start_minute > 1439)
      start_minute = 1439;
   if(end_minute < 0)
      end_minute = 0;
   if(end_minute > 1439)
      end_minute = 1439;
   if(start_minute == end_minute)
      return true;

   const int now_minute = MinuteOfDay(value);
   if(start_minute < end_minute)
      return (now_minute >= start_minute && now_minute < end_minute);
   return (now_minute >= start_minute || now_minute < end_minute);
  }

bool SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   return ((ask - bid) / point <= (double)strategy_max_spread_points);
  }

double HighestHighClosed(const int start_shift, const int bars)
  {
   if(start_shift < 1 || bars < 1)
      return 0.0;

   double highest = -DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      const double value = iHigh(_Symbol, _Period, start_shift + i);
      if(value <= 0.0)
         return 0.0;
      if(value > highest)
         highest = value;
     }
   return highest;
  }

double LowestLowClosed(const int start_shift, const int bars)
  {
   if(start_shift < 1 || bars < 1)
      return 0.0;

   double lowest = DBL_MAX;
   for(int i = 0; i < bars; ++i)
     {
      const double value = iLow(_Symbol, _Period, start_shift + i);
      if(value <= 0.0)
         return 0.0;
      if(value < lowest)
         lowest = value;
     }
   return lowest;
  }

bool FindConfirmedPivotHigh(double &pivot_high)
  {
   pivot_high = 0.0;
   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 || strategy_pivot_lookback < 8)
      return false;

   const int first_shift = 2 + strategy_pivot_right;
   const int last_shift = strategy_pivot_lookback;
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      const double candidate = iHigh(_Symbol, _Period, shift);
      if(candidate <= 0.0)
         continue;

      bool valid = true;
      for(int j = 1; valid && j <= strategy_pivot_left; ++j)
         if(iHigh(_Symbol, _Period, shift + j) >= candidate)
            valid = false;
      for(int j = 1; valid && j <= strategy_pivot_right; ++j)
         if(iHigh(_Symbol, _Period, shift - j) > candidate)
            valid = false;

      if(valid)
        {
         pivot_high = candidate;
         return true;
        }
     }
   return false;
  }

bool FindConfirmedPivotLow(double &pivot_low)
  {
   pivot_low = 0.0;
   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 || strategy_pivot_lookback < 8)
      return false;

   const int first_shift = 2 + strategy_pivot_right;
   const int last_shift = strategy_pivot_lookback;
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      const double candidate = iLow(_Symbol, _Period, shift);
      if(candidate <= 0.0)
         continue;

      bool valid = true;
      for(int j = 1; valid && j <= strategy_pivot_left; ++j)
         if(iLow(_Symbol, _Period, shift + j) <= candidate)
            valid = false;
      for(int j = 1; valid && j <= strategy_pivot_right; ++j)
         if(iLow(_Symbol, _Period, shift - j) < candidate)
            valid = false;

      if(valid)
        {
         pivot_low = candidate;
         return true;
        }
     }
   return false;
  }

bool BullishDisplacement(const double level)
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double range = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double body_ratio = MathAbs(close1 - open1) / range;
   const double upper_edge = (high1 - close1) / range;
   return (close1 > open1 &&
           close1 > level &&
           body_ratio >= strategy_displacement_body_min &&
           upper_edge <= strategy_displacement_edge_max);
  }

bool BearishDisplacement(const double level)
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double range = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double body_ratio = MathAbs(close1 - open1) / range;
   const double lower_edge = (close1 - low1) / range;
   return (close1 < open1 &&
           close1 < level &&
           body_ratio >= strategy_displacement_body_min &&
           lower_edge <= strategy_displacement_edge_max);
  }

bool BullishRetest(const double bos_level)
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double range = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double upper_edge = (high1 - close1) / range;
   return (low1 <= bos_level &&
           close1 > bos_level &&
           close1 > open1 &&
           upper_edge <= strategy_retest_edge_max);
  }

bool BearishRetest(const double bos_level)
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double range = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return false;

   const double lower_edge = (close1 - low1) / range;
   return (high1 >= bos_level &&
           close1 < bos_level &&
           close1 < open1 &&
           lower_edge <= strategy_retest_edge_max);
  }

void ClearRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildTrade(QM_EntryRequest &req,
                const QM_OrderType side,
                const double swept_price,
                const double entry_price,
                const string reason)
  {
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || strategy_atr_stop_buffer_mult < 0.0 ||
      strategy_max_stop_atr <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
      sl = NormalizeDouble(swept_price - atr * strategy_atr_stop_buffer_mult, _Digits);
   else
      sl = NormalizeDouble(swept_price + atr * strategy_atr_stop_buffer_mult, _Digits);

   if(entry_price <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry_price)
      return false;
   if(side == QM_SELL && sl <= entry_price)
      return false;

   if(MathAbs(entry_price - sl) > atr * strategy_max_stop_atr)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;
   if(side == QM_BUY && tp <= entry_price)
      return false;
   if(side == QM_SELL && tp >= entry_price)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!SpreadAllowed())
      return true;
   if(!IsInSession(TimeCurrent()))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ClearRequest(req);

   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 ||
      strategy_pivot_lookback < 8 || strategy_setup_timeout_bars < 1)
      return false;
   if(strategy_displacement_body_min < 0.0 || strategy_displacement_body_min > 1.0 ||
      strategy_displacement_edge_max < 0.0 || strategy_displacement_edge_max > 1.0 ||
      strategy_retest_edge_max < 0.0 || strategy_retest_edge_max > 1.0)
      return false;

   const int min_bars = strategy_pivot_lookback + strategy_pivot_left + strategy_pivot_right + 10;
   if(Bars(_Symbol, _Period) < min_bars)
      return false;

   static int setup_state = 0;       // 1 long BOS, 2 long retest, -1 short BOS, -2 short retest
   static int setup_age = 0;
   static double setup_swept = 0.0;
   static double setup_bos = 0.0;
   static double used_long_sweep = 0.0;
   static double used_short_sweep = 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(setup_state != 0)
     {
      setup_age++;
      if(setup_age > strategy_setup_timeout_bars)
        {
         setup_state = 0;
         setup_age = 0;
         setup_swept = 0.0;
         setup_bos = 0.0;
        }
     }

   if(setup_state == 2)
     {
      if(BullishRetest(setup_bos))
        {
         if(BuildTrade(req, QM_BUY, setup_swept, ask, "LS_BOS_RETEST_LONG"))
           {
            used_long_sweep = setup_swept;
            setup_state = 0;
            setup_age = 0;
            return true;
           }
         setup_state = 0;
         setup_age = 0;
        }
      return false;
     }

   if(setup_state == -2)
     {
      if(BearishRetest(setup_bos))
        {
         if(BuildTrade(req, QM_SELL, setup_swept, bid, "LS_BOS_RETEST_SHORT"))
           {
            used_short_sweep = setup_swept;
            setup_state = 0;
            setup_age = 0;
            return true;
           }
         setup_state = 0;
         setup_age = 0;
        }
      return false;
     }

   if(setup_state == 1)
     {
      if(BullishDisplacement(setup_bos))
        {
         setup_state = 2;
         setup_age = 0;
        }
      return false;
     }

   if(setup_state == -1)
     {
      if(BearishDisplacement(setup_bos))
        {
         setup_state = -2;
         setup_age = 0;
        }
      return false;
     }

   double pivot_high = 0.0;
   double pivot_low = 0.0;
   if(!FindConfirmedPivotHigh(pivot_high) || !FindConfirmedPivotLow(pivot_low))
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   if(low1 < pivot_low && close1 > pivot_low &&
      (used_long_sweep <= 0.0 || MathAbs(low1 - used_long_sweep) > point * 2.0))
     {
      setup_state = 1;
      setup_age = 0;
      setup_swept = low1;
      setup_bos = pivot_high;
      return false;
     }

   if(high1 > pivot_high && close1 < pivot_high &&
      (used_short_sweep <= 0.0 || MathAbs(high1 - used_short_sweep) > point * 2.0))
     {
      setup_state = -1;
      setup_age = 0;
      setup_swept = high1;
      setup_bos = pivot_low;
      return false;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card management is fixed stop plus fixed 2R target; no trailing or partial close.
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
