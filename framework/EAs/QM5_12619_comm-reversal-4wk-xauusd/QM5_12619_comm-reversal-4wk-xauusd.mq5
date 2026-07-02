#property strict
#property version   "5.0"
#property description "QM5_12619 4-Week Short-Term Commodity Reversal — XAUUSD"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12619 — 4-Week Commodity Reversal on XAUUSD
// Card: QM5_12619_comm-reversal-4wk-xauusd.md  |  Source: 05abad87
// Yang, Goncu, Pantelous (2018) QF Table 2: short-term reversal in metals.
// Signal: 20D cumulative return < -3% → fade (long); > +3% → fade (short).
// Entry cadence: first D1 bar of each calendar week (weekly trigger).
// Exit: ATR(14)×1.8 hard SL + 20 D1-bar (~4-week) time-exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12619;
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
input int    strategy_lookback_bars     = 20;    // D1 bars ≈ 4 calendar weeks (formation window)
input double strategy_return_threshold  = 0.03;  // ±3% 20D return triggers reversal entry
input int    strategy_atr_period        = 14;    // ATR period for hard SL
input double strategy_atr_sl_mult       = 1.8;   // SL = entry ± ATR(14)×1.8
input int    strategy_hold_days_cal     = 27;    // calendar-day cap ≈ 20 trading days (4 weeks)
input double strategy_vol_max_ratio     = 0.02;  // guard: skip if ATR(20)/Close >= 2% (trending gold)

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
int g_last_week_key = -1;   // restart-safe weekly cadence via QM_CalendarPeriodKey (returns int yyyyww)

// -----------------------------------------------------------------------------
// Strategy_NoTradeFilter
// Return TRUE to block entry this tick. News/Friday handled by framework.
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_EntrySignal
// Called once per new D1 bar (within QM_IsNewBar gate in OnTick).
// Fires only on the first D1 bar of each calendar week.
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Weekly cadence: evaluate once per calendar week (restart-safe)
   const int week_key = QM_CalendarPeriodKey(PERIOD_W1);
   if(week_key == g_last_week_key)
      return false;
   g_last_week_key = week_key;

   // 20-day cumulative return: (Close[1] - Close[lookback+1]) / Close[lookback+1]
   // perf-allowed: bespoke structural logic; no QM_Close helper exists.
   // Gated inside QM_IsNewBar — executes once per D1 bar, not per tick.
   const double close_prev  = iClose(_Symbol, PERIOD_D1, 1);                          // perf-allowed
   const double close_base  = iClose(_Symbol, PERIOD_D1, strategy_lookback_bars + 1); // perf-allowed
   if(close_prev <= 0.0 || close_base <= 0.0)
      return false;

   const double ret_20d = (close_prev - close_base) / close_base;

   // Volatility guard: skip if 20D ATR/Close ratio exceeds threshold (structurally trending gold)
   const double atr20 = QM_ATR(_Symbol, PERIOD_D1, strategy_lookback_bars, 1);
   if(atr20 <= 0.0)
      return false;
   if(atr20 / close_prev >= strategy_vol_max_ratio)
      return false;

   // Threshold gate: must exceed ±threshold to trade
   if(MathAbs(ret_20d) < strategy_return_threshold)
      return false;

   const int magic = QM_FrameworkMagic();

   // Inventory scan: determine existing position direction
   bool has_long  = false;
   bool has_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)  has_long  = true;
      else                                                          has_short = true;
     }

   // LONG entry: fade the 4-week drop
   if(ret_20d < -strategy_return_threshold && !has_long)
     {
      // Close opposite short first (flip)
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
      const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type           = QM_BUY;
      req.price          = 0.0;  // market order
      req.sl             = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.tp             = 0.0;  // time-exit manages hold; no TP
      req.reason         = "rev_long_ret20d";
      req.symbol_slot    = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // SHORT entry: fade the 4-week rally
   if(ret_20d > strategy_return_threshold && !has_short)
     {
      // Close opposite long first (flip)
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
      const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type           = QM_SELL;
      req.price          = 0.0;  // market order
      req.sl             = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      req.tp             = 0.0;
      req.reason         = "rev_short_ret20d";
      req.symbol_slot    = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_ManageOpenPosition
// Card has no active management (SL set at entry; time-exit in ExitSignal).
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Strategy_ExitSignal
// Time-stop: close after strategy_hold_days_cal calendar days (≈ 20 trading days).
// Called every tick — O(1), no banned indicator calls.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const datetime pos_open = (datetime)PositionGetInteger(POSITION_TIME);
      if((TimeCurrent() - pos_open) >= (long)strategy_hold_days_cal * 86400L)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_NewsFilterHook
// Defers to framework 2-axis news check (moved to entry-only path in OnTick).
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — OnTick uses 2026-07-02 audit ordering:
//   kill-switch → Friday-close → NoTradeFilter → ManageOpenPosition →
//   ExitSignal → news gate → IsNewBar → EntrySignal
// News gate is entry-only: ManageOpenPosition and ExitSignal run through
// news windows to prevent unguarded open positions during news spikes.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12619\",\"slug\":\"comm-reversal-4wk-xauusd\"}");
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

   // Friday-close guard runs before management so positions can be closed on schedule
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management and discretionary exit run THROUGH news windows (2026-07-02 ordering)
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // News gate is ENTRY-ONLY (below management/exit per 2026-07-02 audit)
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
