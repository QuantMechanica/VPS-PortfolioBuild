#property strict
#property version   "5.0"
#property description "QM5_9902 ForexFactory Dance 35/50 Cluster Bounce M15"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9902;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M15;
input int    strategy_ema_fast_period             = 10;
input int    strategy_sma_cluster_period          = 35;
input int    strategy_ema_cluster_period          = 50;
input int    strategy_ema_trend_period            = 100;
input int    strategy_atr_period                  = 14;
input int    strategy_trend_slope_bars            = 12;
input double strategy_cluster_tight_atr_mult      = 0.25;
input double strategy_pullback_touch_atr_mult     = 0.10;
input double strategy_stop_buffer_atr_mult        = 0.25;
input double strategy_min_stop_atr_mult           = 0.45;
input double strategy_max_stop_atr_mult           = 2.20;
input double strategy_take_profit_rr              = 1.60;
input int    strategy_max_hold_bars               = 32;
input int    strategy_min_spacing_bars            = 8;
input int    strategy_session_start_hour_broker   = 8;
input int    strategy_session_end_hour_broker     = 17;
input double strategy_max_spread_atr_pct          = 12.0;

datetime g_long_spacing_until = 0;
datetime g_short_spacing_until = 0;

double Strategy_NormalizePrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_ReadRate(const int shift, MqlRates &bar)
  {
   // perf-allowed: card requires closed-bar OHLC geometry; callers use fixed
   // one-bar reads, and entry is reached only after the framework new-bar gate.
   MqlRates rates[1];
   if(CopyRates(_Symbol, strategy_timeframe, shift, 1, rates) != 1)
      return false;
   bar = rates[0];
   return true;
  }

bool Strategy_InSession(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);

   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour_broker));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour_broker));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool Strategy_FindPosition(long &position_type, datetime &open_time)
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

      position_type = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry_price,
                                  const double stop_price,
                                  const double atr_value)
  {
   if(entry_price <= 0.0 || stop_price <= 0.0 || atr_value <= 0.0)
      return false;

   const double dist = MathAbs(entry_price - stop_price);
   return (dist >= strategy_min_stop_atr_mult * atr_value &&
           dist <= strategy_max_stop_atr_mult * atr_value);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_InSession(TimeCurrent()))
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double max_spread = atr * strategy_max_spread_atr_pct / 100.0;
   return ((ask - bid) > max_spread);
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

   MqlRates confirm_bar;
   MqlRates pullback_bar;
   if(!Strategy_ReadRate(1, confirm_bar) || !Strategy_ReadRate(2, pullback_bar))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 2);
   const double ema_fast_setup = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 2);
   const double ema_fast_confirm = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 1);
   const double sma_cluster = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_cluster_period, 2);
   const double ema_cluster = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_cluster_period, 2);
   const double ema_trend = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_trend_period, 2);
   const double ema_trend_prior = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_trend_period,
                                         2 + strategy_trend_slope_bars);
   if(atr <= 0.0 || ema_fast_setup <= 0.0 || ema_fast_confirm <= 0.0 ||
      sma_cluster <= 0.0 || ema_cluster <= 0.0 || ema_trend <= 0.0 || ema_trend_prior <= 0.0)
      return false;

   const double cluster_low = MathMin(sma_cluster, ema_cluster);
   const double cluster_high = MathMax(sma_cluster, ema_cluster);
   if(MathAbs(sma_cluster - ema_cluster) > strategy_cluster_tight_atr_mult * atr)
      return false;

   const datetime now = TimeCurrent();
   const int spacing_seconds = MathMax(1, strategy_min_spacing_bars) * PeriodSeconds(strategy_timeframe);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool bullish_stack = (ema_fast_setup > sma_cluster && ema_cluster > ema_trend);
   const bool bullish_touch = (pullback_bar.low <= cluster_high + strategy_pullback_touch_atr_mult * atr &&
                               pullback_bar.close > cluster_low &&
                               confirm_bar.close > ema_fast_confirm &&
                               ema_trend > ema_trend_prior);
   if(bullish_stack && bullish_touch && now >= g_long_spacing_until)
     {
      const double sl = Strategy_NormalizePrice(pullback_bar.low - strategy_stop_buffer_atr_mult * atr);
      if(!Strategy_StopDistanceAllowed(ask, sl, atr))
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = Strategy_NormalizePrice(QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_take_profit_rr));
      req.reason = "FF_DANCE_3550_BOUNCE_LONG";
      g_long_spacing_until = now + spacing_seconds;
      return (req.tp > 0.0);
     }

   const bool bearish_stack = (ema_fast_setup < sma_cluster && ema_cluster < ema_trend);
   const bool bearish_touch = (pullback_bar.high >= cluster_low - strategy_pullback_touch_atr_mult * atr &&
                               pullback_bar.close < cluster_high &&
                               confirm_bar.close < ema_fast_confirm &&
                               ema_trend < ema_trend_prior);
   if(bearish_stack && bearish_touch && now >= g_short_spacing_until)
     {
      const double sl = Strategy_NormalizePrice(pullback_bar.high + strategy_stop_buffer_atr_mult * atr);
      if(!Strategy_StopDistanceAllowed(bid, sl, atr))
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = Strategy_NormalizePrice(QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_take_profit_rr));
      req.reason = "FF_DANCE_3550_BOUNCE_SHORT";
      g_short_spacing_until = now + spacing_seconds;
      return (req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP plus discretionary cluster/time exits only.
  }

bool Strategy_ExitSignal()
  {
   long position_type = -1;
   datetime open_time = 0;
   if(!Strategy_FindPosition(position_type, open_time))
      return false;

   MqlRates bar;
   if(!Strategy_ReadRate(1, bar))
      return false;

   const double sma_cluster = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_cluster_period, 1);
   const double ema_cluster = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_cluster_period, 1);
   const double ema_fast = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast_period, 1);
   if(sma_cluster <= 0.0 || ema_cluster <= 0.0 || ema_fast <= 0.0)
      return false;

   const double cluster_low = MathMin(sma_cluster, ema_cluster);
   const double cluster_high = MathMax(sma_cluster, ema_cluster);

   if(open_time > 0)
     {
      const int hold_seconds = MathMax(1, strategy_max_hold_bars) * PeriodSeconds(strategy_timeframe);
      if(TimeCurrent() - open_time >= hold_seconds)
         return true;
     }

   if(position_type == POSITION_TYPE_BUY)
      return (bar.close < cluster_low || ema_fast < cluster_low);
   if(position_type == POSITION_TYPE_SELL)
      return (bar.close > cluster_high || ema_fast > cluster_high);

   return false;
  }

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
