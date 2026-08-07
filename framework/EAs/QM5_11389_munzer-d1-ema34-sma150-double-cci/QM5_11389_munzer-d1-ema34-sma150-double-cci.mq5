#property strict
#property version   "5.0"
#property description "QM5_11389 Munzer D1 EMA34/SMA150 double-CCI pending-stop system"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11389_munzer-d1-ema34-sma150-double-cci
// -----------------------------------------------------------------------------
// Mechanical implementation of the OWNER-approved Strategy Card. Strategy
// logic is confined to the five Strategy_* hooks; framework lifecycle, risk,
// magic, news, Friday-close, MAE, and trade plumbing remain canonical.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11389;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// The card explicitly specifies news filtering OFF for the baseline.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_period                  = 34;
input int    strategy_sma_period                  = 150;
input int    strategy_cci_slow_period             = 50;
input int    strategy_cci_fast_period             = 14;
input int    strategy_stoch_k                     = 5;
input int    strategy_stoch_d                     = 3;
input int    strategy_stoch_slowing               = 3;
input double strategy_stoch_overbought            = 80.0;
input double strategy_stoch_oversold              = 20.0;
input int    strategy_entry_offset_pips           = 10;
input int    strategy_sl_buffer_pips              = 10;
input int    strategy_sl_cap_pips                 = 60;
input int    strategy_atr_period                  = 14;
input double strategy_tp_atr_mult                 = 2.0;
input double strategy_breakeven_atr_mult          = 1.0;
input int    strategy_spread_cap_pips             = 30;
input int    strategy_pending_expiration_seconds  = 86400;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: the D1 cadence is enforced by the framework entry gate,
// news is OFF per card, and this hook applies the card's 30-pip spread cap.
// .DWX zero modeled spread is valid and therefore never blocks entry.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry: caller guarantees a single QM_IsNewBar() event. Read the last
// closed D1 candle, evaluate the card's MA/CCI/Stochastic states, then place a
// stop order 10 pips beyond that signal candle for one D1 interval.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = (strategy_pending_expiration_seconds > 0)
                            ? strategy_pending_expiration_seconds : 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Cancel any unfilled stop from the preceding signal bar before evaluating
   // the newly closed bar. The expiration_seconds field is a second, broker-
   // side bound so a news/market closure cannot leave a stale GTC order.
   bool pending_remove_ok = true;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      if(!QM_TM_RemovePendingOrder(ticket, "munzer_next_d1_bar_expiry"))
         pending_remove_ok = false;
     }
   if(!pending_remove_ok)
      return false;

   if(strategy_ema_period <= 0 || strategy_sma_period <= 0 ||
      strategy_cci_slow_period <= 0 || strategy_cci_fast_period <= 0 ||
      strategy_stoch_k <= 0 || strategy_stoch_d <= 0 ||
      strategy_stoch_slowing <= 0 || strategy_atr_period <= 0 ||
      strategy_entry_offset_pips <= 0 || strategy_sl_buffer_pips <= 0 ||
      strategy_sl_cap_pips <= 0 || strategy_tp_atr_mult <= 0.0)
      return false;

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, signal_bar))
      return false;
   if(signal_bar.close <= 0.0 || signal_bar.high <= 0.0 || signal_bar.low <= 0.0)
      return false;

   const double ema34 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_period, 1);
   const double sma150 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double cci_slow = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_slow_period, 1);
   const double cci_fast = QM_CCI(_Symbol, PERIOD_D1, strategy_cci_fast_period, 1);
   const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_D1,
                                     strategy_stoch_k,
                                     strategy_stoch_d,
                                     strategy_stoch_slowing,
                                     1);
   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(ema34 <= 0.0 || sma150 <= 0.0 || atr_value <= 0.0)
      return false;

   const double lower_ma = MathMin(ema34, sma150);
   const double upper_ma = MathMax(ema34, sma150);
   if(signal_bar.close > lower_ma && signal_bar.close < upper_ma)
      return false;

   const bool long_signal =
      (ema34 > sma150 &&
       signal_bar.close > ema34 &&
       cci_slow > 0.0 &&
       cci_fast > 0.0 &&
       stoch_k < strategy_stoch_overbought);

   const bool short_signal =
      (ema34 < sma150 &&
       signal_bar.close < ema34 &&
       cci_slow < 0.0 &&
       cci_fast < 0.0 &&
       stoch_k > strategy_stoch_oversold);

   if(!long_signal && !short_signal)
      return false;

   const double entry_offset = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                                strategy_entry_offset_pips);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                             strategy_sl_buffer_pips);
   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                          strategy_sl_cap_pips);
   if(entry_offset <= 0.0 || sl_buffer <= 0.0 || sl_cap <= 0.0)
      return false;

   if(long_signal)
     {
      const double entry = QM_StopRulesNormalizePrice(_Symbol,
                                                       signal_bar.high + entry_offset);
      double sl = signal_bar.low - sl_buffer;
      if(entry - sl > sl_cap)
         sl = entry - sl_cap;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double tp = QM_TakeATRFromValue(_Symbol,
                                             QM_BUY,
                                             entry,
                                             atr_value,
                                             strategy_tp_atr_mult);
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type   = QM_BUY_STOP;
      req.price  = entry;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "munzer_d1_long_stop";
      return true;
     }

   const double entry = QM_StopRulesNormalizePrice(_Symbol,
                                                    signal_bar.low - entry_offset);
   double sl = signal_bar.high + sl_buffer;
   if(sl - entry > sl_cap)
      sl = entry + sl_cap;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   const double tp = QM_TakeATRFromValue(_Symbol,
                                          QM_SELL,
                                          entry,
                                          atr_value,
                                          strategy_tp_atr_mult);
   if(entry <= 0.0 || sl <= entry || tp <= 0.0 || tp >= entry)
      return false;

   req.type   = QM_SELL_STOP;
   req.price  = entry;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "munzer_d1_short_stop";
   return true;
  }

// Trade Management: reconstruct the entry-time ATR from the unchanged TP
// distance, making the +1 ATR breakeven rule restart-safe without a per-tick
// indicator read or adaptive state.
void Strategy_ManageOpenPosition()
  {
   if(strategy_tp_atr_mult <= 0.0 || strategy_breakeven_atr_mult <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || current_tp <= 0.0)
         continue;

      const double entry_atr = MathAbs(current_tp - open_price) /
                               strategy_tp_atr_mult;
      const double trigger_distance = strategy_breakeven_atr_mult * entry_atr;
      if(trigger_distance <= 0.0)
         continue;

      const double breakeven_sl = QM_StopRulesNormalizePrice(_Symbol, open_price);
      if(position_type == POSITION_TYPE_BUY)
        {
         if(bid >= open_price + trigger_distance &&
            (current_sl <= 0.0 || current_sl < open_price - 0.5 * point))
            QM_TM_MoveSL(ticket, breakeven_sl, "munzer_breakeven_1atr");
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         if(ask <= open_price - trigger_distance &&
            (current_sl <= 0.0 || current_sl > open_price + 0.5 * point))
            QM_TM_MoveSL(ticket, breakeven_sl, "munzer_breakeven_1atr");
        }
     }
  }

// Trade Close: the card defines exits only through SL, ATR TP, breakeven, and
// the framework Friday-close guard; there is no discretionary close signal.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no strategy-specific override; central news mode is OFF
// for the card's baseline and remains callable for Q09/P8-style news testing.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — copied verbatim from framework/templates/EA_Skeleton.mq5.
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
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
