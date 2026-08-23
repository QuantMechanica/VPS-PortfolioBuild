#property strict
#property version   "5.0"
#property description "QM5_36002 NNFX Kijun-Sen & Absolute Strength (ASO) Engine"
// Strategy Card: QM5_36002 (nnfx-kijunsen-absolute-strength-damiani), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36002
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36002;
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
input int    strategy_kijun_period        = 26;     // Kijun-Sen baseline lookback period
input int    strategy_tenkan_period       = 9;      // Tenkan-Sen period
input int    strategy_senkou_period       = 52;     // Senkou Span B period
input int    strategy_aso_period          = 10;     // Absolute Strength Oscillator period
input int    strategy_aroon_period        = 25;     // Aroon confirmation period
input double strategy_aroon_threshold     = 70.0;   // Aroon confirmation threshold
input int    strategy_damiani_vis_period  = 13;     // Damiani Volatmeter viscosity ATR period
input int    strategy_damiani_sed_period  = 40;     // Damiani Volatmeter sedimentation ATR period
input double strategy_damiani_threshold   = 1.40;   // Damiani Volatmeter threshold multiplier
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_tp_atr_mult         = 1.00;   // TP1 trigger ATR multiplier
input double strategy_tp1_fraction        = 0.50;   // TP1 partial-close volume fraction
input int    strategy_be_buffer_pips      = 1;      // Runner break-even buffer in pips
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.0;    // Daily realized-loss entry halt percent
input double strategy_daily_hard_stop_pct = 2.5;    // Daily equity hard stop percent
input double strategy_total_dd_halt_pct   = 5.0;    // Account-level total drawdown stop percent
input double strategy_per_trade_risk_cap_pct = 0.5; // Per-trade risk cap percent
input int    strategy_slippage_ticks      = 3;      // Market-order slippage tolerance in trade ticks

double g_closed_close_1 = 0.0;
double g_closed_kijun_1 = 0.0;
double g_closed_atr_1   = 0.0;

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
   if(strategy_kijun_period < 2 || strategy_tenkan_period < 2 || strategy_senkou_period < 2)
      return false;
   if(strategy_aso_period < 2 || strategy_aroon_period < 2)
      return false;
   if(strategy_aroon_threshold <= 0.0 || strategy_aroon_threshold > 100.0)
      return false;
   if(strategy_damiani_vis_period < 2 || strategy_damiani_sed_period <= strategy_damiani_vis_period ||
      strategy_damiani_threshold <= 0.0)
      return false;
   if(strategy_atr_period < 2 || strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
      return false;
   if(strategy_tp1_fraction <= 0.0 || strategy_tp1_fraction >= 1.0 || strategy_be_buffer_pips < 0)
      return false;
   if(strategy_spread_atr_mult <= 0.0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct || strategy_total_dd_halt_pct <= 0.0)
      return false;
   if(strategy_per_trade_risk_cap_pct <= 0.0 || strategy_per_trade_risk_cap_pct > 1.0)
      return false;
   if(strategy_slippage_ticks < 1 || strategy_slippage_ticks > 3)
      return false;
   return true;
}

bool Strategy_DailyRealizedLossHalt()
{
   // Card semantics are realized loss, not floating equity. Query the whole
   // account so another strategy's closed loss cannot be ignored by this EA.
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

double Strategy_KijunSen(const string sym, const int shift)
{
   if(shift < 1) return 0.0;
   return QM_Ichimoku_KijunSen(sym, PERIOD_D1, strategy_tenkan_period,
                               strategy_kijun_period, strategy_senkou_period, shift);
}

bool Strategy_ASO(const string sym, const int period, const int shift, double &aso_bulls, double &aso_bears)
{
   aso_bulls = 0.0;
   aso_bears = 0.0;
   if(period <= 0 || shift < 1) return false;
   double sum_bulls = 0.0;
   double sum_bears = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const int s = shift + k;
      const double c      = iClose(sym, PERIOD_D1, s);     // perf-allowed: bespoke ASO close-delta math, called only behind the framework D1 new-bar gate.
      const double c_prev = iClose(sym, PERIOD_D1, s + 1); // perf-allowed: bespoke ASO close-delta math, called only behind the framework D1 new-bar gate.
      if(c <= 0.0 || c_prev <= 0.0) return false;
      if(c > c_prev)
         sum_bulls += (c - c_prev);
      else if(c < c_prev)
         sum_bears += (c_prev - c);
   }
   aso_bulls = sum_bulls / (double)period;
   aso_bears = sum_bears / (double)period;
   return true;
}

