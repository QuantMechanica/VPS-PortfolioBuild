#property strict
#property version   "5.0"
#property description "QM5_10793 TradingView MACD MFI"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10793;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M15;
input int             strategy_macd_fast       = 12;
input int             strategy_macd_slow       = 26;
input int             strategy_macd_signal     = 9;
input int             strategy_mfi_period      = 14;
input double          strategy_mfi_long_min    = 50.0;
input double          strategy_mfi_short_max   = 50.0;
input bool            strategy_ema_filter_on   = false;
input int             strategy_ema_period      = 200;
input bool            strategy_rsi_filter_on   = false;
input int             strategy_rsi_period      = 14;
input double          strategy_rsi_lower       = 40.0;
input double          strategy_rsi_upper       = 70.0;
input bool            strategy_atr_filter_on   = false;
input int             strategy_atr_period      = 14;
input int             strategy_atr_rank_bars   = 100;
input double          strategy_atr_min_pctile  = 20.0;
input int             strategy_stop_mode       = 0;      // 0 = ATR stop, 1 = fixed-percent stop
input double          strategy_stop_atr_mult   = 1.5;
input double          strategy_stop_fixed_pct  = 0.5;
input double          strategy_trail_activate_r = 1.0;
input double          strategy_trail_deviation_r = 1.0;

bool g_suppress_entry_after_exit = false;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_suppress_entry_after_exit)
     {
      g_suppress_entry_after_exit = false;
      return false;
     }

   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_mfi_period <= 0 ||
      strategy_ema_period <= 0 || strategy_rsi_period <= 0 ||
      strategy_atr_period <= 0 || strategy_stop_atr_mult <= 0.0 ||
      strategy_stop_fixed_pct <= 0.0 || strategy_trail_activate_r <= 0.0 ||
      strategy_trail_deviation_r <= 0.0)
      return false;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double macd_now = QM_MACD_Main(_Symbol, strategy_signal_tf,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, 1);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_signal_tf,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, strategy_signal_tf,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 2);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_signal_tf,
                                          strategy_macd_fast, strategy_macd_slow,
                                          strategy_macd_signal, 2);
   const bool bullish_macd = (macd_prev <= sig_prev && macd_now > sig_now);
   const bool bearish_macd = (macd_prev >= sig_prev && macd_now < sig_now);
   if(!bullish_macd && !bearish_macd)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int rates_needed = strategy_mfi_period + 1;
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, rates_needed, rates); // perf-allowed: bounded MFI proxy inside framework closed-bar entry hook
   if(copied < rates_needed)
      return false;

   double positive_flow = 0.0;
   double negative_flow = 0.0;
   for(int i = strategy_mfi_period - 1; i >= 0; --i)
     {
      const double typical_now = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      const double typical_prev = (rates[i + 1].high + rates[i + 1].low + rates[i + 1].close) / 3.0;
      const double raw_flow = typical_now * (double)rates[i].tick_volume;
      if(typical_now > typical_prev)
         positive_flow += raw_flow;
      else if(typical_now < typical_prev)
         negative_flow += raw_flow;
     }

   double mfi = 50.0;
   if(negative_flow <= 0.0 && positive_flow > 0.0)
      mfi = 100.0;
   else if(positive_flow <= 0.0 && negative_flow > 0.0)
      mfi = 0.0;
   else if(positive_flow > 0.0 && negative_flow > 0.0)
     {
      const double money_ratio = positive_flow / negative_flow;
      mfi = 100.0 - (100.0 / (1.0 + money_ratio));
     }

   const double signal_close = rates[0].close;
   if(strategy_ema_filter_on)
     {
      const double ema = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1);
      if((bullish_macd && signal_close <= ema) ||
         (bearish_macd && signal_close >= ema))
         return false;
     }

   if(strategy_rsi_filter_on)
     {
      const double rsi = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
      if(rsi < strategy_rsi_lower || rsi > strategy_rsi_upper)
         return false;
     }

   if(strategy_atr_filter_on)
     {
      const int sample_count = (strategy_atr_rank_bars < 20) ? 20 : strategy_atr_rank_bars;
      double atr_values[];
      ArrayResize(atr_values, sample_count);
      int samples = 0;
      for(int shift = 1; shift <= sample_count; ++shift)
        {
         const double atr_value = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, shift);
         if(atr_value <= 0.0)
            continue;
         atr_values[samples] = atr_value;
         samples++;
        }
      if(samples < 20)
         return false;
      ArrayResize(atr_values, samples);
      ArraySort(atr_values);
      int pct_index = (int)MathFloor((strategy_atr_min_pctile / 100.0) * (double)(samples - 1));
      if(pct_index < 0)
         pct_index = 0;
      if(pct_index >= samples)
         pct_index = samples - 1;
      const double atr_now = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
      if(atr_now < atr_values[pct_index])
         return false;
     }

   req.price = 0.0;
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(bullish_macd && mfi > strategy_mfi_long_min)
     {
      req.type = QM_BUY;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(strategy_stop_mode == 1)
         req.sl = NormalizeDouble(entry * (1.0 - strategy_stop_fixed_pct / 100.0), _Digits);
      else
         req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_stop_atr_mult);
      req.reason = "tv_macd_mfi_long";
      return (entry > 0.0 && req.sl > 0.0 && req.sl < entry);
     }

   if(bearish_macd && mfi < strategy_mfi_short_max)
     {
      req.type = QM_SELL;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(strategy_stop_mode == 1)
         req.sl = NormalizeDouble(entry * (1.0 + strategy_stop_fixed_pct / 100.0), _Digits);
      else
         req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_stop_atr_mult);
      req.reason = "tv_macd_mfi_short";
      return (entry > 0.0 && req.sl > 0.0 && req.sl > entry);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double initial_risk = MathAbs(open_price - current_sl);
      if(initial_risk <= 0.0)
         continue;

      const double profit_distance = is_buy ? (market - open_price) : (open_price - market);
      if(profit_distance < initial_risk * strategy_trail_activate_r)
         continue;

      const double raw_sl = is_buy ? (market - initial_risk * strategy_trail_deviation_r)
                                   : (market + initial_risk * strategy_trail_deviation_r);
      const double trail_sl = NormalizeDouble(raw_sl, _Digits);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0 || trail_sl <= 0.0)
         continue;

      const bool improves = is_buy ? (trail_sl > current_sl + point * 0.5)
                                   : (trail_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, trail_sl, "tv_macd_mfi_trailing_profit");
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE open_type = POSITION_TYPE_BUY;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   const double macd_now = QM_MACD_Main(_Symbol, strategy_signal_tf,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, 1);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_signal_tf,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, strategy_signal_tf,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 2);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_signal_tf,
                                          strategy_macd_fast, strategy_macd_slow,
                                          strategy_macd_signal, 2);
   const bool bullish_cross = (macd_prev <= sig_prev && macd_now > sig_now);
   const bool bearish_cross = (macd_prev >= sig_prev && macd_now < sig_now);

   if((open_type == POSITION_TYPE_BUY && bearish_cross) ||
      (open_type == POSITION_TYPE_SELL && bullish_cross))
     {
      g_suppress_entry_after_exit = true;
      return true;
     }

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10793_tv-macd-mfi\"}");
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
