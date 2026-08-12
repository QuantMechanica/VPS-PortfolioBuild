#property strict
#property version   "5.0"
#property description "QM5_20117 WTI Thursday-surge Friday lag reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20117 - WTI Thursday-Surge Friday Lag Reversal
// -----------------------------------------------------------------------------
// Source-bounded D1 energy seasonality:
//   - require a completed Thursday WTI log return of at least 4.5%
//   - sell once at the first executable Friday D1 tick
//   - flatten at Friday close; non-Friday and three-day exits are stale guards
// A broker week is consumed before fallible signal/news/execution checks.
// Runtime uses native MT5 OHLC and broker calendar only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20117;
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
input double strategy_min_thu_log_return_pct = 4.5;
input int    strategy_entry_grace_minutes    = 5;
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 3.0;
input int    strategy_max_hold_days           = 3;
input int    strategy_max_spread_points       = 1000;

bool     g_entry_ready = false;
int      g_signal_day_key = 0;
double   g_signal_thursday_log_return_pct = 0.0;
int      g_last_attempt_day_key = 0;
string   g_attempt_state_key = "";

bool Strategy_IsHostChart()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return -1;
   return parts.day_of_week;
  }

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_DayStart(const int day_key)
  {
   if(day_key < 19000101)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = day_key / 10000;
   parts.mon = (day_key / 100) % 100;
   parts.day = day_key % 100;
   return StructToTime(parts);
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

bool Strategy_HasOpenPosition()
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
      if(Strategy_DayKey(opened) == day_key)
         return true;
     }

   const datetime day_start = Strategy_DayStart(day_key);
   if(day_start <= 0 || !HistorySelect(day_start, TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_DayKey(deal_time) == day_key)
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

   const int current_day_key = Strategy_DayKey(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_day_key = (int)MathRound(stored);
   if(current_day_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_day_key >= 19000101 &&
      stored_day_key <= current_day_key)
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

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 20117 &&
           qm_magic_slot_offset == 0 &&
           MathAbs(strategy_min_thu_log_return_pct - 4.5) <= 1.0e-12 &&
           strategy_entry_grace_minutes == 5 &&
           strategy_atr_period == 20 &&
           MathAbs(strategy_atr_sl_mult - 3.0) <= 1.0e-12 &&
           strategy_max_hold_days == 3 &&
           strategy_max_spread_points == 1000 &&
           qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21);
  }

bool Strategy_NoTradeFilter()
  {
   return (!Strategy_IsHostChart() || !Strategy_InputsValid());
  }

bool Strategy_LoadThursdaySurge(const datetime friday_time,
                                double &thursday_log_return_pct)
  {
   thursday_log_return_pct = 0.0;
   const datetime thursday_time =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: three-bar D1 calendar check on a genuine new bar.
   const datetime wednesday_time =
      iTime(_Symbol, PERIOD_D1, 2); // perf-allowed: three-bar D1 calendar check on a genuine new bar.
   const double thursday_close =
      iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: bounded source return on a genuine new bar.
   const double wednesday_close =
      iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: bounded source return on a genuine new bar.

   if(friday_time <= 0 || thursday_time <= 0 || wednesday_time <= 0)
      return false;
   if(Strategy_DayOfWeek(friday_time) != 5 ||
      Strategy_DayOfWeek(thursday_time) != 4 ||
      Strategy_DayOfWeek(wednesday_time) != 3)
      return false;
   if(thursday_close <= 0.0 || wednesday_close <= 0.0 ||
      !MathIsValidNumber(thursday_close) ||
      !MathIsValidNumber(wednesday_close))
      return false;

   thursday_log_return_pct =
      100.0 * MathLog(thursday_close / wednesday_close);
   return MathIsValidNumber(thursday_log_return_pct);
  }

void Strategy_AdvanceFridayState()
  {
   g_entry_ready = false;
   g_signal_day_key = 0;
   g_signal_thursday_log_return_pct = 0.0;

   const datetime friday_time =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: new-bar Friday decision anchor.
   if(friday_time <= 0 || Strategy_DayOfWeek(friday_time) != 5)
      return;

   const int day_key = Strategy_DayKey(friday_time);
   if(day_key <= 0 || day_key == g_last_attempt_day_key)
      return;

   // Consume the Friday before history, signal, news, spread, ATR, price, or
   // order checks. Rejection, stop, restart, or a blocked gate cannot retry.
   if(!Strategy_RecordAttemptState(day_key))
      return;
   if(Strategy_DayAlreadyEntered(day_key))
      return;

   const long opening_delay = (long)(TimeCurrent() - friday_time);
   if(opening_delay < 0 ||
      opening_delay > (long)strategy_entry_grace_minutes * 60)
      return;

   double thursday_log_return_pct = 0.0;
   if(!Strategy_LoadThursdaySurge(friday_time,
                                  thursday_log_return_pct))
      return;
   if(thursday_log_return_pct + 1.0e-12 <
      strategy_min_thu_log_return_pct)
      return;

   g_signal_day_key = day_key;
   g_signal_thursday_log_return_pct = thursday_log_return_pct;
   g_entry_ready = true;
  }

void Strategy_CloseExpiredPositions()
  {
   const datetime now = TimeCurrent();
   const datetime current_d1_bar =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: O(1) D1 stale-exit calendar gate.
   const int current_dow =
      (current_d1_bar > 0) ?
      Strategy_DayOfWeek(current_d1_bar) :
      Strategy_DayOfWeek(now);
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = (current_dow != 5);
      if(opened <= 0 || (long)(now - opened) >= hold_seconds)
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
   request.reason = "QM5_20117_WTI_FRI_LAGREV";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(!g_entry_ready ||
      g_signal_day_key <= 0 ||
      g_signal_day_key != g_last_attempt_day_key ||
      g_signal_thursday_log_return_pct + 1.0e-12 <
         strategy_min_thu_log_return_pct ||
      Strategy_HasOpenPosition())
      return false;

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(request.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   request.sl = QM_StopATRFromValue(_Symbol,
                                    request.type,
                                    entry_price,
                                    atr_last,
                                    strategy_atr_sl_mult);
   request.sl = QM_StopRulesNormalizePrice(_Symbol, request.sl);
   if(request.sl <= entry_price || !MathIsValidNumber(request.sl))
      return false;

   request.reason = "WTI_THU_SURGE_FRI_LAGREV_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseExpiredPositions();
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
   if(!Strategy_IsHostChart() || !Strategy_InputsValid())
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

   g_attempt_state_key =
      StringFormat("QM5_20117_FRI_ATTEMPT_%d",
                   QM_FrameworkMagic());
   const datetime reference_time =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one-time restart-state reference.
   Strategy_LoadAttemptState(
      (reference_time > 0) ? reference_time : TimeCurrent());

   string symbols[1] = {"XTIUSD.DWX"};
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_D1, 32);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20117\",\"ea\":\"wti-fri-lagrev\"}");
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
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_entry_ready = false;
   if(new_bar)
     {
      QM_EquityStreamOnNewBar();
      // Consume and derive the Friday state before fallible news/order gates.
      Strategy_AdvanceFridayState();
     }

   // Lifecycle exits always precede entry-only news checks.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      return;
   if(!new_bar || !g_entry_ready)
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows =
         QM_NewsAllowsTrade2(_Symbol,
                             broker_now,
                             qm_news_temporal,
                             qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol,
                            broker_now,
                            qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest request;
   ZeroMemory(request);
   if(Strategy_EntrySignal(request))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(request, out_ticket);
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
