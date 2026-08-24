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
input double strategy_max_slippage_ticks  = 3.0;    // Card market-order slippage tolerance

// One bounded D1 refresh supplies both entry and exit hooks.  TP1 state is
// explicit so a successful partial close is never repeated while the BE move
// is being retried.
bool   g_signal_ready       = false;
double g_cached_close_1     = 0.0;
double g_cached_halftrend_1 = 0.0;
int    g_cached_ht_trend_1  = 0;
double g_cached_jurik_vel_1 = 0.0;
double g_cached_coppock_1   = 0.0;
double g_cached_cmf_1       = 0.0;
double g_cached_atr_1       = 0.0;
ulong  g_tp1_ticket         = 0;
double g_tp1_price          = 0.0;
bool   g_tp1_done           = false;
datetime g_tp1_retry_after  = 0;
double g_initial_equity     = 0.0;

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
   if(strategy_halftrend_amp < 1 || strategy_halftrend_amp > 4 ||
      strategy_halftrend_atr_period < 50 || strategy_halftrend_atr_period > 150 ||
      MathAbs(strategy_halftrend_atr_mult - 2.0) > 1e-9 ||
      strategy_jurik_period < 8 || strategy_jurik_period > 21)
      return false;
   if(strategy_coppock_roc1 < 10 || strategy_coppock_roc1 > 20 ||
      strategy_coppock_roc2 < 8 || strategy_coppock_roc2 > 15 ||
      strategy_coppock_wma < 5 || strategy_coppock_wma > 15 ||
      strategy_cmf_period < 14 || strategy_cmf_period > 30 ||
      strategy_atr_period < 10 || strategy_atr_period > 20)
      return false;
   if(strategy_sl_atr_mult < 0.8 || strategy_sl_atr_mult > 1.5 ||
      MathAbs(strategy_tp_atr_mult - 1.0) > 1e-9 ||
      MathAbs(strategy_tp1_fraction - 0.5) > 1e-9 ||
      strategy_be_buffer_pips != 1 ||
      strategy_spread_atr_mult < 1.0 || strategy_spread_atr_mult > 2.5)
      return false;
   if(MathAbs(strategy_daily_loss_halt_pct - 2.0) > 1e-9 ||
      MathAbs(strategy_daily_hard_stop_pct - 2.5) > 1e-9 ||
      MathAbs(strategy_total_dd_halt_pct - 5.0) > 1e-9)
      return false;
   if(MathAbs(strategy_per_trade_risk_cap_pct - 0.5) > 1e-9 ||
      MathAbs(strategy_max_slippage_ticks - 3.0) > 1e-9)
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

bool Strategy_TotalDrawdownAllows()
{
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity <= 0.0 || equity_now <= 0.0)
      return false;
   const double drawdown_pct = ((g_initial_equity - equity_now) / g_initial_equity) * 100.0;
   if(drawdown_pct < strategy_total_dd_halt_pct)
      return true;

   QM_KillSwitchTrip(KS_PORTFOLIO_DD,
                     StringFormat("{\"initial_equity\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"halt_pct\":%.6f}",
                                  g_initial_equity, equity_now, drawdown_pct,
                                  strategy_total_dd_halt_pct));
   return false;
}

