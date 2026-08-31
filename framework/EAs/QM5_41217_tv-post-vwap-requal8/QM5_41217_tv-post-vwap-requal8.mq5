#property strict
#property version   "5.0"
#property description "QM5_41217 TradingView Post-Absorption VWAP Reversal requalification"

#include <QM/QM_Common.mqh>

// Faithful new-identity port of QM5_10815_tv-post-vwap under
// OWNER-DEC-Q09HOLD-REQUAL-8-20260829. Strategy mechanics and defaults remain
// unchanged; only identity and current V5 framework wiring differ.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41217;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period           = 14;
input int    strategy_volume_lookback      = 20;
input double strategy_vwap_stretch_atr     = 0.50;
input double strategy_volume_ratio         = 1.50;
input double strategy_wick_share           = 0.55;
input double strategy_stop_buffer_atr      = 0.25;
input double strategy_max_stop_atr         = 2.50;
input double strategy_target_rr            = 0.0;
input int    strategy_time_stop_m15_bars   = 24;
input int    strategy_time_stop_h1_bars    = 12;
input bool   strategy_session_filter       = true;
input int    strategy_session_start_hour   = 7;
input int    strategy_session_end_hour     = 21;
input int    strategy_max_spread_points    = 0;

int g_last_absorption_signal_dir = 0;

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   // An open position must remain manageable outside the entry session.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   // Zero spread is normal for .DWX tester symbols; block only a real wide spread.
   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point > 0.0 && ask > 0.0 && bid > 0.0 && ask > bid &&
         ((ask - bid) / point) > (double)strategy_max_spread_points)
         return true;
     }

   if(strategy_session_filter)
     {
      MqlDateTime now_dt;
      TimeToStruct(TimeCurrent(), now_dt);
      const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
      const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
      bool inside = true;
      if(start_h < end_h)
         inside = (now_dt.hour >= start_h && now_dt.hour < end_h);
      else if(start_h > end_h)
         inside = (now_dt.hour >= start_h || now_dt.hour < end_h);
      if(!inside)
         return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_last_absorption_signal_dir = 0;

   if(strategy_atr_period <= 0 ||
      strategy_volume_lookback < 3 ||
      strategy_vwap_stretch_atr <= 0.0 ||
      strategy_volume_ratio <= 0.0 ||
      strategy_wick_share <= 0.0 ||
      strategy_wick_share >= 1.0 ||
      strategy_stop_buffer_atr < 0.0 ||
      strategy_max_stop_atr <= 0.0)
      return false;

   const int required_bars = strategy_volume_lookback + 4;
   const int bars_to_copy = MathMin(MathMax(required_bars, 64), 512);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 0, bars_to_copy, rates); // perf-allowed: bounded closed-bar VWAP/volume read after QM_IsNewBar(PERIOD_H1).
   const int rates_size = ArraySize(rates);
   if(copied < required_bars || rates_size < required_bars || copied > rates_size)
      return false;
   if(ArraySize(rates) <= 3)
      return false;

   MqlDateTime session_dt;
   TimeToStruct(rates[1].time, session_dt);
   double pv_sum = 0.0;
   double vol_sum = 0.0;
   for(int i = 1; i < copied && i < ArraySize(rates); ++i)
     {
      MqlDateTime bar_dt;
      TimeToStruct(rates[i].time, bar_dt);
      if(bar_dt.year != session_dt.year || bar_dt.day_of_year != session_dt.day_of_year)
         break;

      const double bar_vol = MathMax(1.0, (double)rates[i].tick_volume);
      const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      pv_sum += typical * bar_vol;
      vol_sum += bar_vol;
     }
   if(vol_sum <= 0.0)
      return false;
   const double session_vwap = pv_sum / vol_sum;
   if(session_vwap <= 0.0)
      return false;

   const int volume_end = 3 + strategy_volume_lookback;
   if(volume_end > copied || volume_end > ArraySize(rates))
      return false;
   double avg_volume = 0.0;
   for(int i = 3; i < volume_end && i < ArraySize(rates); ++i)
      avg_volume += MathMax(1.0, (double)rates[i].tick_volume);
   avg_volume /= (double)strategy_volume_lookback;
   if(avg_volume <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // The local ArraySize proof above covers every fixed series index here.
   const double abs_open = rates[2].open;
   const double abs_high = rates[2].high;
   const double abs_low = rates[2].low;
   const double abs_close = rates[2].close;
   const double abs_range = abs_high - abs_low;
   if(abs_range <= 0.0)
      return false;

   const double lower_wick = MathMin(abs_open, abs_close) - abs_low;
   const double upper_wick = abs_high - MathMax(abs_open, abs_close);
   const bool high_relative_volume = ((double)rates[2].tick_volume >= avg_volume * strategy_volume_ratio);
   const bool close_inside_prior = (abs_close <= rates[3].high && abs_close >= rates[3].low);
   const bool stretched_below_vwap = (abs_low <= session_vwap - strategy_vwap_stretch_atr * atr);
   const bool stretched_above_vwap = (abs_high >= session_vwap + strategy_vwap_stretch_atr * atr);
   const bool bearish_side_absorption = high_relative_volume &&
                                        close_inside_prior &&
                                        stretched_below_vwap &&
                                        ((lower_wick / abs_range) >= strategy_wick_share);
   const bool bullish_side_absorption = high_relative_volume &&
                                        close_inside_prior &&
                                        stretched_above_vwap &&
                                        ((upper_wick / abs_range) >= strategy_wick_share);

   const bool long_signal = bearish_side_absorption && (rates[1].close > abs_high);
   const bool short_signal = bullish_side_absorption && (rates[1].close < abs_low);
   if(long_signal)
      g_last_absorption_signal_dir = 1;
   else if(short_signal)
      g_last_absorption_signal_dir = -1;
   else
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   if(long_signal)
     {
      const double natural_sl = abs_low - strategy_stop_buffer_atr * atr;
      const double capped_sl = entry - strategy_max_stop_atr * atr;
      sl = MathMax(natural_sl, capped_sl);
      if(session_vwap <= entry)
         return false;
     }
   else
     {
      const double natural_sl = abs_high + strategy_stop_buffer_atr * atr;
      const double capped_sl = entry + strategy_max_stop_atr * atr;
      sl = MathMin(natural_sl, capped_sl);
      if(session_vwap >= entry)
         return false;
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0 || (long_signal && sl >= entry) || (short_signal && sl <= entry))
      return false;

   double tp = 0.0;
   if(strategy_target_rr > 0.0)
      tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   else
      tp = QM_StopRulesNormalizePrice(_Symbol, session_vwap);
   if(tp <= 0.0 || (long_signal && tp <= entry) || (short_signal && tp >= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "POST_ABS_VWAP_LONG" : "POST_ABS_VWAP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   // The approved baseline has no trailing, break-even, or partial-close rule.
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds(PERIOD_H1);
   const int max_bars = strategy_time_stop_h1_bars;

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
      if((ptype == POSITION_TYPE_BUY && g_last_absorption_signal_dir < 0) ||
         (ptype == POSITION_TYPE_SELL && g_last_absorption_signal_dir > 0))
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && period_seconds > 0 && max_bars > 0)
        {
         const int bars_held = (int)((TimeCurrent() - open_time) / period_seconds);
         if(bars_held >= max_bars)
            return true;
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Current V5 framework wiring
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
   // Q08 evidence lifecycle: no guard may skip open-position MAE sampling.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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

   // News rules gate new entries only; management and exits above stay active.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
