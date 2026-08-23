#property strict
#property version   "5.0"
#property description "QM5_36003 NNFX Hull MA & ZeroLag MACD Fast Trend Engine"
// Strategy Card: QM5_36003 (nnfx-hull-ma-zerolag-macd-stc), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36003
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36003;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input int    strategy_hma_period          = 20;     // Hull Moving Average baseline period
input int    strategy_zl_macd_fast        = 12;     // ZeroLag MACD fast EMA
input int    strategy_zl_macd_slow        = 26;     // ZeroLag MACD slow EMA
input int    strategy_zl_macd_signal      = 9;      // ZeroLag MACD signal period
input int    strategy_stc_fast            = 23;     // Schaff Trend Cycle fast MACD period
input int    strategy_stc_slow            = 50;     // Schaff Trend Cycle slow MACD period
input int    strategy_stc_length          = 10;     // Schaff Trend Cycle stochastic lookback
input double strategy_stc_long_thresh     = 75.0;   // STC long confirmation threshold
input double strategy_stc_short_thresh    = 25.0;   // STC short confirmation threshold
input int    strategy_vol_avg_period      = 20;     // Better Volume lookback period
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_tp1_atr_mult        = 1.00;   // TP1 ATR multiplier (50% partial close)
input double strategy_tp1_fraction        = 0.50;   // TP1 volume fraction
input int    strategy_be_buffer_pips      = 1;      // Break-even buffer in pips
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.0;    // Daily realized loss entry halt percent
input double strategy_daily_hard_stop_pct = 2.5;    // Maximum daily drawdown hard stop percent
input double strategy_total_dd_halt_pct   = 5.0;    // Maximum total drawdown stop percent
input double strategy_per_trade_risk_cap_pct = 0.5; // Per-trade risk cap percent

// -----------------------------------------------------------------------------
// Helpers & Indicator Math
// -----------------------------------------------------------------------------

int StrategyHhmm(const datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.hour * 100 + parts.min;
}

bool StrategyInRolloverWindow(const datetime utc_time)
{
   const int hhmm = StrategyHhmm(utc_time);
   return (hhmm >= 2355 || hhmm < 5);
}

bool StrategyDailyEntryHalt()
{
   if(g_qm_ks_day_start_equity <= 0.0)
      return false;

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0)
      return true;

   const double pnl_pct = ((equity_now - g_qm_ks_day_start_equity) / g_qm_ks_day_start_equity) * 100.0;
   return (pnl_pct <= -strategy_daily_loss_halt_pct);
}

double Strategy_WMA(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const int s = shift + k;
      const double c = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar WMA behind QM_IsNewBar()
      if(c <= 0.0) return 0.0;
      const double weight = (double)(period - k);
      sum_w += c * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return sum_w / sum_weight;
}

double Strategy_HMA(const string sym, const int period, const int shift)
{
   if(period < 4 || shift < 1) return 0.0;
   const int half_period = period / 2;
   const int sqrt_period = (int)MathRound(MathSqrt((double)period));
   if(sqrt_period < 1) return 0.0;

   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int k = 0; k < sqrt_period; ++k)
   {
      const int s = shift + k;
      const double w_half = Strategy_WMA(sym, half_period, s);
      const double w_full = Strategy_WMA(sym, period, s);
      if(w_half <= 0.0 || w_full <= 0.0) return 0.0;
      const double diff = 2.0 * w_half - w_full;
      const double weight = (double)(sqrt_period - k);
      sum_w += diff * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return sum_w / sum_weight;
}

double Strategy_ZeroLagEMA(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   const int max_lookback = 40;
   double adj_prices[60];
   for(int k = 0; k < max_lookback; ++k)
   {
      const int s = shift + k;
      const double ema1 = QM_EMA(sym, PERIOD_D1, period, s);
      const double c = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar reference behind QM_IsNewBar()
      if(ema1 <= 0.0 || c <= 0.0) return 0.0;
      adj_prices[k] = 2.0 * c - ema1;
   }

   const double alpha = 2.0 / ((double)period + 1.0);
   double ema2 = adj_prices[max_lookback - 1];
   for(int k = max_lookback - 2; k >= 0; --k)
   {
      ema2 = alpha * adj_prices[k] + (1.0 - alpha) * ema2;
   }
   return ema2;
}

bool Strategy_ZeroLagMACD(const string sym, const int fast_p, const int slow_p, const int sig_p, const int shift, double &zl_macd, double &zl_sig)
{
   zl_macd = 0.0;
   zl_sig = 0.0;
   if(fast_p <= 0 || slow_p <= 0 || sig_p <= 0 || shift < 1) return false;

   double macd_buf[30];
   for(int k = 0; k < sig_p + 10; ++k)
   {
      const int s = shift + k;
      const double fast_z = Strategy_ZeroLagEMA(sym, fast_p, s);
      const double slow_z = Strategy_ZeroLagEMA(sym, slow_p, s);
      if(fast_z <= 0.0 || slow_z <= 0.0) return false;
      macd_buf[k] = fast_z - slow_z;
   }

   zl_macd = macd_buf[0];
   const double alpha_sig = 2.0 / ((double)sig_p + 1.0);
   double ema_sig = macd_buf[sig_p + 9];
   for(int k = sig_p + 8; k >= 0; --k)
   {
      ema_sig = alpha_sig * macd_buf[k] + (1.0 - alpha_sig) * ema_sig;
   }
   zl_sig = ema_sig;
   return true;
}

