#property strict
#property version   "5.0"
#property description "QM5_10147 TII Centerline Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10147;
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
input int    strategy_tii_period          = 60;
input double strategy_tii_centerline      = 50.0;
input double strategy_tii_upper           = 80.0;
input double strategy_tii_lower           = 20.0;
input bool   strategy_shorts_enabled      = true;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 3.0;
input double strategy_max_spread_atr_frac = 0.05;

double g_tii_current = 0.0;
double g_tii_previous = 0.0;
double g_cached_atr = 0.0;
bool   g_tii_state_ready = false;
bool   g_tii_long_extreme_seen = false;
bool   g_tii_short_extreme_seen = false;
bool   g_tii_exit_requested = false;

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type)
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

bool Strategy_CalculateTIIFromWindow(const double &closes[],
                                     const int start_index,
                                     const int period,
                                     double &tii)
  {
   tii = 0.0;
   if(period < 2 || start_index < 0 ||
      ArraySize(closes) < start_index + 2 * period - 1)
      return false;

   // TII compares each close with the SMA ending on that same bar. Build the
   // first SMA once, then roll it through the window instead of creating one
   // framework indicator handle per historical bar.
   double ma_sum = 0.0;
   for(int i = 0; i < period; ++i)
      ma_sum += closes[start_index + i];

   double positive = 0.0;
   double negative = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double ma = ma_sum / (double)period;
      const double deviation = closes[start_index + i] - ma;
      if(deviation > 0.0)
         positive += deviation;
      else
         negative += -deviation;

      if(i + 1 < period)
         ma_sum += closes[start_index + i + period] - closes[start_index + i];
     }

   const double total = positive + negative;
   if(total <= 0.0)
      return false;

   tii = 100.0 * positive / total;
   return true;
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_tii_state_ready = false;
   g_cached_atr = 0.0;

   const int period = MathMax(2, strategy_tii_period);
   const int close_count = 2 * period;
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, _Period, 1, close_count, closes); // perf-allowed: one custom-TII cache fill per completed D1 bar.
   if(copied < close_count)
      return false;

   if(!Strategy_CalculateTIIFromWindow(closes, 0, period, g_tii_current) ||
      !Strategy_CalculateTIIFromWindow(closes, 1, period, g_tii_previous))
      return false;

   // Cache the spread normalizer once per completed bar. The former per-tick
   // QM_ATR call was another avoidable indicator-handle hot path in Q02.
   g_cached_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period,
                         strategy_atr_period, 1);
   g_tii_state_ready = true;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(position_type))
      Strategy_UpdateExitState(position_type);
   else
      Strategy_ResetExitState();

   return true;
  }

void Strategy_ResetExitState()
  {
   g_tii_long_extreme_seen = false;
   g_tii_short_extreme_seen = false;
   g_tii_exit_requested = false;
  }

void Strategy_UpdateExitState(const ENUM_POSITION_TYPE position_type)
  {
   g_tii_exit_requested = false;

   if(position_type == POSITION_TYPE_BUY)
     {
      g_tii_short_extreme_seen = false;
      if(g_tii_current > strategy_tii_upper)
         g_tii_long_extreme_seen = true;

      if(g_tii_long_extreme_seen &&
         g_tii_previous > strategy_tii_upper &&
         g_tii_current <= strategy_tii_upper)
         g_tii_exit_requested = true;
      else if(!g_tii_long_extreme_seen &&
              g_tii_current <= strategy_tii_centerline)
         g_tii_exit_requested = true;
      return;
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      g_tii_long_extreme_seen = false;
      if(g_tii_current < strategy_tii_lower)
         g_tii_short_extreme_seen = true;

      if(g_tii_short_extreme_seen &&
         g_tii_previous < strategy_tii_lower &&
         g_tii_current >= strategy_tii_lower)
         g_tii_exit_requested = true;
      else if(!g_tii_short_extreme_seen &&
              g_tii_current > strategy_tii_centerline)
         g_tii_exit_requested = true;
     }
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_atr_frac <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid || g_cached_atr <= 0.0)
      return false;

   return ((ask - bid) > g_cached_atr * strategy_max_spread_atr_frac);
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_tii_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_tii_lower >= strategy_tii_centerline ||
      strategy_tii_centerline >= strategy_tii_upper)
      return false;

   if(!g_tii_state_ready)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(Strategy_GetOurPosition(position_type))
      return false;

   Strategy_ResetExitState();

   QM_OrderType order_type = QM_BUY;
   string reason = "";
   if(g_tii_previous <= strategy_tii_centerline &&
      g_tii_current > strategy_tii_centerline)
     {
      order_type = QM_BUY;
      reason = "TII_CENTERLINE_UP";
     }
   else if(strategy_shorts_enabled &&
           g_tii_previous >= strategy_tii_centerline &&
           g_tii_current < strategy_tii_centerline)
     {
      order_type = QM_SELL;
      reason = "TII_CENTERLINE_DOWN";
     }
   else
      return false;

   const double entry_price = QM_EntryMarketPrice(order_type);
   const double stop = QM_StopATR(_Symbol, order_type, entry_price,
                                  strategy_atr_period, strategy_atr_stop_mult);
   if(entry_price <= 0.0 || stop <= 0.0)
      return false;

   req.type = order_type;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card defines no break-even, trailing stop, partial close, or pyramiding.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_tii_exit_requested)
      return false;

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!Strategy_GetOurPosition(position_type))
     {
      Strategy_ResetExitState();
      return false;
     }

   return true;
  }

// News Filter Hook.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
   // Q08 evidence lifecycle: no guard may skip floating-P&L sampling.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // QM_IsNewBar is single-consume. Latch it once so TII/ATR state is derived
   // once per completed D1 bar and reused by exit and entry paths.
   const bool qm_new_bar = QM_IsNewBar();
   if(qm_new_bar)
      Strategy_AdvanceStateOnNewBar();

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   bool exit_fired_this_tick = false;
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
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            exit_fired_this_tick = true;
        }
     }

   // News blackouts gate new entries only; management and source exits above
   // remain active during blackout windows.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!qm_new_bar || exit_fired_this_tick)
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
