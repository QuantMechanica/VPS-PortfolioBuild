#property strict
#property version   "5.0"
#property description "QM5_12954 Pring Coppock H4 Variant"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12954 pring-coppock-h4-variant
// -----------------------------------------------------------------------------
// Approved card:
//   D:/QM/strategy_farm/artifacts/cards_approved/
//   QM5_12954_pring-coppock-h4-variant.md
// Source lineage:
//   6e967762-b26d-59a3-b076-35c17f2e7c36
//
// Mechanical contract (H4, closed bars only):
//   ROC11[k]  = (Close[k] / Close[k+11] - 1) * 100
//   ROC14[k]  = (Close[k] / Close[k+14] - 1) * 100
//   Coppock[k] = WMA(ROC11 + ROC14, 10)
//   Long      = Coppock[2] <= 0 and Coppock[1] > 0
//   Short     = Coppock[2] >= 0 and Coppock[1] < 0
//   Exit      = opposite zero cross or 200 closed H4 bars
//   Stop      = 2.5 * ATR(20), capped at 4.0 * ATR(20)
//   Manage    = move SL to entry after +2.0 * ATR(20)
//   Warm-up   = first 35 closed H4 bars after initialization
//   Spread    = no entry when spread > 0.25 * ATR(20)
//
// The framework exposes no 15/15 two-axis temporal enum. The default
// PRE30_POST30 mode is the nearest fail-closed representation of the card's
// mandatory +/-15 minute high-impact blackout; it widens rather than weakens
// the blackout and keeps the standard V5 news contract.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12954;
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
// The approved card can hold for up to 200 H4 bars. Forced weekly liquidation
// would replace that mechanic, so Friday close is intentionally disabled.
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_roc_short_period    = 11;
input int    strategy_roc_long_period     = 14;
input int    strategy_wma_period          = 10;
input int    strategy_atr_period          = 20;
input double strategy_sl_atr_mult         = 2.5;
input double strategy_sl_atr_cap          = 4.0;
input double strategy_be_trigger_atr      = 2.0;
input int    strategy_time_stop_bars      = 200;
input int    strategy_warmup_bars         = 35;
input double strategy_max_spread_atr      = 0.25;

// -----------------------------------------------------------------------------
// Coppock calculation — one bounded CopyClose call per new H4 bar.
// -----------------------------------------------------------------------------

double Strategy_CoppockROC(const double &closes[], const int shift, const int period)
  {
   const int base_index = shift + period;
   if(shift < 0 || period <= 0 || base_index >= ArraySize(closes))
      return 0.0;

   const double base = closes[base_index];
   if(base <= 0.0)
      return 0.0;

   return (closes[shift] / base - 1.0) * 100.0;
  }

bool Strategy_CoppockValue(const double &closes[],
                           const int shift,
                           double &out_value)
  {
   out_value = 0.0;
   if(strategy_wma_period <= 0)
      return false;

   const int deepest_roc = (strategy_roc_long_period > strategy_roc_short_period)
                           ? strategy_roc_long_period
                           : strategy_roc_short_period;
   const int deepest_index = shift + strategy_wma_period - 1 + deepest_roc;
   if(shift < 0 || deepest_index >= ArraySize(closes))
      return false;

   double weighted_sum = 0.0;
   double weight_sum = 0.0;
   for(int i = 0; i < strategy_wma_period; ++i)
     {
      const int value_shift = shift + i;
      const double roc_sum =
         Strategy_CoppockROC(closes, value_shift, strategy_roc_short_period) +
         Strategy_CoppockROC(closes, value_shift, strategy_roc_long_period);
      const double weight = (double)(strategy_wma_period - i);
      weighted_sum += roc_sum * weight;
      weight_sum += weight;
     }

   if(weight_sum <= 0.0)
      return false;

   out_value = weighted_sum / weight_sum;
   return true;
  }

bool Strategy_SeedCloses(double &closes[])
  {
   const int deepest_roc = (strategy_roc_long_period > strategy_roc_short_period)
                           ? strategy_roc_long_period
                           : strategy_roc_short_period;
   const int required = 2 + (strategy_wma_period - 1) + deepest_roc + 4;
   if(required <= 0)
      return false;

   ArrayResize(closes, required);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_H4, 0, required, closes);
   return copied == required;
  }

