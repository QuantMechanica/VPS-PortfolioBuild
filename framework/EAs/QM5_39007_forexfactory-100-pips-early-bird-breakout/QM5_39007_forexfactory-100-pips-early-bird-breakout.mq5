#property strict
#property version   "5.0"
#property description "QM5_39007 100 Pips Early Bird pending-stop breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39007 forexfactory-100-pips-early-bird-breakout
// -----------------------------------------------------------------------------
// Card-faithful mechanics:
//   - Build the eight completed M15 bars in [05:00, 07:00) UTC.
//   - At the 07:00 UTC M15 bar, place a BUY_STOP and SELL_STOP three pips
//     outside the box. Both expire at 12:00 UTC and the unfilled sibling is
//     cancelled as soon as either leg fills (OCO).
//   - Fixed 25-pip SL, 50-pip TP1 (50% partial), 100-pip broker TP2.
//   - Move the remainder to entry +1 pip after a 20-pip favourable move.
//   - Halt entries at 2.0% daily realized loss; flatten and halt at 2.5% daily
//     equity drawdown or 5.0% drawdown from initial equity.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39007;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    InpBoxStartHourUTC             = 5;
input int    InpBoxEndHourUTC               = 7;
input int    InpSessionEndHourUTC           = 12;
input double InpBufferPips                  = 3.0;
input double InpStopLossPips                = 25.0;
input double InpTakeProfitPips              = 50.0;
input double InpTakeProfit2Pips             = 100.0;
input int    strategy_atr_period            = 14;
input int    strategy_be_trigger_pips       = 20;
input double strategy_tp1_close_fraction    = 0.50;
input double strategy_daily_loss_halt_pct   = 2.0;
input double strategy_daily_hard_stop_pct   = 2.5;
input double strategy_total_dd_halt_pct     = 5.0;
input double strategy_per_trade_risk_cap_pct = 1.0;
input double strategy_slippage_ticks        = 3.0;

// The card permits at most a four-hour box; this compile-time ceiling keeps
// every CopyRates request bounded even when inputs are optimized.
#define STRATEGY_MAX_BOX_BARS 16

double   g_cached_box_high              = 0.0;
double   g_cached_box_low               = 0.0;
double   g_cached_atr_1                 = 0.0;
int      g_orders_day_key               = -1;
ulong    g_first_leg_ticket             = 0;
ulong    g_tp1_done_position_identifier = 0;
double   g_initial_equity               = 0.0;
datetime g_realized_cache_second        = 0;
double   g_day_start_balance            = 0.0;
double   g_daily_realized_loss_pct      = 0.0;
bool     g_daily_realized_loss_valid    = false;

int Strategy_UtcDayKey(const datetime broker_time)
{
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   return dt.year * 1000 + dt.day_of_year;
}

datetime Strategy_BrokerDayStart(const datetime broker_time)
{
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

double Strategy_PipsToPriceDistance(const double pips)
{
   if(pips <= 0.0)
      return 0.0;
   const double one_pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   return (one_pip > 0.0) ? one_pip * pips : 0.0;
}

int Strategy_SlippageDeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0 || strategy_slippage_ticks <= 0.0)
      return -1;
   return (int)MathFloor(strategy_slippage_ticks * tick_size / point + 1e-9);
}

bool Strategy_ValidateInputs()
{
   const int box_bars = (InpBoxEndHourUTC - InpBoxStartHourUTC) * 4;
   return (qm_ea_id == 39007 &&
           qm_magic_slot_offset >= 0 && qm_magic_slot_offset <= 1 &&
           InpBoxStartHourUTC >= 4 && InpBoxStartHourUTC <= 6 &&
           InpBoxEndHourUTC > InpBoxStartHourUTC &&
           box_bars > 0 && box_bars <= STRATEGY_MAX_BOX_BARS &&
           InpSessionEndHourUTC > InpBoxEndHourUTC && InpSessionEndHourUTC == 12 &&
           InpBufferPips >= 2.0 && InpBufferPips <= 5.0 &&
           InpStopLossPips > 0.0 && InpTakeProfitPips > 0.0 &&
           InpTakeProfit2Pips > InpTakeProfitPips &&
           strategy_atr_period > 0 && strategy_atr_period <= 200 &&
           strategy_be_trigger_pips > 0 &&
           strategy_tp1_close_fraction > 0.0 && strategy_tp1_close_fraction < 1.0 &&
           strategy_daily_loss_halt_pct > 0.0 && strategy_daily_loss_halt_pct <= 2.0 &&
           strategy_daily_hard_stop_pct >= strategy_daily_loss_halt_pct &&
           strategy_daily_hard_stop_pct <= 2.5 &&
           strategy_total_dd_halt_pct >= strategy_daily_hard_stop_pct &&
           strategy_total_dd_halt_pct <= 5.0 &&
           strategy_per_trade_risk_cap_pct > 0.0 &&
           strategy_per_trade_risk_cap_pct <= 1.0 &&
           strategy_slippage_ticks > 0.0 && strategy_slippage_ticks <= 3.0);
}

