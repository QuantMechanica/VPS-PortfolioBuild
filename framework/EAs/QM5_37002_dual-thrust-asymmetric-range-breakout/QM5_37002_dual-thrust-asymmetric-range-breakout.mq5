#property strict
#property version   "5.0"
#property description "QM5_37002 Dual Thrust Asymmetric Range Breakout (Michael Chalek)"
// Strategy Card: QM5_37002 (dual-thrust-asymmetric-range-breakout), G0 APPROVED.
// Source: Chalek, M. & QuantConnect Research. Dual Thrust Algorithmic Performance Benchmarks.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37002 — Dual Thrust Asymmetric Range Breakout
// -----------------------------------------------------------------------------
// Asymmetric range breakout on D1 bars:
//   - Range = max(HH_N - LC_N, HC_N - LL_N) over N closed daily bars
//   - Buy_Trigger  = Open + k1 * Range
//   - Sell_Trigger = Open - k2 * Range
//
// Entry: place a paired BUY_STOP / SELL_STOP bracket at the current D1 open.
// Exit: opposite trigger is the server-side SL; flatten before 23:55 UTC.
// Target: 1.5R, matching the approved card's stated risk/reward profile.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37002;
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
input int    strategy_lookback_days       = 4;      // Dual Thrust lookback window (days)
input double strategy_k1                  = 0.50;   // Buy trigger range multiplier
input double strategy_k2                  = 0.50;   // Sell trigger range multiplier
input double strategy_daily_loss_limit_pct         = 2.0; // Realized-loss entry halt
input double strategy_daily_drawdown_hard_stop_pct = 2.5; // Equity hard stop
input double strategy_total_drawdown_stop_pct      = 5.0; // Total-drawdown hard stop
input int    strategy_max_slippage_ticks           = 3;   // Card maximum on market exits

const int    STRATEGY_SPREAD_ATR_PERIOD       = 14;
const double STRATEGY_SPREAD_ATR_MULT         = 1.80;
const double STRATEGY_TARGET_R_MULT           = 1.5;

ulong g_strategy_first_pending_ticket = 0;

int Strategy_DeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return strategy_max_slippage_ticks;
   return (int)MathMax(1.0,
                       MathCeil(strategy_max_slippage_ticks * tick_size / point));
}

// -----------------------------------------------------------------------------
// Dual Thrust Calculation Helper
// -----------------------------------------------------------------------------

struct DualThrust_Levels
{
   bool   valid;
   double range;
   double buy_trigger;
   double sell_trigger;
};

DualThrust_Levels CalculateDualThrust(const string sym, const int lookback, const double k1, const double k2)
{
   DualThrust_Levels res;
   res.valid = false;
   res.range = 0.0;
   res.buy_trigger = 0.0;
   res.sell_trigger = 0.0;

   if(lookback < 1 || k1 <= 0.0 || k2 <= 0.0)
      return res;

   // One current bar plus at most eight prior bars (the card's bounded range).
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int required = lookback + 1;
   const int copied = CopyRates(sym, PERIOD_D1, 0, required, rates); // perf-allowed: bounded current-open plus closed D1 range vector
   if(copied != required || ArraySize(rates) < required)
      return res;

   double hh = -1e9;
   double hc = -1e9;
   double ll = 1e9;
   double lc = 1e9;

   // rates[0] is the forming/current D1 bar. Range inputs are strictly the
   // preceding closed bars, rates[1..lookback].
   for(int i = 1; i <= lookback; ++i)
   {
      if(rates[i].high > hh) hh = rates[i].high;
      if(rates[i].close > hc) hc = rates[i].close;
      if(rates[i].low < ll)  ll = rates[i].low;
      if(rates[i].close < lc) lc = rates[i].close;
   }

   if(hh <= ll || hc <= lc)
      return res;

   double range1 = hh - lc;
   double range2 = hc - ll;
   double range = MathMax(range1, range2);
   if(range <= 0.0)
      return res;

   const double ref_open = rates[0].open;
   if(ref_open <= 0.0)
      return res;

   res.range = range;
   res.buy_trigger = ref_open + k1 * range;
   res.sell_trigger = ref_open - k2 * range;
   res.valid = true;
   return res;
}

datetime Strategy_UTCNow()
{
   return QM_BrokerToUTC(TimeCurrent());
}

bool Strategy_IsSettlementWindow()
{
   MqlDateTime dt;
   TimeToStruct(Strategy_UTCNow(), dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   return (minute_of_day >= 1435 || minute_of_day <= 5);
}

int Strategy_SecondsToSettlement()
{
   const datetime utc_now = Strategy_UTCNow();
   MqlDateTime settlement;
   TimeToStruct(utc_now, settlement);
   settlement.hour = 23;
   settlement.min = 55;
   settlement.sec = 0;
   datetime expiry_utc = StructToTime(settlement);
   if(expiry_utc <= utc_now)
      expiry_utc += 86400;
   return (int)(expiry_utc - utc_now);
}

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE order_type)
{
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
}

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
   }
   return false;
}

int Strategy_PendingStopCount()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
   }
   return count;
}

void Strategy_CancelPendingStops(const string reason)
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

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
      QM_TM_RemovePendingOrder(ticket, reason);
   }
}

