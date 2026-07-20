#property strict
#property version   "5.2"
#property description "QM5_1224 White-Okunev FX Cross-Sectional MA Momentum Basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_1224 - White/Okunev FX cross-sectional momentum
// -----------------------------------------------------------------------------
// One EURUSD.DWX/D1 host owns the complete seven-symbol rank calculation and
// the resulting two-leg package. A standalone symbol instance is not an
// economically valid test unit for a cross-sectional strategy.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1224;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 500.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period_d1      = 120;
input int    strategy_min_d1_bars        = 160;
input int    strategy_exit_rank_band     = 2;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 3.0;
input double strategy_basket_loss_r      = 2.0;
input int    strategy_rebalance_mode     = 1;      // 0=weekly, 1=monthly
input int    strategy_spread_days        = 20;
input double strategy_spread_mult        = 3.0;

const int STRATEGY_UNIVERSE_SIZE = 7;
string g_symbols[7] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX",
   "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX"
  };
long g_magics[7];

bool     g_rebalance_due             = false;
bool     g_rank_ready                = false;
bool     g_rebalance_package_ready   = false;
datetime g_decision_bar_time         = 0;
int      g_rebalance_key             = 0;
int      g_last_attempt_period_key   = 0;
int      g_last_kill_period_key      = 0;
double   g_package_per_leg_risk_money = 0.0;
string   g_attempt_state_key         = "";
int      g_entry_directions[7];
int      g_exit_directions[7];

bool Strategy_IsUsdBaseSymbol(const string symbol)
  {
   return (symbol == "USDCAD.DWX" || symbol == "USDCHF.DWX" ||
           symbol == "USDJPY.DWX");
  }

int Strategy_PairDirection(const int slot,
                           const int foreign_currency_direction)
  {
   if(slot < 0 || slot >= STRATEGY_UNIVERSE_SIZE ||
      foreign_currency_direction == 0)
      return 0;
   return Strategy_IsUsdBaseSymbol(g_symbols[slot])
          ? -foreign_currency_direction
          : foreign_currency_direction;
  }

int Strategy_ForeignDirection(const int slot, const int pair_direction)
  {
   if(slot < 0 || slot >= STRATEGY_UNIVERSE_SIZE || pair_direction == 0)
      return 0;
   return Strategy_IsUsdBaseSymbol(g_symbols[slot])
          ? -pair_direction
          : pair_direction;
  }

ENUM_TIMEFRAMES Strategy_RebalanceCadence()
  {
   return (strategy_rebalance_mode == 0) ? PERIOD_W1 : PERIOD_MN1;
  }

int Strategy_CurrentPeriodKey()
  {
   return QM_CalendarPeriodKey(Strategy_RebalanceCadence(), _Symbol, 0);
  }

bool Strategy_IsRebalanceBar()
  {
   const ENUM_TIMEFRAMES cadence = Strategy_RebalanceCadence();
   const int current_key = QM_CalendarPeriodKey(cadence, _Symbol, 0);
   const int previous_key = QM_CalendarPeriodKey(cadence, _Symbol, 1);
   if(current_key <= 0 || previous_key <= 0 || current_key == previous_key)
      return false;
   g_rebalance_key = current_key;
   return true;
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_FX7_XMOM_ATTEMPT_PERIOD", qm_ea_id);
  }

void Strategy_LoadAttemptState()
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_period_key = 0;
   const int current_key = Strategy_CurrentPeriodKey();
   if(current_key <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int stored_key = (int)GlobalVariableGet(g_attempt_state_key);
   if(stored_key > 0 && stored_key <= current_key)
      g_last_attempt_period_key = stored_key;
   else
      GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int period_key)
  {
   if(period_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_period_key = period_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)period_key) > 0);
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 1224 && qm_magic_slot_offset == 0 &&
           _Symbol == g_symbols[0] && _Period == PERIOD_D1 &&
           strategy_sma_period_d1 >= 20 && strategy_sma_period_d1 <= 400 &&
           strategy_min_d1_bars >= 160 && strategy_min_d1_bars <= 600 &&
           strategy_exit_rank_band >= 1 && strategy_exit_rank_band <= 3 &&
           strategy_atr_period >= 5 && strategy_atr_period <= 100 &&
           strategy_atr_sl_mult > 0.0 && strategy_atr_sl_mult <= 10.0 &&
           strategy_basket_loss_r > 0.0 && strategy_basket_loss_r <= 10.0 &&
           strategy_rebalance_mode >= 0 && strategy_rebalance_mode <= 1 &&
           strategy_spread_days >= 1 && strategy_spread_days <= 64 &&
           strategy_spread_mult > 0.0 && strategy_spread_mult <= 10.0 &&
           !qm_friday_close_enabled);
  }