string Strategy_InitialEquityKey()
{
   return StringFormat("QM5_39007_INITIAL_EQUITY_%I64d_%d",
                       AccountInfoInteger(ACCOUNT_LOGIN), QM_FrameworkMagic());
}

bool Strategy_InitCapitalPreservation()
{
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0)
      return false;

   if(MQLInfoInteger(MQL_TESTER) != 0)
   {
      g_initial_equity = equity_now;
      return true;
   }

   const string key = Strategy_InitialEquityKey();
   if(GlobalVariableCheck(key))
      g_initial_equity = GlobalVariableGet(key);
   else
   {
      g_initial_equity = equity_now;
      if(GlobalVariableSet(key, g_initial_equity) == 0)
         return false;
   }
   return (g_initial_equity > 0.0);
}

bool Strategy_UpdateDailyRealizedLoss()
{
   const datetime broker_now = TimeCurrent();
   if(g_realized_cache_second == broker_now && g_daily_realized_loss_valid)
      return true;

   if(!HistorySelect(Strategy_BrokerDayStart(broker_now), broker_now))
   {
      g_daily_realized_loss_valid = false;
      return false;
   }

   double realized_net = 0.0;
   const int deal_count = HistoryDealsTotal();
   for(int i = 0; i < deal_count; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;
      realized_net += HistoryDealGetDouble(deal, DEAL_PROFIT);
      realized_net += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      realized_net += HistoryDealGetDouble(deal, DEAL_SWAP);
      realized_net += HistoryDealGetDouble(deal, DEAL_FEE);
   }

   const double day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE) - realized_net;
   if(day_start_balance <= 0.0)
   {
      g_daily_realized_loss_valid = false;
      return false;
   }

   g_day_start_balance = day_start_balance;
   g_daily_realized_loss_pct = MathMax(0.0, -realized_net / day_start_balance * 100.0);
   g_realized_cache_second = broker_now;
   g_daily_realized_loss_valid = true;
   return true;
}

bool Strategy_CapitalPreservationCheck()
{
   if(!QM_KillSwitchCheck())
      return false;
   if(!Strategy_UpdateDailyRealizedLoss())
      return false;

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0 || g_day_start_balance <= 0.0 || g_initial_equity <= 0.0)
      return false;

   const double daily_drawdown_pct =
      MathMax(0.0, (g_day_start_balance - equity_now) / g_day_start_balance * 100.0);
   if(daily_drawdown_pct >= strategy_daily_hard_stop_pct)
   {
      QM_KillSwitchTrip(KS_DAILY_LOSS,
                        StringFormat("{\"day_start_balance\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"halt_pct\":%.6f}",
                                     g_day_start_balance, equity_now,
                                     daily_drawdown_pct, strategy_daily_hard_stop_pct));
      return false;
   }

   const double total_drawdown_pct =
      MathMax(0.0, (g_initial_equity - equity_now) / g_initial_equity * 100.0);
   if(total_drawdown_pct >= strategy_total_dd_halt_pct)
   {
      QM_KillSwitchTrip("KS_TOTAL_DRAWDOWN",
                        StringFormat("{\"initial_equity\":%.2f,\"equity_now\":%.2f,\"drawdown_pct\":%.6f,\"halt_pct\":%.6f}",
                                     g_initial_equity, equity_now,
                                     total_drawdown_pct, strategy_total_dd_halt_pct));
      return false;
   }
   return true;
}

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE order_type)
{
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
}

bool Strategy_HasPendingOrder()
{
   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < OrdersTotal(); ++i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
   }
   return false;
}

int Strategy_CancelPendingOrders(const string reason)
{
   int removed = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(QM_TM_RemovePendingOrder(ticket, reason))
         removed++;
   }
   return removed;
}

bool Strategy_HasOpenPosition()
{
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
}

