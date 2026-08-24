#property strict
#property version   "5.0"
#property description "QM5_36005 NNFX Coral TrendLord Woodies Harvester"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36005
// Approved card: QM5_36005_nnfx-coral-trendlord-woodies-harvester.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 36005;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_coral_period          = 20;
input int    strategy_trendlord_period      = 50;
input int    strategy_woodies_cci_period    = 14;
input int    strategy_wae_fast              = 12;
input int    strategy_wae_slow              = 26;
input int    strategy_wae_signal            = 9;
input int    strategy_wae_bb_period         = 20;
input double strategy_wae_bb_deviation      = 2.0;
input int    strategy_wae_sensitivity       = 150;
input int    strategy_atr_period            = 14;
input double strategy_sl_atr_mult           = 1.0;
input double strategy_tp1_atr_mult          = 1.0;
input double strategy_tp1_fraction          = 0.50;
input int    strategy_be_buffer_pips        = 1;
input double strategy_spread_atr_mult       = 1.8;
input double strategy_daily_loss_halt_pct   = 2.0;
input double strategy_daily_hard_stop_pct   = 2.5;
input double strategy_total_dd_halt_pct     = 5.0;
input int    strategy_max_slippage_ticks    = 3;

double g_strategy_initial_equity = 0.0;
bool   g_strategy_total_dd_halted = false;
string g_strategy_total_dd_baseline_key = "";
string g_strategy_total_dd_halt_key = "";
ulong  g_strategy_tp1_ticket = 0;
double g_strategy_tp1_initial_volume = 0.0;
bool   g_strategy_tp1_done = false;
string g_strategy_tp1_marker_key = "";

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_ConfigValid()
  {
   if(strategy_coral_period < 2 || strategy_trendlord_period < 2 ||
      strategy_woodies_cci_period < 2 || strategy_wae_fast < 1 ||
      strategy_wae_slow <= strategy_wae_fast || strategy_wae_signal < 1 ||
      strategy_wae_bb_period < 2 || strategy_wae_bb_deviation <= 0.0 ||
      strategy_wae_sensitivity <= 0 || strategy_atr_period < 2)
      return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp1_atr_mult <= 0.0 ||
      strategy_tp1_fraction <= 0.0 || strategy_tp1_fraction >= 1.0 ||
      strategy_be_buffer_pips < 0 || strategy_spread_atr_mult <= 0.0)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0)
      return false;
   if(strategy_max_slippage_ticks < 1 || strategy_max_slippage_ticks > 3)
      return false;
   // InpRiskPercent is the card's risk input; V5 maps it to RISK_PERCENT.
   if(RISK_PERCENT < 0.0 || RISK_PERCENT > 2.0)
      return false;
   return true;
  }

string Strategy_StateKey(const string suffix)
  {
   return StringFormat("QM5_36005_%d_%s", QM_FrameworkMagic(), suffix);
  }

bool Strategy_CapitalLimitsInit()
  {
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0 || QM_FrameworkMagic() <= 0)
      return false;

   g_strategy_total_dd_baseline_key = Strategy_StateKey("TOTAL_DD_BASE");
   g_strategy_total_dd_halt_key = Strategy_StateKey("TOTAL_DD_HALT");

   // Tester passes are independent experiments. Live/demo/shadow re-attaches
   // restore the first-attach baseline and a latched total-DD halt.
   if(MQLInfoInteger(MQL_TESTER) != 0)
     {
      g_strategy_initial_equity = equity_now;
      g_strategy_total_dd_halted = false;
      return true;
     }

   if(GlobalVariableCheck(g_strategy_total_dd_baseline_key))
      g_strategy_initial_equity = GlobalVariableGet(g_strategy_total_dd_baseline_key);
   else
     {
      g_strategy_initial_equity = equity_now;
      if(GlobalVariableSet(g_strategy_total_dd_baseline_key,
                           g_strategy_initial_equity) == 0)
         return false;
     }

   if(g_strategy_initial_equity <= 0.0)
      return false;
   g_strategy_total_dd_halted =
      (GlobalVariableCheck(g_strategy_total_dd_halt_key) &&
       GlobalVariableGet(g_strategy_total_dd_halt_key) > 0.5);
   return true;
  }

void Strategy_CloseOwnedPositions(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_TotalDrawdownHalt()
  {
   if(g_strategy_initial_equity <= 0.0)
      return true;

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   const double floor_equity =
      g_strategy_initial_equity * (1.0 - strategy_total_dd_halt_pct / 100.0);
   if(!g_strategy_total_dd_halted &&
      (equity_now <= 0.0 || equity_now <= floor_equity))
     {
      g_strategy_total_dd_halted = true;
      if(MQLInfoInteger(MQL_TESTER) == 0)
         GlobalVariableSet(g_strategy_total_dd_halt_key, 1.0);
      QM_LogFatal("STRATEGY_TOTAL_DD_HALT",
                  StringFormat("{\"initial_equity\":%.2f,\"equity_now\":%.2f,\"halt_pct\":%.4f}",
                               g_strategy_initial_equity,
                               equity_now,
                               strategy_total_dd_halt_pct));
     }

   if(!g_strategy_total_dd_halted)
      return false;

   // Retry the owned-position sweep on every tick until exposure is flat.
   Strategy_CloseOwnedPositions(QM_EXIT_KILLSWITCH);
   return true;
  }

int Strategy_MaxSlippagePoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return -1;
   return (int)MathCeil((double)strategy_max_slippage_ticks * tick_size / point);
  }