bool Strategy_SelectedOwnedPosition(int &slot, int &pair_direction)
  {
   slot = -1;
   pair_direction = 0;
   const long magic = PositionGetInteger(POSITION_MAGIC);
   const string symbol = PositionGetString(POSITION_SYMBOL);
   for(int index = 0; index < STRATEGY_UNIVERSE_SIZE; ++index)
     {
      if(magic != g_magics[index] || symbol != g_symbols[index])
         continue;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL)
         return false;
      slot = index;
      pair_direction = (type == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

int Strategy_OpenOwnedPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int direction = 0;
      if(Strategy_SelectedOwnedPosition(slot, direction))
         ++count;
     }
   return count;
  }

bool Strategy_HasOpenSlot(const int wanted_slot)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int direction = 0;
      if(Strategy_SelectedOwnedPosition(slot, direction) && slot == wanted_slot)
         return true;
     }
   return false;
  }

bool Strategy_ForeignSideOpen(const int wanted_foreign_direction)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int pair_direction = 0;
      if(!Strategy_SelectedOwnedPosition(slot, pair_direction))
         continue;
      if(Strategy_ForeignDirection(slot, pair_direction) ==
         wanted_foreign_direction)
         return true;
     }
   return false;
  }

bool Strategy_PackageCompositionValid()
  {
   int owned_count = 0;
   int foreign_long_count = 0;
   int foreign_short_count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int pair_direction = 0;
      if(!Strategy_SelectedOwnedPosition(slot, pair_direction))
         continue;
      ++owned_count;
      if(PositionGetDouble(POSITION_SL) <= 0.0)
         return false;
      const int foreign_direction =
         Strategy_ForeignDirection(slot, pair_direction);
      if(foreign_direction > 0)
         ++foreign_long_count;
      else if(foreign_direction < 0)
         ++foreign_short_count;
     }
   return (owned_count == 2 && foreign_long_count == 1 &&
           foreign_short_count == 1);
  }

void Strategy_CloseAllOwned(const QM_ExitReason reason)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int direction = 0;
      if(Strategy_SelectedOwnedPosition(slot, direction))
         QM_TM_ClosePosition(ticket, reason);
     }
   g_package_per_leg_risk_money = 0.0;
  }

double Strategy_OpenBasketProfit()
  {
   double profit = 0.0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int direction = 0;
      if(!Strategy_SelectedOwnedPosition(slot, direction))
         continue;
      profit += PositionGetDouble(POSITION_PROFIT) +
                PositionGetDouble(POSITION_SWAP);
     }
   return profit;
  }

bool Strategy_CloseBasketIfLossLimit()
  {
   const int open_count = Strategy_OpenOwnedPositionCount();
   if(open_count <= 0 || strategy_basket_loss_r <= 0.0)
      return false;

   const int current_key = Strategy_CurrentPeriodKey();
   if(current_key > 0 && current_key == g_last_kill_period_key)
      return false;

   if(g_package_per_leg_risk_money <= 0.0)
      g_package_per_leg_risk_money =
         QM_RiskSizerRiskMoney(AccountInfoDouble(ACCOUNT_EQUITY));
   if(g_package_per_leg_risk_money <= 0.0)
      return false;

   const double loss_limit =
      strategy_basket_loss_r * g_package_per_leg_risk_money;
   if(Strategy_OpenBasketProfit() > -loss_limit)
      return false;

   Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
   g_last_kill_period_key = current_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_CloseBasketIfLossLimit())
      return;
   const int open_count = Strategy_OpenOwnedPositionCount();
   if(open_count <= 0)
     {
      g_package_per_leg_risk_money = 0.0;
      return;
     }
   if(open_count != 2 || !Strategy_PackageCompositionValid())
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }
   if(g_package_per_leg_risk_money <= 0.0)
      g_package_per_leg_risk_money =
         QM_RiskSizerRiskMoney(AccountInfoDouble(ACCOUNT_EQUITY));
  }

