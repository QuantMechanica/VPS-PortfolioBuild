#property strict
#property version   "5.0"
#property description "QM5_9467 ConnorsRSI Pullback Limit Entry D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9467
// Strategy Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9467_connors-crsi-pullback-d1.md
// Source: Matt Radtke / Connors Research LLC (ef14a5d7-e3f1-52be-910a-3ca6b736a152)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9467;
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
input int    strategy_crsi_rsi_period        = 3;
input int    strategy_crsi_streak_period     = 2;
input int    strategy_crsi_rank_period       = 100;
input double strategy_crsi_entry_thresh      = 5.0;
input double strategy_crsi_exit_thresh       = 80.0;
input int    strategy_adx_period             = 10;
input double strategy_adx_thresh             = 30.0;
input double strategy_closing_range_thresh   = 0.25;
input double strategy_limit_mult             = 0.90;
input int    strategy_atr_period             = 14;
input double strategy_sl_atr_mult            = 3.0;
input int    strategy_time_stop_bars         = 8;
input double strategy_spread_max_atr         = 0.25;
input int    strategy_warmup_bars            = 120;

const ENUM_TIMEFRAMES STRATEGY_TIMEFRAME = PERIOD_D1;
double   g_strategy_closed_crsi = -1.0;
datetime g_strategy_snapshot_bar = 0;

// -----------------------------------------------------------------------------
// ConnorsRSI (CRSI) calculation
// -----------------------------------------------------------------------------

bool Strategy_RsiChron(const double &values[],
                       const int count,
                       const int period,
                       const int index,
                       double &out_rsi)
{
   out_rsi = 0.0;
   if(period <= 0 || index < period || index >= count)
      return false;

   double avg_gain = 0.0;
   double avg_loss = 0.0;
   for(int i = 1; i <= period; ++i)
   {
      const double change = values[i] - values[i - 1];
      if(change > 0.0)
         avg_gain += change;
      else
         avg_loss -= change;
   }

   avg_gain /= (double)period;
   avg_loss /= (double)period;

   for(int i = period + 1; i <= index; ++i)
   {
      const double change = values[i] - values[i - 1];
      const double gain = (change > 0.0) ? change : 0.0;
      const double loss = (change < 0.0) ? -change : 0.0;
      avg_gain = ((avg_gain * (period - 1)) + gain) / (double)period;
      avg_loss = ((avg_loss * (period - 1)) + loss) / (double)period;
   }

   if(avg_loss <= 0.0)
   {
      out_rsi = 100.0;
      return true;
   }
   if(avg_gain <= 0.0)
   {
      out_rsi = 0.0;
      return true;
   }

   const double rs = avg_gain / avg_loss;
   out_rsi = 100.0 - (100.0 / (1.0 + rs));
   return true;
}

double Strategy_ComputeCRSI(const int shift)
{
   const int total_needed = strategy_crsi_rank_period + 20;
   const int history_needed = (strategy_warmup_bars > total_needed) ? strategy_warmup_bars : total_needed;
   if(iBars(_Symbol, STRATEGY_TIMEFRAME) < history_needed + shift) // perf-allowed: bounded once-per-D1 snapshot preflight.
      return -1.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, STRATEGY_TIMEFRAME, shift, total_needed, rates); // perf-allowed: bounded immutable closed-D1 snapshot only.
   if(copied < total_needed || ArraySize(rates) < total_needed)
      return -1.0;

   // 1. Price RSI(3)
   const double price_rsi = QM_RSI(_Symbol, STRATEGY_TIMEFRAME, strategy_crsi_rsi_period, shift, PRICE_CLOSE);
   if(price_rsi < 0.0)
      return -1.0;

   // Build chronological closes: closes[0] is oldest, closes[copied-1] is newest (shift)
   double closes[];
   ArrayResize(closes, copied);
   for(int i = 0; i < copied; ++i)
   {
      closes[i] = rates[copied - 1 - i].close;
      if(closes[i] <= 0.0)
         return -1.0;
   }

   // 2. Up/Down Streak RSI(2)
   double streaks[];
   ArrayResize(streaks, copied);
   streaks[0] = 0.0;
   for(int i = 1; i < copied; ++i)
   {
      if(closes[i] > closes[i - 1])
         streaks[i] = (streaks[i - 1] > 0.0 ? streaks[i - 1] : 0.0) + 1.0;
      else if(closes[i] < closes[i - 1])
         streaks[i] = (streaks[i - 1] < 0.0 ? streaks[i - 1] : 0.0) - 1.0;
      else
         streaks[i] = 0.0;
   }

   const int current = copied - 1;
   if(current >= ArraySize(closes) || current < 1)
      return -1.0;
   if(current >= ArraySize(streaks) || current < 1)
      return -1.0;

   double streak_rsi = 0.0;
   if(!Strategy_RsiChron(streaks, copied, strategy_crsi_streak_period, current, streak_rsi))
      return -1.0;

   // 3. PercentRank(100) of 1-day return
   const double current_return = (closes[current] / closes[current - 1]) - 1.0;
   int lower_count = 0;
   const int start_idx = current - strategy_crsi_rank_period;
   if(start_idx < 1)
      return -1.0;

   for(int i = start_idx; i < copied; ++i)
   {
      if(i >= current)
         break;
      const double hist_return = (closes[i] / closes[i - 1]) - 1.0;
      if(hist_return < current_return)
         ++lower_count;
   }

   const double percent_rank = 100.0 * (double)lower_count / (double)strategy_crsi_rank_period;
   const double crsi = (price_rsi + streak_rsi + percent_rank) / 3.0;
   return crsi;
}

