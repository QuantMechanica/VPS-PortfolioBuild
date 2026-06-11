#property strict
#property version   "5.0"
#property description "QM5_9638 DeMark TD Termination Active H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9638 — DeMark TD Termination Active H4
// Card: artifacts/cards_approved/QM5_9638_demark-td-termination-active-h4.md
// Source: ForexFactory DeMark thread / Thomas DeMark publication lineage
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9638;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;   // ATR period for SL/filter
input double strategy_sl_atr_buffer       = 0.25; // SL buffer = N * ATR beyond sequence extreme
input double strategy_tp_r_multiple       = 2.0;  // TP = entry + N * risk (R)
input int    strategy_time_stop_bars      = 16;   // Exit after N H4 bars
input int    strategy_max_span_bars       = 30;   // Max bars from count-1 to count-9
input double strategy_min_range_atr       = 1.5;  // Ignore if seq range < N * ATR

// =============================================================================
// TD count state — persistent across ticks, updated once per closed bar
// =============================================================================

// BUY (long exhaustion → bullish reversal)
static int    g_long_count    = 0;
static double g_long_lows[9];         // lows of the 9 counted bars (index 0..8)
static int    g_long_span     = 0;    // bars elapsed since count bar 0
static double g_long_seq_low  = 0.0;  // lowest low of the current sequence
static double g_long_seq_high = 0.0;  // highest high of the current sequence

// SELL (high exhaustion → bearish reversal)
static int    g_short_count   = 0;
static double g_short_highs[9];       // highs of the 9 counted bars
static int    g_short_span    = 0;
static double g_short_seq_low = 0.0;
static double g_short_seq_high = 0.0;

// Signal state — cleared and recomputed each new bar
static bool   g_long_signal   = false;
static double g_long_sl_price = 0.0;

static bool   g_short_signal  = false;
static double g_short_sl_price = 0.0;

// =============================================================================

void ResetLongCount()
  {
   g_long_count    = 0;
   g_long_span     = 0;
   g_long_seq_low  = 0.0;
   g_long_seq_high = 0.0;
   ArrayInitialize(g_long_lows, 0.0);
  }

void ResetShortCount()
  {
   g_short_count    = 0;
   g_short_span     = 0;
   g_short_seq_low  = 0.0;
   g_short_seq_high = 0.0;
   ArrayInitialize(g_short_highs, 0.0);
  }

