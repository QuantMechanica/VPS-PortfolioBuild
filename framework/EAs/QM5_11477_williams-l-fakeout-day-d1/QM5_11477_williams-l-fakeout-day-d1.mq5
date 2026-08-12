#property strict
#property version   "5.0"
#property description "QM5_11477 Larry Williams Fake-Out Day reversal (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11477 williams-l-fakeout-day-d1
// -----------------------------------------------------------------------------
// Mechanical implementation of the APPROVED Strategy Card. The EA identifies
// the closed D1 Fake-Out Day at shifts 1 and 2, places a one-day stop order at
// the signal bar's extreme plus one pip, and uses the opposite signal-bar
// extreme as the protective stop. Framework code owns risk sizing, magic,
// news, kill-switch, Friday close, order dispatch, and evidence logging.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11477;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_buffer_pips     = 1;
input int    strategy_sl_buffer_pips        = 1;
input int    strategy_max_signal_range_pips = 80;
input double strategy_tp_range_mult         = 1.5;
input int    strategy_pending_expiry_bars   = 1;
input int    strategy_time_stop_bars        = 5;
input bool   strategy_require_close_third   = false;
input bool   strategy_no_friday_entry       = true;
input int    strategy_spread_cap_pips       = 25;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter: block only invalid quotes or a genuinely wide spread.
// Darwinex .DWX tester quotes may have ask == bid, so zero spread passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_spread_cap_pips);
   if(ask > bid && spread_cap > 0.0 && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry: evaluate one closed D1 signal bar and place the card's stop
// order. The framework calls this only after the single QM_IsNewBar gate.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Do not stack a new signal while this EA already owns an unfilled order.
   const int order_total = OrdersTotal();
   for(int i = 0; i < order_total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         return false;
     }

   if(strategy_no_friday_entry)
     {
      MqlDateTime now_parts;
      TimeToStruct(TimeCurrent(), now_parts);
      if(now_parts.day_of_week == 5)
         return false;
     }

   // perf-allowed: the card is a bespoke two-candle OHLC structure evaluated
   // once behind the framework's closed-D1-bar gate.
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double high2  = iHigh(_Symbol, PERIOD_D1, 2);  // perf-allowed
   const double low2   = iLow(_Symbol, PERIOD_D1, 2);   // perf-allowed
   const double close2 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0 ||
      high1 <= low1 || high2 <= low2)
      return false;

   const double signal_range = high1 - low1;
   const double max_range = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                             strategy_max_signal_range_pips);
   if(max_range <= 0.0 || signal_range > max_range)
      return false;

   const bool long_signal = (high1 > high2 &&
                             low1 > low2 &&
                             close1 < close2);
   const bool short_signal = (high1 < high2 &&
                              low1 < low2 &&
                              close1 > close2);
   if(!long_signal && !short_signal)
      return false;

   if(strategy_require_close_third)
     {
      if(long_signal && !((high1 - close1) > 0.67 * signal_range))
         return false;
      if(short_signal && !((close1 - low1) > 0.67 * signal_range))
         return false;
     }

   const double entry_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                                strategy_entry_buffer_pips);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                             strategy_sl_buffer_pips);
   const int period_seconds = PeriodSeconds(PERIOD_D1);
   if(entry_buffer <= 0.0 || sl_buffer <= 0.0 ||
      strategy_tp_range_mult <= 0.0 ||
      strategy_pending_expiry_bars <= 0 || period_seconds <= 0)
      return false;

   if(long_signal)
     {
      req.type = QM_BUY_STOP;
      req.price = QM_StopRulesNormalizePrice(_Symbol, high1 + entry_buffer);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, low1 - sl_buffer);
      req.tp = QM_StopRulesNormalizePrice(_Symbol,
                                           high1 + strategy_tp_range_mult * signal_range);
      req.reason = "williams_fakeout_long";
     }
   else
     {
      req.type = QM_SELL_STOP;
      req.price = QM_StopRulesNormalizePrice(_Symbol, low1 - entry_buffer);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, high1 + sl_buffer);
      req.tp = QM_StopRulesNormalizePrice(_Symbol,
                                           low1 - strategy_tp_range_mult * signal_range);
      req.reason = "williams_fakeout_short";
     }

   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_pending_expiry_bars * period_seconds;
   return true;
  }

// Trade Management: the card specifies no trailing, break-even, scale-in, or
// partial-close rule. SL/TP and pending-order expiry are server-side.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: after five completed D1 bars, exit only when the open trade is
// not profitable. The framework helper counts actual bars and skips weekends.
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int held_bars = QM_TM_HeldPeriodsForMagic((long)magic,
                                                    _Symbol,
                                                    PERIOD_D1);
   if(held_bars < strategy_time_stop_bars)
      return false;

   return (QM_TM_OpenPnL(magic) <= 0.0);
  }

// News Filter Hook: callable for Q09/P8 news-impact work; the strategy adds no
// custom event rule and defers to the central framework filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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
   // Q08 MAE sampling must precede every early return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management and exits remain active before the entry-only news gate.
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
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