bool Strategy_RefreshClosedD1Snapshot()
{
   const datetime closed_bar = iTime(_Symbol, STRATEGY_TIMEFRAME, 1); // perf-allowed: one closed-bar identity read at the governed D1 boundary.
   if(closed_bar <= 0)
      return false;

   if(g_strategy_snapshot_bar == closed_bar)
      return (g_strategy_closed_crsi >= 0.0);

   // One immutable CRSI reconstruction per closed D1 bar. Entry and exit hooks
   // only read this cache; neither performs recursive history work per tick.
   g_strategy_snapshot_bar = closed_bar;
   g_strategy_closed_crsi = Strategy_ComputeCRSI(1);
   return (g_strategy_closed_crsi >= 0.0);
}

bool Strategy_IsApprovedSymbol()
{
   return (_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX");
}

int Strategy_ApprovedMagicSlot()
{
   if(_Symbol == "NDX.DWX")
      return 1;
   if(_Symbol == "SP500.DWX")
      return 2;
   if(_Symbol == "WS30.DWX")
      return 4;
   return -1;
}

bool Strategy_IsPendingType(const ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT ||
           type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP ||
           type == ORDER_TYPE_BUY_STOP_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT);
}

bool Strategy_HasOurExposure()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return true;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
   }
   return false;
}

bool Strategy_ReconcilePendingAtD1Boundary()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool all_ok = true;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      const int setup_shift = iBarShift(_Symbol, STRATEGY_TIMEFRAME, setup_time, false); // perf-allowed: one pending-order age lookup at the governed D1 boundary.
      if(setup_shift < 1)
         continue;

      if(!QM_TM_RemovePendingOrder(ticket, "CONNORS_D1_T_PLUS_1_EXPIRY"))
         all_ok = false;
   }
   return all_ok;
}

