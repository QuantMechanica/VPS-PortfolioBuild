#property strict
#property version   "5.0"
#property description "QM5_12847 Turn-of-the-Month / Ultimo (SP500 index seasonal)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12847 — Turn-of-the-Month / Ultimo
// Source: quantified-turn-of-month-20260701
// Card:   cards_approved/QM5_12847_turn-of-month-sp500.md
//
// Mechanic (D1):
//   Long-only. Enter at close of Nth-last trading day of calendar month
//   (counting ACTUAL D1 bars, not calendar days). Exit at close of Mth
//   trading day of the NEXT calendar month. Optional 200-SMA regime gate.
//   One trade per calendar month. No ML, no grid, no martingale.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12847;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    entry_td_from_end   = 5;    // Nth-last trading day of month to enter (card default 5; sweep 4/5/6)
input int    exit_td_of_next     = 3;    // Mth trading day of NEXT month to exit (card default 3; sweep 2/3/4)
input int    regime_sma_period   = 200;  // SMA period for bull-regime filter (D1)
input bool   use_regime_filter   = true; // true = only trade when price > SMA (card default; sweep on/off)
input int    sl_atr_period       = 14;   // ATR period for protective stop
input double sl_atr_mult         = 3.0;  // ATR multiplier below entry

// -----------------------------------------------------------------------------
// File-scope calendar state (advanced once per new D1 bar)
// -----------------------------------------------------------------------------
int   g_cur_mon           = -1;
int   g_cur_year          = -1;
int   g_td_in_month       = 0;
int   g_prev_tdc          = 21;   // seed with typical ~21 trading days/month
bool  g_entered_this_mon  = false;

int   g_pos_entry_mon     = -1;
int   g_pos_entry_year    = -1;
bool  g_exit_pending      = false;
int   g_exit_td_count     = 0;

// -----------------------------------------------------------------------------
// Advance calendar state — called once per new D1 bar from Strategy_EntrySignal
// -----------------------------------------------------------------------------
void AdvanceMonthTracking()
  {
   const datetime bar1_t = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: bespoke calendar month detection; no QM_ wrapper for bar open-time
   if(bar1_t <= 0)
      return;

   MqlDateTime dt1;
   TimeToStruct(bar1_t, dt1);

   const bool month_rolled = (dt1.mon != g_cur_mon || dt1.year != g_cur_year);
   if(month_rolled)
     {
      if(g_cur_mon >= 0)
         g_prev_tdc = g_td_in_month;

      g_cur_mon          = dt1.mon;
      g_cur_year         = dt1.year;
      g_td_in_month      = 1;
      g_entered_this_mon = false;

      if(g_pos_entry_mon >= 0)
        {
         g_exit_pending  = true;
         g_exit_td_count = 1;
        }
     }
   else
     {
      g_td_in_month++;
      if(g_exit_pending)
         g_exit_td_count++;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceMonthTracking();

   const int magic      = QM_FrameworkMagic();
   const int open_count = QM_TM_OpenPositionCount(magic);

   // --- Time exit: close on Mth trading day of next month ---
   if(g_exit_pending)
     {
      if(open_count > 0 && g_exit_td_count >= exit_td_of_next)
        {
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != magic)
               continue;
            QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
           }
         g_pos_entry_mon = -1;
         g_exit_pending  = false;
         g_exit_td_count = 0;
        }
      else if(open_count == 0)
        {
         // SL was hit; reset exit tracking
         g_pos_entry_mon = -1;
         g_exit_pending  = false;
         g_exit_td_count = 0;
        }
     }

   if(open_count > 0)     return false;
   if(g_entered_this_mon) return false;

   // Regime filter: price > N-bar SMA on D1 (SMA, not EMA — per card spec)
   if(use_regime_filter)
     {
      const double sma200 = QM_SMA(_Symbol, PERIOD_D1, regime_sma_period, 1);
      const double cls1   = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
      if(sma200 <= 0.0 || cls1 <= 0.0 || cls1 <= sma200)
         return false;
     }

   // Near-end-of-month: remaining = prev_tdc - td_in_month (days AFTER bar 1 in same month)
   const int remaining_est = g_prev_tdc - g_td_in_month;
   if(remaining_est >= entry_td_from_end)
      return false;

   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   // ATR-based protective stop; primary exit is time stop
   const double atr = QM_ATR(_Symbol, PERIOD_D1, sl_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type        = QM_BUY;
   req.price       = 0.0;
   req.sl          = bid - sl_atr_mult * atr;
   req.tp          = 0.0;
   req.reason      = "TOM_ENTRY_D1";
   req.symbol_slot = qm_magic_slot_offset;

   g_pos_entry_mon    = g_cur_mon;
   g_pos_entry_year   = g_cur_year;
   g_entered_this_mon = true;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing stop or BE for a time-exit monthly strategy.
  }

bool Strategy_ExitSignal()
  {
   // Time exit is handled inside Strategy_EntrySignal (new-bar gate).
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_12847\",\"slug\":\"turn-of-month-sp500\","
               "\"entry_td_from_end\":" + IntegerToString(entry_td_from_end) +
               ",\"exit_td_of_next\":" + IntegerToString(exit_td_of_next) + "}");
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
