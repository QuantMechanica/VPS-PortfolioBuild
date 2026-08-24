#property strict
#property version   "5.0"
#property description "QM5_36001 VP NNFX Classic Benchmark Algorithm (McGinley + SSL + WAE)"
// Strategy Card: QM5_36001 (nnfx-classic-mcginley-ssl-wae), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36001
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36001;
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
input int    strategy_mcginley_period     = 14;     // McGinley Dynamic baseline period
input int    strategy_ssl_period          = 10;     // SSL Channel C1 trigger period
input int    strategy_vortex_period       = 14;     // Vortex C2 confirmation period
input int    strategy_wae_fast            = 12;     // WAE MACD fast EMA period
input int    strategy_wae_slow            = 26;     // WAE MACD slow EMA period
input int    strategy_wae_signal          = 9;      // WAE MACD signal SMA period
input int    strategy_wae_bb_period       = 20;     // WAE Bollinger Bands period
input double strategy_wae_bb_deviation    = 2.0;    // WAE Bollinger Bands deviation
input int    strategy_wae_sensitivity     = 150;    // WAE sensitivity multiplier
input int    strategy_wae_deadzone_pts    = 150;    // WAE deadzone in points
input int    strategy_demarker_period     = 14;     // DeMarker exit indicator period
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_tp_atr_mult         = 1.00;   // Take profit ATR multiplier
input double strategy_tp1_fraction        = 0.50;   // Fraction closed at the +1 ATR TP1 trigger
input int    strategy_be_buffer_pips      = 1;      // Runner protection beyond entry after TP1
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_warmup_bars         = 150;    // Warmup lookback bars for McGinley recursion
input double strategy_daily_loss_halt_pct = 2.0;    // Realized-loss entry halt from the card
input double strategy_daily_hard_stop_pct = 2.5;    // Restart-safe daily equity hard stop
input double strategy_total_dd_halt_pct   = 5.0;    // Account total-drawdown hard stop
input double strategy_per_trade_risk_cap_pct = 1.0; // Card risk ceiling per trade
input double strategy_max_slippage_ticks  = 3.0;    // Market-order slippage ceiling

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

double Strategy_McGinley(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1)
      return 0.0;

   const int bars_needed = strategy_warmup_bars + 1;
   double closes[];
   ArrayResize(closes, bars_needed);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(sym, PERIOD_D1, shift, bars_needed, closes); // perf-allowed: bounded closed-bar McGinley vector behind QM_IsNewBar()
   if(copied != bars_needed || ArraySize(closes) < bars_needed)
      return 0.0;

   double md = closes[bars_needed - 1];
   if(md <= 0.0)
      return 0.0;
   for(int i = bars_needed - 2; i >= 0; --i)
   {
      if(i >= ArraySize(closes))
         return 0.0;
      const double c = closes[i];
      if(c <= 0.0 || md <= 0.0)
         return 0.0;
      const double ratio = c / md;
      const double denom = (double)period * MathPow(ratio, 4.0);
      if(denom <= 0.0)
         return 0.0;
      md = md + (c - md) / denom;
   }
   return md;
}

int Strategy_SSLState(const int shift)
{
   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, shift, closed_bar))
      return 0;
   const double close_price = closed_bar.close;
   const double high_ma = QM_SMA(_Symbol, PERIOD_D1, strategy_ssl_period, shift, PRICE_HIGH);
   const double low_ma  = QM_SMA(_Symbol, PERIOD_D1, strategy_ssl_period, shift, PRICE_LOW);
   if(close_price <= 0.0 || high_ma <= 0.0 || low_ma <= 0.0)
      return 0;
   if(close_price > high_ma)
      return 1;
   if(close_price < low_ma)
      return -1;
   return 0;
}

int Strategy_SSLCross(const int shift)
{
   const int state_now = Strategy_SSLState(shift);
   const int state_prev = Strategy_SSLState(shift + 1);
   if(state_now == 1 && state_prev != 1)
      return 1;
   if(state_now == -1 && state_prev != -1)
      return -1;
   return 0;
}