double Strategy_StopDistance()
{
   const double atr = QM_ATR(_Symbol, STRATEGY_TIMEFRAME, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return 0.0;
   return atr * strategy_sl_atr_mult;
}

bool Strategy_EnsureFillRelativeStop(const ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return false;
   if((int)PositionGetInteger(POSITION_MAGIC) != QM_FrameworkMagic())
      return false;
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
      return false;

   const double fill_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double stop_distance = Strategy_StopDistance();
   if(fill_price <= 0.0 || stop_distance <= 0.0)
      return false;

   const double target_sl = QM_StopRulesNormalizePrice(_Symbol, fill_price - stop_distance);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double epsilon = (point > 0.0) ? point * 0.5 : 1e-10;
   if(target_sl > 0.0 && target_sl < fill_price && MathAbs(current_sl - target_sl) <= epsilon)
      return true;

   if(target_sl <= 0.0 || target_sl >= fill_price)
      return false;
   if(!QM_TM_SendSLTPModify(ticket, target_sl, current_tp, "CONNORS_FILL_RELATIVE_ATR_STOP"))
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;
   return (MathAbs(PositionGetDouble(POSITION_SL) - target_sl) <= epsilon);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, STRATEGY_TIMEFRAME, strategy_atr_period, 1);
   if(atr > 0.0 && ask > bid && (ask - bid) > (strategy_spread_max_atr * atr))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(g_strategy_snapshot_bar <= 0 || g_strategy_closed_crsi < 0.0)
      return false;

   if(Strategy_HasOurExposure())
      return false;

   MqlRates setup_rates[];
   ArraySetAsSeries(setup_rates, true);
   const int copied = CopyRates(_Symbol, STRATEGY_TIMEFRAME, 1, 2, setup_rates); // perf-allowed: two closed D1 bars, once at the governed boundary.
   if(copied != 2 || ArraySize(setup_rates) < 2)
      return false;

   const double close1 = setup_rates[0].close;
   const double close2 = setup_rates[1].close;
   const double high1  = setup_rates[0].high;
   const double low1   = setup_rates[0].low;

   if(close1 <= 0.0 || close2 <= 0.0 || high1 <= low1 || low1 <= 0.0)
      return false;

   // 1. ADX(10) > 30.0
   const double adx = QM_ADX(_Symbol, STRATEGY_TIMEFRAME, strategy_adx_period, 1);
   if(adx <= strategy_adx_thresh)
      return false;

   // 2. Current low <= previous close * 0.98
   if(low1 > close2 * 0.98)
      return false;

   // 3. Closing range (Close - Low) / (High - Low) <= 0.25
   const double closing_range = (close1 - low1) / (high1 - low1);
   if(closing_range > strategy_closing_range_thresh)
      return false;

   // 4. ConnorsRSI(3, 2, 100) < 5.0
   const double crsi = g_strategy_closed_crsi;
   if(crsi < 0.0 || crsi >= strategy_crsi_entry_thresh)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double limit_price = close1 * strategy_limit_mult;
   const double stop_distance = Strategy_StopDistance();
   if(stop_distance <= 0.0)
      return false;
   if(limit_price >= ask)
   {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - stop_distance);
   }
   else
   {
      req.type = QM_BUY_LIMIT;
      req.price = limit_price;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, limit_price - stop_distance);
   }

   const double sizing_reference = (req.price > 0.0) ? req.price : ask;
   if(req.sl <= 0.0 || req.sl >= sizing_reference)
      return false;

   req.tp = 0.0;
   req.reason = "CONNORS_CRSI_PULLBACK_BUY";
   req.symbol_slot = qm_magic_slot_offset;
   // The card's t+1 expiry is enforced by Strategy_ReconcilePendingAtD1Boundary.
   // GTC avoids converting a trading-bar rule into a DST/weekend wall-clock rule.
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
       const int bars_held = iBarShift(_Symbol, STRATEGY_TIMEFRAME, open_time, false); // perf-allowed: one time-stop age read per open position at the D1 boundary.
      if(bars_held >= strategy_time_stop_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
      }
   }
}

bool Strategy_ExitSignal()
{
   // Exit when ConnorsRSI closes > 80.0
   return (g_strategy_closed_crsi >= 0.0 &&
           g_strategy_closed_crsi > strategy_crsi_exit_thresh);
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!Strategy_IsApprovedSymbol() || qm_magic_slot_offset != Strategy_ApprovedMagicSlot())
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(STRATEGY_TIMEFRAME,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "CARD_HAS_NO_FRIDAY_RULE_FRAMEWORK_RISK_OVERRIDE"))
      return INIT_FAILED;
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!QM_IsNewBar(_Symbol, STRATEGY_TIMEFRAME))
      return;

   QM_EquityStreamOnNewBar();

   // Expiry, time-stop and CRSI exits are risk-reducing and must remain
   // reachable independently of quote/spread/news entry filters.
   const bool pending_reconciled = Strategy_ReconcilePendingAtD1Boundary();
   const bool snapshot_ready = Strategy_RefreshClosedD1Snapshot();
   Strategy_ManageOpenPosition();

   if(snapshot_ready && Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!snapshot_ready || !pending_reconciled)
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(Strategy_NoTradeFilter())
      return;

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

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0 || trans.position == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != QM_FrameworkMagic())
      return;

   // Pending and market requests are sized from the same ATR distance carried
   // in req.sl. Rebinding that distance to POSITION_PRICE_OPEN preserves fixed
   // risk after a price-improved/gapped fill. Failure to verify protection is
   // fail-closed: the newly opened exposure is immediately removed.
   if(!Strategy_EnsureFillRelativeStop(trans.position))
   {
      QM_LogEvent(QM_ERROR, "FILL_RELATIVE_STOP_FAILED",
                  StringFormat("{\"position\":%I64u,\"deal\":%I64u}", trans.position, trans.deal));
      QM_TM_ClosePosition(trans.position, QM_EXIT_KILLSWITCH);
   }
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}

