#property strict
#property version   "5.0"
#property description "QM5_41242 WTI EIA negative first-minute drift"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41242 - WTI EIA Negative First-Minute Drift
// -----------------------------------------------------------------------------
// One standard-Wednesday decision: a strictly negative completed 10:30 New
// York M1 bar is the price-only negative-news proxy. Enter SELL at 10:31 and
// flatten at 10:35, the end of the source's five-minute drift window.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41242;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_release_hhmm_ny       = 1030;
input int    strategy_decision_hhmm_ny      = 1031;
input int    strategy_flat_hhmm_ny          = 1035;
input int    strategy_entry_grace_seconds   = 30;
input int    strategy_atr_period_m1         = 20;
input double strategy_atr_stop_multiple     = 3.0;
input int    strategy_max_hold_minutes      = 10;
input int    strategy_max_spread_points     = 1500;

bool   g_entry_ready = false;
int    g_signal_day_key = 0;
double g_signal_atr = 0.0;
int    g_last_attempt_day_key = 0;
string g_attempt_state_key = "";

bool Strategy_IsHostChart()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_M1);
  }

datetime Strategy_BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

bool Strategy_TimeParts(const datetime value, MqlDateTime &parts)
  {
   ZeroMemory(parts);
   return (value > 0 && TimeToStruct(value, parts));
  }

int Strategy_NYDayKey(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(Strategy_BrokerToNY(broker_time), parts) ||
      parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_NYDayOfWeek(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(Strategy_BrokerToNY(broker_time), parts))
      return -1;
   return parts.day_of_week;
  }

int Strategy_NYHhmm(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(Strategy_BrokerToNY(broker_time), parts))
      return -1;
   return parts.hour * 100 + parts.min;
  }

int Strategy_NYSecond(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(Strategy_BrokerToNY(broker_time), parts))
      return -1;
   return parts.sec;
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 41242 &&
           qm_magic_slot_offset == 0 &&
           qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
           qm_news_compliance == QM_NEWS_COMPLIANCE_NONE &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21 &&
           strategy_release_hhmm_ny == 1030 &&
           strategy_decision_hhmm_ny == 1031 &&
           strategy_flat_hhmm_ny == 1035 &&
           strategy_entry_grace_seconds == 30 &&
           strategy_atr_period_m1 == 20 &&
           MathAbs(strategy_atr_stop_multiple - 3.0) <= 1.0e-12 &&
           strategy_max_hold_minutes == 10 &&
           strategy_max_spread_points == 1500);
  }

bool Strategy_NoTradeFilter()
  {
   return (!Strategy_IsHostChart() || !Strategy_InputsValid());
  }

bool Strategy_IsMagicPosition()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

bool Strategy_IsManagedPosition()
  {
   return (Strategy_IsMagicPosition() &&
           PositionGetString(POSITION_SYMBOL) == _Symbol);
  }

int Strategy_MagicPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsMagicPosition())
         ++count;
     }
   return count;
  }

bool Strategy_HasManagedPosition()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         return true;
     }
   return false;
  }

bool Strategy_DayAlreadyEntered(const int day_key)
  {
   if(day_key <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_NYDayKey(opened) == day_key)
         return true;
     }

   const datetime now = TimeCurrent();
   if(now <= 0 || !HistorySelect(now - 14 * 86400, now))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0 ||
         (int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_NYDayKey(deal_time) == day_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_day_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_day_key = Strategy_NYDayKey(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_day_key = (int)MathRound(stored);
   if(current_day_key > 0 && MathIsValidNumber(stored) &&
      stored_day_key >= 19000101 && stored_day_key <= current_day_key)
     {
      g_last_attempt_day_key = stored_day_key;
      return;
     }
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int day_key)
  {
   if(day_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key, (double)day_key) <= 0)
      return false;
   g_last_attempt_day_key = day_key;
   return true;
  }

void Strategy_ClearSignal()
  {
   g_entry_ready = false;
   g_signal_day_key = 0;
   g_signal_atr = 0.0;
  }

bool Strategy_ValidReleaseBar(const double open_value,
                              const double high_value,
                              const double low_value,
                              const double close_value)
  {
   return (open_value > 0.0 && high_value > 0.0 &&
           low_value > 0.0 && close_value > 0.0 &&
           MathIsValidNumber(open_value) &&
           MathIsValidNumber(high_value) &&
           MathIsValidNumber(low_value) &&
           MathIsValidNumber(close_value) &&
           high_value >= low_value &&
           open_value <= high_value && open_value >= low_value &&
           close_value <= high_value && close_value >= low_value);
  }

