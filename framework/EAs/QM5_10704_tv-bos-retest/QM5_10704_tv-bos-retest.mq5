#property strict
#property version   "5.0"
#property description "QM5_10704 TradingView BOS Retest Scale"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy-specific code implements the five Strategy_* hooks only; framework
// lifecycle, risk, magic, news, stress, Friday-close, and entry plumbing stay
// delegated to QM_Common and the V5 helpers.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10704;
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
input int    strategy_pivot_left              = 16;
input int    strategy_pivot_right             = 3;
input int    strategy_retest_window_bars      = 15;
input int    strategy_bos_max_age_bars        = 30;
input int    strategy_reclaim_mode            = 0;     // 0 close, 1 wick rejection, 2 full bar
input int    strategy_atr_period              = 14;
input double strategy_atr_min_stop_mult       = 1.25;
input double strategy_structure_buffer_atr    = 0.10;
input double strategy_rr_target               = 2.00;
input bool   strategy_volume_filter_enabled   = false;
input int    strategy_volume_lookback_bars    = 20;
input double strategy_volume_min_ratio        = 1.20;
input bool   strategy_scale_out_enabled       = false;
input double strategy_tp1_rr                  = 1.00;
input double strategy_tp2_rr                  = 2.00;
input double strategy_tp3_rr                  = 3.00;
input double strategy_tp1_close_fraction      = 0.33;
input double strategy_tp2_close_fraction      = 0.33;
input double strategy_be_buffer_atr_mult      = 0.05;
input bool   strategy_sunday_filter_enabled   = true;
input bool   strategy_session_filter_enabled  = false;
input int    strategy_session_start_minute    = 420;
input int    strategy_session_end_minute      = 1320;
input int    strategy_max_spread_points       = 250;

void ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int MinuteOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

bool IsFxSymbol()
  {
   string base = _Symbol;
   const int dot = StringFind(base, ".");
   if(dot > 0)
      base = StringSubstr(base, 0, dot);

   if(StringFind(base, "XAU") == 0 || StringFind(base, "XAG") == 0 ||
      StringFind(base, "XTI") == 0 || StringFind(base, "XNG") == 0)
      return false;

   return (StringLen(base) == 6 &&
           (StringFind(base, "USD") >= 0 ||
            StringFind(base, "EUR") >= 0 ||
            StringFind(base, "GBP") >= 0 ||
            StringFind(base, "JPY") >= 0 ||
            StringFind(base, "CHF") >= 0 ||
            StringFind(base, "CAD") >= 0 ||
            StringFind(base, "AUD") >= 0 ||
            StringFind(base, "NZD") >= 0));
  }

bool SessionAllows(const datetime value)
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

bool SpreadAllows()
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

bool VolumeAllowsBos()
  {
   if(!strategy_volume_filter_enabled)
      return true;
   if(strategy_volume_lookback_bars < 2 || strategy_volume_min_ratio <= 0.0)
      return false;

   const double bos_volume = (double)iVolume(_Symbol, _Period, 1);
   if(bos_volume <= 0.0)
      return false;

   double sum_volume = 0.0;
   int count = 0;
   for(int shift = 2; shift < 2 + strategy_volume_lookback_bars; ++shift)
     {
      const double volume = (double)iVolume(_Symbol, _Period, shift);
      if(volume <= 0.0)
         continue;
      sum_volume += volume;
      count++;
     }

   if(count <= 0 || sum_volume <= 0.0)
      return false;
   return (bos_volume >= (sum_volume / (double)count) * strategy_volume_min_ratio);
  }