double Strategy_MedianDailySpreadPoints(const string symbol)
  {
   int spreads[];
   ArrayResize(spreads, strategy_spread_days);
   const int copied = CopySpread(symbol, PERIOD_D1, 1,
                                 strategy_spread_days, spreads); // perf-allowed: first-trading-day preflight only.
   if(copied <= 0)
      return 0.0;

   double values[];
   ArrayResize(values, copied);
   int count = 0;
   for(int index = 0; index < copied; ++index)
     {
      if(spreads[index] <= 0)
         continue;
      values[count] = (double)spreads[index];
      ++count;
     }
   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry(const string symbol)
  {
   const double median_spread = Strategy_MedianDailySpreadPoints(symbol);
   if(median_spread <= 0.0)
      return false;
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double current_spread = (ask - bid) / point;
   return (current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_SymbolScore(const string symbol, double &out_score)
  {
   out_score = 0.0;
   const int required_bars =
      (int)MathMax((double)strategy_min_d1_bars,
                   (double)(strategy_sma_period_d1 + 1));
   MqlRates recent_bar;
   MqlRates oldest_required_bar;
   if(!QM_ReadBar(symbol, PERIOD_D1, 1, recent_bar) ||
      !QM_ReadBar(symbol, PERIOD_D1, required_bars,
                  oldest_required_bar))
      return false;
   if(recent_bar.time != g_decision_bar_time || recent_bar.close <= 0.0)
      return false;

   const double sma_close =
      QM_SMA(symbol, PERIOD_D1, strategy_sma_period_d1, 1, PRICE_CLOSE);
   if(sma_close <= 0.0 || !MathIsValidNumber(sma_close))
      return false;

   double raw_score = (recent_bar.close / sma_close) - 1.0;
   if(Strategy_IsUsdBaseSymbol(symbol))
      raw_score = -raw_score;
   if(!MathIsValidNumber(raw_score))
      return false;
   out_score = raw_score;
   return true;
  }

bool Strategy_RankDirections(int &entry_directions[],
                             int &exit_directions[])
  {
   ArrayInitialize(entry_directions, 0);
   ArrayInitialize(exit_directions, 0);

   double scores[7];
   int indexes[7];
   int count = 0;
   for(int slot = 0; slot < STRATEGY_UNIVERSE_SIZE; ++slot)
     {
      double score = 0.0;
      if(!Strategy_SymbolScore(g_symbols[slot], score))
         continue;
      scores[count] = score;
      indexes[count] = slot;
      ++count;
     }
   if(count < 5)
      return false;

   for(int left = 0; left < count - 1; ++left)
      for(int right = left + 1; right < count; ++right)
         if(scores[right] < scores[left])
           {
            const double score_swap = scores[left];
            scores[left] = scores[right];
            scores[right] = score_swap;
            const int index_swap = indexes[left];
            indexes[left] = indexes[right];
            indexes[right] = index_swap;
           }

   const int band =
      (int)MathMin((double)strategy_exit_rank_band,
                   (double)(count / 2));
   for(int rank = 0; rank < band; ++rank)
      exit_directions[indexes[rank]] =
         Strategy_PairDirection(indexes[rank], -1);
   for(int rank = count - band; rank < count; ++rank)
      exit_directions[indexes[rank]] =
         Strategy_PairDirection(indexes[rank], 1);

   entry_directions[indexes[0]] =
      Strategy_PairDirection(indexes[0], -1);
   entry_directions[indexes[count - 1]] =
      Strategy_PairDirection(indexes[count - 1], 1);
   return true;
  }

bool Strategy_PositionOutsideExitBand()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int pair_direction = 0;
      if(!Strategy_SelectedOwnedPosition(slot, pair_direction))
         continue;
      if(g_exit_directions[slot] != pair_direction)
         return true;
     }
   return false;
  }

bool Strategy_ApplyRankExits()
  {
   bool close_ok = true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      int slot = -1;
      int pair_direction = 0;
      if(!Strategy_SelectedOwnedPosition(slot, pair_direction))
         continue;
      if(g_exit_directions[slot] == pair_direction)
         continue;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         close_ok = false;
     }

   if(!close_ok || Strategy_PositionOutsideExitBand())
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }
   const int open_count = Strategy_OpenOwnedPositionCount();
   if(open_count > 2 ||
      (open_count == 2 && !Strategy_PackageCompositionValid()))
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }
   return true;
  }

