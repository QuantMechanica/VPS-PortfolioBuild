#property strict
#property version   "5.0"
#property description "QM5_1583 Alpha Architect SMA10M plus 4-month return timing"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1583 — Alpha Architect SMA10M plus 4-Month Return Timing
// -----------------------------------------------------------------------------
// Approved-card mechanics, evaluated once at each new broker calendar month:
//   * close above the 10-month SMA AND 4-month return > 0 -> 100% risk budget
//   * exactly one signal positive                         ->  50% risk budget
//   * neither signal positive                            ->   0% (flat/cash)
//
// .DWX tester symbols do not reliably expose MN1 bars. The EA therefore scans
// a bounded, closed D1 history once per monthly rebalance and extracts exact
// completed-month endpoints. It never substitutes a rolling 210-day average
// for the card's month-end observations.
//
// A monthly rebalance closes any existing strategy position and, when the new
// target is positive, reopens it at the target risk fraction on the same bar.
// This makes the 100/50/0 ladder restart-safe without inferring the old target
// from broker-quantized position volume. The fixed 3 x ATR(20,D1) stop is the
// only intra-month strategy exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1583;
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
// Monthly positions intentionally span weekends; liquidation is signal-led.
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_months           = 10;
input int    strategy_return_months        = 4;
input int    strategy_min_daily_bars       = 220;
input int    strategy_min_monthly_closes   = 11;
input int    strategy_history_daily_bars   = 320;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_spread_points    = 0;

#define QM5_1583_SYMBOL_COUNT 13

int g_last_rebalance_key = 0;

string Strategy_SymbolForSlot(const int slot)
  {
   if(slot == 0)  return "GDAXI.DWX";
   if(slot == 1)  return "NDX.DWX";
   if(slot == 2)  return "SP500.DWX";
   if(slot == 3)  return "UK100.DWX";
   if(slot == 4)  return "WS30.DWX";
   if(slot == 5)  return "XAUUSD.DWX";
   if(slot == 6)  return "EURUSD.DWX";
   if(slot == 7)  return "GBPUSD.DWX";
   if(slot == 8)  return "USDJPY.DWX";
   if(slot == 9)  return "USDCHF.DWX";
   if(slot == 10) return "AUDUSD.DWX";
   if(slot == 11) return "USDCAD.DWX";
   if(slot == 12) return "NZDUSD.DWX";
   return "";
  }

bool Strategy_SymbolSlotAllowed()
  {
   return (qm_magic_slot_offset >= 0 &&
           qm_magic_slot_offset < QM5_1583_SYMBOL_COUNT &&
           _Symbol == Strategy_SymbolForSlot(qm_magic_slot_offset));
  }

bool Strategy_ParametersValid()
  {
   if(strategy_sma_months < 2 || strategy_return_months < 1)
      return false;
   if(strategy_min_daily_bars < 220 || strategy_min_monthly_closes < 11)
      return false;
   if(strategy_history_daily_bars < strategy_min_daily_bars)
      return false;
   if(strategy_min_monthly_closes < strategy_sma_months ||
      strategy_min_monthly_closes < strategy_return_months + 1)
      return false;
   if(strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(strategy_max_spread_points < 0)
      return false;
   return true;
  }

int Strategy_MonthKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PreviousMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;
   --month;
   if(month == 0)
     {
      --year;
      month = 12;
     }
   return year * 100 + month;
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

bool Strategy_CloseOurPositions()
  {
   const int magic = QM_FrameworkMagic();
   bool all_closed = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
         all_closed = false;
     }
   return (all_closed && !Strategy_HasOpenPosition());
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   return (spread_points <= strategy_max_spread_points);
  }

// Collect exact completed-month D1 endpoints, newest first. ArraySetAsSeries
// makes rates[0] the latest CLOSED D1 bar because CopyRates starts at shift 1.
bool Strategy_LoadMonthlyCloses(double &monthly_closes[])
  {
   int required = strategy_min_monthly_closes;
   if(strategy_sma_months > required)
      required = strategy_sma_months;
   if(strategy_return_months + 1 > required)
      required = strategy_return_months + 1;

   if(Bars(_Symbol, PERIOD_D1) <= strategy_min_daily_bars)
      return false;
   if(ArrayResize(monthly_closes, required) != required)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded month-end scan behind the monthly D1 new-bar gate.
                                PERIOD_D1,
                                1,
                                strategy_history_daily_bars,
                                rates);
   if(copied < strategy_min_daily_bars)
      return false;

   int count = 0;
   int newest_seen_month = 0;
   for(int index = 0; index < copied && count < required; ++index)
     {
      if(rates[index].time <= 0 || rates[index].close <= 0.0 ||
         !MathIsValidNumber(rates[index].close))
         return false;
      if(index > 0 && rates[index - 1].time <= rates[index].time)
         return false;

      const int month_key = Strategy_MonthKey(rates[index].time);
      if(month_key <= 0)
         return false;
      if(month_key == newest_seen_month)
         continue;

      if(newest_seen_month > 0 &&
         month_key != Strategy_PreviousMonthKey(newest_seen_month))
         return false;

      // The first (newest) bar encountered for a month is its exact endpoint.
      monthly_closes[count] = rates[index].close;
      ++count;
      newest_seen_month = month_key;
     }

   return (count == required);
  }