bool Strategy_DailyRealizedLossHalt()
  {
   // Use closed account history, not equity, for the card's realized-loss
   // entry halt. The history survives EA restarts and includes other EAs.
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
  }

// Return TRUE only for entry blackouts. Open-position management and exits run
// before this hook in OnTick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   if(g_strategy_total_dd_halted || g_strategy_initial_equity <= 0.0)
      return true;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return true;

   const datetime broker_now = TimeCurrent();
   if(Strategy_DailyRealizedLossHalt())
      return true;

   // Card states the rollover interval in GMT, so convert broker time to UTC.
   MqlDateTime utc_parts;
   TimeToStruct(QM_BrokerToUTC(broker_now), utc_parts);
   if((utc_parts.hour == 23 && utc_parts.min >= 55) ||
      (utc_parts.hour == 0 && utc_parts.min <= 5))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return true;

   // A zero modeled spread on .DWX is valid. Block only a genuinely wide one.
   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr_1)
      return true;

   return false;
  }

// The framework calls this once per new D1 bar. All strategy math uses pooled
// QM_* readers on the completed bar at shift 1.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   // Slot zero is relative to the host magic already resolved and validated
   // from qm_magic_slot_offset by QM_FrameworkInit.
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(Strategy_NoTradeFilter())
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   if(strategy_coral_period < 2 || strategy_trendlord_period < 2 ||
      strategy_woodies_cci_period < 2 || strategy_wae_fast < 1 ||
      strategy_wae_slow <= strategy_wae_fast || strategy_wae_signal < 1 ||
      strategy_wae_bb_period < 2 || strategy_wae_bb_deviation <= 0.0 ||
      strategy_wae_sensitivity <= 0 || strategy_atr_period < 2 ||
      strategy_sl_atr_mult <= 0.0)
      return false;

   const double close_1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double coral_1 = QM_SMMA(_Symbol, PERIOD_D1, strategy_coral_period, 1, PRICE_CLOSE);
   const double trendlord_1 = QM_LWMA(_Symbol, PERIOD_D1, strategy_trendlord_period, 1, PRICE_CLOSE);
   const double trendlord_2 = QM_LWMA(_Symbol, PERIOD_D1, strategy_trendlord_period, 2, PRICE_CLOSE);
   const double woodies_cci_1 = QM_CCI(_Symbol, PERIOD_D1, strategy_woodies_cci_period, 1, PRICE_TYPICAL);
   const double macd_1 = QM_MACD_Main(_Symbol, PERIOD_D1,
                                     strategy_wae_fast, strategy_wae_slow,
                                     strategy_wae_signal, 1, PRICE_CLOSE);
   const double macd_2 = QM_MACD_Main(_Symbol, PERIOD_D1,
                                     strategy_wae_fast, strategy_wae_slow,
                                     strategy_wae_signal, 2, PRICE_CLOSE);
   const double bb_upper_1 = QM_BB_Upper(_Symbol, PERIOD_D1,
                                        strategy_wae_bb_period,
                                        strategy_wae_bb_deviation,
                                        1, PRICE_CLOSE);
   const double bb_lower_1 = QM_BB_Lower(_Symbol, PERIOD_D1,
                                        strategy_wae_bb_period,
                                        strategy_wae_bb_deviation,
                                        1, PRICE_CLOSE);
   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(close_1 <= 0.0 || coral_1 <= 0.0 || trendlord_1 <= 0.0 ||
      trendlord_2 <= 0.0 || bb_upper_1 <= bb_lower_1 || atr_1 <= 0.0)
      return false;

   const double wae_value = MathAbs(macd_1 - macd_2) * (double)strategy_wae_sensitivity;
   const double explosion_line = MathAbs(bb_upper_1 - bb_lower_1);
   if(wae_value <= explosion_line)
      return false;

   const int trendlord_color = (trendlord_1 > trendlord_2) ? 1 :
                               ((trendlord_1 < trendlord_2) ? -1 : 0);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close_1 > coral_1 && trendlord_color > 0 && woodies_cci_1 > 0.0)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr_1, strategy_sl_atr_mult);
      req.reason = "NNFX_CORAL_TL_WOODIES_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(close_1 < coral_1 && trendlord_color < 0 && woodies_cci_1 < 0.0)
     {
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr_1, strategy_sl_atr_mult);
      req.reason = "NNFX_CORAL_TL_WOODIES_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