int Strategy_TargetSlotForForeignSide(const int wanted_foreign_direction)
  {
   for(int slot = 0; slot < STRATEGY_UNIVERSE_SIZE; ++slot)
     {
      const int pair_direction = g_entry_directions[slot];
      if(pair_direction == 0)
         continue;
      if(Strategy_ForeignDirection(slot, pair_direction) ==
         wanted_foreign_direction)
         return slot;
     }
   return -1;
  }

bool Strategy_SymbolCanTradeDirection(const string symbol,
                                      const int pair_direction)
  {
   const long mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED ||
      mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   if(pair_direction > 0 && mode == SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(pair_direction < 0 && mode == SYMBOL_TRADE_MODE_LONGONLY)
      return false;
   return true;
  }

bool Strategy_PrepareLegRequest(const int slot,
                                const int pair_direction,
                                QM_BasketOrderRequest &request)
  {
   if(slot < 0 || slot >= STRATEGY_UNIVERSE_SIZE ||
      pair_direction == 0 || Strategy_HasOpenSlot(slot))
      return false;
   const string symbol = g_symbols[slot];
   if(!Strategy_SymbolCanTradeDirection(symbol, pair_direction) ||
      !Strategy_SpreadAllowsEntry(symbol))
      return false;

   const QM_OrderType order_type =
      (pair_direction > 0) ? QM_BUY : QM_SELL;
   const double price = QM_BasketMarketPrice(symbol, order_type);
   const double stop = QM_StopATR(symbol, order_type, price,
                                  strategy_atr_period,
                                  strategy_atr_sl_mult);
   const double stop_points = QM_BasketSLPoints(symbol, price, stop);
   const double preflight_lots =
      QM_BasketNormalizeLots(symbol, QM_LotsForRisk(symbol, stop_points));
   if(price <= 0.0 || stop <= 0.0 || stop_points <= 0.0 ||
      preflight_lots <= 0.0)
      return false;

   request.symbol = symbol;
   request.type = order_type;
   request.price = 0.0;
   request.sl = stop;
   request.tp = 0.0;
   request.lots = 0.0;
   request.reason = (Strategy_ForeignDirection(slot, pair_direction) > 0)
                    ? "WHITE_OKUNEV_FX_FOREIGN_LONG"
                    : "WHITE_OKUNEV_FX_FOREIGN_SHORT";
   request.symbol_slot = slot;
   request.expiration_seconds = 0;
   return true;
  }

bool Strategy_OpenPreparedLeg(const QM_BasketOrderRequest &request)
  {
   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20,
                                request, ticket);
  }

bool Strategy_OpenMissingLegs()
  {
   int open_count = Strategy_OpenOwnedPositionCount();
   if(open_count == 2)
      return Strategy_PackageCompositionValid();
   if(open_count < 0 || open_count > 1)
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }

   const bool need_foreign_long = !Strategy_ForeignSideOpen(1);
   const bool need_foreign_short = !Strategy_ForeignSideOpen(-1);
   if(!need_foreign_long && !need_foreign_short)
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }

   QM_BasketOrderRequest long_request;
   QM_BasketOrderRequest short_request;
   if(need_foreign_long)
     {
      const int long_slot = Strategy_TargetSlotForForeignSide(1);
      if(long_slot < 0 ||
         !Strategy_PrepareLegRequest(long_slot,
                                     g_entry_directions[long_slot],
                                     long_request))
        {
         Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
         return false;
        }
     }
   if(need_foreign_short)
     {
      const int short_slot = Strategy_TargetSlotForForeignSide(-1);
      if(short_slot < 0 ||
         !Strategy_PrepareLegRequest(short_slot,
                                     g_entry_directions[short_slot],
                                     short_request))
        {
         Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
         return false;
        }
     }

   if(need_foreign_long && !Strategy_OpenPreparedLeg(long_request))
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }
   if(need_foreign_short && !Strategy_OpenPreparedLeg(short_request))
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }
   if(!Strategy_PackageCompositionValid())
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }
   g_package_per_leg_risk_money =
      QM_RiskSizerRiskMoney(AccountInfoDouble(ACCOUNT_EQUITY));
   return true;
  }

