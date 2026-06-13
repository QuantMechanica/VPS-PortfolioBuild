#property strict
#property version   "5.0"
#property description "QM5_12544 — Katz MACD Divergence with Limit Entry (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12544 — katz-macd-divergence-limit-d1
//
// Source: Katz & McCormick (2000), The Encyclopedia of Trading Strategies,
// McGraw-Hill, Ch.7 (Oscillator-Based Entries), pp. 161-166.
//
// Algorithm: detect MACD divergence with temporal constraint (MACD valley
// must precede price valley by ≥4 bars), price valley must be 1-6 bars ago,
// MACD just turned up → enter via BUY_LIMIT at signal-bar midpoint (H+L)/2,
// valid for 2 D1 bars. SES exit: 1×ATR(50) stop, 4×ATR(50) target, 10-bar
// time stop. SHORT = full mirror.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12544;
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
input int    strategy_macd_fast    = 5;    // MACD fast EMA period (Katz default)
input int    strategy_macd_slow    = 25;   // MACD slow EMA period (Katz default)
input int    strategy_lookback     = 20;   // bars to scan for valley/peak
input int    strategy_temporal_min = 4;    // min bars MACD valley must precede price valley
input int    strategy_recency_min  = 1;    // price valley recency: min bars ago
input int    strategy_recency_max  = 6;    // price valley recency: max bars ago
input double strategy_sl_mult      = 1.0;  // SL = entry ± sl_mult × ATR(atr_period)
input double strategy_tp_mult      = 4.0;  // TP = entry ± tp_mult × ATR(atr_period)
input int    strategy_atr_period   = 50;   // ATR period for SES stop/target sizing
input int    strategy_time_exit_bars = 10; // close position after this many D1 bars

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Skip if a pending limit order for this magic is already active
   const long magic = QM_FrameworkMagic();
   for(int i = OrdersTotal()-1; i >= 0; --i)
     {
      if(OrderGetTicket(i) == 0) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) == magic) return false;
     }

   // Scan look-back window once per new D1 bar.
   // iClose/iHigh/iLow used for structural valley/peak detection —
   // bespoke logic with no QM_* equivalent; runs once per new bar. // perf-allowed
   int    I_PV_L = -1, I_MV_L = -1;  // price valley, MACD valley (LONG)
   int    I_PV_S = -1, I_MV_S = -1;  // price peak,   MACD peak   (SHORT)
   double min_close = DBL_MAX,  min_macd = DBL_MAX;
   double max_close = -DBL_MAX, max_macd = -DBL_MAX;

   for(int i = strategy_recency_min; i <= strategy_lookback; i++)
     {
      const double c = iClose(_Symbol, PERIOD_D1, i);  // perf-allowed: valley/peak scan
      if(c < min_close) { min_close = c; I_PV_L = i; }
      if(c > max_close) { max_close = c; I_PV_S = i; }

      const double m = QM_MACD_Main(_Symbol, PERIOD_D1,
                                    strategy_macd_fast, strategy_macd_slow, 1, i);
      if(m < min_macd) { min_macd = m; I_MV_L = i; }
      if(m > max_macd) { max_macd = m; I_MV_S = i; }
     }

   if(I_PV_L < 0 || I_MV_L < 0 || I_PV_S < 0 || I_MV_S < 0)
      return false;

   // MACD direction at the most recently closed bar (shift=1) vs previous (shift=2)
   const double macd_now  = QM_MACD_Main(_Symbol, PERIOD_D1,
                                         strategy_macd_fast, strategy_macd_slow, 1, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, PERIOD_D1,
                                         strategy_macd_fast, strategy_macd_slow, 1, 2);
   const double atr50 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr50 <= 0.0) return false;

   // Signal bar = most recently closed bar (shift=1); limit at its midpoint
   const double sig_hi = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: signal bar H/L
   const double sig_lo = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double entry  = (sig_hi + sig_lo) * 0.5;
   const int    expiry = 2 * PeriodSeconds(PERIOD_D1);

   // LONG: MACD valley temporally before price valley (≥4 bars), price valley recent
   const bool long_sig = (I_PV_L >= strategy_recency_min && I_PV_L <= strategy_recency_max) &&
                          (I_MV_L > I_PV_L + strategy_temporal_min - 1) &&
                          (macd_now > macd_prev);

   // SHORT: MACD peak temporally before price peak (≥4 bars), price peak recent
   // MACD direction flags are mutually exclusive so at most one fires per bar
   const bool short_sig = (I_PV_S >= strategy_recency_min && I_PV_S <= strategy_recency_max) &&
                           (I_MV_S > I_PV_S + strategy_temporal_min - 1) &&
                           (macd_now < macd_prev);

   if(long_sig)
     {
      req.type               = QM_BUY_LIMIT;
      req.price              = entry;
      req.sl                 = entry - strategy_sl_mult * atr50;
      req.tp                 = entry + strategy_tp_mult * atr50;
      req.reason             = "katz_div_long";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = expiry;
      return true;
     }

   if(short_sig)
     {
      req.type               = QM_SELL_LIMIT;
      req.price              = entry;
      req.sl                 = entry + strategy_sl_mult * atr50;
      req.tp                 = entry - strategy_tp_mult * atr50;
      req.reason             = "katz_div_short";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = expiry;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   // SES baseline: fixed SL/TP set at order time; no trail, no partial.
   // Time exit handled in Strategy_ExitSignal.
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   // Time exit: close position if held for ≥ strategy_time_exit_bars D1 bars
   const long magic = QM_FrameworkMagic();
   const long hold_seconds = (long)strategy_time_exit_bars * (long)PeriodSeconds(PERIOD_D1);
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if((long)(now - open_time) >= hold_seconds) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 in framework
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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
      for(int i = PositionsTotal()-1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
