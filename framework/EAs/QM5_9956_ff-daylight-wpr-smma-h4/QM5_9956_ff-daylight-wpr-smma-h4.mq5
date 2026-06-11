#property strict
#property version   "5.0"
#property description "QM5_9956 ForexFactory Daylight WPR Smoothed-MA H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9956 — ForexFactory Daylight WPR Smoothed-MA H4
// Card: QM5_9956_ff-daylight-wpr-smma-h4
// Source: LauraT, "Daylight Trading Strategy", ForexFactory, 2021
//
// Entry: Bullish daylight between SMMA(5) and SMMA(5,shift=5) on H4,
//        H4 close above green SMMA(5), and WPR subwindow SMMA(8) > SMMA(21)
//        by at least 2 pts. Enter within 3 bars of the first qualifying close.
// Exit:  TP at 1.2R, SL at 1.2*ATR or nearest 5-bar swing (whichever is closer),
//        or on opposite-daylight / opposite-WPR-cross, or after 12 H4 bars.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9956;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_wpr_period          = 14;    // Williams %R lookback period
input int    strategy_smma_period         = 5;     // Main chart SMMA period
input int    strategy_smma_shift          = 5;     // Red line: SMMA from this many bars before green
input int    strategy_wpr_smma_fast       = 8;     // Fast SMMA period applied to WPR values
input int    strategy_wpr_smma_slow       = 21;    // Slow SMMA period applied to WPR values
input int    strategy_atr_period          = 14;    // ATR period
input double strategy_daylight_mult       = 0.05;  // Min MA gap: must exceed mult * ATR(14)
input double strategy_sl_atr_mult         = 1.2;   // SL distance = mult * ATR(14)
input double strategy_tp_rr               = 1.2;   // TP = rr * R
input double strategy_entry_atr_mult      = 1.0;   // Skip if entry is farther than mult*ATR from green
input int    strategy_max_entry_bars      = 3;     // Max bars after first qualifying close to enter
input int    strategy_max_hold_bars       = 12;    // Time stop: bars (H4); 12 = 48 h
input int    strategy_swing_lookback      = 5;     // Bars to scan for swing-based SL
input double strategy_spread_atr_mult     = 0.12;  // Skip entry if spread > mult * ATR
input double strategy_wpr_min_sep         = 2.0;   // Min WPR SMMA separation to trigger

// -----------------------------------------------------------------------------
// Cached per-bar state
// -----------------------------------------------------------------------------

double   g_wpr_smma8       = -50.0;  // running SMMA(fast) of WPR  [-100..0]
double   g_wpr_smma21      = -50.0;  // running SMMA(slow) of WPR
bool     g_smma_inited     = false;
int      g_green_above_cnt = 0;      // consecutive bars meeting long setup
int      g_red_below_cnt   = 0;      // consecutive bars meeting short setup
datetime g_state_bar       = 0;      // bar timestamp of last state advancement

// -----------------------------------------------------------------------------
// One-time WPR SMMA initialisation from history
// -----------------------------------------------------------------------------

void InitSmmaFromHistory()
  {
   const int warmup = 3 * strategy_wpr_smma_slow;   // ~3 slow-SMMA periods for convergence
   double seed = QM_WPR(_Symbol, PERIOD_H4, strategy_wpr_period, warmup);
   if(seed == 0.0)
      seed = -50.0;
   g_wpr_smma8  = seed;
   g_wpr_smma21 = seed;

   for(int s = warmup - 1; s >= 1; --s)
     {
      double w = QM_WPR(_Symbol, PERIOD_H4, strategy_wpr_period, s);
      if(w == 0.0)
         w = g_wpr_smma8;
      g_wpr_smma8  = (g_wpr_smma8  * (strategy_wpr_smma_fast - 1) + w) / strategy_wpr_smma_fast;
      g_wpr_smma21 = (g_wpr_smma21 * (strategy_wpr_smma_slow - 1) + w) / strategy_wpr_smma_slow;
     }
   g_smma_inited = true;
  }

// -----------------------------------------------------------------------------
// Per-bar counter update for entry-window tracking
// -----------------------------------------------------------------------------

void UpdateBarCounters()
  {
   const double green = QM_SMMA(_Symbol, PERIOD_H4, strategy_smma_period, 1);
   const double red   = QM_SMMA(_Symbol, PERIOD_H4, strategy_smma_period, 1 + strategy_smma_shift);
   const double atr   = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || green <= 0.0 || red <= 0.0)
     {
      g_green_above_cnt = 0;
      g_red_below_cnt   = 0;
      return;
     }
   const double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: structural close-vs-MA
   if(close1 <= 0.0)
     {
      g_green_above_cnt = 0;
      g_red_below_cnt   = 0;
      return;
     }

   const bool day_long   = (green - red)  > strategy_daylight_mult * atr;
   const bool day_short  = (red   - green) > strategy_daylight_mult * atr;
   const bool wpr_long   = g_wpr_smma8 > g_wpr_smma21 + strategy_wpr_min_sep;
   const bool wpr_short  = g_wpr_smma8 < g_wpr_smma21 - strategy_wpr_min_sep;

   if(day_long && wpr_long && close1 > green)
      g_green_above_cnt = MathMin(g_green_above_cnt + 1, strategy_max_entry_bars + 1);
   else
      g_green_above_cnt = 0;

   if(day_short && wpr_short && close1 < red)
      g_red_below_cnt = MathMin(g_red_below_cnt + 1, strategy_max_entry_bars + 1);
   else
      g_red_below_cnt = 0;
  }

