#property strict
#property version   "5.0"
#property description "QM5_11038 atc-imex-time - Time-Point Bulls/Bears IMEX Forecast"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11038 atc-imex-time
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_11038_atc-imex-time.md, g0_status APPROVED.
//
// The card asks for fixed intraday decision points inside the current D1 bar
// (P2 baseline 25%, 50%, 75%), a Bulls/Bears Power approximation of the
// proprietary IMEX index, ATR SL/TP, one active position per symbol/magic, and
// optional reversal on a later opposite forecast.
//
// This EA is intended to run on the card's signal timeframes. H1 is the P2
// baseline because it can hit the 06:00/12:00/18:00 broker-time points using the
// framework's single new-bar entry gate. H4 and D1 setfiles are generated for
// downstream parameter testing exactly as listed in the card.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11038;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_tp1_broker_minutes         = 360;
input int    strategy_tp2_broker_minutes         = 720;
input int    strategy_tp3_broker_minutes         = 1080;
input int    strategy_tp_window_min              = 60;
input int    strategy_latest_entry_broker_minutes = 1080;
input int    strategy_imex_ma_period             = 13;
input int    strategy_imex_lookback              = 34;
input double strategy_imex_threshold             = 0.50;
input ENUM_TIMEFRAMES strategy_atr_tf            = PERIOD_D1;
input int    strategy_atr_period                 = 14;
input double strategy_sl_atr_mult                = 0.70;
input double strategy_tp_atr_mult                = 0.45;
input bool   strategy_reversal_enabled           = false;
input double strategy_spread_pct_of_stop         = 25.0;

datetime g_last_attempt_day[3] = {0, 0, 0};

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int BrokerMinuteOfBarOpen()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar timestamp
   if(bar_open <= 0)
      return -1;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(bar_open, dt);
   return dt.hour * 60 + dt.min;
  }

datetime BrokerDayOfBarOpen()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar timestamp
   if(bar_open <= 0)
      return 0;
   return (datetime)((bar_open / 86400) * 86400);
  }

int ActiveTimePointSlot(const int minute_of_day)
  {
   if(minute_of_day < 0 || strategy_tp_window_min <= 0)
      return -1;

   const int starts[3] = {strategy_tp1_broker_minutes,
                          strategy_tp2_broker_minutes,
                          strategy_tp3_broker_minutes};
   for(int i = 0; i < 3; ++i)
     {
      const int start = starts[i];
      if(start < 0)
         continue;
      if(minute_of_day >= start && minute_of_day < start + strategy_tp_window_min)
         return i;
     }
   return -1;
  }

bool ComputeImex(double &imex_out)
  {
   imex_out = 0.0;
   const int n = strategy_imex_lookback;
   if(strategy_imex_ma_period <= 0 || n < 2)
      return false;

   double bulls[];
   double bears_abs[];
   ArrayResize(bulls, n);
   ArrayResize(bears_abs, n);

   for(int k = 0; k < n; ++k)
     {
      const int shift = 1 + k;
      const double ema_k = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_imex_ma_period, shift);
      const double high_k = iHigh(_Symbol, _Period, shift); // perf-allowed: Bulls Power closed-bar high
      const double low_k = iLow(_Symbol, _Period, shift);   // perf-allowed: Bears Power closed-bar low
      if(ema_k <= 0.0 || high_k <= 0.0 || low_k <= 0.0)
         return false;

      bulls[k] = high_k - ema_k;
      bears_abs[k] = MathAbs(low_k - ema_k);
     }

   double mean_bulls = 0.0;
   double mean_bears = 0.0;
   for(int k = 0; k < n; ++k)
     {
      mean_bulls += bulls[k];
      mean_bears += bears_abs[k];
     }
   mean_bulls /= n;
   mean_bears /= n;

   double var_bulls = 0.0;
   double var_bears = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double db = bulls[k] - mean_bulls;
      const double dr = bears_abs[k] - mean_bears;
      var_bulls += db * db;
      var_bears += dr * dr;
     }
   var_bulls /= n;
   var_bears /= n;

   const double sd_bulls = MathSqrt(var_bulls);
   const double sd_bears = MathSqrt(var_bears);
   if(sd_bulls <= 0.0 || sd_bears <= 0.0)
      return false;

   const double z_bulls = (bulls[0] - mean_bulls) / sd_bulls;
   const double z_bears = (bears_abs[0] - mean_bears) / sd_bears;
   imex_out = z_bulls - z_bears;
   return true;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
   if(atr_value <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return false;

   const double stop_distance = atr_value * strategy_sl_atr_mult;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
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
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_tp_atr_mult <= 0.0 ||
      strategy_imex_threshold <= 0.0)
      return false;

   const int minute_of_day = BrokerMinuteOfBarOpen();
   if(minute_of_day < 0 || minute_of_day >= strategy_latest_entry_broker_minutes)
      return false;

   const int slot = ActiveTimePointSlot(minute_of_day);
   if(slot < 0)
      return false;

   const datetime day = BrokerDayOfBarOpen();
   if(day == 0 || g_last_attempt_day[slot] == day)
      return false;
   g_last_attempt_day[slot] = day;

   double imex = 0.0;
   if(!ComputeImex(imex))
      return false;

   QM_OrderType side = QM_BUY;
   if(imex > strategy_imex_threshold)
      side = QM_BUY;
   else if(imex < -strategy_imex_threshold)
      side = QM_SELL;
   else
      return false;

   const double atr_value = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "atc_imex_time";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!strategy_reversal_enabled)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int minute_of_day = BrokerMinuteOfBarOpen();
   if(minute_of_day < 0 || minute_of_day >= strategy_latest_entry_broker_minutes)
      return false;
   if(ActiveTimePointSlot(minute_of_day) < 0)
      return false;

   double imex = 0.0;
   if(!ComputeImex(imex))
      return false;

   bool is_long = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long position_type = PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         is_long = true;
      if(position_type == POSITION_TYPE_SELL)
         is_short = true;
     }

   if(is_long && imex < -strategy_imex_threshold)
      return true;
   if(is_short && imex > strategy_imex_threshold)
      return true;
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