bool FindRecentPivots(double &pivot_high,
                      int &pivot_high_shift,
                      double &pivot_low,
                      int &pivot_low_shift)
  {
   pivot_high = 0.0;
   pivot_low = 0.0;
   pivot_high_shift = 0;
   pivot_low_shift = 0;

   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 ||
      strategy_bos_max_age_bars < 1)
      return false;

   const int first_shift = strategy_pivot_right + 1;
   const int last_shift = strategy_bos_max_age_bars + strategy_pivot_right;

   for(int shift = first_shift; shift <= last_shift && pivot_high <= 0.0; ++shift)
     {
      const double candidate = iHigh(_Symbol, _Period, shift);
      bool valid = (candidate > 0.0);
      for(int j = 1; valid && j <= strategy_pivot_left; ++j)
         if(iHigh(_Symbol, _Period, shift + j) >= candidate)
            valid = false;
      for(int j = 1; valid && j <= strategy_pivot_right; ++j)
         if(iHigh(_Symbol, _Period, shift - j) > candidate)
            valid = false;
      if(valid)
        {
         pivot_high = candidate;
         pivot_high_shift = shift;
        }
     }

   for(int shift = first_shift; shift <= last_shift && pivot_low <= 0.0; ++shift)
     {
      const double candidate = iLow(_Symbol, _Period, shift);
      bool valid = (candidate > 0.0);
      for(int j = 1; valid && j <= strategy_pivot_left; ++j)
         if(iLow(_Symbol, _Period, shift + j) <= candidate)
            valid = false;
      for(int j = 1; valid && j <= strategy_pivot_right; ++j)
         if(iLow(_Symbol, _Period, shift - j) < candidate)
            valid = false;
      if(valid)
        {
         pivot_low = candidate;
         pivot_low_shift = shift;
        }
     }

   return (pivot_high > 0.0 && pivot_low > 0.0);
  }

bool LongReclaimConfirmed(const double level)
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;
   if(low1 > level)
      return false;

   if(strategy_reclaim_mode == 1)
      return (close1 > level && close1 > open1);
   if(strategy_reclaim_mode == 2)
      return (open1 > level && close1 > level);
   return (close1 > level);
  }

bool ShortReclaimConfirmed(const double level)
  {
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;
   if(high1 < level)
      return false;

   if(strategy_reclaim_mode == 1)
      return (close1 < level && close1 < open1);
   if(strategy_reclaim_mode == 2)
      return (open1 < level && close1 < level);
   return (close1 < level);
  }

