#property strict
#property version   "5.0"
#property description "QM5_12759 WTI ETF Roll-Relief Rebound"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12759 - WTI ETF Roll-Relief Rebound
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - confirms same-month early ETF roll pressure during trading days 5-9
//   - buys only in the post-pressure relief window after D1 reclaim above SMA
//   - exits at relief-window end, trend failure, month change, or max hold
// Runtime uses MT5 OHLC/broker calendar only; no ETF feed, futures curve, CFTC
// feed, COT data, API, CSV, or external roll schedule.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12759;
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
input int    strategy_pressure_start_trading_day = 5;
input int    strategy_pressure_end_trading_day   = 9;
input int    strategy_relief_start_trading_day   = 10;
input int    strategy_relief_end_trading_day     = 14;
input double strategy_min_pressure_return_pct    = 0.10;
input double strategy_min_reclaim_return_pct     = 0.10;
input int    strategy_trend_period               = 20;
input int    strategy_atr_period                 = 20;
input double strategy_atr_sl_mult                = 2.50;
input int    strategy_max_hold_days              = 5;
input int    strategy_max_spread_points          = 1000;

int g_last_entry_month_key = 0;
int g_last_managed_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

// Position-lifecycle bookkeeping only (POSITION_TIME is a real broker
// timestamp, not a bar shift QM_CalendarPeriodKey can look up).
int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

// Ordinal count of D1 trading days from the start of `target_shift`'s
// calendar month through `target_shift`, inclusive. Built entirely on
// QM_CalendarPeriodKey (never raw iTime) per framework-corset rules.
int Strategy_TradingDayOfMonth(const int target_shift)
  {
   const int target_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, target_shift);
   const int target_day_key   = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, target_shift);
   if(target_month_key <= 0 || target_day_key <= 0)
      return 0;

   int count = 0;
   for(int shift = 0; shift < 80; ++shift)
     {
      const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, shift);
      if(month_key <= 0 || month_key < target_month_key)
         break;
      if(month_key != target_month_key)
         continue;

      const int day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, shift);
      if(day_key > 0 && day_key <= target_day_key)
         ++count;
     }

   return count;
  }

bool Strategy_InPressureWindow(const int shift)
  {
   const int td = Strategy_TradingDayOfMonth(shift);
   return (td >= strategy_pressure_start_trading_day && td <= strategy_pressure_end_trading_day);
  }

bool Strategy_InReliefWindow(const int shift)
  {
   const int td = Strategy_TradingDayOfMonth(shift);
   return (td >= strategy_relief_start_trading_day && td <= strategy_relief_end_trading_day);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

bool Strategy_LoadClosedState(double &close_last,
                              double &close_prev,
                              double &return_pct,
                              double &sma_last)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 2, rates) < 2) // perf-allowed: prior D1 relief-reclaim confirmation state, new-bar gated.
      return false;

   close_last = rates[0].close;
   close_prev = rates[1].close;
   if(close_last <= 0.0 || close_prev <= 0.0)
      return false;

   return_pct = ((close_last / close_prev) - 1.0) * 100.0;
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(sma_last <= 0.0)
      return false;

   return MathIsValidNumber(return_pct);
  }

bool Strategy_HadPressureInCurrentMonth()
  {
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(current_month_key <= 0)
      return false;

   for(int shift = 1; shift < 80; ++shift)
     {
      const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, shift);
      if(month_key <= 0 || month_key < current_month_key)
         break;
      if(month_key != current_month_key)
         continue;
      if(!Strategy_InPressureWindow(shift))
         continue;

      const double close_bar = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: closed D1 pressure bar, same-symbol only.
      const double close_prev = iClose(_Symbol, PERIOD_D1, shift + 1); // perf-allowed: closed D1 pressure return, same-symbol only.
      if(close_bar <= 0.0 || close_prev <= 0.0)
         continue;

      const double pressure_return_pct = ((close_bar / close_prev) - 1.0) * 100.0;
      if(!MathIsValidNumber(pressure_return_pct))
         continue;

      const double sma_bar = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, shift, PRICE_CLOSE);
      if(sma_bar <= 0.0)
         continue;

      if(pressure_return_pct <= -strategy_min_pressure_return_pct && close_bar < sma_bar)
         return true;
     }

   return false;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int current_td = Strategy_TradingDayOfMonth(0);
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const bool in_relief_window = Strategy_InReliefWindow(0);

   double close_last = 0.0;
   double close_prev = 0.0;
   double return_pct = 0.0;
   double sma_last = 0.0;
   const bool have_state = Strategy_LoadClosedState(close_last, close_prev, return_pct, sma_last);

   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int opened_month_key = Strategy_MonthKey(opened);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(!in_relief_window || current_td > strategy_relief_end_trading_day)
         should_close = true;
      if(opened_month_key > 0 && current_month_key > 0 && opened_month_key != current_month_key)
         should_close = true;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;
      if(pos_type != POSITION_TYPE_BUY)
         should_close = true;
      if(have_state && pos_type == POSITION_TYPE_BUY && close_last < sma_last)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_pressure_start_trading_day < 1 || strategy_pressure_end_trading_day < strategy_pressure_start_trading_day)
      return true;
   if(strategy_relief_start_trading_day <= strategy_pressure_end_trading_day)
      return true;
   if(strategy_relief_end_trading_day < strategy_relief_start_trading_day || strategy_relief_end_trading_day > 23)
      return true;
   if(strategy_min_pressure_return_pct <= 0.0 || strategy_min_reclaim_return_pct <= 0.0)
      return true;
   if(strategy_trend_period <= 1 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12759_WTI_ROLL_RELIEF";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   if(!Strategy_InReliefWindow(0))
      return false;

   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(current_month_key <= 0 || current_month_key == g_last_entry_month_key)
      return false;
   if(!Strategy_HadPressureInCurrentMonth())
      return false;

   double close_last = 0.0;
   double close_prev = 0.0;
   double return_pct = 0.0;
   double sma_last = 0.0;
   if(!Strategy_LoadClosedState(close_last, close_prev, return_pct, sma_last))
      return false;
   if(return_pct < strategy_min_reclaim_return_pct)
      return false;
   if(close_last <= sma_last)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "WTI_ETF_ROLL_RELIEF_LONG";
   g_last_entry_month_key = current_month_key;
   return true;
  }

// Management is invoked unconditionally every tick (canonical OnTick order
// keeps risk management above the news gate), but the actual D1-close-driven
// exit evaluation only needs to run once per new calendar day. Gating on
// QM_CalendarPeriodKey (not QM_IsNewBar) avoids double-consuming the
// single-use new-bar edge that OnTick still needs for the entry gate.
void Strategy_ManageOpenPosition()
  {
   const int today_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(today_key <= 0 || today_key == g_last_managed_day_key)
      return;
   g_last_managed_day_key = today_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12759\",\"ea\":\"wti-roll-relief\"}");
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

   // Canonical order (2026-07-02 audit finding): management/exit run ABOVE
   // the news gate so risk handling never suspends during news windows.
   // Management self-gates to once-per-day via QM_CalendarPeriodKey, so
   // calling it unconditionally here does not blow the smoke perf budget.
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
