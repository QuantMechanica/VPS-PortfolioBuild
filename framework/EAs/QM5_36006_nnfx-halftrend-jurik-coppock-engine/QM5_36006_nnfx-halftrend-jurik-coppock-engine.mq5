#property strict
#property version   "5.0"
#property description "QM5_36006 NNFX HalfTrend & Jurik Velocity Engine"
// Strategy Card: QM5_36006 (nnfx-halftrend-jurik-coppock-engine), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36006
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36006;
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
input int    strategy_halftrend_amp       = 2;      // HalfTrend amplitude setting
input int    strategy_halftrend_atr_period= 100;    // HalfTrend ATR period for hysteresis
input double strategy_halftrend_atr_mult  = 2.0;    // Card HalfTrend ATR displacement
input int    strategy_jurik_period        = 14;     // Jurik JMA smoothing period
input int    strategy_coppock_roc1        = 14;     // Coppock primary ROC period
input int    strategy_coppock_roc2        = 11;     // Coppock secondary ROC period
input int    strategy_coppock_wma         = 10;     // Coppock WMA smoothing period
input int    strategy_cmf_period          = 20;     // Chaikin Money Flow lookback
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_tp_atr_mult         = 1.00;   // TP1 trigger ATR multiplier
input double strategy_tp1_fraction        = 0.50;   // TP1 partial-close fraction
input int    strategy_be_buffer_pips      = 1;      // Runner break-even buffer
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.0;    // Account realized-loss entry halt
input double strategy_daily_hard_stop_pct = 2.5;    // Restart-safe daily equity stop
input double strategy_total_dd_halt_pct   = 5.0;    // Account-level total-DD signal threshold
input double strategy_per_trade_risk_cap_pct = 0.5; // Framework per-trade risk cap

// -----------------------------------------------------------------------------
// Helpers & Indicator Math
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
}

bool Strategy_ConfigValid()
{
   if(strategy_halftrend_amp != 2 || strategy_halftrend_atr_period < 2 ||
      strategy_halftrend_atr_mult != 2.0 || strategy_jurik_period < 2)
      return false;
   if(strategy_coppock_roc1 < 1 || strategy_coppock_roc2 < 1 ||
      strategy_coppock_wma < 1 || strategy_cmf_period < 2 || strategy_atr_period < 2)
      return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0 ||
      strategy_tp1_fraction <= 0.0 || strategy_tp1_fraction >= 1.0 ||
      strategy_be_buffer_pips < 0 || strategy_spread_atr_mult <= 0.0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0)
      return false;
   if(strategy_per_trade_risk_cap_pct <= 0.0 || strategy_per_trade_risk_cap_pct > 1.0)
      return false;
   return true;
}

bool Strategy_DailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
}

bool Strategy_HalfTrend(const string sym, const int amplitude, const int atr_period, const int shift, double &ht_val, int &ht_trend)
{
   ht_val = 0.0;
   ht_trend = 0;
   if(amplitude != 2 || atr_period < 2 || shift < 1) return false;

   MqlRates bar;
   if(!QM_ReadBar(sym, PERIOD_D1, shift, bar) || bar.close <= 0.0)
      return false;
   const double ema = QM_EMA(sym, PERIOD_D1, amplitude, shift, PRICE_CLOSE);
   const double atr = QM_ATR(sym, PERIOD_D1, atr_period, shift);
   if(ema <= 0.0 || atr <= 0.0)
      return false;

   ht_trend = (bar.close >= ema) ? 1 : -1;
   ht_val = (ht_trend > 0) ? (ema - strategy_halftrend_atr_mult * atr)
                           : (ema + strategy_halftrend_atr_mult * atr);
   return true;
}

double Strategy_JMA(const string sym, const int period, const int shift)
{
   if(period <= 1 || shift < 1) return 0.0;
   const int warmup = period * 8 + 40;
   const int start_shift = shift + warmup;

   MqlRates start_bar;
   if(!QM_ReadBar(sym, PERIOD_D1, start_shift, start_bar) || start_bar.close <= 0.0)
      return 0.0;

   // Standard open Jurik recurrence with conventional phase=0 and power=2.
   const double phase_ratio = 1.5;
   const double beta = (0.45 * ((double)period - 1.0)) /
                       (0.45 * ((double)period - 1.0) + 2.0);
   const double alpha = MathPow(beta, 2.0);
   const double one_minus_alpha = 1.0 - alpha;
   double e0 = start_bar.close;
   double e1 = 0.0;
   double e2 = 0.0;
   double jma = start_bar.close;

   for(int s = start_shift - 1; s >= shift; --s)
   {
      MqlRates bar;
      if(!QM_ReadBar(sym, PERIOD_D1, s, bar) || bar.close <= 0.0)
         return 0.0;
      e0 = one_minus_alpha * bar.close + alpha * e0;
      e1 = (bar.close - e0) * (1.0 - beta) + beta * e1;
      e2 = (e0 + phase_ratio * e1 - jma) * one_minus_alpha * one_minus_alpha +
           alpha * alpha * e2;
      jma += e2;
   }
   return jma;
}

double Strategy_JurikVelocity(const string sym, const int period, const int shift)
{
   const double jma_now = Strategy_JMA(sym, period, shift);
   const double jma_prev = Strategy_JMA(sym, period, shift + 1);
   if(jma_now <= 0.0 || jma_prev <= 0.0) return 0.0;
   return (jma_now - jma_prev);
}

