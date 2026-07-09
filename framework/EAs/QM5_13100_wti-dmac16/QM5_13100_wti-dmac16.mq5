#property strict
#property version   "5.0"
#property description "QM5_13100 WTI monthly 1/6 DMAC neutral-band trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13100 - WTI Monthly 1/6 DMAC Neutral-Band Trend
// -----------------------------------------------------------------------------
// Source-exact monthly commodity trend state:
//   - STMA = latest completed month-end XTI close
//   - LTMA = arithmetic mean of six completed month-end closes
//   - long above LTMA +2.5%, short below LTMA -2.5%, flat inside the band
//   - ATR hard stop is the only V5 risk-contract addition
// Runtime is Darwinex-native: MT5 OHLC, ATR, spread, calendar, framework state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 13100;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_long_months          = 6;
input double strategy_band_pct             = 2.5;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 4.0;
input int    strategy_max_spread_points     = 1500;

int g_last_entry_month_key = 0;
int g_candidate_month_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const int current_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_key <= 0 || prior_key <= 0)
      return false;
   return current_key != prior_key;
  }

bool Strategy_LoadDmacState(double &short_value,
                            double &long_mean,
                            int &target_state)
  {
   short_value = 0.0;
   long_mean = 0.0;
   target_state = 0;

   const int months = MathMax(2, strategy_long_months);
   double closes[];
   ArrayResize(closes, months);

   // Reconstruct month-end values from D1 because .DWX MN1 bars are not
   // guaranteed to be materialized in every tester. Shift 1 is the most recent
   // completed D1 close; the first close seen for each older calendar-month key
   // is therefore that month's final completed D1 close.
   int collected = 0;
   int last_month_key = 0;
   const int scan_limit = months * 35 + 20;
   for(int shift = 1; shift <= scan_limit && collected < months; ++shift)
     {
      const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, shift); // perf-allowed: bounded D1 calendar scan once per month.
      if(month_key <= 0 || month_key == last_month_key)
         continue;

      const double month_end_close = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: at most strategy_long_months D1 reads once per month.
      if(month_end_close <= 0.0 || !MathIsValidNumber(month_end_close))
         return false;

      closes[collected] = month_end_close;
      ++collected;
      last_month_key = month_key;
     }

   if(collected < months)
      return false;

   double total = 0.0;
   for(int i = 0; i < months; ++i)
     {
      if(closes[i] <= 0.0 || !MathIsValidNumber(closes[i]))
         return false;
      total += closes[i];
     }

   short_value = closes[0];
   long_mean = total / (double)months;
   if(long_mean <= 0.0 || !MathIsValidNumber(long_mean))
      return false;

   const double band = MathMax(0.0, strategy_band_pct) / 100.0;
   const double upper = long_mean * (1.0 + band);
   const double lower = long_mean * (1.0 - band);

   if(short_value > upper)
      target_state = 1;
   else if(short_value < lower)
      target_state = -1;
   else
      target_state = 0;

   return true;
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

int Strategy_PositionState(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return 0;
   const long position_type = PositionGetInteger(POSITION_TYPE);
   if(position_type == POSITION_TYPE_BUY)
      return 1;
   if(position_type == POSITION_TYPE_SELL)
      return -1;
   return 0;
  }

void Strategy_CloseOpposedOrNeutralPositions()
  {
   if(!Strategy_IsMonthlyRebalanceBar())
      return;

   double short_value = 0.0;
   double long_mean = 0.0;
   int target_state = 0;
   if(!Strategy_LoadDmacState(short_value, long_mean, target_state))
      return;

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

      const int position_state = Strategy_PositionState(ticket);
      if(target_state == 0 || position_state != target_state)
         QM_TM_ClosePosition(ticket,
                             target_state == 0 ? QM_EXIT_STRATEGY : QM_EXIT_OPPOSITE_SIGNAL);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_long_months < 2 || strategy_long_months > 24)
      return true;
   if(strategy_band_pct <= 0.0 || strategy_band_pct >= 25.0)
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13100_WTI_DMAC16";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_candidate_month_key = 0;

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double short_value = 0.0;
   double long_mean = 0.0;
   int target_state = 0;
   if(!Strategy_LoadDmacState(short_value, long_mean, target_state))
      return false;
   if(target_state == 0)
      return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   req.type = (target_state > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.reason = (target_state > 0) ? "WTI_DMAC16_MONTHLY_LONG" :
                                     "WTI_DMAC16_MONTHLY_SHORT";
   g_candidate_month_key = month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpposedOrNeutralPositions();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13100\",\"ea\":\"wti-dmac16\"}");
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

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket) && out_ticket > 0)
         g_last_entry_month_key = g_candidate_month_key;
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
