#property strict
#property version   "5.0"
#property description "QM5_36004 NNFX ALMA & QQE Volume Flow Sniper"
// Strategy Card: QM5_36004 (nnfx-alma-qqe-volume-flow-sniper), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36004
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36004;
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
input int    strategy_alma_period         = 20;     // ALMA baseline window period
input double strategy_alma_sigma          = 6.0;    // ALMA Gaussian distribution width
input double strategy_alma_offset         = 0.85;   // ALMA Gaussian offset parameter
input int    strategy_qqe_rsi_period      = 14;     // QQE RSI smoothing period
input int    strategy_qqe_sf              = 5;      // QQE smoothing factor (RSI EMA)
input int    strategy_qqe_wilder          = 27;     // QQE Wilder smoothing period
input double strategy_qqe_mult            = 4.236;  // QQE fast ATR multiplier
input int    strategy_dpo_period          = 20;     // Detrended Price Oscillator period
input int    strategy_vfi_period          = 130;    // Volume Flow Indicator lookback period
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_tp_atr_mult         = 1.00;   // Take profit ATR multiplier (TP1 partial close level)
input double strategy_tp1_fraction        = 0.50;   // TP1 partial-close volume fraction
input int    strategy_be_buffer_pips      = 1;      // Runner break-even buffer in pips
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.0;    // Daily realized-loss entry halt percent
input double strategy_daily_hard_stop_pct = 2.5;    // Daily equity hard stop percent
input double strategy_total_dd_halt_pct   = 5.0;    // Account-level total drawdown stop percent
input double strategy_per_trade_risk_cap_pct = 1.0; // Per-trade risk cap percent
input int    strategy_slippage_ticks      = 3;      // Market-order slippage tolerance in trade ticks

const int STRATEGY_MAX_INDICATOR_BARS = 512;
long g_tp1_position_id = 0;
bool g_tp1_completed = false;
bool g_tp1_state_known = false;

// -----------------------------------------------------------------------------
// Helpers & Indicator Math
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool Strategy_ConfigValid()
{
   if(strategy_alma_period < 2 || strategy_alma_period > STRATEGY_MAX_INDICATOR_BARS ||
      strategy_alma_sigma <= 0.0 || strategy_alma_offset < 0.0 || strategy_alma_offset > 1.0)
      return false;
   if(strategy_qqe_rsi_period < 2 || strategy_qqe_sf < 1 || strategy_qqe_wilder < 1 ||
      strategy_qqe_mult <= 0.0 ||
      strategy_qqe_sf + 2 * strategy_qqe_wilder + 30 > STRATEGY_MAX_INDICATOR_BARS)
      return false;
   if(strategy_dpo_period < 2 || strategy_dpo_period > STRATEGY_MAX_INDICATOR_BARS ||
      strategy_vfi_period < 2 || strategy_vfi_period > STRATEGY_MAX_INDICATOR_BARS ||
      strategy_atr_period < 2 || strategy_atr_period > STRATEGY_MAX_INDICATOR_BARS)
      return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0 ||
      strategy_tp1_fraction <= 0.0 || strategy_tp1_fraction >= 1.0 ||
      strategy_be_buffer_pips < 0 || strategy_spread_atr_mult <= 0.0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0 || strategy_per_trade_risk_cap_pct <= 0.0 ||
      strategy_per_trade_risk_cap_pct > 1.0)
      return false;
   if(strategy_slippage_ticks < 1 || strategy_slippage_ticks > 3)
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

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
}

bool Strategy_VolumeCanSplitTp1(const double volume)
{
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume <= 0.0 || volume_min <= 0.0 || volume_step <= 0.0)
      return false;

   const double close_lots = QM_TM_NormalizeVolume(_Symbol,
                                                    volume * strategy_tp1_fraction);
   const double runner_lots = volume - close_lots;
   const double tolerance = volume_step * 1e-6;
   return (close_lots >= volume_min - tolerance &&
           runner_lots >= volume_min - tolerance &&
           MathAbs(close_lots - runner_lots) <= tolerance);
}