double Strategy_Coppock(const string sym, const int roc1, const int roc2, const int wma_len, const int shift)
{
   if(roc1 <= 0 || roc2 <= 0 || wma_len <= 0 || shift < 1) return 0.0;
   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int i = 0; i < wma_len; ++i)
   {
      const int s = shift + i;
      MqlRates current_bar, roc1_bar, roc2_bar;
      if(!QM_ReadBar(sym, PERIOD_D1, s, current_bar) ||
         !QM_ReadBar(sym, PERIOD_D1, s + roc1, roc1_bar) ||
         !QM_ReadBar(sym, PERIOD_D1, s + roc2, roc2_bar))
         return 0.0;
      const double c_curr = current_bar.close;
      const double c_roc1 = roc1_bar.close;
      const double c_roc2 = roc2_bar.close;
      if(c_curr <= 0.0 || c_roc1 <= 0.0 || c_roc2 <= 0.0) return 0.0;

      const double r1 = (c_curr - c_roc1) / c_roc1 * 100.0;
      const double r2 = (c_curr - c_roc2) / c_roc2 * 100.0;
      const double roc_sum = r1 + r2;

      const double weight = (double)(wma_len - i);
      sum_w += roc_sum * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return (sum_w / sum_weight);
}

double Strategy_CMF(const string sym, const int period, const int shift)
{
   if(period <= 1 || shift < 1) return 0.0;
   double mfv_sum = 0.0;
   double vol_sum = 0.0;
   for(int i = 0; i < period; ++i)
   {
      const int s = shift + i;
      MqlRates bar;
      if(!QM_ReadBar(sym, PERIOD_D1, s, bar))
         return 0.0;
      const double h = bar.high;
      const double l = bar.low;
      const double c = bar.close;
      const long v = bar.tick_volume;
      if(h <= 0.0 || l <= 0.0 || c <= 0.0 || v <= 0) continue;
      const double range = h - l;
      if(range <= 0.0) continue;
      const double mult = ((c - l) - (h - c)) / range;
      mfv_sum += mult * (double)v;
      vol_sum += (double)v;
   }
   if(vol_sum <= 0.0) return 0.0;
   return (mfv_sum / vol_sum);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return true;

   if(Strategy_DailyRealizedLossHalt())
      return true;

   const int hhmm = GetBarHhmm(QM_BrokerToUTC(TimeCurrent()));
   if(hhmm >= 2355 || hhmm <= 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr_1 <= 0.0)
      return true;
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr_1)
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

   if(Strategy_HasOpenPosition())
      return false;

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, signal_bar) || signal_bar.close <= 0.0)
      return false;
   const double close_1 = signal_bar.close;

   double ht_val_1 = 0.0;
   int ht_trend_1 = 0;
   if(!Strategy_HalfTrend(_Symbol, strategy_halftrend_amp, strategy_halftrend_atr_period, 1, ht_val_1, ht_trend_1))
      return false;

   const double jurik_vel_1 = Strategy_JurikVelocity(_Symbol, strategy_jurik_period, 1);
   const double coppock_1 = Strategy_Coppock(_Symbol, strategy_coppock_roc1, strategy_coppock_roc2, strategy_coppock_wma, 1);
   const double cmf_1 = Strategy_CMF(_Symbol, strategy_cmf_period, 1);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   // Long: Close[1] > HalfTrend[1] AND JurikVel[1] > 0 AND Coppock[1] > 0 AND CMF(20)[1] > +0.05
   if(close_1 > ht_val_1 && ht_trend_1 == 1 && jurik_vel_1 > 0.0 && coppock_1 > 0.0 && cmf_1 > 0.05)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, exec_price, atr_1, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "nnfx_halftrend_jurik_long";
      return (req.sl > 0.0 && req.sl < exec_price);
   }

   // Short: Close[1] < HalfTrend[1] AND JurikVel[1] < 0 AND Coppock[1] < 0 AND CMF(20)[1] < -0.05
   if(close_1 < ht_val_1 && ht_trend_1 == -1 && jurik_vel_1 < 0.0 && coppock_1 < 0.0 && cmf_1 < -0.05)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, exec_price, atr_1, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "nnfx_halftrend_jurik_short";
      return (req.sl > exec_price);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || current_sl <= 0.0 || volume <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const bool unprotected = is_buy ? (current_sl < open_price - point * 0.5)
                                      : (current_sl > open_price + point * 0.5);
      if(!unprotected)
         continue;

      const double initial_risk = is_buy ? (open_price - current_sl)
                                         : (current_sl - open_price);
      if(initial_risk <= 0.0)
         continue;

      const double atr_at_entry = initial_risk / strategy_sl_atr_mult;
      const double trigger_distance = strategy_tp_atr_mult * atr_at_entry;
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double favorable_move = is_buy ? (market_price - open_price)
                                           : (open_price - market_price);
      if(market_price <= 0.0 || favorable_move < trigger_distance)
         continue;

      const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_fraction);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(partial_lots <= 0.0 || partial_lots >= volume ||
         volume - partial_lots < min_lot - 1e-8)
         continue;

      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
      {
         const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips);
         const double target_sl = is_buy ? (open_price + be_buffer) : (open_price - be_buffer);
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, target_sl), "NNFX_TP1_BE_PROTECTION");
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   double ht_val_1 = 0.0;
   int ht_trend_1 = 0;
   if(!Strategy_HalfTrend(_Symbol, strategy_halftrend_amp, strategy_halftrend_atr_period, 1, ht_val_1, ht_trend_1))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: HalfTrend direction flips to down (-1)
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(ht_trend_1 == -1)
            return true;
      }
      // Short exit: HalfTrend direction flips to up (1)
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(ht_trend_1 == 1)
            return true;
      }
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
   if(!Strategy_ConfigValid())
      return INIT_PARAMETERS_INCORRECT;

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

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar(_Symbol, PERIOD_D1)) return;

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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(Strategy_NoTradeFilter()) return;
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
