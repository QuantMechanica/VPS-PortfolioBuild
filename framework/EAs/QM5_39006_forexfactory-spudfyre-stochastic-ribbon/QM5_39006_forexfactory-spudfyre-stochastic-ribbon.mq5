#property strict
#property version   "5.0"
#property description "QM5_39006 forexfactory-spudfyre-stochastic-ribbon - Spudfyre Stochastic Ribbon (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39006 forexfactory-spudfyre-stochastic-ribbon
// -----------------------------------------------------------------------------
// Source: Spudfyre (2007-2024). The Spud Stochastic Thread. Forex Factory (>10M Views).
// Card: artifacts/cards_approved/QM5_39006_forexfactory-spudfyre-stochastic-ribbon.md (g0_status APPROVED).
//
// Mechanics (closed-bar, H1):
//   - Harmonic Stochastic Ribbon bundle: %K periods (6, 9, 12, 14, 18, 24, 30), %D=3, slowing=3.
//   - Long Setup: Compression in oversold at [2] (min <= 20, max <= 25) AND Stoch(6)[1] unhooks > 20 and > Stoch(30)[1].
//   - Short Setup: Compression in overbought at [2] (max >= 80, min >= 75) AND Stoch(6)[1] unhooks < 80 and < Stoch(30)[1].
//   - SL: Placed beyond recent swing low/high +/- 3.0 pips buffer.
//   - TP: 1:2.0 R:R target.
//   - Management: Move to Break-Even at +1.0R.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39006;
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
input double InpOverbought              = 80.0;   // Overbought extreme threshold
input double InpOversold                = 20.0;   // Oversold extreme threshold
input int    strategy_atr_period        = 14;     // ATR period (H1)
input double strategy_sl_buffer_pips    = 3.0;    // SL buffer beyond swing structure in pips
input double strategy_tp_rr             = 2.0;    // Take profit R:R multiple
input int    strategy_swing_lookback    = 10;     // Swing structure lookback bars
input double strategy_be_trigger_r      = 1.0;    // Break-even trigger multiple of initial risk (R)
input double strategy_daily_loss_halt_pct = 2.0;    // Daily realized loss entry halt percent
input double strategy_daily_hard_stop_pct = 2.5;    // Daily hard stop percent
input double strategy_total_dd_halt_pct   = 5.0;    // Total drawdown halt percent
input double strategy_per_trade_risk_cap_pct = 1.0; // Per-trade risk cap percent
input double strategy_max_slippage_ticks = 3.0;     // Maximum market-order slippage in symbol ticks

// -----------------------------------------------------------------------------
// File-scope cached state (updated once per new closed bar)
// -----------------------------------------------------------------------------
bool   g_state_valid        = false;
double g_cached_min_stoch_2 = 50.0;
double g_cached_max_stoch_2 = 50.0;
double g_cached_stoch_6_1   = 50.0;
double g_cached_stoch_30_1  = 50.0;
double g_cached_atr_1       = 0.0;

void AdvanceState_OnNewBar()
{
   g_state_valid = false;
   const int stoch_periods[7] = {6, 9, 12, 14, 18, 24, 30};
   double min_val = 1000.0;
   double max_val = -1000.0;

   for(int i = 0; i < 7; ++i)
   {
      const double k_val = QM_Stoch_K(_Symbol, PERIOD_H1, stoch_periods[i], 3, 3, 2);
      if(k_val < 0.0 || k_val > 100.0) return;
      if(k_val < min_val) min_val = k_val;
      if(k_val > max_val) max_val = k_val;
   }

   const double stoch_6_1  = QM_Stoch_K(_Symbol, PERIOD_H1, 6, 3, 3, 1);
   const double stoch_30_1 = QM_Stoch_K(_Symbol, PERIOD_H1, 30, 3, 3, 1);
   const double atr_1      = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);

   if(stoch_6_1 < 0.0 || stoch_6_1 > 100.0 || stoch_30_1 < 0.0 || stoch_30_1 > 100.0 || atr_1 <= 0.0)
      return;

   g_cached_min_stoch_2 = min_val;
   g_cached_max_stoch_2 = max_val;
   g_cached_stoch_6_1   = stoch_6_1;
   g_cached_stoch_30_1  = stoch_30_1;
   g_cached_atr_1       = atr_1;
   g_state_valid        = true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

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

bool Strategy_NoTradeFilter()
{
   if(Strategy_DailyRealizedLossHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && g_cached_atr_1 > 0.0)
   {
      if((ask - bid) > 1.8 * g_cached_atr_1)
         return true;
   }

   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(TimeCurrent()), dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day < 5) // 23:55 - 00:05 blackout
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(!g_state_valid)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_cached_atr_1 <= 0.0)
      return false;

   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));

   // Long Condition: Oversold compression at bar 2 + unhook at bar 1
   if(g_cached_min_stoch_2 <= InpOversold && g_cached_max_stoch_2 <= (InpOversold + 5.0) &&
      g_cached_stoch_6_1 > InpOversold && g_cached_stoch_6_1 > g_cached_stoch_30_1)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      const double swing_low = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_swing_lookback);
      if(swing_low <= 0.0) return false;

      const double sl = swing_low - buf;
      if(sl <= 0.0 || sl >= ask) return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "SPUDFYRE_STOCH_RIBBON_BUY";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short Condition: Overbought compression at bar 2 + unhook at bar 1
   if(g_cached_max_stoch_2 >= InpOverbought && g_cached_min_stoch_2 >= (InpOverbought - 5.0) &&
      g_cached_stoch_6_1 < InpOverbought && g_cached_stoch_6_1 < g_cached_stoch_30_1)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      const double swing_high = QM_StopStructure(_Symbol, QM_SELL, bid, strategy_swing_lookback);
      if(swing_high <= 0.0) return false;

      const double sl = swing_high + buf;
      if(sl <= 0.0 || sl <= bid) return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "SPUDFYRE_STOCH_RIBBON_SELL";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0) continue;

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(current_sl < open_price)
         {
            const double initial_risk = open_price - current_sl;
            if(initial_risk > 0.0 && (bid - open_price) >= initial_risk * strategy_be_trigger_r)
            {
               QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "BE_AT_1R");
            }
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(current_sl > open_price)
         {
            const double initial_risk = current_sl - open_price;
            if(initial_risk > 0.0 && (open_price - ask) >= initial_risk * strategy_be_trigger_r)
            {
               QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "BE_AT_1R");
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
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
   if(strategy_max_slippage_ticks <= 0.0 || strategy_max_slippage_ticks > 3.0)
      return INIT_PARAMETERS_INCORRECT;

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

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const int deviation_points = (point > 0.0 && tick_size > 0.0)
      ? (int)MathFloor((strategy_max_slippage_ticks * tick_size / point) + 1e-9)
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H1,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   AdvanceState_OnNewBar();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39006_forexfactory-spudfyre-stochastic-ribbon\"}");
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

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();
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