bool Strategy_BuildBox(const datetime current_bar_broker)
{
   const datetime current_bar_utc = QM_BrokerToUTC(current_bar_broker);
   MqlDateTime current_dt;
   TimeToStruct(current_bar_utc, current_dt);
   if(current_dt.hour != InpBoxEndHourUTC || current_dt.min != 0)
      return false;

   const int box_bars = (InpBoxEndHourUTC - InpBoxStartHourUTC) * 4;
   if(box_bars <= 0 || box_bars > STRATEGY_MAX_BOX_BARS)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, box_bars, rates); // perf-allowed: once-daily bounded completed-box scan.
   if(copied != box_bars || ArraySize(rates) < box_bars)
      return false;

   const int expected_day_key = current_dt.year * 1000 + current_dt.day_of_year;
   const int start_minute = InpBoxStartHourUTC * 60;
   const int end_minute = InpBoxEndHourUTC * 60;
   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   for(int i = 0; i < box_bars; ++i)
   {
      MqlDateTime bar_dt;
      TimeToStruct(QM_BrokerToUTC(rates[i].time), bar_dt);
      const int bar_day_key = bar_dt.year * 1000 + bar_dt.day_of_year;
      const int bar_minute = bar_dt.hour * 60 + bar_dt.min;
      if(bar_day_key != expected_day_key || bar_minute < start_minute || bar_minute >= end_minute)
         return false;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         return false;
      box_high = MathMax(box_high, rates[i].high);
      box_low = MathMin(box_low, rates[i].low);
   }

   if(box_high <= box_low || box_low <= 0.0)
      return false;
   g_cached_box_high = box_high;
   g_cached_box_low = box_low;
   return true;
}

int Strategy_SecondsToSessionEnd()
{
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime end_dt;
   TimeToStruct(utc_now, end_dt);
   end_dt.hour = InpSessionEndHourUTC;
   end_dt.min = 0;
   end_dt.sec = 0;
   const datetime end_utc = StructToTime(end_dt);
   return (end_utc > utc_now) ? (int)(end_utc - utc_now) : 0;
}

bool Strategy_BuildStopRequest(const QM_OrderType side,
                               const double entry,
                               const int expiration_seconds,
                               const string reason,
                               QM_EntryRequest &req)
{
   const double sl_distance = Strategy_PipsToPriceDistance(InpStopLossPips);
   const double tp2_distance = Strategy_PipsToPriceDistance(InpTakeProfit2Pips);
   if(entry <= 0.0 || sl_distance <= 0.0 || tp2_distance <= 0.0 || expiration_seconds <= 0)
      return false;

   req.type = side;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, req.price, sl_distance);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, req.price, tp2_distance);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   if(side == QM_BUY_STOP)
      return (req.sl > 0.0 && req.sl < req.price && req.tp > req.price);
   return (req.sl > req.price && req.tp > 0.0 && req.tp < req.price);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!g_daily_realized_loss_valid ||
      g_daily_realized_loss_pct >= strategy_daily_loss_halt_pct)
      return true;

   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > bid && g_cached_atr_1 > 0.0 && (ask - bid) > 1.8 * g_cached_atr_1)
      return true;

   MqlDateTime utc_dt;
   TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc_dt);
   const int minute_of_day = utc_dt.hour * 60 + utc_dt.min;
   return (minute_of_day >= 1435 || minute_of_day < 5);
}

// The framework hook returns the SELL_STOP request. The BUY_STOP sibling is
// sent first through the same framework trade manager; OnTick sends the returned
// leg and rolls the first leg back if the second send fails.
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const datetime current_bar = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: one current-bar timestamp on the new-bar path.
   if(current_bar <= 0)
      return false;
   const int day_key = Strategy_UtcDayKey(current_bar);
   if(g_orders_day_key == day_key || !Strategy_BuildBox(current_bar))
      return false;

   g_cached_atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(g_cached_atr_1 <= 0.0)
      return false;

   const double buffer = Strategy_PipsToPriceDistance(InpBufferPips);
   const double buy_stop = QM_StopRulesNormalizePrice(_Symbol, g_cached_box_high + buffer);
   const double sell_stop = QM_StopRulesNormalizePrice(_Symbol, g_cached_box_low - buffer);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int expiration_seconds = Strategy_SecondsToSessionEnd();
   if(buffer <= 0.0 || ask <= 0.0 || bid <= 0.0 ||
      buy_stop <= ask || sell_stop >= bid || sell_stop <= 0.0 || expiration_seconds <= 0)
      return false;

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_stop, expiration_seconds,
                                 "EARLY_BIRD_BUY_STOP", buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_stop, expiration_seconds,
                                 "EARLY_BIRD_SELL_STOP", req))
      return false;

   g_orders_day_key = day_key;
   g_first_leg_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, g_first_leg_ticket))
      return false;
   return true;
}