void Strategy_PrepareEventSignal()
  {
   Strategy_ClearSignal();

   const datetime decision_bar =
      iTime(_Symbol, PERIOD_M1, 0); // perf-allowed: one new-bar event anchor.
   if(decision_bar <= 0 ||
      Strategy_NYDayOfWeek(decision_bar) != 3 ||
      Strategy_NYHhmm(decision_bar) != strategy_decision_hhmm_ny)
      return;

   const int day_key = Strategy_NYDayKey(decision_bar);
   if(day_key <= 0 || day_key == g_last_attempt_day_key)
      return;

   // Consume before history, signal, news, spread, quote, ATR, sizing, or
   // submission. A blocked or failed attempt cannot retry this New York date.
   if(!Strategy_RecordAttemptState(day_key))
      return;
   if(Strategy_DayAlreadyEntered(day_key))
      return;

   const datetime now = TimeCurrent();
   const long opening_delay = (long)(now - decision_bar);
   if(opening_delay < 0 ||
      opening_delay >= (long)strategy_entry_grace_seconds ||
      Strategy_NYSecond(now) < 0 ||
      Strategy_NYSecond(now) >= strategy_entry_grace_seconds)
      return;

   const datetime release_bar =
      iTime(_Symbol, PERIOD_M1, 1); // perf-allowed: exact completed event bar.
   if(release_bar <= 0 || decision_bar - release_bar != 60 ||
      Strategy_NYDayKey(release_bar) != day_key ||
      Strategy_NYHhmm(release_bar) != strategy_release_hhmm_ny)
      return;

   const double release_open =
      iOpen(_Symbol, PERIOD_M1, 1); // perf-allowed: one fixed completed bar.
   const double release_high =
      iHigh(_Symbol, PERIOD_M1, 1); // perf-allowed: one fixed completed bar.
   const double release_low =
      iLow(_Symbol, PERIOD_M1, 1); // perf-allowed: one fixed completed bar.
   const double release_close =
      iClose(_Symbol, PERIOD_M1, 1); // perf-allowed: one fixed completed bar.
   if(!Strategy_ValidReleaseBar(release_open,
                                release_high,
                                release_low,
                                release_close) ||
      !(release_close < release_open))
      return;

   const double atr =
      QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period_m1, 1);
   if(atr <= 0.0 || !MathIsValidNumber(atr))
      return;

   g_signal_day_key = day_key;
   g_signal_atr = atr;
   g_entry_ready = true;
  }

void Strategy_ManageOwnedPositions()
  {
   const int magic_count = Strategy_MagicPositionCount();
   if(magic_count <= 0)
      return;

   const datetime now = TimeCurrent();
   const int now_day_key = Strategy_NYDayKey(now);
   const int now_hhmm = Strategy_NYHhmm(now);
   const long max_hold_seconds =
      (long)MathMax(1, strategy_max_hold_minutes) * 60L;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsMagicPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int opened_day_key = Strategy_NYDayKey(opened);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);

      bool should_close =
         (magic_count != 1 || symbol != _Symbol ||
          position_type != POSITION_TYPE_SELL ||
          opened <= 0 || opened > now || opened_day_key <= 0 ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= 0.0 || !MathIsValidNumber(stop_price));

      if(!should_close &&
         (now_day_key <= 0 || opened_day_key != now_day_key))
         should_close = true;
      if(!should_close && now_hhmm >= strategy_flat_hhmm_ny)
         should_close = true;
      if(!should_close && (long)(now - opened) >= max_hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_SELL;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "WTI_EIA_NEGDRIFT_M1_SHORT";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(!g_entry_ready || g_signal_day_key <= 0 ||
      g_signal_day_key != g_last_attempt_day_key ||
      g_signal_atr <= 0.0 || !MathIsValidNumber(g_signal_atr) ||
      Strategy_HasManagedPosition())
      return false;

   MqlTick tick;
   ZeroMemory(tick);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(!SymbolInfoTick(_Symbol, tick) ||
      tick.bid <= 0.0 || tick.ask <= 0.0 ||
      !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      tick.ask < tick.bid || point <= 0.0 || !MathIsValidNumber(point))
      return false;

   const double spread_points = (tick.ask - tick.bid) / point;
   if(!MathIsValidNumber(spread_points) || spread_points < 0.0 ||
      spread_points > (double)strategy_max_spread_points)
      return false;

   const double entry_price = tick.bid;
   request.sl = QM_StopATRFromValue(_Symbol,
                                    QM_SELL,
                                    entry_price,
                                    g_signal_atr,
                                    strategy_atr_stop_multiple);
   request.sl = QM_StopRulesNormalizePrice(_Symbol, request.sl);
   if(request.sl <= entry_price || !MathIsValidNumber(request.sl))
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_ManageOwnedPositions();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!SymbolSelect("XTIUSD.DWX", true) ||
      !Strategy_IsHostChart() || !Strategy_InputsValid())
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_M1,
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved card keeps framework Friday close enabled; planned WTI event hold is four minutes"))
      return INIT_FAILED;

   g_attempt_state_key =
      StringFormat("QM5_41242_WTI_EIA_NEGDRIFT_DAY_ATTEMPT_%d",
                   QM_FrameworkMagic());
   const datetime reference_time =
      iTime(_Symbol, PERIOD_M1, 0); // perf-allowed: one-time state reference.
   Strategy_LoadAttemptState(
      (reference_time > 0) ? reference_time : TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = "XTIUSD.DWX";
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols, PERIOD_M1, 64);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41242\",\"ea\":\"wti-eia-negdrift-m1\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO,
               "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(!Strategy_IsHostChart())
      return;

   const bool new_bar = QM_IsNewBar(_Symbol, PERIOD_M1);
   Strategy_ClearSignal();
   if(new_bar)
      QM_EquityStreamOnNewBar();

   // Repair and timed exits precede all entry-only gates.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;
   if(!new_bar || Strategy_NoTradeFilter())
      return;

   Strategy_PrepareEventSignal();
   if(!g_entry_ready)
      return;

   QM_EntryRequest request;
   ZeroMemory(request);
   if(!Strategy_EntrySignal(request))
      return;

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

   ulong out_ticket = 0;
   QM_TM_OpenPosition(request, out_ticket);
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