bool Strategy_Vortex(const string sym, const int period, const int shift, double &vi_plus, double &vi_minus)
{
   vi_plus = 0.0;
   vi_minus = 0.0;
   if(period <= 0 || shift < 1)
      return false;

   const int bars_needed = period + 1;
   MqlRates rates[];
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(sym, PERIOD_D1, shift, bars_needed, rates); // perf-allowed: bounded closed-bar Vortex vector behind QM_IsNewBar()
   if(copied != bars_needed || ArraySize(rates) < bars_needed)
      return false;

   double sum_vmp = 0.0;
   double sum_vmm = 0.0;
   double sum_tr  = 0.0;
   for(int k = 0; k < period; ++k)
   {
      if(k + 1 >= ArraySize(rates))
         return false;
      const double hi   = rates[k].high;
      const double lo   = rates[k].low;
      const double hi_p = rates[k + 1].high;
      const double lo_p = rates[k + 1].low;
      const double cl_p = rates[k + 1].close;
      if(hi <= 0.0 || lo <= 0.0 || hi_p <= 0.0 || lo_p <= 0.0 || cl_p <= 0.0)
         return false;

      const double vmp = MathAbs(hi - lo_p);
      const double vmm = MathAbs(lo - hi_p);
      const double tr  = MathMax(hi - lo, MathMax(MathAbs(hi - cl_p), MathAbs(lo - cl_p)));

      sum_vmp += vmp;
      sum_vmm += vmm;
      sum_tr  += tr;
   }
   if(sum_tr <= 0.0)
      return false;
   vi_plus  = sum_vmp / sum_tr;
   vi_minus = sum_vmm / sum_tr;
   return true;
}

bool Strategy_WAEPass(double &wae_val, double &explosion_val)
{
   wae_val = 0.0;
   explosion_val = 0.0;
   const double macd_now  = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 1, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 2, PRICE_CLOSE);
   const double bb_upper  = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower  = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || point <= 0.0)
      return false;

   const double explosion = MathAbs(bb_upper - bb_lower);
   const double deadzone = (double)strategy_wae_deadzone_pts * point;
   const double threshold = MathMax(explosion, deadzone);
   explosion_val = threshold;

   // The approved equations use WAE as a direction-neutral expansion gate.
   // McGinley, SSL and Vortex determine direction; WAE only proves magnitude.
   const double momentum = (macd_now - macd_prev) * (double)strategy_wae_sensitivity;
   wae_val = MathAbs(momentum);
   return (wae_val > threshold);
}

bool Strategy_ConfigValid()
{
   if(strategy_mcginley_period < 2 || strategy_ssl_period < 2 ||
      strategy_vortex_period < 2 || strategy_wae_fast < 1 ||
      strategy_wae_slow <= strategy_wae_fast || strategy_wae_signal < 1 ||
      strategy_wae_bb_period < 2 || strategy_wae_bb_deviation <= 0.0 ||
      strategy_wae_sensitivity <= 0 || strategy_wae_deadzone_pts < 0 ||
      strategy_demarker_period < 2 || strategy_atr_period < 2 ||
      strategy_warmup_bars < strategy_mcginley_period)
      return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0 ||
      strategy_tp1_fraction <= 0.0 || strategy_tp1_fraction >= 1.0 ||
      strategy_be_buffer_pips < 0 || strategy_spread_atr_mult <= 0.0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0 || strategy_per_trade_risk_cap_pct <= 0.0 ||
      strategy_per_trade_risk_cap_pct > 1.0 || strategy_max_slippage_ticks <= 0.0)
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