bool Strategy_Tp1AlreadyDone(const ulong identifier)
{
   if(identifier == 0)
      return true;
   if(g_tp1_done_position_identifier == identifier)
      return true;
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return false;
   const string key = StringFormat("QM5_39007_TP1_%I64d_%I64u",
                                   AccountInfoInteger(ACCOUNT_LOGIN), identifier);
   return GlobalVariableCheck(key);
}

void Strategy_MarkTp1Done(const ulong identifier)
{
   g_tp1_done_position_identifier = identifier;
   if(MQLInfoInteger(MQL_TESTER) == 0)
   {
      const string key = StringFormat("QM5_39007_TP1_%I64d_%I64u",
                                      AccountInfoInteger(ACCOUNT_LOGIN), identifier);
      GlobalVariableSet(key, (double)TimeCurrent());
   }
}

void Strategy_ManageOpenPosition()
{
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc_dt;
   TimeToStruct(utc_now, utc_dt);
   if(utc_dt.hour >= InpSessionEndHourUTC)
      Strategy_CancelPendingOrders("EARLY_BIRD_NOON_CANCEL");

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      Strategy_CancelPendingOrders("EARLY_BIRD_OCO_SIBLING");
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, 1);

      const ulong identifier = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(Strategy_Tp1AlreadyDone(identifier))
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double market_price = (pos_type == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double tp1_distance = Strategy_PipsToPriceDistance(InpTakeProfitPips);
      const double favourable_move = (pos_type == POSITION_TYPE_BUY)
         ? market_price - open_price
         : open_price - market_price;
      if(open_price <= 0.0 || market_price <= 0.0 || tp1_distance <= 0.0 ||
         favourable_move < tp1_distance)
         continue;

      const double current_volume = PositionGetDouble(POSITION_VOLUME);
      const double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double close_volume =
         QM_TM_NormalizeVolume(_Symbol, current_volume * strategy_tp1_close_fraction);
      if(close_volume <= 0.0 || current_volume - close_volume < min_volume - 1e-12)
         continue;
      if(QM_TM_PartialClose(ticket, close_volume, QM_EXIT_PARTIAL))
         Strategy_MarkTp1Done(identifier);
   }
}

bool Strategy_ExitSignal()
{
   // Active positions exit only by fixed SL, TP1/TP2 management, framework
   // Friday close, or a capital-preservation kill switch. Noon cancels only
   // unfilled orders, exactly as the card specifies.
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return (broker_time <= 0);
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!Strategy_ValidateInputs())
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_M15,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   const int deviation_points = Strategy_SlippageDeviationPoints();
   if(deviation_points <= 0)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;
   if(!Strategy_InitCapitalPreservation())
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39007_forexfactory-100-pips-early-bird-breakout\"}");
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

   // Keep protective position/OCO management alive even when a history read
   // fails closed for new entries. A tripped kill switch has already flattened
   // owned exposure; this call is therefore safe on both outcomes.
   const bool capital_allows_entries = Strategy_CapitalPreservationCheck();
   Strategy_ManageOpenPosition();
   if(!capital_allows_entries)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_ExitSignal())
      return;

   const bool strategy_new_bar = QM_IsNewBar(_Symbol, PERIOD_M15);
   if(!strategy_new_bar)
      return;
   QM_EquityStreamOnNewBar();

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   // Refresh the closed-bar ATR before the spread filter. The entry hook also
   // refreshes it after the exact 07:00 box has been validated.
   g_cached_atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong second_leg_ticket = 0;
      if(!QM_TM_OpenPosition(req, second_leg_ticket))
      {
         if(g_first_leg_ticket > 0)
            QM_TM_RemovePendingOrder(g_first_leg_ticket, "EARLY_BIRD_STRADDLE_ROLLBACK");
      }
      g_first_leg_ticket = 0;
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
   if(Strategy_HasOpenPosition())
      Strategy_CancelPendingOrders("EARLY_BIRD_OCO_FILL_TRANSACTION");
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