double Strategy_STC(const string sym, const int fast_p, const int slow_p, const int length, const int shift)
{
   if(fast_p <= 0 || slow_p <= 0 || length <= 0 || shift < 1) return 50.0;
   const int lookback = length + 20;
   double macd[40];
   for(int k = 0; k < lookback; ++k)
   {
      const int s = shift + k;
      const double e_fast = QM_EMA(sym, PERIOD_D1, fast_p, s);
      const double e_slow = QM_EMA(sym, PERIOD_D1, slow_p, s);
      if(e_fast <= 0.0 || e_slow <= 0.0) return 50.0;
      macd[k] = e_fast - e_slow;
   }

   double min_m = DBL_MAX, max_m = -DBL_MAX;
   for(int k = 0; k < length; ++k)
   {
      if(macd[k] < min_m) min_m = macd[k];
      if(macd[k] > max_m) max_m = macd[k];
   }

   if(max_m <= min_m) return 50.0;
   const double stoch_k = 100.0 * (macd[0] - min_m) / (max_m - min_m);
   return stoch_k;
}

bool Strategy_BetterVolumeHigh(const string sym, const int shift)
{
   if(shift < 1) return false;
   const long v_1 = iTickVolume(sym, PERIOD_D1, shift); // perf-allowed: closed-bar volume behind QM_IsNewBar()
   if(v_1 <= 0) return false;

   long sum_v = 0;
   for(int k = 1; k <= strategy_vol_avg_period; ++k)
   {
      const long v = iTickVolume(sym, PERIOD_D1, shift + k); // perf-allowed: closed-bar volume behind QM_IsNewBar()
      if(v <= 0) return false;
      sum_v += v;
   }
   const double avg_v = (double)sum_v / (double)strategy_vol_avg_period;
   return ((double)v_1 > avg_v);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);

   // 1. Rollover Blackout in UTC (23:55 to 00:05 GMT)
   if(StrategyInRolloverWindow(utc_now))
      return true;

   // 2. Spread Filter (> 1.8 * ATR(14, D1)[1])
   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
         return true;
   }

   // 3. Daily Loss Limit (2.0% entry halt)
   if(StrategyDailyEntryHalt())
      return true;

   // 4. Max Open Positions (>= 1)
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) >= 1)
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_D1;
   const double close_1 = iClose(_Symbol, tf, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()
   if(close_1 <= 0.0) return false;

   const double hma_1 = Strategy_HMA(_Symbol, strategy_hma_period, 1);
   if(hma_1 <= 0.0) return false;

   double zl_macd_1 = 0.0, zl_sig_1 = 0.0;
   if(!Strategy_ZeroLagMACD(_Symbol, strategy_zl_macd_fast, strategy_zl_macd_slow, strategy_zl_macd_signal, 1, zl_macd_1, zl_sig_1))
      return false;

   const double stc_1 = Strategy_STC(_Symbol, strategy_stc_fast, strategy_stc_slow, strategy_stc_length, 1);
   const bool vol_high = Strategy_BetterVolumeHigh(_Symbol, 1);
   if(!vol_high) return false;

   const double atr_1 = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr_1 <= 0.0) return false;

   // 1. Long Entry: Close[1] > HMA[1] AND ZL_MACD[1] > ZL_Signal[1] AND STC[1] >= 75.0 AND BetterVol == HIGH
   if((close_1 > hma_1) && (zl_macd_1 > zl_sig_1) && (stc_1 >= strategy_stc_long_thresh))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;
      const double sl = exec_price - strategy_sl_atr_mult * atr_1;

      if(sl <= 0.0 || sl >= exec_price)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0; // TP1 is dynamically managed via partial close at +1 ATR; runner trails to ZL_MACD cross
      req.reason = "nnfx_hma_zl_long";
      return true;
   }

   // 2. Short Entry: Close[1] < HMA[1] AND ZL_MACD[1] < ZL_Signal[1] AND STC[1] <= 25.0 AND BetterVol == HIGH
   if((close_1 < hma_1) && (zl_macd_1 < zl_sig_1) && (stc_1 <= strategy_stc_short_thresh))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;
      const double sl = exec_price + strategy_sl_atr_mult * atr_1;

      if(sl <= 0.0 || sl <= exec_price)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0; // TP1 is dynamically managed via partial close at +1 ATR; runner trails to ZL_MACD cross
      req.reason = "nnfx_hma_zl_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr_1 <= 0.0 || point <= 0.0) return;

   const double trigger_distance = strategy_tp1_atr_mult * atr_1;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume     = PositionGetDouble(POSITION_VOLUME);
      const bool is_buy       = (pos_type == POSITION_TYPE_BUY);

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      const double favorable_move = is_buy ? (market_price - open_price)
                                           : (open_price - market_price);

      if(market_price <= 0.0 || favorable_move < trigger_distance)
         continue;

      const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_fraction);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(partial_lots > 0.0 && partial_lots < volume && (volume - partial_lots) >= (min_lot - 1e-8))
      {
         if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
         {
            const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips);
            const double be_sl = is_buy ? (open_price + be_buffer) : (open_price - be_buffer);
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, be_sl), "NNFX_TP1_BE_PROTECTION");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   double zl_macd_1 = 0.0, zl_sig_1 = 0.0;
   if(!Strategy_ZeroLagMACD(_Symbol, strategy_zl_macd_fast, strategy_zl_macd_slow, strategy_zl_macd_signal, 1, zl_macd_1, zl_sig_1))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && (zl_macd_1 < zl_sig_1))
         return true;
      if(pos_type == POSITION_TYPE_SELL && (zl_macd_1 > zl_sig_1))
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;

   // 1. Manage open positions and evaluate exit signals before entry filters
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   // 2. News filter check
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   // 3. Entry-only filter (spread, rollover in UTC, 2% daily loss halt, max open positions)
   if(Strategy_NoTradeFilter()) return;

   // 4. Bar evaluation for entry
   if(!QM_IsNewBar(_Symbol, PERIOD_D1)) return;
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