int Strategy_TP1PartialState(const ulong position_id, const datetime position_time)
{
   if(position_id == 0 || position_time <= 0)
      return -1;
   if(!HistorySelect(position_time, TimeCurrent()))
      return -1;

   const long magic = (long)QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != position_id)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
         return 1;
   }
   return 0;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
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

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, closed_bar))
      return false;
   const double close_1 = closed_bar.close;
   if(close_1 <= 0.0)
      return false;

   const double mcginley_1 = Strategy_McGinley(_Symbol, strategy_mcginley_period, 1);
   if(mcginley_1 <= 0.0)
      return false;

   const int ssl_cross = Strategy_SSLCross(1);
   if(ssl_cross == 0)
      return false;

   double vi_plus = 0.0, vi_minus = 0.0;
   if(!Strategy_Vortex(_Symbol, strategy_vortex_period, 1, vi_plus, vi_minus))
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 10.0 * pip_size);

   double wae_val = 0.0, explosion_val = 0.0;

   // Long: Close > McGinley AND SSL Crossover == UP AND Vortex+ > Vortex- AND WAE > ExplosionLine
   if(close_1 > mcginley_1 && ssl_cross > 0 && vi_plus > vi_minus && Strategy_WAEPass(wae_val, explosion_val))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);
      req.tp = 0.0;
      req.reason = "nnfx_classic_long";
      return true;
   }

   // Short: Close < McGinley AND SSL Crossover == DOWN AND Vortex- > Vortex+ AND WAE > ExplosionLine
   if(close_1 < mcginley_1 && ssl_cross < 0 && vi_minus > vi_plus && Strategy_WAEPass(wae_val, explosion_val))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);
      req.tp = 0.0;
      req.reason = "nnfx_classic_short";
      return true;
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
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_sl <= 0.0 || price <= 0.0 || volume <= 0.0) continue;

      const bool unprotected = is_buy ? (current_sl < open_price - point * 0.5)
                                      : (current_sl > open_price + point * 0.5);
      if(!unprotected)
         continue;

      const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int partial_state = Strategy_TP1PartialState(position_id, position_time);
      if(partial_state < 0)
         continue;

      const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                               strategy_be_buffer_pips);
      if(be_buffer < 0.0)
         continue;
      const double be_sl = QM_TM_NormalizePrice(_Symbol,
                                                is_buy ? (open_price + be_buffer)
                                                       : (open_price - be_buffer));
      if(partial_state > 0)
      {
         QM_TM_MoveSL(ticket, be_sl, "NNFX_TP1_BE_RESTORE");
         continue;
      }

      const double initial_risk = is_buy ? (open_price - current_sl)
                                         : (current_sl - open_price);
      if(initial_risk <= 0.0)
         continue;
      const double atr_at_entry = initial_risk / strategy_sl_atr_mult;
      const double be_trigger = strategy_tp_atr_mult * atr_at_entry;

      const double trigger = is_buy ? (open_price + be_trigger) : (open_price - be_trigger);
      const bool hit_trigger = is_buy ? (price >= trigger) : (price <= trigger);
      if(hit_trigger)
      {
         const double partial_lots = QM_TM_NormalizeVolume(_Symbol,
                                                           volume * strategy_tp1_fraction);
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(partial_lots <= 0.0 || partial_lots >= volume ||
            volume - partial_lots < min_lot - 1e-8)
            continue;
         if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
         {
            QM_TM_MoveSL(ticket, be_sl, "NNFX_TP1_BE_PROTECTION");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   const double demarker_1 = QM_DeMarker(_Symbol, PERIOD_D1, strategy_demarker_period, 1);
   const double demarker_2 = QM_DeMarker(_Symbol, PERIOD_D1, strategy_demarker_period, 2);
   const int ssl_state_1 = Strategy_SSLState(1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long runner exit: DeMarker crosses overbought (>= 0.70 while bar 2 was < 0.70) OR SSL flips DOWN (< 0)
      if(pos_type == POSITION_TYPE_BUY)
      {
         if((demarker_1 >= 0.70 && demarker_2 < 0.70) || (ssl_state_1 < 0))
            return true;
      }
      // Short runner exit: DeMarker crosses oversold (<= 0.30 while bar 2 was > 0.30) OR SSL flips UP (> 0)
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if((demarker_1 > 0.0 && demarker_1 <= 0.30 && demarker_2 > 0.30) || (ssl_state_1 > 0))
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

   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tick_size <= 0.0 || point <= 0.0)
      return INIT_FAILED;
   const int deviation_points =
      (int)MathCeil(strategy_max_slippage_ticks * tick_size / point);
   if(deviation_points <= 0)
      return INIT_FAILED;
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

   const bool is_new_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   if(!is_new_bar)
      return;
   QM_EquityStreamOnNewBar();

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

