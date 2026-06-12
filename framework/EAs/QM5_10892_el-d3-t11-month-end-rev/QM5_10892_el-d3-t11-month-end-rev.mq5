#property strict
#property version   "5.0"
#property description "QM5_10892 Month-End Portfolio Rebalancing Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10892 — el-d3-t11-month-end-rev
// Etula et al. 2020 (RFS) month-end institutional rebalancing reversion.
// On D-3 (3rd-to-last trading day of month): rank 7 USD-major pairs by MTD
// return. SHORT top-2 overperformers, LONG bottom-2 underperformers.
// Exit: close at end of first trading day of new month.
// Runs one instance per symbol; cross-sectional ranking computed from all 7.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10892;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_FTMO_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input int    strategy_max_spread_points  = 0;

// -----------------------------------------------------------------------------
// Basket constants — 7 USD-major .DWX pairs for MTD ranking
// -----------------------------------------------------------------------------

const string QM10892_PAIRS[7] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX",
   "USDJPY.DWX","USDCHF.DWX","USDCAD.DWX"
  };

// -----------------------------------------------------------------------------
// File-scope state (per-bar, reset on month change)
// -----------------------------------------------------------------------------

int  g_prev_bar_month_key  = -1;    // year*100+mon of last processed bar
bool g_cycle_fired          = false; // true once entry fired this month-end cycle
bool g_exit_pending         = false; // true after first bar of new month; close next bar

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int QM10892_PairSlot(const string symbol)
  {
   for(int i = 0; i < 7; ++i)
      if(QM10892_PAIRS[i] == symbol) return i;
   return -1;
  }

int QM10892_LastDayOfMonth(int year, int mon)
  {
   const int days[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
   if(mon == 2)
     {
      bool leap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
      return leap ? 29 : 28;
     }
   return days[mon - 1];
  }

// Returns number of weekday-days AFTER current_day in the given month
int QM10892_WeekdaysRemaining(int year, int mon, int day)
  {
   int last = QM10892_LastDayOfMonth(year, mon);
   int count = 0;
   for(int d = day + 1; d <= last; ++d)
     {
      MqlDateTime chk;
      chk.year = year; chk.mon = mon; chk.day = d;
      chk.hour = 12;   chk.min = 0;  chk.sec = 0;
      TimeToStruct(StructToTime(chk), chk);
      if(chk.day_of_week >= 1 && chk.day_of_week <= 5)
         ++count;
     }
   return count;
  }

bool QM10892_HasPosition()
  {
   const long my_magic = (long)QM_FrameworkMagic();
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == my_magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

void QM10892_CloseAll()
  {
   const long my_magic = (long)QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != my_magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// Compute the MTD cross-sectional signal for _Symbol.
// Returns +1 (long), -1 (short), 0 (no trade / middle-group).
// MTD return = (last_closed_D1_close) / (first-bar-of-month open) - 1
// Gated by QM_IsNewBar in the caller; iOpen/iClose are perf-allowed here.
int QM10892_ComputeSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   MqlDateTime ms;
   ms.year = dt.year; ms.mon = dt.mon; ms.day = 1;
   ms.hour = 0;       ms.min = 0;      ms.sec = 0;
   datetime month_start = StructToTime(ms);

   int self_slot = QM10892_PairSlot(_Symbol);
   if(self_slot < 0) return 0;

   double mtd[7];
   for(int i = 0; i < 7; ++i)
     {
      int bar_ms = iBarShift(QM10892_PAIRS[i], PERIOD_D1, month_start, false); // perf-allowed
      if(bar_ms < 1) return 0;

      double base = iOpen(QM10892_PAIRS[i],  PERIOD_D1, bar_ms); // perf-allowed
      double cur  = iClose(QM10892_PAIRS[i], PERIOD_D1, 1);      // perf-allowed
      if(base <= 0.0 || cur <= 0.0) return 0;

      mtd[i] = (cur / base) - 1.0;
     }

   // Bubble-sort indices descending by MTD return
   int order[7];
   for(int i = 0; i < 7; ++i) order[i] = i;
   for(int a = 0; a < 6; ++a)
      for(int b = 0; b < 6 - a; ++b)
         if(mtd[order[b]] < mtd[order[b + 1]])
           {
            int t = order[b]; order[b] = order[b + 1]; order[b + 1] = t;
           }

   // order[0..1] = top-2 overperformers → SHORT
   for(int r = 0; r < 2; ++r)
      if(order[r] == self_slot) return -1;

   // order[5..6] = bottom-2 underperformers → LONG
   for(int r = 5; r < 7; ++r)
      if(order[r] == self_slot) return  1;

   return 0; // middle group — no trade
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(QM10892_PairSlot(_Symbol) < 0)
      return true;
   if(strategy_max_spread_points > 0 &&
      (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_key = dt.year * 100 + dt.mon;

   // --- Exit path (deferred): close at END of first trading day of new month ---
   // g_exit_pending is set on the first bar of new month; close fires on the
   // NEXT bar (= start of second trading day = end of first trading day).
   if(g_exit_pending)
     {
      QM10892_CloseAll();
      g_exit_pending = false;
      QM_LogEvent(QM_INFO, "MTD_EXIT",
                  StringFormat("{\"action\":\"close_all\",\"slot\":%d,\"reason\":\"month_end_exit\"}",
                               qm_magic_slot_offset));
     }

   // --- Detect new month ---
   if(g_prev_bar_month_key > 0 && current_key != g_prev_bar_month_key)
     {
      // First bar of new month — schedule exit for next bar
      g_exit_pending = true;
      g_cycle_fired  = false;
     }
   g_prev_bar_month_key = current_key;

   // --- No new entry when exit is pending or already fired this cycle ---
   if(g_exit_pending || g_cycle_fired || QM10892_HasPosition())
      return false;

   // --- D-3 check: exactly 2 weekday-days remaining after today ---
   int remaining = QM10892_WeekdaysRemaining(dt.year, dt.mon, dt.day);
   if(remaining != 2)
      return false;

   // --- Cross-sectional MTD ranking ---
   int signal = QM10892_ComputeSignal();
   if(signal == 0)
      return false;

   // --- Build entry request ---
   req.type  = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = QM_OrderTypeIsBuy(req.type) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(req.price <= 0.0) return false;

   req.sl = QM_StopATR(_Symbol, req.type, req.price,
                        strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0) return false;

   req.tp                 = 0.0;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason             = StringFormat("MTD_REV_%s_slot%d",
                                         (signal > 0) ? "LONG" : "SHORT",
                                         qm_magic_slot_offset);

   g_cycle_fired = true;

   QM_LogEvent(QM_INFO, "MTD_ENTRY",
               StringFormat("{\"action\":\"entry\",\"side\":\"%s\",\"slot\":%d,\"remaining_days\":%d}",
                            (signal > 0) ? "BUY" : "SELL",
                            qm_magic_slot_offset,
                            remaining));
   return true;
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal() { return false; }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2
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

   string basket[7];
   for(int i = 0; i < 7; ++i)
      basket[i] = QM10892_PAIRS[i];
   QM_SymbolGuardInit(basket);
   QM_BasketWarmupHistory(basket, PERIOD_D1, 100);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"card\":\"QM5_10892_el-d3-t11-month-end-rev\",\"slot\":%d}",
                            qm_magic_slot_offset));
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