// Close half at +1 ATR and protect the runner at entry plus/minus one pip.
// Hard drawdown limits are enforced by the restart-safe framework kill switch.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool found_owned_position = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found_owned_position = true;

      if(strategy_tp1_atr_mult <= 0.0 || strategy_tp1_fraction <= 0.0 ||
         strategy_tp1_fraction >= 1.0 || strategy_sl_atr_mult <= 0.0)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || volume <= 0.0 || point <= 0.0)
         continue;

      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                               strategy_be_buffer_pips);
      const double be_sl = is_buy ? (open_price + be_buffer)
                                  : (open_price - be_buffer);
      const bool runner_protected =
         is_buy ? (current_sl >= be_sl - point * 0.5)
                : (current_sl <= be_sl + point * 0.5);

      if(ticket != g_strategy_tp1_ticket)
        {
         if(StringLen(g_strategy_tp1_marker_key) > 0 &&
            MQLInfoInteger(MQL_TESTER) == 0)
            GlobalVariableDel(g_strategy_tp1_marker_key);
         g_strategy_tp1_ticket = ticket;
         g_strategy_tp1_initial_volume = volume;
         g_strategy_tp1_marker_key =
            StringFormat("QM5_36005_TP1_%d_%I64u", magic, ticket);
         g_strategy_tp1_done = runner_protected;
         if(MQLInfoInteger(MQL_TESTER) == 0 &&
            GlobalVariableCheck(g_strategy_tp1_marker_key))
            g_strategy_tp1_done =
               (GlobalVariableGet(g_strategy_tp1_marker_key) > 0.5);
        }

      if(g_strategy_tp1_done)
        {
         if(!runner_protected)
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, be_sl),
                         "NNFX_TP1_BE_PROTECTION_RETRY");
         continue;
        }

      const double initial_risk = is_buy ? (open_price - current_sl)
                                         : (current_sl - open_price);
      if(initial_risk <= 0.0)
         continue;

      const double atr_at_entry = initial_risk / strategy_sl_atr_mult;
      const double trigger_distance = atr_at_entry * strategy_tp1_atr_mult;
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double favorable_move = is_buy ? (market_price - open_price)
                                           : (open_price - market_price);
      if(market_price <= 0.0 || favorable_move < trigger_distance)
         continue;

      const double partial_lots =
         QM_TM_NormalizeVolume(_Symbol,
                               g_strategy_tp1_initial_volume * strategy_tp1_fraction);
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(partial_lots <= 0.0 || partial_lots >= volume ||
         volume - partial_lots < min_lot - 1e-8)
         continue;

      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
        {
         g_strategy_tp1_done = true;
         if(MQLInfoInteger(MQL_TESTER) == 0)
            GlobalVariableSet(g_strategy_tp1_marker_key, 1.0);
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, be_sl),
                      "NNFX_TP1_BE_PROTECTION");
        }
     }

   if(!found_owned_position && g_strategy_tp1_ticket != 0)
     {
      if(StringLen(g_strategy_tp1_marker_key) > 0 &&
         MQLInfoInteger(MQL_TESTER) == 0)
         GlobalVariableDel(g_strategy_tp1_marker_key);
      g_strategy_tp1_ticket = 0;
      g_strategy_tp1_initial_volume = 0.0;
      g_strategy_tp1_done = false;
      g_strategy_tp1_marker_key = "";
     }
  }

// The approved runner has exactly one discretionary exit: Trend Lord color
// reversal. CCI remains an entry confirmation only.
bool Strategy_ExitSignal()
  {
   if(strategy_trendlord_period < 2)
      return false;

   const double trendlord_1 = QM_LWMA(_Symbol, PERIOD_D1,
                                      strategy_trendlord_period, 1, PRICE_CLOSE);
   const double trendlord_2 = QM_LWMA(_Symbol, PERIOD_D1,
                                      strategy_trendlord_period, 2, PRICE_CLOSE);
   if(trendlord_1 <= 0.0 || trendlord_2 <= 0.0 || trendlord_1 == trendlord_2)
      return false;

   const int trendlord_color = (trendlord_1 > trendlord_2) ? 1 : -1;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && trendlord_color < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && trendlord_color > 0)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — copied intact from framework/templates/EA_Skeleton.mq5.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!Strategy_ConfigValid())
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

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         (RISK_PERCENT > 0.0 ? RISK_PERCENT : 1.0)))
      return INIT_FAILED;

   if(!Strategy_CapitalLimitsInit())
      return INIT_FAILED;

   const int max_slippage_points = Strategy_MaxSlippagePoints();
   if(max_slippage_points <= 0)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     max_slippage_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

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

   if(Strategy_TotalDrawdownHalt())
      return;

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
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
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   if(Strategy_NoTradeFilter())
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
