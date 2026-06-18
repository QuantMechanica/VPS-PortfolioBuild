#property strict
#property version   "5.0"
#property description "QM5_1098 Unger S&P Pivot-Point Trend Following"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1098;
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
input int    strategy_entry_hhmm_ny        = 1030;
input int    strategy_cash_open_hhmm_ny    = 930;
input int    strategy_cash_close_hhmm_ny   = 1600;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 1.5;
input bool   strategy_use_rr_tp            = false;
input double strategy_rr_tp                = 2.0;
input double strategy_median_spread_points = 0.0;
input int    strategy_pivot_scan_bars      = 160;

double g_cached_r1 = 0.0;
double g_cached_s1 = 0.0;
int    g_pivot_cache_day_key = 0;
int    g_entry_eval_day_key = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): central news is handled by the framework;
// this hook blocks only weekends/out-of-session entries and a nonzero spread cap.
bool Strategy_NoTradeFilter()
  {
   bool has_position = false;
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
      has_position = true;
      break;
     }

   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const datetime ny_now = utc_now + ((QM_IsUSDSTUTC(utc_now) ? -4 : -5) * 3600);
   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(ny_now, ny);

   if((ny.day_of_week == 0 || ny.day_of_week == 6) && !has_position)
      return true;

   const int now_min = (ny.hour * 60) + ny.min;
   const int open_min = ((strategy_cash_open_hhmm_ny / 100) * 60) + (strategy_cash_open_hhmm_ny % 100);
   const int close_min = ((strategy_cash_close_hhmm_ny / 100) * 60) + (strategy_cash_close_hhmm_ny % 100);
   if((now_min < open_min || now_min > close_min) && !has_position)
      return true;

   if(strategy_median_spread_points > 0.0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > 0 && (double)spread_points > (2.0 * strategy_median_spread_points))
         return true;
     }

   return false;
  }

// Trade Entry: previous cash-session floor pivots; one 10:30 NY closed-bar check.
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
   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int scan_bars = (strategy_pivot_scan_bars < 40) ? 40 : strategy_pivot_scan_bars;
   const int copied = CopyRates(_Symbol, PERIOD_M30, 1, scan_bars, rates); // perf-allowed: one closed-bar bounded scan for prior cash-session pivots.
   if(copied < 20)
      return false;

   const int period_seconds = PeriodSeconds(PERIOD_M30);
   const datetime signal_close_broker = rates[0].time + period_seconds;
   const datetime signal_close_utc = QM_BrokerToUTC(signal_close_broker);
   const datetime signal_close_ny = signal_close_utc + ((QM_IsUSDSTUTC(signal_close_utc) ? -4 : -5) * 3600);
   MqlDateTime signal_ny;
   ZeroMemory(signal_ny);
   TimeToStruct(signal_close_ny, signal_ny);

   if(signal_ny.day_of_week == 0 || signal_ny.day_of_week == 6)
      return false;

   const int signal_hhmm = (signal_ny.hour * 100) + signal_ny.min;
   if(signal_hhmm != strategy_entry_hhmm_ny)
      return false;

   const int signal_day_key = (signal_ny.year * 10000) + (signal_ny.mon * 100) + signal_ny.day;
   if(g_entry_eval_day_key == signal_day_key)
      return false;
   g_entry_eval_day_key = signal_day_key;

   double r1 = g_cached_r1;
   double s1 = g_cached_s1;
   if(g_pivot_cache_day_key != signal_day_key || r1 <= 0.0 || s1 <= 0.0)
     {
      const int open_min = ((strategy_cash_open_hhmm_ny / 100) * 60) + (strategy_cash_open_hhmm_ny % 100);
      const int close_min = ((strategy_cash_close_hhmm_ny / 100) * 60) + (strategy_cash_close_hhmm_ny % 100);
      int target_day_key = 0;
      double prev_high = 0.0;
      double prev_low = 0.0;
      double prev_close = 0.0;

      for(int i = 1; i < copied; ++i)
        {
         const datetime bar_utc = QM_BrokerToUTC(rates[i].time);
         const datetime bar_ny = bar_utc + ((QM_IsUSDSTUTC(bar_utc) ? -4 : -5) * 3600);
         MqlDateTime bar_dt;
         ZeroMemory(bar_dt);
         TimeToStruct(bar_ny, bar_dt);

         const int bar_day_key = (bar_dt.year * 10000) + (bar_dt.mon * 100) + bar_dt.day;
         if(bar_day_key >= signal_day_key)
            continue;
         if(bar_dt.day_of_week == 0 || bar_dt.day_of_week == 6)
            continue;

         const int bar_min = (bar_dt.hour * 60) + bar_dt.min;
         if(bar_min < open_min || bar_min >= close_min)
            continue;

         if(target_day_key == 0)
           {
            target_day_key = bar_day_key;
            prev_close = rates[i].close;
           }
         else if(bar_day_key != target_day_key)
            break;

         if(rates[i].high <= 0.0 || rates[i].low <= 0.0)
            continue;
         if(prev_high <= 0.0 || rates[i].high > prev_high)
            prev_high = rates[i].high;
         if(prev_low <= 0.0 || rates[i].low < prev_low)
            prev_low = rates[i].low;
        }

      if(prev_high <= 0.0 || prev_low <= 0.0 || prev_close <= 0.0 || prev_high <= prev_low)
         return false;

      const double pivot = (prev_high + prev_low + prev_close) / 3.0;
      r1 = QM_StopRulesNormalizePrice(_Symbol, (2.0 * pivot) - prev_low);
      s1 = QM_StopRulesNormalizePrice(_Symbol, (2.0 * pivot) - prev_high);
      if(r1 <= 0.0 || s1 <= 0.0)
         return false;

      g_cached_r1 = r1;
      g_cached_s1 = s1;
      g_pivot_cache_day_key = signal_day_key;
     }

   const double signal_close = rates[0].close;
   if(signal_close <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(signal_close > r1)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, ask, strategy_atr_period, strategy_atr_sl_mult);
      if(req.sl <= 0.0)
         return false;
      req.tp = strategy_use_rr_tp ? QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr_tp) : 0.0;
      req.reason = "UNGER_PIVOT_R1_BREAK";
      return true;
     }

   if(signal_close < s1)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, bid, strategy_atr_period, strategy_atr_sl_mult);
      if(req.sl <= 0.0)
         return false;
      req.tp = strategy_use_rr_tp ? QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr_tp) : 0.0;
      req.reason = "UNGER_PIVOT_S1_BREAK";
      return true;
     }

   return false;
  }

// Trade Management: no trailing, break-even, partial close, or pyramiding in card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: cash-session close or opposite pivot condition after entry.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool has_position = false;
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const datetime ny_now = utc_now + ((QM_IsUSDSTUTC(utc_now) ? -4 : -5) * 3600);
   MqlDateTime ny;
   ZeroMemory(ny);
   TimeToStruct(ny_now, ny);

   const int now_min = (ny.hour * 60) + ny.min;
   const int close_min = ((strategy_cash_close_hhmm_ny / 100) * 60) + (strategy_cash_close_hhmm_ny % 100);
   if(now_min >= close_min)
      return true;

   if(g_cached_r1 <= 0.0 || g_cached_s1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && bid < g_cached_s1)
      return true;
   if(position_type == POSITION_TYPE_SELL && ask > g_cached_r1)
      return true;

   return false;
  }

// News Filter Hook: framework handles FOMC/CPI/NFP high-impact windows.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
   if(!QM_KillSwitchCheck())
      return;

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
