#property strict
#property version   "5.0"
#property description "QM5_12829 WTI Cushing Failed-Spike Fade"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12829 - WTI Cushing Failed-Spike Fade
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - host/traded symbol: XTIUSD.DWX
//   - weekly entry gate
//   - short-only failed upside channel pierce after a Cushing-tightness spike
// Runtime uses MT5 OHLC/broker calendar only; no EIA feed, curve, API, CSV, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12829;
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
input int    strategy_channel_lookback_d1     = 63;
input int    strategy_return_lookback_d1      = 21;
input int    strategy_fast_sma_period         = 20;
input int    strategy_slow_sma_period         = 126;
input double strategy_min_pierce_margin_pct   = 0.50;
input double strategy_min_return_pct          = 4.0;
input double strategy_max_return_pct          = 22.0;
input double strategy_min_bar_range_atr       = 0.80;
input double strategy_reversal_close_ratio    = 0.45;
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 3.0;
input int    strategy_max_hold_days           = 14;
input int    strategy_max_spread_points       = 1000;

int g_last_entry_week_key = 0;

bool Strategy_IsHostD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_WeekKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

bool Strategy_IsWeeklySignalBar()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate behind framework new-bar.
   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 calendar gate behind framework new-bar.
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return Strategy_WeekKey(current_bar) != Strategy_WeekKey(prior_bar);
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

bool Strategy_LoadFadeSignal(double &signal_close, double &fast_sma)
  {
   signal_close = 0.0;
   fast_sma = 0.0;

   const int channel_lb = MathMax(20, strategy_channel_lookback_d1);
   const int return_lb = MathMax(5, strategy_return_lookback_d1);

   MqlRates signal[];
   ArraySetAsSeries(signal, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, signal) != 1) // perf-allowed: one completed D1 signal bar behind new-bar gate.
      return false;

   double highs[];
   ArraySetAsSeries(highs, true);
   if(CopyHigh(_Symbol, PERIOD_D1, 2, channel_lb, highs) != channel_lb) // perf-allowed: bounded D1 channel sample behind new-bar gate.
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(_Symbol, PERIOD_D1, 1, return_lb + 1, closes) != return_lb + 1) // perf-allowed: bounded D1 return sample behind new-bar gate.
      return false;

   double prior_channel_high = highs[0];
   for(int i = 0; i < channel_lb; ++i)
     {
      if(highs[i] <= 0.0)
         return false;
      if(highs[i] > prior_channel_high)
         prior_channel_high = highs[i];
     }
   if(prior_channel_high <= 0.0)
      return false;

   signal_close = signal[0].close;
   const double signal_open = signal[0].open;
   const double signal_high = signal[0].high;
   const double signal_low = signal[0].low;
   if(signal_open <= 0.0 || signal_close <= 0.0 || signal_high <= signal_low)
      return false;

   const double return_base = closes[return_lb];
   if(return_base <= 0.0)
      return false;

   const double recent_return_pct = 100.0 * MathLog(signal_close / return_base);
   if(!MathIsValidNumber(recent_return_pct))
      return false;

   fast_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1);
   const double slow_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_slow_sma_period, 1);
   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(fast_sma <= 0.0 || slow_sma <= 0.0 || atr_last <= 0.0)
      return false;

   const double range = signal_high - signal_low;
   if(range < strategy_min_bar_range_atr * atr_last)
      return false;

   const double pierce_threshold = prior_channel_high * (1.0 + MathMax(0.0, strategy_min_pierce_margin_pct) / 100.0);
   const double close_position = (signal_close - signal_low) / range;
   if(signal_high < pierce_threshold)
      return false;
   if(signal_close >= signal_open)
      return false;
   if(signal_close > prior_channel_high)
      return false;
   if(close_position > strategy_reversal_close_ratio)
      return false;
   if(signal_close <= slow_sma)
      return false;
   if(fast_sma <= slow_sma)
      return false;
   if(recent_return_pct < strategy_min_return_pct)
      return false;
   if(recent_return_pct > strategy_max_return_pct)
      return false;

   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   double close_buffer[];
   ArraySetAsSeries(close_buffer, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, 1, close_buffer); // perf-allowed: single closed D1 close behind new-bar gate.
   const double recent_close = (copied >= 1) ? close_buffer[0] : 0.0;
   const double fast_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool should_close = false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(recent_close > 0.0 && fast_sma > 0.0 && recent_close <= fast_sma)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_channel_lookback_d1 < 20)
      return true;
   if(strategy_return_lookback_d1 < 5)
      return true;
   if(strategy_fast_sma_period <= 1 || strategy_slow_sma_period <= strategy_fast_sma_period)
      return true;
   if(strategy_min_pierce_margin_pct < 0.0)
      return true;
   if(strategy_min_return_pct < 0.0 || strategy_max_return_pct <= strategy_min_return_pct)
      return true;
   if(strategy_min_bar_range_atr <= 0.0)
      return true;
   if(strategy_reversal_close_ratio <= 0.0 || strategy_reversal_close_ratio >= 1.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12829_WTI_CUSHING_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsWeeklySignalBar())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 weekly de-dupe behind new-bar gate.
   const int week_key = Strategy_WeekKey(current_bar);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double signal_close = 0.0;
   double fast_sma = 0.0;
   if(!Strategy_LoadFadeSignal(signal_close, fast_sma))
      return false;

   req.type = QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "WTI_CUSHING_FAILED_SPIKE_SHORT";
   g_last_entry_week_key = week_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12829\",\"ea\":\"wti-cushing-fade\"}");
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

