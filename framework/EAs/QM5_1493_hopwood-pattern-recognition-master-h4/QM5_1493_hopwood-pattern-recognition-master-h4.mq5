#property strict
#property version   "5.0"
#property description "QM5_1493 Hopwood Pattern Recognition Master H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1493;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_atr_period                  = 14;
input double strategy_strong_move_atr_mult        = 1.0;
input double strategy_consolidation_body_atr_mult = 0.5;
input double strategy_retracement_atr_mult        = 0.25;
input double strategy_reversal_body_atr_mult      = 0.7;
input int    strategy_rsi_period                  = 14;
input double strategy_rsi_oversold                = 30.0;
input double strategy_rsi_overbought              = 70.0;
input double strategy_rsi_midline                 = 50.0;
input int    strategy_d1_sma_period               = 50;
input double strategy_sl_atr_mult                 = 1.5;
input double strategy_tp1_atr_mult                = 1.5;
input double strategy_tp1_close_fraction          = 0.60;
input int    strategy_time_stop_h4_bars           = 18;
input int    strategy_warmup_h4_bars              = 80;
input int    strategy_pattern_reuse_bars          = 16;
input int    strategy_spread_lookback_bars        = 20;
input double strategy_spread_median_mult          = 1.5;

double g_pending_entry_atr = 0.0;
int    g_pending_entry_side = 0;
ulong  g_managed_ticket = 0;
double g_tp1_target = 0.0;
bool   g_tp1_taken = false;
int    g_pattern_cooldown_bars = 0;