bool Strategy_TargetExposure(double &target_exposure,
                             bool &sma_positive,
                             bool &return_positive,
                             double &recent_close,
                             double &sma_value,
                             double &return_value)
  {
   target_exposure = 0.0;
   sma_positive = false;
   return_positive = false;
   recent_close = 0.0;
   sma_value = 0.0;
   return_value = 0.0;

   double monthly_closes[];
   if(!Strategy_LoadMonthlyCloses(monthly_closes))
      return false;

   recent_close = monthly_closes[0];
   double sum = 0.0;
   for(int i = 0; i < strategy_sma_months; ++i)
      sum += monthly_closes[i];
   sma_value = sum / (double)strategy_sma_months;

   const double return_base = monthly_closes[strategy_return_months];
   if(recent_close <= 0.0 || sma_value <= 0.0 || return_base <= 0.0 ||
      !MathIsValidNumber(sma_value))
      return false;
   return_value = (recent_close / return_base) - 1.0;
   if(!MathIsValidNumber(return_value))
      return false;

   sma_positive = (recent_close > sma_value);
   return_positive = (return_value > 0.0);
   if(sma_positive && return_positive)
      target_exposure = 1.0;
   else if(sma_positive || return_positive)
      target_exposure = 0.5;
   return true;
  }

bool Strategy_ConfigureRiskForExposure(const double exposure)
  {
   const double weight = PORTFOLIO_WEIGHT * exposure;
   if(weight <= 0.0 || weight > 1.0)
      return false;

   const QM_RiskMode mode = (RISK_FIXED > 0.0)
                            ? QM_RISK_MODE_FIXED
                            : QM_RISK_MODE_PERCENT;
   const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
   return QM_RiskSizerConfigure(mode,
                                RISK_PERCENT,
                                RISK_FIXED,
                                weight,
                                risk_cap_money);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_ParametersValid() || !Strategy_SymbolSlotAllowed())
      return true;
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

   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(current_month_key <= 0 || current_month_key == g_last_rebalance_key)
      return false;

   // Consume the monthly decision before fallible history/spread/order gates.
   // A failed rebalance cannot retry later in the same month with different data.
   g_last_rebalance_key = current_month_key;

   double target_exposure = 0.0;
   bool sma_positive = false;
   bool return_positive = false;
   double recent_close = 0.0;
   double sma_value = 0.0;
   double return_value = 0.0;
   const bool signal_ready = Strategy_TargetExposure(target_exposure,
                                                       sma_positive,
                                                       return_positive,
                                                       recent_close,
                                                       sma_value,
                                                       return_value);
   QM_LogEvent(signal_ready ? QM_INFO : QM_WARN,
               "MONTHLY_ALLOCATION_STATE",
               StringFormat("{\"month\":%d,\"ready\":%s,\"close\":%.10f,\"sma10m\":%.10f,\"return4m\":%.10f,\"sma_positive\":%s,\"return_positive\":%s,\"target\":%.1f}",
                            current_month_key,
                            signal_ready ? "true" : "false",
                            recent_close,
                            sma_value,
                            return_value,
                            sma_positive ? "true" : "false",
                            return_positive ? "true" : "false",
                            target_exposure));
   if(!signal_ready)
      return false;

   // Reconcile at every monthly decision. Close-then-reopen gives exact target
   // sizing even after an EA restart or broker volume quantization.
   if(Strategy_HasOpenPosition() && !Strategy_CloseOurPositions())
      return false;
   if(target_exposure <= 0.0)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_ConfigureRiskForExposure(target_exposure))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_value = QM_ATR(_Symbol,
                                   PERIOD_D1,
                                   strategy_atr_period,
                                   1);
   if(entry <= 0.0 || atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol,
                                QM_BUY,
                                entry,
                                atr_value,
                                strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.tp = 0.0;
   req.reason = (target_exposure >= 1.0)
                ? "AA_SMA10M_TR4_FULL"
                : "AA_SMA10M_TR4_HALF";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card authorizes only the fixed initial ATR stop and monthly rebalance.
  }

bool Strategy_ExitSignal()
  {
   // Monthly close/resize is centralized in Strategy_EntrySignal so the
   // replacement entry can be sent on the same rebalance bar.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework's mandatory two-axis news blackout
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

   if(!Strategy_ParametersValid() || !Strategy_SymbolSlotAllowed())
     {
      QM_LogEvent(QM_ERROR,
                  "INIT_REJECTED",
                  "{\"reason\":\"invalid_parameters_or_symbol_slot\"}");
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   // Mid-month initialization waits for the next month. On the first D1 bar
   // of a month, shift 1 still belongs to the previous month and the rebalance
   // remains due.
   g_last_rebalance_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"card\":\"QM5_1583\",\"last_rebalance_key\":%d}",
                            g_last_rebalance_key));
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

   // Management and strategy exits remain available through news windows.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOurPositions();
     }

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
