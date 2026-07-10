#property strict
#property version   "5.0"
#property description "QM5_13116 XNG Monthly Return-Sign Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13116 - Natural-Gas Return-Sign Momentum
// -----------------------------------------------------------------------------
// Peer-reviewed Papailias-Liu-Thomakos RSM carrier:
//   - first XNG D1 bar of each broker month only
//   - reconstruct the prior 12 completed monthly return signs
//   - long when the non-negative sign share is >= 0.40, short otherwise
//   - renew monthly; frozen ATR hard stop and 35-day stale guard
// Runtime is Darwinex MT5-native: D1 OHLC, ATR, spread, calendar, positions.
// No magnitude-momentum, RSI, adaptive threshold, external feed, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 13116;
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
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months      = 12;
input double strategy_positive_threshold   = 0.40;
input int    strategy_history_bars          = 500;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.5;
input int    strategy_max_hold_days         = 35;
input int    strategy_max_spread_points     = 3000;

int g_last_attempt_month_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int previous_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month <= 0 || previous_month <= 0)
      return false;
   return current_month != previous_month;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_LoadPositiveProbability(double &probability, int &positive_count)
  {
   probability = 0.0;
   positive_count = 0;

   const int needed_closes = strategy_lookback_months + 1;
   if(needed_closes < 3)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int requested = MathMax(strategy_history_bars, needed_closes * 24);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: bounded D1 month-end reconstruction behind monthly new-bar gate.
   if(copied <= 0)
      return false;

   double month_closes[];
   ArrayResize(month_closes, needed_closes);
   int close_count = 0;
   int previous_key = 0;

   // rates[0] is the most recent completed D1 bar. The first bar encountered
   // for each distinct month is therefore that month's completed month-end close.
   for(int index = 0; index < copied && close_count < needed_closes; ++index)
     {
      const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, index + 1);
      const double close_value = rates[index].close;
      if(month_key <= 0 || close_value <= 0.0 || !MathIsValidNumber(close_value))
         continue;
      if(month_key == previous_key)
         continue;
      month_closes[close_count] = close_value;
      ++close_count;
      previous_key = month_key;
     }

   if(close_count < needed_closes)
      return false;

   for(int index = 0; index < strategy_lookback_months; ++index)
     {
      const double newer_close = month_closes[index];
      const double older_close = month_closes[index + 1];
      if(newer_close <= 0.0 || older_close <= 0.0)
         return false;
      // The source's binary sign is 1 for a non-negative monthly return.
      if(newer_close >= older_close)
         ++positive_count;
     }

   probability = (double)positive_count / (double)strategy_lookback_months;
   return MathIsValidNumber(probability) && probability >= 0.0 && probability <= 1.0;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const bool month_changed = Strategy_IsMonthlyRebalanceBar();
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = month_changed;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_lookback_months != 12)
      return true;
   if(strategy_positive_threshold <= 0.0 || strategy_positive_threshold >= 1.0)
      return true;
   if(strategy_history_bars < 300 || strategy_history_bars > 1000)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   if(strategy_max_spread_points <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13116_XNG_SIGNMOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0 || month_key == g_last_attempt_month_key)
      return false;
   g_last_attempt_month_key = month_key;

   if(Strategy_HasOpenPosition())
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 || spread_points > strategy_max_spread_points)
      return false;

   double positive_probability = 0.0;
   int positive_count = 0;
   if(!Strategy_LoadPositiveProbability(positive_probability, positive_count))
      return false;

   const int direction = (positive_probability >= strategy_positive_threshold) ? 1 : -1;
   req.type = (direction > 0) ? QM_BUY : QM_SELL;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price,
                                atr_last, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;

   req.reason = StringFormat("XNG_SIGNMOM_%s_P%02d_OF_%02d",
                             direction > 0 ? "LONG" : "SHORT",
                             positive_count,
                             strategy_lookback_months);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13116\",\"ea\":\"xng-signmom\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   // Monthly and stale exits are never blocked by an entry-news blackout.
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
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