bool Strategy_NewsAllowsSymbol(const string symbol,
                               const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(symbol, broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!Strategy_ForeignSideOpen(1))
     {
      const int slot = Strategy_TargetSlotForForeignSide(1);
      if(slot < 0 || !Strategy_NewsAllowsSymbol(g_symbols[slot], broker_time))
         return true;
     }
   if(!Strategy_ForeignSideOpen(-1))
     {
      const int slot = Strategy_TargetSlotForForeignSide(-1);
      if(slot < 0 || !Strategy_NewsAllowsSymbol(g_symbols[slot], broker_time))
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   return !Strategy_InputsValid();
  }

bool Strategy_ExitSignal()
  {
   g_rebalance_package_ready = false;
   if(!g_rebalance_due)
      return false;
   if(!g_rank_ready)
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return false;
     }
   g_rebalance_package_ready = Strategy_ApplyRankExits();
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "WHITE_OKUNEV_FX_LOGICAL_HOST";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(g_rebalance_due && g_rank_ready && g_rebalance_package_ready)
      Strategy_OpenMissingLegs();
   return false;
  }

int OnInit()
  {
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
   for(int slot = 0; slot < STRATEGY_UNIVERSE_SIZE; ++slot)
      if(!SymbolSelect(g_symbols[slot], true))
         return INIT_FAILED;

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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_DISABLED,
         "Card requires monthly rank retention; Friday flattening changes the holding rule"))
      return INIT_FAILED;

   for(int slot = 0; slot < STRATEGY_UNIVERSE_SIZE; ++slot)
     {
      const int magic = QM_MagicChecked(qm_ea_id, slot, g_symbols[slot]);
      if(magic <= 0 || !QM_KillSwitchRegisterMagic((long)magic))
         return INIT_FAILED;
      g_magics[slot] = (long)magic;
     }

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1,
                          strategy_min_d1_bars + 5);
   Strategy_LoadAttemptState();
   if(Strategy_PackageCompositionValid())
      g_package_per_leg_risk_money =
         QM_RiskSizerRiskMoney(AccountInfoDouble(ACCOUNT_EQUITY));

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_1224\",\"ea\":\"white-okunev-fx-xmom\",\"scope\":\"logical_fx7_basket\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
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
   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   g_rebalance_due = false;
   g_rank_ready = false;
   g_rebalance_package_ready = false;
   g_decision_bar_time = 0;
   g_rebalance_key = 0;
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      MqlRates decision_bar;
      if(QM_ReadBar(_Symbol, PERIOD_D1, 1, decision_bar))
         g_decision_bar_time = decision_bar.time;
      if(g_decision_bar_time > 0 && Strategy_IsRebalanceBar())
        {
         g_rebalance_due = true;
         g_rank_ready =
            Strategy_RankDirections(g_entry_directions,
                                    g_exit_directions);
        }
     }

   // Risk, orphan repair, and rank exits are never blocked by entry news gates.
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();
   if(!g_rebalance_due || !g_rank_ready ||
      !g_rebalance_package_ready)
      return;
   if(Strategy_OpenOwnedPositionCount() == 2 &&
      Strategy_PackageCompositionValid())
      return;
   if(g_rebalance_key <= 0 ||
      g_rebalance_key == g_last_kill_period_key ||
      g_rebalance_key == g_last_attempt_period_key)
     {
      if(Strategy_OpenOwnedPositionCount() == 1)
         Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }

   // Consume the first-trading-day attempt before any entry-only blocker so a
   // restart cannot turn a monthly rule into an intraday retry strategy.
   if(!Strategy_RecordAttemptState(g_rebalance_key))
     {
      if(Strategy_OpenOwnedPositionCount() == 1)
         Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }
   if(Strategy_NewsFilterHook(broker_now))
     {
      if(Strategy_OpenOwnedPositionCount() == 1)
         Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }

   QM_EntryRequest request;
   ZeroMemory(request);
   if(Strategy_EntrySignal(request))
     {
      ulong ticket = 0;
      QM_TM_OpenPosition(request, ticket);
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
