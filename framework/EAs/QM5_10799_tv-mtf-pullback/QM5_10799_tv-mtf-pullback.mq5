#property strict
#property version   "5.0"
#property description "QM5_10799 TradingView MTF Pullback RSI Divergence"

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
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10799;
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
input ENUM_TIMEFRAMES strategy_trend_tf        = PERIOD_H4;
input int             strategy_ema_period      = 50;
input int             strategy_rsi_period      = 14;
input double          strategy_rsi_oversold    = 30.0;
input double          strategy_rsi_pullback    = 40.0;
input double          strategy_rsi_overbought  = 70.0;
input double          strategy_rsi_rally       = 60.0;
input int             strategy_atr_period      = 14;
input double          strategy_atr_sl_mult     = 2.0;
input double          strategy_take_profit_pct = 2.0;
input int             strategy_swing_lookback  = 12;
input int             strategy_div_lookback    = 8;

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No card-specific session/regime/spread filter. Framework defaults handle
// global no-trade conditions.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Caller guarantees QM_IsNewBar() == true. All raw OHLC reads below are bounded
// structural checks for swing/pullback/engulfing/divergence mechanics.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_ema_period < 2 || strategy_rsi_period < 2 ||
      strategy_atr_period < 1 || strategy_swing_lookback < 3 ||
      strategy_swing_lookback > 48 || strategy_div_lookback < 4 ||
      strategy_div_lookback > 32 || strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_pct <= 0.0)
      return false;
   // perf-allowed: closed-bar MTF price context (raw close read, bounded to entry path).
   const double htf_close = iClose(_Symbol, strategy_trend_tf, 1); // perf-allowed: closed-bar MTF price context.
   const double htf_ema = QM_EMA(_Symbol, strategy_trend_tf, strategy_ema_period, 1);
   const double htf_ema_prev = QM_EMA(_Symbol, strategy_trend_tf, strategy_ema_period, 2);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(htf_close <= 0.0 || htf_ema <= 0.0 || htf_ema_prev <= 0.0 || atr <= 0.0)
      return false;

   double htf_swing_high = -DBL_MAX;
   double htf_swing_low = DBL_MAX;
   for(int i = 1; i <= strategy_swing_lookback; ++i)
     {
      const double h = iHigh(_Symbol, strategy_trend_tf, i); // perf-allowed: bounded H4 swing scan on closed-bar entry path.
      const double l = iLow(_Symbol, strategy_trend_tf, i);  // perf-allowed: bounded H4 swing scan on closed-bar entry path.
      if(h <= 0.0 || l <= 0.0)
         return false;
      htf_swing_high = MathMax(htf_swing_high, h);
      htf_swing_low = MathMin(htf_swing_low, l);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double r1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double r2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double r3 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 3);
   if(r1 <= 0.0 || r2 <= 0.0 || r3 <= 0.0)
      return false;

   const bool rsi_turns_up = (r2 <= strategy_rsi_pullback && r1 > r2 && r2 <= r3);
   const bool rsi_turns_down = (r2 >= strategy_rsi_rally && r1 < r2 && r2 >= r3);

   bool bullish_engulfing = false;
   bool bearish_engulfing = false;
   for(int shift = 1; shift <= 3; ++shift)
     {
      const double o1 = iOpen(_Symbol, _Period, shift);      // perf-allowed: bounded engulfing check on closed-bar entry path.
      const double c1 = iClose(_Symbol, _Period, shift);     // perf-allowed: bounded engulfing check on closed-bar entry path.
      const double o2 = iOpen(_Symbol, _Period, shift + 1);  // perf-allowed: bounded engulfing check on closed-bar entry path.
      const double c2 = iClose(_Symbol, _Period, shift + 1); // perf-allowed: bounded engulfing check on closed-bar entry path.
      if(o1 <= 0.0 || c1 <= 0.0 || o2 <= 0.0 || c2 <= 0.0)
         return false;

      if(c2 < o2 && c1 > o1 && c1 >= o2 && o1 <= c2)
         bullish_engulfing = true;
      if(c2 > o2 && c1 < o1 && c1 <= o2 && o1 >= c2)
         bearish_engulfing = true;
     }

   const int split = MathMax(3, strategy_div_lookback / 2);
   double recent_low = DBL_MAX;
   double prior_low = DBL_MAX;
   double recent_high = -DBL_MAX;
   double prior_high = -DBL_MAX;
   int recent_low_shift = 1;
   int prior_low_shift = split + 1;
   int recent_high_shift = 1;
   int prior_high_shift = split + 1;

   for(int i = 1; i <= split; ++i)
     {
      const double l = iLow(_Symbol, _Period, i);  // perf-allowed: bounded RSI divergence check on closed-bar entry path.
      const double h = iHigh(_Symbol, _Period, i); // perf-allowed: bounded RSI divergence check on closed-bar entry path.
      if(l <= 0.0 || h <= 0.0)
         return false;
      if(l < recent_low)
        {
         recent_low = l;
         recent_low_shift = i;
        }
      if(h > recent_high)
        {
         recent_high = h;
         recent_high_shift = i;
        }
     }

   for(int i = split + 1; i <= strategy_div_lookback; ++i)
     {
      const double l = iLow(_Symbol, _Period, i);  // perf-allowed: bounded RSI divergence check on closed-bar entry path.
      const double h = iHigh(_Symbol, _Period, i); // perf-allowed: bounded RSI divergence check on closed-bar entry path.
      if(l <= 0.0 || h <= 0.0)
         return false;
      if(l < prior_low)
        {
         prior_low = l;
         prior_low_shift = i;
        }
      if(h > prior_high)
        {
         prior_high = h;
         prior_high_shift = i;
        }
     }

   const double r_recent_low = QM_RSI(_Symbol, _Period, strategy_rsi_period, recent_low_shift);
   const double r_prior_low = QM_RSI(_Symbol, _Period, strategy_rsi_period, prior_low_shift);
   const double r_recent_high = QM_RSI(_Symbol, _Period, strategy_rsi_period, recent_high_shift);
   const double r_prior_high = QM_RSI(_Symbol, _Period, strategy_rsi_period, prior_high_shift);
   if(r_recent_low <= 0.0 || r_prior_low <= 0.0 || r_recent_high <= 0.0 || r_prior_high <= 0.0)
      return false;

   const bool bullish_divergence = (recent_low < prior_low && r_recent_low > r_prior_low);
   const bool bearish_divergence = (recent_high > prior_high && r_recent_high < r_prior_high);

   const bool htf_up = (htf_close > htf_ema && htf_ema > htf_ema_prev && ask > htf_ema);
   const bool htf_down = (htf_close < htf_ema && htf_ema < htf_ema_prev && bid < htf_ema);
   const bool pullback_from_high = (htf_close < htf_swing_high && htf_close > htf_ema);
   const bool pullback_from_low = (htf_close > htf_swing_low && htf_close < htf_ema);
   const bool long_rsi_ok = (bullish_divergence || rsi_turns_up);
   const bool short_rsi_ok = (bearish_divergence || rsi_turns_down);

   const double stop_dist = strategy_atr_sl_mult * atr;
   const double tp_mult = strategy_take_profit_pct / 100.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(htf_up && pullback_from_high && long_rsi_ok && bullish_engulfing)
     {
      req.type = QM_BUY;
      req.sl = NormalizeDouble(ask - stop_dist, digits);
      req.tp = NormalizeDouble(ask * (1.0 + tp_mult), digits);
      req.reason = "TV_MTF_PULLBACK_LONG";
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(htf_down && pullback_from_low && short_rsi_ok && bearish_engulfing)
     {
      req.type = QM_SELL;
      req.sl = NormalizeDouble(bid + stop_dist, digits);
      req.tp = NormalizeDouble(bid * (1.0 - tp_mult), digits);
      req.reason = "TV_MTF_PULLBACK_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR stop and fixed percent target only; no trailing,
   // break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   // Mechanical exits are broker SL/TP plus framework Friday close.
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
