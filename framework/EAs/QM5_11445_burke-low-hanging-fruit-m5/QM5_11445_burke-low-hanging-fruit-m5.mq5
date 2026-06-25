#property strict
#property version   "5.0"
#property description "QM5_11445 burke-low-hanging-fruit-m5"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// -----------------------------------------------------------------------------
// Implements QM5_11445 Burke Low Hanging Fruit from the APPROVED strategy card.
// Session state advances once per closed M5 bar through Strategy_EntrySignal,
// which the framework calls only after QM_IsNewBar().
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11445;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M5;
input int             strategy_london_start_utc = 7;
input int             strategy_london_end_utc   = 12;
input int             strategy_ny_start_utc     = 13;
input int             strategy_ny_end_utc       = 17;
input int             strategy_ema_period       = 20;
input int             strategy_pullback_min_pips = 25;
input int             strategy_pullback_max_pips = 50;
input int             strategy_sl_pips          = 20;
input int             strategy_tp_primary_pips  = 50;
input bool            strategy_use_d1_atr_tp    = true;
input int             strategy_d1_atr_period    = 14;
input int             strategy_tp_min_pips      = 25;
input int             strategy_tp_max_pips      = 100;
input int             strategy_spread_cap_pips  = 15;

int    g_session_key       = -1;
double g_session_high      = 0.0;
double g_session_low       = 0.0;
double g_hod_break_level   = 0.0;
double g_lod_break_level   = 0.0;
bool   g_session_seeded    = false;
bool   g_hod_break_active  = false;
bool   g_lod_break_active  = false;
bool   g_reentry_done      = false;
bool   g_long_signal       = false;
bool   g_short_signal      = false;

int Strategy_SessionIdUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_time, dt);

   if(dt.hour >= strategy_london_start_utc && dt.hour < strategy_london_end_utc)
      return 0;
   if(dt.hour >= strategy_ny_start_utc && dt.hour < strategy_ny_end_utc)
      return 1;

   return -1;
  }

bool Strategy_InSessionUTC(const datetime utc_time)
  {
   return (Strategy_SessionIdUTC(utc_time) >= 0);
  }

int Strategy_SessionKeyUTC(const datetime utc_time, const int session_id)
  {
   return (int)(utc_time / 86400) * 2 + session_id;
  }

int Strategy_TargetPips()
  {
   int target = strategy_tp_primary_pips;

   if(strategy_use_d1_atr_tp)
     {
      const double one_pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_d1_atr_period, 1);
      if(one_pip > 0.0 && atr > 0.0)
         target = (int)MathRound((atr * 0.5) / one_pip);
     }

   if(target < strategy_tp_min_pips)
      target = strategy_tp_min_pips;
   if(target > strategy_tp_max_pips)
      target = strategy_tp_max_pips;

   return target;
  }

void Strategy_ResetSession(const int session_key)
  {
   g_session_key       = session_key;
   g_session_high      = 0.0;
   g_session_low       = 0.0;
   g_hod_break_level   = 0.0;
   g_lod_break_level   = 0.0;
   g_session_seeded    = false;
   g_hod_break_active  = false;
   g_lod_break_active  = false;
   g_reentry_done      = false;
   g_long_signal       = false;
   g_short_signal      = false;
  }

void Strategy_AdvanceSessionState()
  {
   g_long_signal = false;
   g_short_signal = false;

   MqlRates rates[1];
   // perf-allowed: one closed M5 bar copied inside the framework new-bar gate for session HOD/LOD state.
   if(CopyRates(_Symbol, strategy_signal_tf, 1, 1, rates) != 1)
      return;

   const datetime bar_utc = QM_BrokerToUTC(rates[0].time);
   const int session_id = Strategy_SessionIdUTC(bar_utc);
   if(session_id < 0)
      return;

   const int session_key = Strategy_SessionKeyUTC(bar_utc, session_id);
   if(session_key != g_session_key)
      Strategy_ResetSession(session_key);

   const double close1 = rates[0].close;
   if(close1 <= 0.0)
      return;

   if(!g_session_seeded)
     {
      g_session_high = close1;
      g_session_low = close1;
      g_session_seeded = true;
      return;
     }

   const double pb_min = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_pullback_min_pips);
   const double pb_max = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_pullback_max_pips);
   const double ema = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1);
   if(pb_min <= 0.0 || pb_max <= 0.0 || ema <= 0.0)
      return;

   if(close1 > g_session_high)
     {
      g_hod_break_level = close1;
      g_hod_break_active = true;
      g_lod_break_active = false;
     }
   else if(g_hod_break_active && !g_reentry_done)
     {
      const double pullback = g_hod_break_level - close1;
      if(pullback >= pb_min && pullback <= pb_max && close1 > ema)
        {
         g_long_signal = true;
         g_reentry_done = true;
         g_hod_break_active = false;
        }
     }

   if(close1 < g_session_low)
     {
      g_lod_break_level = close1;
      g_lod_break_active = true;
      g_hod_break_active = false;
     }
   else if(g_lod_break_active && !g_reentry_done)
     {
      const double pullback = close1 - g_lod_break_level;
      if(pullback >= pb_min && pullback <= pb_max && close1 < ema)
        {
         g_short_signal = true;
         g_reentry_done = true;
         g_lod_break_active = false;
        }
     }

   if(close1 > g_session_high)
      g_session_high = close1;
   if(close1 < g_session_low)
      g_session_low = close1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   if(!Strategy_InSessionUTC(utc_now))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > cap)
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

   Strategy_AdvanceSessionState();

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_long_signal && !g_short_signal)
      return false;

   const QM_OrderType side = g_long_signal ? QM_BUY : QM_SELL;
   double entry = 0.0;
   if(side == QM_BUY)
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   else
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const int tp_pips = Strategy_TargetPips();
   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY ? "burke_hod_pullback_ema20" : "burke_lod_pullback_ema20");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

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