bool Strategy_RefreshClosedBarSignals()
{
   g_signal_ready = false;

   int required = strategy_jurik_period * 8 + 42;
   int candidate = strategy_coppock_wma + strategy_coppock_roc1 + 2;
   if(strategy_coppock_roc2 > strategy_coppock_roc1)
      candidate = strategy_coppock_wma + strategy_coppock_roc2 + 2;
   if(candidate > required) required = candidate;
   if(strategy_cmf_period + 2 > required) required = strategy_cmf_period + 2;
   if(required < 64 || required > 256)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, required, rates); // perf-allowed: one bounded D1 cache fill after QM_IsNewBar; no pooled JMA/Coppock/CMF helper exists.
   if(copied != required || ArraySize(rates) < required)
      return false;

   const int newest = copied - 1;
   if(newest < 2 || newest >= ArraySize(rates) || rates[newest].close <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_D1, strategy_halftrend_amp, 1, PRICE_CLOSE);
   const double halftrend_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_halftrend_atr_period, 1);
   const double trade_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ema <= 0.0 || halftrend_atr <= 0.0 || trade_atr <= 0.0)
      return false;

   const double close_1 = rates[newest].close;
   const int ht_trend = (close_1 >= ema) ? 1 : -1;
   const double halftrend = (ht_trend > 0)
      ? (ema - strategy_halftrend_atr_mult * halftrend_atr)
      : (ema + strategy_halftrend_atr_mult * halftrend_atr);

   // Open Jurik recurrence, phase=0 (phase ratio 1.5) and power=2.
   const double phase_ratio = 1.5;
   const double beta = (0.45 * ((double)strategy_jurik_period - 1.0)) /
                       (0.45 * ((double)strategy_jurik_period - 1.0) + 2.0);
   const double alpha = MathPow(beta, 2.0);
   const double one_minus_alpha = 1.0 - alpha;
   double e0 = rates[0].close;
   double e1 = 0.0;
   double e2 = 0.0;
   double jma = rates[0].close;
   double jma_previous = 0.0;
   double jma_current = 0.0;
   if(e0 <= 0.0)
      return false;
   for(int i = 1; i <= newest; ++i)
   {
      if(i >= ArraySize(rates) || rates[i].close <= 0.0)
         return false;
      e0 = one_minus_alpha * rates[i].close + alpha * e0;
      e1 = (rates[i].close - e0) * (1.0 - beta) + beta * e1;
      e2 = (e0 + phase_ratio * e1 - jma) * one_minus_alpha * one_minus_alpha +
           alpha * alpha * e2;
      jma += e2;
      if(i == newest - 1) jma_previous = jma;
      if(i == newest) jma_current = jma;
   }
   if(jma_current <= 0.0 || jma_previous <= 0.0)
      return false;

   double coppock_sum = 0.0;
   double coppock_weight = 0.0;
   for(int i = 0; i < strategy_coppock_wma; ++i)
   {
      const int current_index = newest - i;
      const int roc1_index = current_index - strategy_coppock_roc1;
      const int roc2_index = current_index - strategy_coppock_roc2;
      if(current_index < 0 || roc1_index < 0 || roc2_index < 0 ||
         current_index >= ArraySize(rates) || roc1_index >= ArraySize(rates) ||
         roc2_index >= ArraySize(rates))
         return false;
      const double current_close = rates[current_index].close;
      const double roc1_close = rates[roc1_index].close;
      const double roc2_close = rates[roc2_index].close;
      if(current_close <= 0.0 || roc1_close <= 0.0 || roc2_close <= 0.0)
         return false;
      const double roc_sum = ((current_close - roc1_close) / roc1_close * 100.0) +
                             ((current_close - roc2_close) / roc2_close * 100.0);
      const double weight = (double)(strategy_coppock_wma - i);
      coppock_sum += roc_sum * weight;
      coppock_weight += weight;
   }
   if(coppock_weight <= 0.0)
      return false;

   double mfv_sum = 0.0;
   double volume_sum = 0.0;
   for(int i = 0; i < strategy_cmf_period; ++i)
   {
      const int index = newest - i;
      if(index < 0 || index >= ArraySize(rates))
         return false;
      const double range = rates[index].high - rates[index].low;
      const long volume = rates[index].tick_volume;
      if(range <= 0.0 || volume <= 0)
         continue;
      const double multiplier = ((rates[index].close - rates[index].low) -
                                 (rates[index].high - rates[index].close)) / range;
      mfv_sum += multiplier * (double)volume;
      volume_sum += (double)volume;
   }
   if(volume_sum <= 0.0)
      return false;

   g_cached_close_1 = close_1;
   g_cached_halftrend_1 = halftrend;
   g_cached_ht_trend_1 = ht_trend;
   g_cached_jurik_vel_1 = jma_current - jma_previous;
   g_cached_coppock_1 = coppock_sum / coppock_weight;
   g_cached_cmf_1 = mfv_sum / volume_sum;
   g_cached_atr_1 = trade_atr;
   g_signal_ready = true;
   return true;
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

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || g_cached_atr_1 <= 0.0)
      return true;
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * g_cached_atr_1)
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

   if(!g_signal_ready)
      return false;

   // Long: Close[1] > HalfTrend[1] AND JurikVel[1] > 0 AND Coppock[1] > 0 AND CMF(20)[1] > +0.05
   if(g_cached_close_1 > g_cached_halftrend_1 && g_cached_ht_trend_1 == 1 &&
      g_cached_jurik_vel_1 > 0.0 && g_cached_coppock_1 > 0.0 && g_cached_cmf_1 > 0.05)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, g_cached_atr_1, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "nnfx_halftrend_jurik_long";
      return (req.sl > 0.0 && req.sl < ask);
   }

   // Short: Close[1] < HalfTrend[1] AND JurikVel[1] < 0 AND Coppock[1] < 0 AND CMF(20)[1] < -0.05
   if(g_cached_close_1 < g_cached_halftrend_1 && g_cached_ht_trend_1 == -1 &&
      g_cached_jurik_vel_1 < 0.0 && g_cached_coppock_1 < 0.0 && g_cached_cmf_1 < -0.05)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, g_cached_atr_1, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "nnfx_halftrend_jurik_short";
      return (req.sl > bid);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;

   bool found_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      found_position = true;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || current_sl <= 0.0 || volume <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      if(ticket != g_tp1_ticket)
      {
         g_tp1_ticket = ticket;
         g_tp1_retry_after = 0;
         g_tp1_done = is_buy ? (current_sl >= open_price)
                             : (current_sl > 0.0 && current_sl <= open_price);
         const double initial_risk = MathAbs(open_price - current_sl);
         if(initial_risk <= point)
         {
            g_tp1_price = 0.0;
            continue;
         }
         const double trigger_distance = initial_risk * strategy_tp_atr_mult /
                                         strategy_sl_atr_mult;
         g_tp1_price = QM_TM_NormalizePrice(_Symbol,
                           is_buy ? open_price + trigger_distance
                                  : open_price - trigger_distance);
      }

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool tp1_reached = is_buy ? (market_price > 0.0 && market_price >= g_tp1_price)
                                      : (market_price > 0.0 && market_price <= g_tp1_price);
      if(!g_tp1_done && g_tp1_price > 0.0 && tp1_reached)
      {
         const datetime now = TimeCurrent();
         if(now < g_tp1_retry_after)
            continue;
         const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_fraction);
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         const bool can_partial = (partial_lots > 0.0 && partial_lots < volume &&
                                   min_lot > 0.0 && volume_step > 0.0 &&
                                   volume - partial_lots + volume_step * 0.1 >= min_lot);
         if(!can_partial)
         {
            QM_LogEvent(QM_ERROR, "NNFX_TP1_VOLUME_UNSPLITTABLE",
                        StringFormat("{\"ticket\":%I64u,\"volume\":%.4f}", ticket, volume));
            g_tp1_retry_after = now + 60;
            continue;
         }
         if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
         {
            g_tp1_done = true;
            g_tp1_retry_after = 0;
         }
         else
         {
            g_tp1_retry_after = now + 60;
            continue;
         }
      }

      // This branch is separate from the partial-close call.  Once TP1 has
      // succeeded, only the protective SL is retried on later ticks.
      if(g_tp1_done && PositionSelectByTicket(ticket))
      {
         const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips);
         if(be_buffer <= 0.0)
            continue;
         const double selected_sl = PositionGetDouble(POSITION_SL);
         const double target_sl = is_buy ? (open_price + be_buffer) : (open_price - be_buffer);
         const bool needs_move = is_buy ? (target_sl > selected_sl + point * 0.5)
                                        : (selected_sl <= 0.0 || target_sl < selected_sl - point * 0.5);
         if(needs_move)
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, target_sl),
                         "NNFX_TP1_BE_PROTECTION");
      }
   }

   if(!found_position)
   {
      g_tp1_ticket = 0;
      g_tp1_price = 0.0;
      g_tp1_done = false;
      g_tp1_retry_after = 0;
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !g_signal_ready) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: HalfTrend direction flips to down (-1)
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(g_cached_ht_trend_1 == -1)
            return true;
      }
      // Short exit: HalfTrend direction flips to up (1)
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(g_cached_ht_trend_1 == 1)
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const int deviation_points = (point > 0.0 && tick_size > 0.0)
      ? (int)MathFloor(strategy_max_slippage_ticks * tick_size / point + 1e-9)
      : 0;
   if(deviation_points < 1)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   g_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity <= 0.0)
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_36006\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!Strategy_TotalDrawdownAllows()) return;
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar(_Symbol, PERIOD_D1)) return;
   if(!Strategy_RefreshClosedBarSignals()) return;

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
