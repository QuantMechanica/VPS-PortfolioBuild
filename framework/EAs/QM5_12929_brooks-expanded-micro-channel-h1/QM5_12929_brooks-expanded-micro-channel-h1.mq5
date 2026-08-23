#property strict
#property version   "5.0"
#property description "QM5_12929 Brooks Expanded Micro-Channel Continuation H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12929 Brooks Expanded Micro-Channel Continuation (H1)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/
//       QM5_12929_brooks-expanded-micro-channel-h1.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12929;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf                 = PERIOD_H1;
input int    strategy_atr_period                  = 14;
input int    strategy_fast_sma_period             = 50;
input int    strategy_slow_sma_period             = 200;
input int    strategy_channel_min_bars            = 8;
input int    strategy_channel_max_bars            = 20;
input double strategy_stair_noise_atr             = 0.25;
input double strategy_max_body_atr                = 1.50;
input double strategy_min_slope_atr_per_bar       = 0.15;
input double strategy_max_range_atr_per_bar       = 0.50;
input double strategy_entry_buffer_atr            = 0.50;
input double strategy_initial_sl_buffer_atr       = 0.50;
input double strategy_initial_sl_cap_atr          = 3.00;
input double strategy_tp_atr                      = 2.00;
input int    strategy_pending_valid_bars          = 3;
input int    strategy_trail_lookback_bars         = 3;
input double strategy_trail_buffer_atr            = 0.10;
input int    strategy_time_stop_bars              = 36;
input int    strategy_reuse_guard_bars            = 12;
input int    strategy_spread_lookback_bars        = 20;
input double strategy_spread_average_multiplier   = 1.50;
input int    strategy_session_start_hour          = 7;
input int    strategy_session_end_hour            = 21;

bool g_new_bar = false;

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
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
      return true;
     }
   return false;
  }

bool Strategy_HasPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_ReuseGuardActive()
  {
   if(strategy_reuse_guard_bars <= 0)
      return false;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 14 * 24 * 60 * 60, now))
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime entry_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const int bars_since_entry = iBarShift(_Symbol, strategy_tf, entry_time, false);
      if(bars_since_entry >= 0 && bars_since_entry < strategy_reuse_guard_bars)
         return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_lookback_bars <= 0 || strategy_spread_average_multiplier <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   double spread_sum = 0.0;
   int spread_count = 0;
   for(int shift = 1; shift <= strategy_spread_lookback_bars; ++shift)
     {
      const long sample = (long)iSpread(_Symbol, strategy_tf, shift); // card-authorized closed-bar sample
      if(sample <= 0)
         continue;
      spread_sum += (double)sample;
      ++spread_count;
     }
   if(spread_count == 0)
      return true;

   const double average_spread = spread_sum / (double)spread_count;
   return ((double)current_spread <= strategy_spread_average_multiplier * average_spread);
  }

bool Strategy_SessionAllowsEntry(int &seconds_remaining)
  {
   seconds_remaining = 0;
   MqlDateTime broker;
   TimeToStruct(TimeCurrent(), broker);
   if(broker.hour < strategy_session_start_hour || broker.hour >= strategy_session_end_hour)
      return false;
   seconds_remaining = (strategy_session_end_hour - broker.hour) * 3600
                     - broker.min * 60 - broker.sec;
   return (seconds_remaining > 0);
  }

double Strategy_RegressionSlope(const int direction, const int bars)
  {
   if(bars < 2)
      return 0.0;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int shift = bars; shift >= 1; --shift)
     {
      const double x = (double)(bars - shift);
      const double y = (direction > 0)
                       ? iHigh(_Symbol, strategy_tf, shift) // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
                       : iLow(_Symbol, strategy_tf, shift); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
      if(y <= 0.0)
         return 0.0;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double count = (double)bars;
   const double denominator = count * sum_xx - sum_x * sum_x;
   if(MathAbs(denominator) <= 1e-12)
      return 0.0;
   return (count * sum_xy - sum_x * sum_y) / denominator;
  }