bool   g_coppock_ready = false;
double g_coppock_last  = 0.0;
double g_coppock_prev  = 0.0;
bool   g_cross_up      = false;
bool   g_cross_down    = false;
int    g_closed_bars_seen = 0;
QM_ExitReason g_strategy_exit_reason = QM_EXIT_STRATEGY;

void Strategy_AdvanceCoppockOnNewBar()
  {
   ++g_closed_bars_seen;
   g_coppock_ready = false;
   g_cross_up = false;
   g_cross_down = false;

   double closes[];
   if(!Strategy_SeedCloses(closes))
      return;
   if(!Strategy_CoppockValue(closes, 1, g_coppock_last))
      return;
   if(!Strategy_CoppockValue(closes, 2, g_coppock_prev))
      return;

   g_cross_up = (g_coppock_prev <= 0.0 && g_coppock_last > 0.0);
   g_cross_down = (g_coppock_prev >= 0.0 && g_coppock_last < 0.0);
   g_coppock_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // The card's spread filter is entry-only; management and exits must continue
   // during a wide spread.
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
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(g_closed_bars_seen < strategy_warmup_bars || !g_coppock_ready)
      return false;
   if(!g_cross_up && !g_cross_down)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr_value <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > strategy_max_spread_atr * atr_value)
      return false;

   const QM_OrderType side = g_cross_up ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? ask : bid;
   const double effective_sl_mult = MathMin(strategy_sl_atr_mult, strategy_sl_atr_cap);
   const double stop = QM_StopATRFromValue(_Symbol, side, entry, atr_value, effective_sl_mult);
   if(stop <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0; // card has no take-profit; opposite cross/time stop governs exit
   req.reason = (side == QM_BUY)
                ? "pring_coppock_zero_cross_up"
                : "pring_coppock_zero_cross_down";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;
   const double trigger_distance = strategy_be_trigger_atr * atr_value;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(trigger_distance <= 0.0 || point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(entry <= 0.0)
         continue;

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double favorable = is_buy ? (market - entry) : (entry - market);
      if(favorable < trigger_distance)
         continue;

      const double breakeven = QM_TM_NormalizePrice(_Symbol, entry);
      const bool improves = current_sl <= 0.0 ||
                            (is_buy ? breakeven > current_sl + point * 0.5
                                    : breakeven < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, breakeven, "pring_coppock_break_even_2atr");
     }
  }

bool Strategy_ExitSignal()
  {
   g_strategy_exit_reason = QM_EXIT_STRATEGY;
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_stop_bars > 0 && opened_at > 0)
        {
         const int bars_held = iBarShift(_Symbol, PERIOD_H4, opened_at, false);
         if(bars_held >= strategy_time_stop_bars)
           {
            g_strategy_exit_reason = QM_EXIT_TIME_STOP;
            return true;
           }
        }

      if(!g_coppock_ready)
         return false;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && g_cross_down)
        {
         g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
         return true;
        }
      if(position_type == POSITION_TYPE_SELL && g_cross_up)
        {
         g_strategy_exit_reason = QM_EXIT_OPPOSITE_SIGNAL;
         return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the central fail-closed two-axis news filter
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(qm_ea_id != 12954 || qm_magic_slot_offset < 0 || qm_magic_slot_offset > 12)
      return INIT_PARAMETERS_INCORRECT;
   if(_Period != PERIOD_H4)
     {
      Print("QM5_12954 requires H4.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(strategy_roc_short_period <= 0 || strategy_roc_long_period <= 0 ||
      strategy_wma_period <= 0 || strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 || strategy_sl_atr_cap <= 0.0 ||
      strategy_be_trigger_atr <= 0.0 || strategy_time_stop_bars <= 0 ||
      strategy_warmup_bars < 35 || strategy_max_spread_atr < 0.0 ||
      qm_news_stale_max_hours <= 0 || qm_news_stale_max_hours > 336)
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

   const bool is_new_bar = QM_IsNewBar(_Symbol, PERIOD_H4);
   if(is_new_bar)
     {
      Strategy_AdvanceCoppockOnNewBar();
      QM_EquityStreamOnNewBar();
     }

   Strategy_ManageOpenPosition();

   if(is_new_bar && Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !is_new_bar || Strategy_NoTradeFilter())
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
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