bool BuildMarketTrade(QM_EntryRequest &req,
                      const QM_OrderType side,
                      const double structure_stop,
                      const string reason)
  {
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0 ||
      strategy_atr_min_stop_mult <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? ask : bid;
   const double buffer = MathMax(0.0, strategy_structure_buffer_atr) * atr;
   const double min_stop_distance = atr * strategy_atr_min_stop_mult;

   double sl = 0.0;
   if(side == QM_BUY)
     {
      sl = structure_stop - buffer;
      if(entry - sl < min_stop_distance)
         sl = entry - min_stop_distance;
      if(sl <= 0.0 || sl >= entry)
         return false;
     }
   else
     {
      sl = structure_stop + buffer;
      if(sl - entry < min_stop_distance)
         sl = entry + min_stop_distance;
      if(sl <= entry)
         return false;
     }

   const double rr = strategy_scale_out_enabled ? strategy_tp3_rr : strategy_rr_target;
   if(rr <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, rr);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.tp <= 0.0)
      return false;
   if(side == QM_BUY && req.tp <= entry)
      return false;
   if(side == QM_SELL && req.tp >= entry)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!SpreadAllows())
      return true;

   const datetime broker_now = TimeCurrent();
   if(!SessionAllows(broker_now))
      return true;

   if(strategy_sunday_filter_enabled && IsFxSymbol())
     {
      MqlDateTime dt;
      TimeToStruct(broker_now, dt);
      if(dt.day_of_week == 0)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetRequest(req);

   if(strategy_pivot_left < 1 || strategy_pivot_right < 1 ||
      strategy_retest_window_bars < 1 || strategy_bos_max_age_bars < 1 ||
      strategy_atr_period < 1 || strategy_reclaim_mode < 0 || strategy_reclaim_mode > 2)
      return false;

   const int bars_needed = strategy_bos_max_age_bars + strategy_pivot_left +
                           strategy_pivot_right + strategy_volume_lookback_bars + 10;
   if(Bars(_Symbol, _Period) < bars_needed)
      return false;

   static int setup_dir = 0;
   static int setup_age = 0;
   static double setup_level = 0.0;
   static double setup_structure_stop = 0.0;
   static double used_long_level = 0.0;
   static double used_short_level = 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   if(setup_dir != 0)
     {
      setup_age++;
      if(setup_age > strategy_retest_window_bars || setup_age > strategy_bos_max_age_bars)
        {
         setup_dir = 0;
         setup_age = 0;
         setup_level = 0.0;
         setup_structure_stop = 0.0;
        }
     }

   if(setup_dir > 0)
     {
      if(LongReclaimConfirmed(setup_level))
        {
         if(BuildMarketTrade(req, QM_BUY, setup_structure_stop, "BOS_RETEST_LONG"))
           {
            used_long_level = setup_level;
            setup_dir = 0;
            setup_age = 0;
            return true;
           }
         setup_dir = 0;
         setup_age = 0;
        }
      return false;
     }

   if(setup_dir < 0)
     {
      if(ShortReclaimConfirmed(setup_level))
        {
         if(BuildMarketTrade(req, QM_SELL, setup_structure_stop, "BOS_RETEST_SHORT"))
           {
            used_short_level = setup_level;
            setup_dir = 0;
            setup_age = 0;
            return true;
           }
         setup_dir = 0;
         setup_age = 0;
        }
      return false;
     }

   double pivot_high = 0.0;
   double pivot_low = 0.0;
   int pivot_high_shift = 0;
   int pivot_low_shift = 0;
   if(!FindRecentPivots(pivot_high, pivot_high_shift, pivot_low, pivot_low_shift))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;
   if(!VolumeAllowsBos())
      return false;

   const bool long_level_unused = (used_long_level <= 0.0 ||
                                   MathAbs(pivot_high - used_long_level) > point * 0.5);
   if(long_level_unused && close1 > pivot_high && close2 <= pivot_high)
     {
      setup_dir = 1;
      setup_age = 0;
      setup_level = pivot_high;
      setup_structure_stop = pivot_low;
      return false;
     }

   const bool short_level_unused = (used_short_level <= 0.0 ||
                                    MathAbs(pivot_low - used_short_level) > point * 0.5);
   if(short_level_unused && close1 < pivot_low && close2 >= pivot_low)
     {
      setup_dir = -1;
      setup_age = 0;
      setup_level = pivot_low;
      setup_structure_stop = pivot_high;
      return false;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_scale_out_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   ulong ticket = 0;
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
      break;
     }

   static ulong managed_ticket = 0;
   static double initial_entry = 0.0;
   static double initial_sl = 0.0;
   static double initial_volume = 0.0;
   static bool tp1_done = false;
   static bool tp2_done = false;

   if(ticket == 0)
     {
      managed_ticket = 0;
      initial_entry = 0.0;
      initial_sl = 0.0;
      initial_volume = 0.0;
      tp1_done = false;
      tp2_done = false;
      return;
     }

   if(!PositionSelectByTicket(ticket))
      return;

   if(ticket != managed_ticket)
     {
      managed_ticket = ticket;
      initial_entry = PositionGetDouble(POSITION_PRICE_OPEN);
      initial_sl = PositionGetDouble(POSITION_SL);
      initial_volume = PositionGetDouble(POSITION_VOLUME);
      tp1_done = false;
      tp2_done = false;
     }

   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (pos_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(initial_entry <= 0.0 || initial_sl <= 0.0 || initial_volume <= 0.0 ||
      current_volume <= 0.0 || market <= 0.0 || point <= 0.0)
      return;

   const double risk = MathAbs(initial_entry - initial_sl);
   if(risk <= 0.0)
      return;

   const double moved = is_buy ? (market - initial_entry) : (initial_entry - market);
   if(moved <= 0.0)
      return;

   if(!tp1_done && moved >= risk * strategy_tp1_rr)
     {
      double close_lots = QM_TM_NormalizeVolume(_Symbol, initial_volume * strategy_tp1_close_fraction);
      if(close_lots > 0.0 && close_lots < current_volume && QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
        {
         tp1_done = true;
         const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
         const double be_buffer = (atr > 0.0) ? atr * MathMax(0.0, strategy_be_buffer_atr_mult) : 0.0;
         const double be_sl = is_buy ? (initial_entry + be_buffer) : (initial_entry - be_buffer);
         QM_TM_MoveSL(ticket, be_sl, "BOS_TP1_BREAK_EVEN");
        }
      return;
     }

   if(tp1_done && !tp2_done && moved >= risk * strategy_tp2_rr)
     {
      if(!PositionSelectByTicket(ticket))
         return;
      const double refreshed_volume = PositionGetDouble(POSITION_VOLUME);
      double close_lots = QM_TM_NormalizeVolume(_Symbol, initial_volume * strategy_tp2_close_fraction);
      if(close_lots > 0.0 && close_lots < refreshed_volume && QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
         tp2_done = true;
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
// -----------------------------------------------------------------------------

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
