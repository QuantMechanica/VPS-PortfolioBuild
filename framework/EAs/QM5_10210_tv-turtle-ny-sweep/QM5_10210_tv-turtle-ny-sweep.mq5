#property strict
#property version   "5.0"
#property description "QM5_10210 TradingView Turtle Soup NY Sweep"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10210;
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
input int    strategy_timeframe_minutes       = 5;
input int    strategy_preopen_start_hhmm_ny   = 0;
input int    strategy_ny_open_hhmm            = 930;
input int    strategy_ny_flat_hhmm            = 1600;
input int    strategy_atr_period              = 14;
input double strategy_stop_atr_buffer         = 0.25;
input double strategy_expansion_atr_mult      = 1.20;
input double strategy_expansion_body_ratio    = 0.60;
input double strategy_retrace_body_fraction   = 0.50;
input int    strategy_max_scan_bars           = 240;
input int    strategy_pending_expiry_minutes  = 120;
input double strategy_max_spread_atr_fraction = 0.20;

// Return TRUE to BLOCK trading this tick (time, spread, news). Cheap O(1) checks
// only - runs on every tick. News itself is handled by framework wiring.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const datetime ny_now = utc_now + (QM_IsUSDSTUTC(utc_now) ? -4 * 3600 : -5 * 3600);
   MqlDateTime ny;
   TimeToStruct(ny_now, ny);
   const int hhmm_ny = ny.hour * 100 + ny.min;
   if(hhmm_ny < strategy_ny_open_hhmm || hhmm_ny >= strategy_ny_flat_hhmm)
      return true;

   const ENUM_TIMEFRAMES tf = (strategy_timeframe_minutes == 15) ? PERIOD_M15 : PERIOD_M5;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   return ((ask - bid) > strategy_max_spread_atr_fraction * atr);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   static int session_key = 0;
   static bool long_taken = false;
   static bool short_taken = false;

   const ENUM_TIMEFRAMES tf = (strategy_timeframe_minutes == 15) ? PERIOD_M15 : PERIOD_M5;
   const datetime signal_bar = iTime(_Symbol, tf, 1); // perf-allowed: structural session math, closed-bar only
   if(signal_bar <= 0)
      return false;

   const datetime signal_utc = QM_BrokerToUTC(signal_bar);
   const datetime signal_ny = signal_utc + (QM_IsUSDSTUTC(signal_utc) ? -4 * 3600 : -5 * 3600);
   MqlDateTime sdt;
   TimeToStruct(signal_ny, sdt);
   const int today_key = sdt.year * 10000 + sdt.mon * 100 + sdt.day;
   const int signal_hhmm = sdt.hour * 100 + sdt.min;
   if(today_key != session_key)
     {
      session_key = today_key;
      long_taken = false;
      short_taken = false;
     }
   if(signal_hhmm < strategy_ny_open_hhmm || signal_hhmm >= strategy_ny_flat_hhmm)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int bars = MathMax(30, strategy_max_scan_bars);
   double ref_high = -DBL_MAX;
   double ref_low = DBL_MAX;
   double sweep_high = 0.0;
   double sweep_low = 0.0;

   for(int shift = 1; shift <= bars; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, tf, shift); // perf-allowed: bounded session scan, closed-bar only
      if(bar_time <= 0)
         break;

      const datetime bar_utc = QM_BrokerToUTC(bar_time);
      const datetime bar_ny = bar_utc + (QM_IsUSDSTUTC(bar_utc) ? -4 * 3600 : -5 * 3600);
      MqlDateTime bdt;
      TimeToStruct(bar_ny, bdt);
      const int bar_key = bdt.year * 10000 + bdt.mon * 100 + bdt.day;
      if(bar_key != today_key)
         continue;

      const int bar_hhmm = bdt.hour * 100 + bdt.min;
      if(bar_hhmm < strategy_preopen_start_hhmm_ny || bar_hhmm > signal_hhmm)
         continue;

      const double high = iHigh(_Symbol, tf, shift); // perf-allowed: bespoke session range
      const double low = iLow(_Symbol, tf, shift);   // perf-allowed: bespoke session range
      if(high <= 0.0 || low <= 0.0)
         continue;

      if(bar_hhmm < strategy_ny_open_hhmm)
        {
         ref_high = MathMax(ref_high, high);
         ref_low = MathMin(ref_low, low);
         continue;
        }

      if(ref_high > ref_low)
        {
         if(high > ref_high)
            sweep_high = MathMax(sweep_high, high);
         if(low < ref_low)
            sweep_low = (sweep_low <= 0.0) ? low : MathMin(sweep_low, low);
        }
     }
   if(ref_high <= ref_low || ref_low >= DBL_MAX)
      return false;

   const double open1 = iOpen(_Symbol, tf, 1);   // perf-allowed: closed confirmation candle
   const double high1 = iHigh(_Symbol, tf, 1);   // perf-allowed: closed confirmation candle
   const double low1 = iLow(_Symbol, tf, 1);     // perf-allowed: closed confirmation candle
   const double close1 = iClose(_Symbol, tf, 1); // perf-allowed: closed confirmation candle
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || atr <= 0.0)
      return false;

   const double range = high1 - low1;
   const double body = MathAbs(close1 - open1);
   if(range <= 0.0 || body <= 0.0)
      return false;
   if(body < strategy_expansion_atr_mult * atr && body < strategy_expansion_body_ratio * range)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(!long_taken && sweep_low > 0.0 && low1 <= ref_low && close1 > ref_low && close1 > open1)
     {
      const double retrace = NormalizeDouble(open1 + strategy_retrace_body_fraction * (close1 - open1), _Digits);
      const double sl = NormalizeDouble(sweep_low - strategy_stop_atr_buffer * atr, _Digits);
      const double entry = (ask <= retrace) ? ask : retrace;
      if(entry <= sl || ref_high <= entry)
         return false;

      req.type = (ask <= retrace) ? QM_BUY : QM_BUY_LIMIT;
      req.price = (req.type == QM_BUY) ? 0.0 : retrace;
      req.sl = sl;
      req.tp = NormalizeDouble(ref_high, _Digits);
      req.reason = "TV_TURTLE_NY_SWEEP_LONG";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      long_taken = true;
      return true;
     }

   if(!short_taken && sweep_high > 0.0 && high1 >= ref_high && close1 < ref_high && close1 < open1)
     {
      const double retrace = NormalizeDouble(open1 - strategy_retrace_body_fraction * (open1 - close1), _Digits);
      const double sl = NormalizeDouble(sweep_high + strategy_stop_atr_buffer * atr, _Digits);
      const double entry = (bid >= retrace) ? bid : retrace;
      if(entry >= sl || ref_low >= entry)
         return false;

      req.type = (bid >= retrace) ? QM_SELL : QM_SELL_LIMIT;
      req.price = (req.type == QM_SELL) ? 0.0 : retrace;
      req.sl = sl;
      req.tp = NormalizeDouble(ref_low, _Digits);
      req.reason = "TV_TURTLE_NY_SWEEP_SHORT";
      req.expiration_seconds = MathMax(1, strategy_pending_expiry_minutes) * 60;
      short_taken = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card baseline: no trailing, partial close, or break-even rule.
  }

// Return TRUE to close the open position now at end of NY cash session.
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const datetime ny_now = utc_now + (QM_IsUSDSTUTC(utc_now) ? -4 * 3600 : -5 * 3600);
   MqlDateTime ny;
   TimeToStruct(ny_now, ny);
   const int hhmm_ny = ny.hour * 100 + ny.min;
   if(hhmm_ny < strategy_ny_flat_hhmm)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
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