double Strategy_DailyRealizedNet()
{
   const datetime utc_now = Strategy_UTCNow();
   MqlDateTime utc_day;
   TimeToStruct(utc_now, utc_day);
   utc_day.hour = 0;
   utc_day.min = 0;
   utc_day.sec = 0;
   const datetime broker_day_start = QM_UTCToBroker(StructToTime(utc_day));
   if(!HistorySelect(broker_day_start, TimeCurrent()))
      return 0.0;

   double total = 0.0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      total += HistoryDealGetDouble(deal, DEAL_PROFIT);
      total += HistoryDealGetDouble(deal, DEAL_SWAP);
      total += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      total += HistoryDealGetDouble(deal, DEAL_FEE);
   }
   return total;
}

bool Strategy_DailyRealizedLossLimitHit()
{
   const double net = Strategy_DailyRealizedNet();
   if(net >= 0.0)
      return false;
   const double start_balance = AccountInfoDouble(ACCOUNT_BALANCE) - net;
   if(start_balance <= 0.0)
      return true;
   return ((-net / start_balance) * 100.0 >= strategy_daily_loss_limit_pct);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(Strategy_IsSettlementWindow())
      return true;
   if(Strategy_DailyRealizedLossLimitHit())
      return true;
   if(Strategy_HasOpenPosition() || Strategy_PendingStopCount() > 0)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, STRATEGY_SPREAD_ATR_PERIOD, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(atr_1 > 0.0 && (ask - bid) > (STRATEGY_SPREAD_ATR_MULT * atr_1))
         return true;
   }
   return false;
}

void Strategy_InitEntryRequest(QM_EntryRequest &req)
{
   req.type               = QM_BUY_STOP;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   Strategy_InitEntryRequest(req);
   g_strategy_first_pending_ticket = 0;

   if(Strategy_HasOpenPosition() || Strategy_PendingStopCount() > 0)
      return false;

   DualThrust_Levels dt = CalculateDualThrust(_Symbol, strategy_lookback_days, strategy_k1, strategy_k2);
   if(!dt.valid)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double min_distance = MathMax(point, (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point);
   const double buy_price = QM_TM_NormalizePrice(_Symbol, dt.buy_trigger);
   const double sell_price = QM_TM_NormalizePrice(_Symbol, dt.sell_trigger);
   if(buy_price <= ask + min_distance || sell_price >= bid - min_distance)
      return false;

   const double buy_sl = QM_TM_NormalizePrice(_Symbol, sell_price);
   const double sell_sl = QM_TM_NormalizePrice(_Symbol, buy_price);
   const double buy_risk = buy_price - buy_sl;
   const double sell_risk = sell_sl - sell_price;
   if(buy_risk <= min_distance || sell_risk <= min_distance)
      return false;

   const int expiry_seconds = Strategy_SecondsToSettlement();
   if(expiry_seconds <= 0)
      return false;

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);
   Strategy_InitEntryRequest(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_price;
   buy_req.sl = buy_sl;
   buy_req.tp = QM_TM_NormalizePrice(_Symbol, buy_price + STRATEGY_TARGET_R_MULT * buy_risk);
   buy_req.reason = "QM5_37002_DUALTHRUST_BUY_STOP";
   buy_req.expiration_seconds = expiry_seconds;

   req.type = QM_SELL_STOP;
   req.price = sell_price;
   req.sl = sell_sl;
   req.tp = QM_TM_NormalizePrice(_Symbol, sell_price - STRATEGY_TARGET_R_MULT * sell_risk);
   req.reason = "QM5_37002_DUALTHRUST_SELL_STOP";
   req.expiration_seconds = expiry_seconds;

   if(buy_req.tp <= buy_req.price || req.tp <= 0.0 || req.tp >= req.price)
      return false;

   if(!QM_TM_OpenPosition(buy_req, g_strategy_first_pending_ticket))
   {
      g_strategy_first_pending_ticket = 0;
      return false;
   }

   return true;
}

void Strategy_ManageOpenPosition()
{
   if(Strategy_IsSettlementWindow())
   {
      Strategy_CancelPendingStops("daily_settlement");
      return;
   }

   if(Strategy_HasOpenPosition())
      Strategy_CancelPendingStops("oco_peer_cancel");
}

bool Strategy_ExitSignal()
{
   return (Strategy_HasOpenPosition() && Strategy_IsSettlementWindow());
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
{
   if(strategy_lookback_days < 2 || strategy_lookback_days > 8 ||
      strategy_k1 < 0.30 || strategy_k1 > 0.80 ||
      strategy_k2 < 0.30 || strategy_k2 > 0.80 ||
      strategy_daily_loss_limit_pct <= 0.0 || strategy_daily_loss_limit_pct > 2.0 ||
      strategy_daily_drawdown_hard_stop_pct <= 0.0 || strategy_daily_drawdown_hard_stop_pct > 2.5 ||
      strategy_daily_loss_limit_pct > strategy_daily_drawdown_hard_stop_pct ||
      strategy_total_drawdown_stop_pct <= 0.0 || strategy_total_drawdown_stop_pct > 5.0 ||
      strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3)
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

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     Strategy_DeviationPoints(),
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_drawdown_hard_stop_pct,
                         strategy_total_drawdown_stop_pct,
                         1.0))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_37002_dual_thrust_breakout\"}");
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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(QM_FrameworkHandleFridayClose())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
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
      if(!QM_TM_OpenPosition(req, out_ticket))
      {
         if(g_strategy_first_pending_ticket > 0)
            QM_TM_RemovePendingOrder(g_strategy_first_pending_ticket, "paired_submit_rollback");
      }
      g_strategy_first_pending_ticket = 0;
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