bool Strategy_EntryVolumeSupportsTp1(const QM_OrderType side,
                                     const double entry_price,
                                     const double stop_price)
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || stop_price <= 0.0)
      return false;
   const double sl_points = MathAbs(entry_price - stop_price) / point;
   const ENUM_ORDER_TYPE order_type = (side == QM_BUY) ? ORDER_TYPE_BUY
                                                       : ORDER_TYPE_SELL;
   const double expected_lots = QM_LotsForRiskAtEntry(_Symbol,
                                                       sl_points,
                                                       order_type,
                                                       entry_price);
   return Strategy_VolumeCanSplitTp1(expected_lots);
}

bool Strategy_LoadTp1State(const long position_id, bool &completed)
{
   completed = false;
   if(position_id <= 0 || !HistorySelectByPosition((ulong)position_id))
      return false;

   const int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; ++i)
   {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0 ||
         (long)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) != position_id)
         continue;

      const ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      const ENUM_DEAL_ENTRY deal_entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      const bool trade_deal = (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL);
      if(trade_deal &&
         (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_OUT_BY ||
          deal_entry == DEAL_ENTRY_INOUT))
      {
         completed = true;
         break;
      }
   }
   return true;
}

bool Strategy_Tp1State(const long position_id, bool &completed)
{
   if(g_tp1_state_known && g_tp1_position_id == position_id)
   {
      completed = g_tp1_completed;
      return true;
   }

   bool reconstructed = false;
   if(!Strategy_LoadTp1State(position_id, reconstructed))
      return false;
   g_tp1_position_id = position_id;
   g_tp1_completed = reconstructed;
   g_tp1_state_known = true;
   completed = reconstructed;
   return true;
}

double Strategy_ALMA(const string sym, const int period, const double sigma, const double offset, const int shift)
{
   if(period < 2 || period > STRATEGY_MAX_INDICATOR_BARS || sigma <= 0.0 || shift < 1)
      return 0.0;
   const double m = offset * (double)(period - 1);
   const double s = (double)period / sigma;
   const double s2 = 2.0 * s * s;
   if(s2 <= 0.0) return 0.0;

   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const double c = iClose(sym, PERIOD_D1, shift + k); // perf-allowed: closed-bar ALMA Gaussian calculation behind QM_IsNewBar()
      if(c <= 0.0) return 0.0;
      const double diff = (double)k - m;
      const double weight = MathExp(-(diff * diff) / s2);
      sum_w += c * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return sum_w / sum_weight;
}

bool Strategy_QQEValue(const string sym, const int shift, double &out_rsi_ma, double &out_trail)
{
   out_rsi_ma = 0.0;
   out_trail = 0.0;

   const int sf = strategy_qqe_sf;
   const int wilder = strategy_qqe_wilder;
   const int rsi_p = strategy_qqe_rsi_period;
   const double factor = strategy_qqe_mult;

   if(sf < 1 || wilder < 1 || rsi_p < 2 || factor <= 0.0 || shift < 1)
      return false;

   const int warmup = sf + 2 * wilder + 30;
   const int n = warmup;
   if(n < 2 || n > STRATEGY_MAX_INDICATOR_BARS) return false;

   double rsi_ma[];
   if(ArrayResize(rsi_ma, n) != n || ArraySize(rsi_ma) < n)
      return false;

   const double k_factor = 2.0 / ((double)sf + 1.0);
   double ema = QM_RSI(sym, PERIOD_D1, rsi_p, shift + n - 1, PRICE_CLOSE);
   if(ema <= 0.0 && ema != 0.0) return false;
   rsi_ma[0] = ema;

   for(int idx = 1; idx < n; ++idx)
   {
      const int s = shift + n - 1 - idx;
      const double rsi = QM_RSI(sym, PERIOD_D1, rsi_p, s, PRICE_CLOSE);
      ema = k_factor * rsi + (1.0 - k_factor) * ema;
      rsi_ma[idx] = ema;
   }

   const double wk = 1.0 / (double)wilder;
   double atr_rsi = 0.0;
   double dar = 0.0;
   double trail = 50.0;

   for(int idx = 1; idx < n; ++idx)
   {
      const double diff = MathAbs(rsi_ma[idx] - rsi_ma[idx - 1]);
      if(idx == 1)
      {
         atr_rsi = diff;
         dar = diff;
      }
      else
      {
         atr_rsi = wk * diff + (1.0 - wk) * atr_rsi;
         dar = wk * atr_rsi + (1.0 - wk) * dar;
      }

      const double band = dar * factor;
      const double rma = rsi_ma[idx];
      const double rma_prev = rsi_ma[idx - 1];

      if(rma > trail)
      {
         const double long_band = rma - band;
         if(rma_prev > trail)
            trail = MathMax(trail, long_band);
         else
            trail = long_band;
      }
      else
      {
         const double short_band = rma + band;
         if(rma_prev < trail)
            trail = MathMin(trail, short_band);
         else
            trail = short_band;
      }
   }

   out_rsi_ma = rsi_ma[n - 1];
   out_trail = trail;
   return true;
}

