#property strict
#property version   "5.0"
#property description "QM5_11000 The5ers MACD Third Divergence"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11000;
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
input ENUM_TIMEFRAMES strategy_timeframe           = PERIOD_D1;
input int             strategy_macd_fast           = 3;
input int             strategy_macd_slow           = 9;
input int             strategy_macd_signal         = 7;
input int             strategy_swing_left          = 3;
input int             strategy_swing_right         = 3;
input int             strategy_swing_min_span_bars = 15;
input int             strategy_swing_max_span_bars = 120;
input int             strategy_atr_period          = 14;
input double          strategy_sl_atr_mult         = 0.5;
input double          strategy_tp_rr               = 2.0;
input int             strategy_atr_percentile_bars = 250;
input double          strategy_atr_percentile_min  = 0.15;
input int             strategy_max_hold_bars       = 20;

bool Strategy_NoTradeFilter()
  {
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_swing_left < 1 || strategy_swing_right < 1 ||
      strategy_swing_min_span_bars < 1 || strategy_swing_max_span_bars < strategy_swing_min_span_bars ||
      strategy_macd_fast < 1 || strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal < 1 ||
      strategy_atr_period < 1 || strategy_sl_atr_mult <= 0.0 || strategy_tp_rr <= 0.0)
      return false;

   const double current_atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   int atr_samples = 0;
   int atr_not_above_current = 0;
   for(int shift = 2; shift < 2 + strategy_atr_percentile_bars; ++shift)
     {
      const double hist_atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(hist_atr <= 0.0)
         continue;
      atr_samples++;
      if(hist_atr <= current_atr)
         atr_not_above_current++;
     }
   if(atr_samples >= 50)
     {
      const double atr_percentile = (double)atr_not_above_current / (double)atr_samples;
      if(atr_percentile <= strategy_atr_percentile_min)
         return false;
     }

   const int bars_needed = strategy_swing_max_span_bars + strategy_swing_left + strategy_swing_right + 10;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, bars_needed, rates); // perf-allowed: bounded D1 OHLC swing scan; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < strategy_swing_min_span_bars + strategy_swing_left + strategy_swing_right + 5)
      return false;

   double high_price[3];
   double high_macd[3];
   int    high_shift[3];
   double low_price[3];
   double low_macd[3];
   int    low_shift[3];
   for(int i = 0; i < 3; ++i)
     {
      high_price[i] = 0.0;
      high_macd[i] = 0.0;
      high_shift[i] = 0;
      low_price[i] = 0.0;
      low_macd[i] = 0.0;
      low_shift[i] = 0;
     }

   int high_count = 0;
   int low_count = 0;
   const int first_confirmed_shift = strategy_swing_right + 1;
   int max_shift = strategy_swing_max_span_bars + strategy_swing_left + strategy_swing_right;
   if(max_shift > copied - strategy_swing_left - 1)
      max_shift = copied - strategy_swing_left - 1;

   for(int shift = first_confirmed_shift; shift <= max_shift && (high_count < 3 || low_count < 3); ++shift)
     {
      bool swing_high = true;
      bool swing_low = true;

      for(int k = 1; k <= strategy_swing_left; ++k)
        {
         if(rates[shift].high <= rates[shift + k].high)
            swing_high = false;
         if(rates[shift].low >= rates[shift + k].low)
            swing_low = false;
        }
      for(int k = 1; k <= strategy_swing_right; ++k)
        {
         if(rates[shift].high <= rates[shift - k].high)
            swing_high = false;
         if(rates[shift].low >= rates[shift - k].low)
            swing_low = false;
        }

      if(swing_high && high_count < 3)
        {
         high_price[high_count] = rates[shift].high;
         high_macd[high_count] = QM_MACD_Main(_Symbol, strategy_timeframe,
                                              strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                              shift, PRICE_CLOSE);
         high_shift[high_count] = shift;
         high_count++;
        }

      if(swing_low && low_count < 3)
        {
         low_price[low_count] = rates[shift].low;
         low_macd[low_count] = QM_MACD_Main(_Symbol, strategy_timeframe,
                                            strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                            shift, PRICE_CLOSE);
         low_shift[low_count] = shift;
         low_count++;
        }
     }

   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_timeframe,
                                           strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                           1, PRICE_CLOSE);
   const double macd_signal_1 = QM_MACD_Signal(_Symbol, strategy_timeframe,
                                               strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                               1, PRICE_CLOSE);

   bool bearish = false;
   if(high_count == 3)
     {
      const int span = high_shift[2] - high_shift[0];
      const int post_shift = high_shift[0] - 1;
      if(span >= strategy_swing_min_span_bars && span <= strategy_swing_max_span_bars &&
         high_price[0] > high_price[1] && high_price[1] > high_price[2] &&
         high_macd[0] < high_macd[1] && high_macd[1] < high_macd[2] &&
         post_shift >= 1 &&
         (rates[1].close < rates[post_shift].low || macd_main_1 < macd_signal_1))
         bearish = true;
     }

   bool bullish = false;
   if(low_count == 3)
     {
      const int span = low_shift[2] - low_shift[0];
      const int post_shift = low_shift[0] - 1;
      if(span >= strategy_swing_min_span_bars && span <= strategy_swing_max_span_bars &&
         low_price[0] < low_price[1] && low_price[1] < low_price[2] &&
         low_macd[0] > low_macd[1] && low_macd[1] > low_macd[2] &&
         post_shift >= 1 &&
         (rates[1].close > rates[post_shift].high || macd_main_1 > macd_signal_1))
         bullish = true;
     }

   if(!bearish && !bullish)
      return false;

   if(bearish && bullish)
     {
      if(high_shift[0] > low_shift[0])
         bearish = false;
      else
         bullish = false;
     }

   if(bearish)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, high_price[0] + (strategy_sl_atr_mult * current_atr));
      if(req.sl <= entry)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);
      if(req.tp <= 0.0)
         return false;
      req.reason = "THIRD_MACD_DIVERGENCE_SHORT";
      return true;
     }

   if(bullish)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, low_price[0] - (strategy_sl_atr_mult * current_atr));
      if(req.sl >= entry)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);
      if(req.tp <= 0.0)
         return false;
      req.reason = "THIRD_MACD_DIVERGENCE_LONG";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_timeframe,
                                           strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                           1, PRICE_CLOSE);
   const double macd_signal_1 = QM_MACD_Signal(_Symbol, strategy_timeframe,
                                               strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                               1, PRICE_CLOSE);
   const double macd_main_2 = QM_MACD_Main(_Symbol, strategy_timeframe,
                                           strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                           2, PRICE_CLOSE);
   const double macd_signal_2 = QM_MACD_Signal(_Symbol, strategy_timeframe,
                                               strategy_macd_fast, strategy_macd_slow, strategy_macd_signal,
                                               2, PRICE_CLOSE);

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
      const bool long_exit = (position_type == POSITION_TYPE_BUY &&
                              macd_main_1 < macd_signal_1 && macd_main_2 >= macd_signal_2);
      const bool short_exit = (position_type == POSITION_TYPE_SELL &&
                               macd_main_1 > macd_signal_1 && macd_main_2 <= macd_signal_2);
      if(long_exit || short_exit)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
         continue;
        }

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_bars = iBarShift(_Symbol, strategy_timeframe, open_time, false); // perf-allowed: O(1) D1 hold-time lookup for card 20-bar time stop.
      if(strategy_max_hold_bars > 0 && held_bars >= strategy_max_hold_bars)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11000_the5ers_macd_third_div\"}");
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
   Strategy_ExitSignal();

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