// -----------------------------------------------------------------------------
// Once-per-H4-bar state advancement (called from both ExitSignal and EntrySignal)
// -----------------------------------------------------------------------------

void EnsureStateAdvanced()
  {
   const datetime t0 = iTime(_Symbol, PERIOD_H4, 0); // perf-allowed: bar-advance gate
   if(t0 <= 0 || t0 == g_state_bar)
      return;
   g_state_bar = t0;

   if(!g_smma_inited)
     {
      InitSmmaFromHistory();
      UpdateBarCounters();
      return;
     }

   double w = QM_WPR(_Symbol, PERIOD_H4, strategy_wpr_period, 1);
   if(w == 0.0)
      w = g_wpr_smma8;
   g_wpr_smma8  = (g_wpr_smma8  * (strategy_wpr_smma_fast - 1) + w) / strategy_wpr_smma_fast;
   g_wpr_smma21 = (g_wpr_smma21 * (strategy_wpr_smma_slow - 1) + w) / strategy_wpr_smma_slow;

   UpdateBarCounters();
  }

// -----------------------------------------------------------------------------
// Trade Filter
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;
   const double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (spread > strategy_spread_atr_mult * atr);
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   EnsureStateAdvanced();

   if(g_green_above_cnt < 1 && g_red_below_cnt < 1)
      return false;

   const double atr   = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double green = QM_SMMA(_Symbol, PERIOD_H4, strategy_smma_period, 1);
   const double red   = QM_SMMA(_Symbol, PERIOD_H4, strategy_smma_period, 1 + strategy_smma_shift);
   if(atr <= 0.0 || green <= 0.0 || red <= 0.0)
      return false;

   // ---- Long ----------------------------------------------------------------
   if(g_green_above_cnt >= 1 && g_green_above_cnt <= strategy_max_entry_bars)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((ask - green) > strategy_entry_atr_mult * atr)
         return false;

      double sl_atr    = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
      double sl_struct = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_swing_lookback);

      double sl;
      if(sl_struct > 0.0 && sl_atr > 0.0)
         sl = MathMax(sl_atr, sl_struct);   // tighter (closer) stop wins
      else if(sl_struct > 0.0)
         sl = sl_struct;
      else
         sl = sl_atr;

      if(sl <= 0.0 || sl >= ask)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_rr);
      if(tp <= ask)
         return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "FF_DAYLIGHT_LONG";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // ---- Short ---------------------------------------------------------------
   if(g_red_below_cnt >= 1 && g_red_below_cnt <= strategy_max_entry_bars)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if((red - bid) > strategy_entry_atr_mult * atr)
         return false;

      double sl_atr    = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
      double sl_struct = QM_StopStructure(_Symbol, QM_SELL, bid, strategy_swing_lookback);

      double sl;
      if(sl_struct > 0.0 && sl_atr > 0.0)
         sl = MathMin(sl_atr, sl_struct);   // tighter (closer) stop wins
      else if(sl_struct > 0.0)
         sl = sl_struct;
      else
         sl = sl_atr;

      if(sl <= 0.0 || sl <= bid)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
      if(tp >= bid)
         return false;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "FF_DAYLIGHT_SHORT";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   // Card: no trailing stop or partial close; SL/TP and time stop handle exits.
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE pos_type  = POSITION_TYPE_BUY;
   datetime           pos_open  = 0;
   bool               have_pos  = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      pos_open = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos = true;
      break;
     }

   if(!have_pos)
      return false;

   // Time stop: 12 H4 bars = 48 hours
   if((TimeCurrent() - pos_open) >= (long)strategy_max_hold_bars * 4 * 3600L)
      return true;

   EnsureStateAdvanced();

   const double green = QM_SMMA(_Symbol, PERIOD_H4, strategy_smma_period, 1);
   const double red   = QM_SMMA(_Symbol, PERIOD_H4, strategy_smma_period, 1 + strategy_smma_shift);
   const double atr   = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(green <= 0.0 || red <= 0.0 || atr <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY)
     {
      const bool day_bearish = (red - green)  > strategy_daylight_mult * atr;
      const bool wpr_bearish = g_wpr_smma8 < g_wpr_smma21 - strategy_wpr_min_sep;
      return (day_bearish || wpr_bearish);
     }
   else
     {
      const bool day_bullish = (green - red)  > strategy_daylight_mult * atr;
      const bool wpr_bullish = g_wpr_smma8 > g_wpr_smma21 + strategy_wpr_min_sep;
      return (day_bullish || wpr_bullish);
     }
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------

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