bool Strategy_Aroon(const string sym, const int period, const int shift, double &aroon_up, double &aroon_down)
{
   aroon_up = 0.0;
   aroon_down = 0.0;
   if(period <= 1 || shift < 1) return false;
   const int high_shift = iHighest(sym, PERIOD_D1, MODE_HIGH, period, shift); // perf-allowed: bespoke Aroon window, called only behind the framework D1 new-bar gate.
   const int low_shift  = iLowest(sym, PERIOD_D1, MODE_LOW, period, shift);   // perf-allowed: bespoke Aroon window, called only behind the framework D1 new-bar gate.
   if(high_shift < shift || low_shift < shift) return false;
   const int periods_since_high = high_shift - shift;
   const int periods_since_low  = low_shift - shift;
   aroon_up   = ((double)(period - periods_since_high) / (double)period) * 100.0;
   aroon_down = ((double)(period - periods_since_low)  / (double)period) * 100.0;
   return true;
}

bool Strategy_DamianiTrade(const string sym, const int shift)
{
   const double atr_vis = QM_ATR(sym, PERIOD_D1, strategy_damiani_vis_period, shift);
   const double atr_sed = QM_ATR(sym, PERIOD_D1, strategy_damiani_sed_period, shift);
   const double std_vis = QM_StdDev(sym, PERIOD_D1, strategy_damiani_vis_period, shift);
   const double std_sed = QM_StdDev(sym, PERIOD_D1, strategy_damiani_sed_period, shift);
   if(atr_sed <= 0.0 || std_sed <= 0.0) return false;
   const double vol  = atr_vis / atr_sed;
   const double anti = (std_vis / std_sed) * strategy_damiani_threshold;
   return (vol > anti);
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

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && g_closed_atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = g_closed_atr_1 / point;
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

   if(g_closed_close_1 <= 0.0)
      return false;

   if(g_closed_kijun_1 <= 0.0)
      return false;

   double aso_bulls = 0.0, aso_bears = 0.0;
   if(!Strategy_ASO(_Symbol, strategy_aso_period, 1, aso_bulls, aso_bears))
      return false;

   double aroon_up = 0.0, aroon_down = 0.0;
   if(!Strategy_Aroon(_Symbol, strategy_aroon_period, 1, aroon_up, aroon_down))
      return false;

   if(!Strategy_DamianiTrade(_Symbol, 1))
      return false;

   if(g_closed_atr_1 <= 0.0)
      return false;

   // Long: Close[1] > Kijun[1] AND ASO_Bulls[1] > ASO_Bears[1] AND AroonUp[1] >= 70.0 AND Damiani Trade == TRUE
   if(g_closed_close_1 > g_closed_kijun_1 && aso_bulls > aso_bears && aroon_up >= strategy_aroon_threshold)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : g_closed_close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, exec_price, g_closed_atr_1, strategy_sl_atr_mult);
      req.tp = 0.0; // TP1 is a managed 50% partial close; the remainder is the Kijun runner.
      req.reason = "nnfx_kijun_aso_long";
      return (req.sl > 0.0);
   }

   // Short: Close[1] < Kijun[1] AND ASO_Bears[1] > ASO_Bulls[1] AND AroonDown[1] >= 70.0 AND Damiani Trade == TRUE
   if(g_closed_close_1 < g_closed_kijun_1 && aso_bears > aso_bulls && aroon_down >= strategy_aroon_threshold)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : g_closed_close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, exec_price, g_closed_atr_1, strategy_sl_atr_mult);
      req.tp = 0.0; // TP1 is a managed 50% partial close; the remainder is the Kijun runner.
      req.reason = "nnfx_kijun_aso_short";
      return (req.sl > 0.0);
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   // This calendar edge is independent of the framework entry new-bar tracker,
   // so it cannot consume the single QM_IsNewBar event used below in OnTick.
   if(QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol))
   {
      g_closed_close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one closed D1 read per calendar-period edge.
      g_closed_kijun_1 = Strategy_KijunSen(_Symbol, 1);
      g_closed_atr_1   = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   }

   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0) return;

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
         continue; // TP1 already completed; do not repeatedly halve the runner.

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

   if(g_closed_close_1 <= 0.0 || g_closed_kijun_1 <= 0.0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: price re-crosses below Kijun-Sen line
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(g_closed_close_1 < g_closed_kijun_1)
            return true;
      }
      // Short exit: price re-crosses above Kijun-Sen line
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(g_closed_close_1 > g_closed_kijun_1)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_36002\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;

   // Entry blackouts must not suppress management or strategy exits.
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1)) return;
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
