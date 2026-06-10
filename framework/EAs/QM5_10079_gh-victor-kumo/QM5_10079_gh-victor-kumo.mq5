#property strict
#property version   "5.0"
#property description "QM5_10079 GitHub Victor Algo Ichimoku Kumo Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10079;
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
input int    strategy_tenkan_period     = 9;
input int    strategy_kijun_period      = 26;
input int    strategy_senkou_b_period   = 52;
input double strategy_stop_percent      = 3.0;

// Cached Ichimoku cloud boundaries for bar[-1]; refreshed once per closed bar
// via Strategy_EntrySignal → RefreshCloudCache.
double g_cached_cloud_lower = 0.0;
double g_cached_cloud_upper = 0.0;
bool   g_cloud_cache_ready  = false;

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool HasOpenPositionForMagic()
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

bool SelectPositionTypeForMagic(ENUM_POSITION_TYPE &position_type)
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

// Checks if an entry deal for this magic was recorded during the prior closed bar.
// Called only inside the QM_IsNewBar() gate in Strategy_EntrySignal.
bool TradedDuringPriorBar()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   const datetime prior_bar_open    = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed — Ichimoku: closed-bar timestamp gate, no QM_* equivalent
   const datetime current_bar_open  = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0); // perf-allowed — Ichimoku: closed-bar timestamp gate, no QM_* equivalent
   if(prior_bar_open <= 0 || current_bar_open <= prior_bar_open)
      return false;

   if(!HistorySelect(prior_bar_open, current_bar_open - 1))
      return false;

   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;

      const ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_IN || entry_type == DEAL_ENTRY_INOUT)
         return true;
     }

   return false;
  }

// Ichimoku Tenkan/Kijun/Senkou midpoint: (period_high + period_low) / 2.
// Bespoke structural math — no QM_* equivalent. Called only inside QM_IsNewBar gate.
bool MidpointHighLow(const int start_shift, const int period, double &midpoint)
  {
   if(period <= 0 || start_shift < 0)
      return false;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = start_shift; i < start_shift + period; ++i)
     {
      const double hi = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i); // perf-allowed — Ichimoku HL midpoint, bespoke structural, called once/bar
      const double lo = iLow(_Symbol,  (ENUM_TIMEFRAMES)_Period, i); // perf-allowed — Ichimoku HL midpoint, bespoke structural, called once/bar
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      highest = MathMax(highest, hi);
      lowest  = MathMin(lowest, lo);
     }

   midpoint = (highest + lowest) * 0.5;
   return true;
  }

// Compute Senkou Span A and B at a given display shift (cloud projected by kijun_period).
// Called only inside QM_IsNewBar gate.
bool CloudAtShift(const int display_shift, double &span_a, double &span_b)
  {
   if(strategy_tenkan_period <= 0 || strategy_kijun_period <= 0 ||
      strategy_senkou_b_period <= 0)
      return false;

   const int origin_shift = display_shift + strategy_kijun_period;

   double tenkan = 0.0;
   double kijun  = 0.0;
   if(!MidpointHighLow(origin_shift, strategy_tenkan_period,   tenkan))   return false;
   if(!MidpointHighLow(origin_shift, strategy_kijun_period,    kijun))    return false;
   if(!MidpointHighLow(origin_shift, strategy_senkou_b_period, span_b))   return false;

   span_a = (tenkan + kijun) * 0.5;
   return true;
  }

// Refresh cloud cache from bar[-1]. Called once per new bar from Strategy_EntrySignal.
bool RefreshCloudCache()
  {
   double span_a = 0.0;
   double span_b = 0.0;
   if(!CloudAtShift(1, span_a, span_b))
      return false;

   g_cached_cloud_lower = MathMin(span_a, span_b);
   g_cached_cloud_upper = MathMax(span_a, span_b);
   g_cloud_cache_ready  = true;
   return true;
  }

// Entry: D1 Kumo breakout. Long when bearish-to-bullish breakout across Kumo upper;
// short when bullish-to-bearish breakdown below Kumo lower. One position per magic.
// Called only after QM_IsNewBar() — all series reads are per-bar, not per-tick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_stop_percent <= 0.0)
      return false;
   if(!RefreshCloudCache())
      return false;
   if(HasOpenPositionForMagic())
      return false;
   if(TradedDuringPriorBar())
      return false;

   double span_a_1 = 0.0, span_b_1 = 0.0;
   double span_a_2 = 0.0, span_b_2 = 0.0;
   if(!CloudAtShift(1, span_a_1, span_b_1)) return false;
   if(!CloudAtShift(2, span_a_2, span_b_2)) return false;
   const double low1  = iLow (_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed — Ichimoku Kumo breakout, called once/bar
   const double low2  = iLow (_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed — Ichimoku Kumo breakout, called once/bar
   const double high1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed — Ichimoku Kumo breakout, called once/bar
   const double high2 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed — Ichimoku Kumo breakout, called once/bar
   if(low1 <= 0.0 || low2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0)
      return false;

   const bool bullish_kumo = (span_a_1 > span_b_1 && span_a_2 > span_b_2);
   const bool bearish_kumo = (span_a_1 < span_b_1 && span_a_2 < span_b_2);

   const double upper_1 = MathMax(span_a_1, span_b_1);
   const double upper_2 = MathMax(span_a_2, span_b_2);
   const double lower_1 = MathMin(span_a_1, span_b_1);
   const double lower_2 = MathMin(span_a_2, span_b_2);

   QM_OrderType side  = QM_BUY;
   string       reason = "";
   if(bullish_kumo && low2 < upper_2 && low1 > upper_1)
     {
      side   = QM_BUY;
      reason = "KUMO_BREAKOUT_LONG";
     }
   else if(bearish_kumo && high2 > lower_2 && high1 < lower_1)
     {
      side   = QM_SELL;
      reason = "KUMO_BREAKOUT_SHORT";
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double stop_distance = entry * strategy_stop_percent / 100.0;
   if(stop_distance <= 0.0)
      return false;

   req.type   = side;
   req.sl     = (side == QM_BUY) ? entry - stop_distance : entry + stop_distance;
   req.reason = reason;
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Source strategy specifies no trailing, break-even, or partial-close rule.
  }

// Exit: close long if developing bar low crosses below cached cloud lower boundary;
// close short if developing bar high crosses above cached cloud upper boundary.
// g_cached_cloud_lower/upper are refreshed each new bar by Strategy_EntrySignal.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!SelectPositionTypeForMagic(position_type))
      return false;
   if(!g_cloud_cache_ready && !RefreshCloudCache())
      return false;
   const double current_low  = iLow (_Symbol, (ENUM_TIMEFRAMES)_Period, 0); // perf-allowed — intraday exit vs cached cloud; O(1) current-bar read
   const double current_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 0); // perf-allowed — intraday exit vs cached cloud; O(1) current-bar read
   if(current_low <= 0.0 || current_high <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY  && current_low  < g_cached_cloud_lower) return true;
   if(position_type == POSITION_TYPE_SELL && current_high > g_cached_cloud_upper) return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