bool Strategy_NoTradeFilter()
  {
   if(Bars(_Symbol, PERIOD_H4) < strategy_warmup_h4_bars) // perf-allowed: O(1) H4 warmup guard for card-required 80 bars.
      return true;
   if(Bars(_Symbol, PERIOD_D1) < strategy_d1_sma_period + 2) // perf-allowed: O(1) D1 warmup guard for SMA(50) macro filter.
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

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

   if(g_pattern_cooldown_bars > 0)
     {
      g_pattern_cooldown_bars--;
      return false;
     }

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const int spread_need = MathMin(MathMax(strategy_spread_lookback_bars, 1), 64);
   MqlRates spread_rates[64];
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, spread_need, spread_rates); // perf-allowed: bounded 20-bar spread median; EntrySignal is framework new-bar gated.
   if(copied < spread_need)
      return false;

   double spread_points[64];
   int spread_count = 0;
   for(int i = 0; i < copied; i++)
     {
      spread_points[spread_count] = (double)spread_rates[i].spread;
      spread_count++;
     }
   for(int i = 1; i < spread_count; i++)
     {
      const double v = spread_points[i];
      int j = i - 1;
      while(j >= 0 && spread_points[j] > v)
        {
         spread_points[j + 1] = spread_points[j];
         j--;
        }
      spread_points[j + 1] = v;
     }
   double median_spread_points = 0.0;
   if(spread_count > 0)
     {
      const int mid = spread_count / 2;
      median_spread_points = ((spread_count % 2) == 1)
                             ? spread_points[mid]
                             : 0.5 * (spread_points[mid - 1] + spread_points[mid]);
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;
   if(ask > bid && median_spread_points > 0.0)
     {
      const double current_spread_points = (ask - bid) / point;
      if(current_spread_points > strategy_spread_median_mult * median_spread_points)
         return false;
     }

   const double open_1 = iOpen(_Symbol, PERIOD_H4, 1);   // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double high_1 = iHigh(_Symbol, PERIOD_H4, 1);   // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double low_1 = iLow(_Symbol, PERIOD_H4, 1);     // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double close_1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double open_2 = iOpen(_Symbol, PERIOD_H4, 2);   // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double high_2 = iHigh(_Symbol, PERIOD_H4, 2);   // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double low_2 = iLow(_Symbol, PERIOD_H4, 2);     // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double close_2 = iClose(_Symbol, PERIOD_H4, 2); // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double open_3 = iOpen(_Symbol, PERIOD_H4, 3);   // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double high_3 = iHigh(_Symbol, PERIOD_H4, 3);   // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double low_3 = iLow(_Symbol, PERIOD_H4, 3);     // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   const double close_3 = iClose(_Symbol, PERIOD_H4, 3); // perf-allowed: fixed closed-bar OHLC for bespoke 3-bar candle topology.
   if(open_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0 ||
      open_2 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0 || close_2 <= 0.0 ||
      open_3 <= 0.0 || high_3 <= 0.0 || low_3 <= 0.0 || close_3 <= 0.0)
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr_2 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 2);
   const double atr_3 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 3);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_2 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 2, PRICE_CLOSE);
   const double rsi_3 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 3, PRICE_CLOSE);
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed D1 close for macro-bias vs framework SMA reader.
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
   if(atr_1 <= 0.0 || atr_2 <= 0.0 || atr_3 <= 0.0 ||
      rsi_1 <= 0.0 || rsi_2 <= 0.0 || rsi_3 <= 0.0 ||
      d1_close <= 0.0 || d1_sma <= 0.0)
      return false;

   const double body_1 = MathAbs(close_1 - open_1);
   const double body_2 = MathAbs(close_2 - open_2);
   const double body_3 = MathAbs(close_3 - open_3);
   const bool consolidation_body = body_2 < strategy_consolidation_body_atr_mult * atr_2;
   const bool consolidation_range = (high_2 < high_3 + strategy_retracement_atr_mult * atr_3) &&
                                    (low_2 > low_3 - strategy_retracement_atr_mult * atr_3);
   if(!consolidation_body || !consolidation_range)
      return false;

   const bool bullish_pattern =
      close_3 < open_3 &&
      body_3 > strategy_strong_move_atr_mult * atr_3 &&
      close_1 > open_1 &&
      body_1 > strategy_reversal_body_atr_mult * atr_1 &&
      rsi_3 < strategy_rsi_oversold &&
      rsi_1 > strategy_rsi_oversold &&
      rsi_2 <= strategy_rsi_oversold &&
      d1_close > d1_sma;

   const bool bearish_pattern =
      close_3 > open_3 &&
      body_3 > strategy_strong_move_atr_mult * atr_3 &&
      close_1 < open_1 &&
      body_1 > strategy_reversal_body_atr_mult * atr_1 &&
      rsi_3 > strategy_rsi_overbought &&
      rsi_1 < strategy_rsi_overbought &&
      rsi_2 >= strategy_rsi_overbought &&
      d1_close < d1_sma;

   if(!bullish_pattern && !bearish_pattern)
      return false;

   const QM_OrderType side = bullish_pattern ? QM_BUY : QM_SELL;
   const double entry_price = bullish_pattern ? ask : bid;
   const double raw_sl = bullish_pattern
                         ? (low_2 - strategy_sl_atr_mult * atr_1)
                         : (high_2 + strategy_sl_atr_mult * atr_1);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0)
      return false;
   if(bullish_pattern && sl >= entry_price)
      return false;
   if(bearish_pattern && sl <= entry_price)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = bullish_pattern ? "HOPWOOD_3BAR_RSI_LONG" : "HOPWOOD_3BAR_RSI_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_pending_entry_atr = atr_1;
   g_pending_entry_side = bullish_pattern ? 1 : -1;
   g_pattern_cooldown_bars = MathMax(strategy_pattern_reuse_bars, 0);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double volume = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      break;
     }

   if(ticket == 0)
     {
      g_managed_ticket = 0;
      g_tp1_target = 0.0;
      g_tp1_taken = false;
      return;
     }

   if(ticket != g_managed_ticket)
     {
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double fallback_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
      double entry_atr = g_pending_entry_atr;
      if(entry_atr <= 0.0 || (is_buy && g_pending_entry_side < 0) || (!is_buy && g_pending_entry_side > 0))
         entry_atr = fallback_atr;
      g_managed_ticket = ticket;
      g_tp1_taken = false;
      g_tp1_target = (entry_atr > 0.0 && open_price > 0.0)
                     ? (is_buy ? open_price + strategy_tp1_atr_mult * entry_atr
                               : open_price - strategy_tp1_atr_mult * entry_atr)
                     : 0.0;
     }

   if(g_tp1_taken || g_tp1_target <= 0.0 || volume <= 0.0)
      return;

   const bool is_buy_position = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy_position ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;
   if(is_buy_position && market_price < g_tp1_target)
      return;
   if(!is_buy_position && market_price > g_tp1_target)
      return;

   const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_close_fraction);
   if(close_lots <= 0.0)
      return;
   if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
      g_tp1_taken = true;
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime entry_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(ticket == 0)
      return false;

   if(!g_tp1_taken && entry_time > 0)
     {
      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      if(h4_seconds > 0 && TimeCurrent() - entry_time >= strategy_time_stop_h4_bars * h4_seconds)
         return true;
     }

   if(g_tp1_taken)
     {
      const double rsi_1 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 1, PRICE_CLOSE);
      const double rsi_2 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 2, PRICE_CLOSE);
      if(rsi_1 <= 0.0 || rsi_2 <= 0.0)
         return false;
      if(position_type == POSITION_TYPE_BUY && rsi_2 > strategy_rsi_midline && rsi_1 <= strategy_rsi_midline)
         return true;
      if(position_type == POSITION_TYPE_SELL && rsi_2 < strategy_rsi_midline && rsi_1 >= strategy_rsi_midline)
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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_1493\",\"slug\":\"hopwood-pattern-recognition-master-h4\"}");
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

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
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