// Called once per closed H4 bar (from Strategy_EntrySignal, which only runs
// when QM_IsNewBar() is true in the framework wiring).
void AdvanceState_OnNewBar()
  {
   g_long_signal  = false;
   g_short_signal = false;

   // Increment span counters (measure elapsed bars since count started)
   if(g_long_count > 0)  g_long_span++;
   if(g_short_count > 0) g_short_span++;

   // Enforce 30-bar window: reset if count started too long ago
   if(g_long_span  > strategy_max_span_bars && g_long_count  < 9) ResetLongCount();
   if(g_short_span > strategy_max_span_bars && g_short_count < 9) ResetShortCount();

   // TD sequential count requires raw OHLC at bounded shift offsets (5 reads, once per bar)
   const double cl1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: bespoke TD count, bounded shift
   const double cl2 = iClose(_Symbol, PERIOD_H4, 2); // perf-allowed: bespoke TD count, bounded shift
   const double cl5 = iClose(_Symbol, PERIOD_H4, 5); // perf-allowed: bespoke TD count, bounded shift
   const double lo1 = iLow(_Symbol,   PERIOD_H4, 1); // perf-allowed: bespoke TD count, bounded shift
   const double hi1 = iHigh(_Symbol,  PERIOD_H4, 1); // perf-allowed: bespoke TD count, bounded shift

   if(cl1 <= 0.0 || cl5 <= 0.0) return;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0) return;

   // --- BUY COUNT: Close[t] < Close[t+4], low progressing lower ---
   if(cl1 < cl5)
     {
      bool low_ok;
      if(g_long_count == 0)
         low_ok = true;
      else if(g_long_count == 1)
         low_ok = (lo1 < g_long_lows[0]);
      else
         low_ok = (lo1 < g_long_lows[g_long_count - 1]) &&
                  (lo1 < g_long_lows[g_long_count - 2]);

      if(low_ok)
        {
         if(g_long_count == 0)
           {
            g_long_span     = 0;
            g_long_seq_low  = lo1;
            g_long_seq_high = hi1;
           }
         else
           {
            if(lo1 < g_long_seq_low)  g_long_seq_low  = lo1;
            if(hi1 > g_long_seq_high) g_long_seq_high = hi1;
           }
         g_long_lows[g_long_count] = lo1;
         g_long_count++;

         if(g_long_count == 9)
           {
            // Active termination: bar 9 closes back above bar immediately before it
            // "bar t closes back above Close[t+1]" where t=shift1, t+1=shift2
            const bool active    = (cl1 > cl2);
            const double range   = g_long_seq_high - g_long_seq_low;
            const bool range_ok  = (range >= strategy_min_range_atr * atr);

            if(active && range_ok)
              {
               g_long_signal   = true;
               g_long_sl_price = g_long_seq_low - strategy_sl_atr_buffer * atr;
              }
            ResetLongCount();
           }
        }
     }

   // --- SELL COUNT: Close[t] > Close[t+4], high progressing higher ---
   if(cl1 > cl5)
     {
      bool high_ok;
      if(g_short_count == 0)
         high_ok = true;
      else if(g_short_count == 1)
         high_ok = (hi1 > g_short_highs[0]);
      else
         high_ok = (hi1 > g_short_highs[g_short_count - 1]) &&
                   (hi1 > g_short_highs[g_short_count - 2]);

      if(high_ok)
        {
         if(g_short_count == 0)
           {
            g_short_span     = 0;
            g_short_seq_low  = lo1;
            g_short_seq_high = hi1;
           }
         else
           {
            if(lo1 < g_short_seq_low)  g_short_seq_low  = lo1;
            if(hi1 > g_short_seq_high) g_short_seq_high = hi1;
           }
         g_short_highs[g_short_count] = hi1;
         g_short_count++;

         if(g_short_count == 9)
           {
            // Active termination: bar 9 closes back below bar immediately before it
            const bool active   = (cl1 < cl2);
            const double range  = g_short_seq_high - g_short_seq_low;
            const bool range_ok = (range >= strategy_min_range_atr * atr);

            if(active && range_ok)
              {
               g_short_signal   = true;
               g_short_sl_price = g_short_seq_high + strategy_sl_atr_buffer * atr;
              }
            ResetShortCount();
           }
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // No additional filter beyond framework news/Friday guards
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance bar state (runs once per new H4 bar — framework gates on QM_IsNewBar)
   AdvanceState_OnNewBar();

   // One position per magic is enforced by QM_Entry (REJECTED_DUPLICATE),
   // but skip early to avoid computing entry for no reason
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   if(g_long_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl    = g_long_sl_price;
      if(entry <= sl) return false;  // invalid geometry
      const double risk  = entry - sl;
      req.type             = QM_BUY;
      req.price            = 0.0;   // market
      req.sl               = NormalizeDouble(sl, _Digits);
      req.tp               = NormalizeDouble(entry + strategy_tp_r_multiple * risk, _Digits);
      req.reason           = "TD_LONG_TERM9";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   if(g_short_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl    = g_short_sl_price;
      if(sl <= entry) return false;  // invalid geometry
      const double risk  = sl - entry;
      req.type             = QM_SELL;
      req.price            = 0.0;   // market
      req.sl               = NormalizeDouble(sl, _Digits);
      req.tp               = NormalizeDouble(entry - strategy_tp_r_multiple * risk, _Digits);
      req.reason           = "TD_SHORT_TERM9";
      req.symbol_slot      = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No active management — SL/TP handle the primary exits
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time stop: exit after strategy_time_stop_bars H4 bars
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((TimeCurrent() - open_time) / (4 * 3600));
      if(bars_held >= strategy_time_stop_bars) return true;

      // Opposite TD termination exit
      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY  && g_short_signal) return true;
      if(pt == POSITION_TYPE_SELL && g_long_signal)  return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;  // defer to framework 2-axis news filter
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

   ResetLongCount();
   ResetShortCount();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9638\",\"strategy\":\"demark-td-termination-active-h4\"}");
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