int Strategy_QQEState(const string sym, const int shift)
{
   double rsi_ma = 0.0, trail = 0.0;
   if(!Strategy_QQEValue(sym, shift, rsi_ma, trail)) return 0;
   if(rsi_ma > trail) return 1;
   if(rsi_ma < trail) return -1;
   return 0;
}

int Strategy_QQECross(const string sym, const int shift)
{
   const int state_now = Strategy_QQEState(sym, shift);
   const int state_prev = Strategy_QQEState(sym, shift + 1);
   if(state_now == 1 && state_prev != 1)
      return 1;
   if(state_now == -1 && state_prev != -1)
      return -1;
   return 0;
}

double Strategy_DPO(const string sym, const int period, const int shift)
{
   if(period < 2 || period > STRATEGY_MAX_INDICATOR_BARS || shift < 1) return 0.0;
   const double c = iClose(sym, PERIOD_D1, shift); // perf-allowed: closed-bar DPO close price
   if(c <= 0.0) return 0.0;
   const int offset = period / 2 + 1;
   const double sma = QM_SMA(sym, PERIOD_D1, period, shift + offset, PRICE_CLOSE);
   if(sma <= 0.0) return 0.0;
   return (c - sma);
}

double Strategy_VFI(const string sym, const int period, const int shift)
{
   if(period < 2 || period > STRATEGY_MAX_INDICATOR_BARS || shift < 1) return 0.0;
   const double atr = QM_ATR(sym, PERIOD_D1, 14, shift);
   if(atr <= 0.0) return 0.0;
   const double cutoff = 0.2 * atr;

   double sum_flow = 0.0;
   double sum_vol = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const int s = shift + k;
      const double h   = iHigh(sym, PERIOD_D1, s);       // perf-allowed: closed-bar VFI typical price
      const double l   = iLow(sym, PERIOD_D1, s);        // perf-allowed: closed-bar VFI typical price
      const double c   = iClose(sym, PERIOD_D1, s);      // perf-allowed: closed-bar VFI typical price
      const double h_p = iHigh(sym, PERIOD_D1, s + 1);   // perf-allowed: closed-bar VFI prior typical price
      const double l_p = iLow(sym, PERIOD_D1, s + 1);    // perf-allowed: closed-bar VFI prior typical price
      const double c_p = iClose(sym, PERIOD_D1, s + 1);  // perf-allowed: closed-bar VFI prior typical price
      const double vol = (double)iVolume(sym, PERIOD_D1, s); // perf-allowed: closed-bar VFI volume
      if(h <= 0.0 || l <= 0.0 || c <= 0.0 || h_p <= 0.0 || l_p <= 0.0 || c_p <= 0.0 || vol <= 0.0)
         continue;

      const double typ   = (h + l + c) / 3.0;
      const double typ_p = (h_p + l_p + c_p) / 3.0;
      const double diff  = typ - typ_p;

      double flow = 0.0;
      if(diff > cutoff)
         flow = vol;
      else if(diff < -cutoff)
         flow = -vol;

      sum_flow += flow;
      sum_vol  += vol;
   }
   if(sum_vol <= 0.0) return 0.0;
   return (sum_flow / sum_vol);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(Strategy_HasOpenPosition())
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   const int hhmm = GetBarHhmm(utc_now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   if(Strategy_DailyRealizedLossHalt())
      return true;

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

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   if(close_1 <= 0.0)
      return false;

   const double alma_1 = Strategy_ALMA(_Symbol, strategy_alma_period, strategy_alma_sigma, strategy_alma_offset, 1);
   if(alma_1 <= 0.0)
      return false;

   const int qqe_cross = Strategy_QQECross(_Symbol, 1);
   if(qqe_cross == 0)
      return false;

   const double dpo_1 = Strategy_DPO(_Symbol, strategy_dpo_period, 1);
   const double vfi_1 = Strategy_VFI(_Symbol, strategy_vfi_period, 1);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 10.0 * pip_size);

   // Long: Close > ALMA AND QQE Cross == UP AND DPO > 0 AND VFI > 0
   if(close_1 > alma_1 && qqe_cross > 0 && dpo_1 > 0.0 && vfi_1 > 0.0)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);
      req.tp = 0.0; // TP1 is a managed 50% partial close; the remainder is the QQE runner.
      req.reason = "nnfx_alma_qqe_long";
      return (req.sl > 0.0 && Strategy_EntryVolumeSupportsTp1(req.type, exec_price, req.sl));
   }

   // Short: Close < ALMA AND QQE Cross == DOWN AND DPO < 0 AND VFI < 0
   if(close_1 < alma_1 && qqe_cross < 0 && dpo_1 < 0.0 && vfi_1 < 0.0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);
      req.tp = 0.0; // TP1 is a managed 50% partial close; the remainder is the QQE runner.
      req.reason = "nnfx_alma_qqe_short";
      return (req.sl > 0.0 && Strategy_EntryVolumeSupportsTp1(req.type, exec_price, req.sl));
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
      const long position_id = PositionGetInteger(POSITION_IDENTIFIER);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(position_id <= 0 || open_price <= 0.0 || current_sl <= 0.0 || volume <= 0.0)
         continue;

      bool tp1_completed = false;
      if(!Strategy_Tp1State(position_id, tp1_completed))
         continue;

      const bool unprotected = is_buy ? (current_sl < open_price - point * 0.5)
                                      : (current_sl > open_price + point * 0.5);
      if(tp1_completed)
      {
         if(unprotected)
         {
            const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips);
            const double target_sl = is_buy ? (open_price + be_buffer) : (open_price - be_buffer);
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, target_sl), "NNFX_TP1_BE_PROTECTION");
         }
         continue;
      }

      if(!unprotected || !Strategy_VolumeCanSplitTp1(volume))
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

      const double partial_lots = QM_TM_NormalizeVolume(_Symbol,
                                                         volume * strategy_tp1_fraction);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(partial_lots <= 0.0 || partial_lots >= volume ||
         volume - partial_lots < min_lot - 1e-8)
         continue;

      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
      {
         g_tp1_position_id = position_id;
         g_tp1_completed = true;
         g_tp1_state_known = true;
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

   const int qqe_cross = Strategy_QQECross(_Symbol, 1);
   if(qqe_cross == 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Runner exit is the card-authorized opposite QQE crossover.
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(qqe_cross < 0)
            return true;
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(qqe_cross > 0)
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

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return INIT_FAILED;
   const int deviation_points = (int)MathCeil(strategy_slippage_ticks * tick_size / point);
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

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
   g_tp1_state_known = false;
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}