int Strategy_DetectExpandedChannel(const int direction,
                                   const double atr,
                                   double &window_high,
                                   double &window_low)
  {
   if(atr <= 0.0)
      return 0;

   const int minimum_bars = MathMax(2, strategy_channel_min_bars);
   const int maximum_bars = MathMax(minimum_bars, strategy_channel_max_bars);
   for(int bars = maximum_bars; bars >= minimum_bars; --bars)
     {
      bool valid = true;
      double highest = -DBL_MAX;
      double lowest = DBL_MAX;

      for(int shift = 1; shift <= bars && valid; ++shift)
        {
         const double open_price = iOpen(_Symbol, strategy_tf, shift); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
         const double close_price = iClose(_Symbol, strategy_tf, shift); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
         const double high_price = iHigh(_Symbol, strategy_tf, shift); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
         const double low_price = iLow(_Symbol, strategy_tf, shift); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
         if(open_price <= 0.0 || close_price <= 0.0 || high_price <= low_price)
           {
            valid = false;
            break;
           }
         if(MathAbs(close_price - open_price) > strategy_max_body_atr * atr)
           {
            valid = false;
            break;
           }

         highest = MathMax(highest, high_price);
         lowest = MathMin(lowest, low_price);

         if(shift < bars)
           {
            const double older_high = iHigh(_Symbol, strategy_tf, shift + 1); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
            const double older_low = iLow(_Symbol, strategy_tf, shift + 1); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
            if(direction > 0)
              {
               if(high_price <= older_high ||
                  low_price < older_low - strategy_stair_noise_atr * atr)
                  valid = false;
              }
            else
              {
               if(low_price >= older_low ||
                  high_price > older_high + strategy_stair_noise_atr * atr)
                  valid = false;
              }
           }
        }
      if(!valid)
         continue;

      const double slope = Strategy_RegressionSlope(direction, bars);
      if(direction > 0 && slope < strategy_min_slope_atr_per_bar * atr)
         continue;
      if(direction < 0 && slope > -strategy_min_slope_atr_per_bar * atr)
         continue;

      if((highest - lowest) / (double)bars > strategy_max_range_atr_per_bar * atr)
         continue;

      window_high = highest;
      window_low = lowest;
      return bars;
     }
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_tf || strategy_tf != PERIOD_H1)
      return true;
   if(strategy_atr_period < 2 || strategy_fast_sma_period < 2 ||
      strategy_slow_sma_period <= strategy_fast_sma_period ||
      strategy_channel_min_bars < 2 ||
      strategy_channel_max_bars < strategy_channel_min_bars ||
      strategy_pending_valid_bars < 1 || strategy_trail_lookback_bars < 1 ||
      strategy_session_start_hour < 0 || strategy_session_end_hour > 24 ||
      strategy_session_end_hour <= strategy_session_start_hour)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0 || Strategy_HasPendingOrder())
      return false;
   if(Strategy_ReuseGuardActive() || !Strategy_SpreadAllowsEntry())
      return false;

   int session_seconds_remaining = 0;
   if(!Strategy_SessionAllowsEntry(session_seconds_remaining))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
   const double sma_fast = QM_SMA(_Symbol, strategy_tf, strategy_fast_sma_period, 1);
   const double sma_slow = QM_SMA(_Symbol, strategy_tf, strategy_slow_sma_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || close1 <= 0.0 || sma_fast <= 0.0 || sma_slow <= 0.0 ||
      ask <= 0.0 || bid <= 0.0)
      return false;

   const int requested_valid_seconds = strategy_pending_valid_bars * PeriodSeconds(strategy_tf);
   req.expiration_seconds = MathMin(requested_valid_seconds, session_seconds_remaining);
   if(req.expiration_seconds <= 0)
      return false;

   double window_high = 0.0;
   double window_low = 0.0;
   if(close1 > sma_fast && sma_fast > sma_slow &&
      Strategy_DetectExpandedChannel(+1, atr, window_high, window_low) > 0)
     {
      const double newest_high = iHigh(_Symbol, strategy_tf, 1); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
      const double entry = newest_high + strategy_entry_buffer_atr * atr;
      const double structural_sl = window_low - strategy_initial_sl_buffer_atr * atr;
      const double sl = MathMax(structural_sl, entry - strategy_initial_sl_cap_atr * atr);
      const double tp = entry + strategy_tp_atr * atr;
      if(entry <= ask || sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "BROOKS_EXPANDED_MICRO_CHANNEL_BUY_H1";
      return true;
     }

   window_high = 0.0;
   window_low = 0.0;
   if(close1 < sma_fast && sma_fast < sma_slow &&
      Strategy_DetectExpandedChannel(-1, atr, window_high, window_low) > 0)
     {
      const double newest_low = iLow(_Symbol, strategy_tf, 1); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
      const double entry = newest_low - strategy_entry_buffer_atr * atr;
      const double structural_sl = window_high + strategy_initial_sl_buffer_atr * atr;
      const double sl = MathMin(structural_sl, entry + strategy_initial_sl_cap_atr * atr);
      const double tp = entry - strategy_tp_atr * atr;
      if(entry >= bid || entry <= 0.0 || sl <= entry || tp <= 0.0)
         return false;

      req.type = QM_SELL_STOP;
      req.price = QM_TM_NormalizePrice(_Symbol, entry);
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "BROOKS_EXPANDED_MICRO_CHANNEL_SELL_H1";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!g_new_bar)
      return;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_SelectOurPosition(ticket, position_type) || !PositionSelectByTicket(ticket))
      return;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   double trail_extreme = (position_type == POSITION_TYPE_BUY) ? DBL_MAX : -DBL_MAX;
   for(int shift = 1; shift <= strategy_trail_lookback_bars; ++shift)
     {
      if(position_type == POSITION_TYPE_BUY)
         trail_extreme = MathMin(trail_extreme, iLow(_Symbol, strategy_tf, shift)); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
      else
         trail_extreme = MathMax(trail_extreme, iHigh(_Symbol, strategy_tf, shift)); // perf-allowed: closed-bar structural OHLC, evaluated only after QM_IsNewBar
     }

   const double current_sl = PositionGetDouble(POSITION_SL);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double proposed = QM_TM_NormalizePrice(
         _Symbol, trail_extreme - strategy_trail_buffer_atr * atr);
      if(proposed > current_sl && proposed < bid)
         QM_TM_MoveSL(ticket, proposed, "brooks_expanded_three_bar_trail");
     }
   else
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double proposed = QM_TM_NormalizePrice(
         _Symbol, trail_extreme + strategy_trail_buffer_atr * atr);
      if((current_sl <= 0.0 || proposed < current_sl) && proposed > ask)
         QM_TM_MoveSL(ticket, proposed, "brooks_expanded_three_bar_trail");
     }
  }

bool Strategy_ExitSignal()
  {
   if(!g_new_bar || strategy_time_stop_bars <= 0)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_SelectOurPosition(ticket, position_type) || !PositionSelectByTicket(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   return (bars_since_open >= strategy_time_stop_bars);
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_12929\",\"ea\":\"brooks-expanded-micro-channel-h1\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   g_new_bar = QM_IsNewBar(_Symbol, strategy_tf);
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(
         _Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !g_new_bar)
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
