#property strict
#property version   "5.0"
#property description "QM5_9193 mql5-rsi-sweep — RSI Liquidity Sweep Reversal (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// Strategy: RSI Liquidity Sweep Reversal
// Detects RSI extremes (< 30 long, > 70 short), records the pivot candle's
// low/high as a liquidity level. After RSI recovers, waits for price to sweep
// (break) that level. On the first confirmation candle (bullish close above
// the swept low for long; bearish close below the swept high for short),
// enters with 2R TP and moves SL to break-even at +1R.
// Source: Israel Pelumi Abioye, Introduction to MQL5 Part 10, 2024-12-04
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9193;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period          = 14;   // RSI period
input double strategy_rsi_oversold        = 30.0; // oversold threshold
input double strategy_rsi_overbought      = 70.0; // overbought threshold
input int    strategy_extreme_valid_bars  = 20;   // bars RSI-recovered before sweep expires
input int    strategy_atr_period          = 14;   // ATR period for stop buffer
input double strategy_sl_atr_mult         = 0.25; // SL = swept_level ± ATR * mult
input double strategy_rr                  = 2.0;  // risk-reward for TP

// =============================================================================
// Per-bar state (advanced once per closed bar in Strategy_EntrySignal)
// =============================================================================
static int    g_long_phase   = 0;    // 0=IDLE 1=WATCH_SWEEP 2=WATCH_CONFIRM
static double g_long_ext_low = 0.0;  // low of the RSI-extreme bar (updated if RSI stays extreme)
static int    g_long_ext_bar = 0;    // bars since RSI returned above oversold
static double g_long_swept   = 0.0;  // the swept level (= ext_low at sweep time)
static int    g_long_sw_bar  = 0;    // bars since sweep (confirm grace window)

static int    g_short_phase    = 0;
static double g_short_ext_high = 0.0;
static int    g_short_ext_bar  = 0;
static double g_short_swept    = 0.0;
static int    g_short_sw_bar   = 0;

// Set true in EntrySignal when an opposite signal fires vs an open position;
// ExitSignal reads this flag on the next tick to close the position.
static bool   g_close_opposite = false;

// =============================================================================
// Internal helpers
// =============================================================================
bool HasOpenBuy()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) return true;
     }
   return false;
  }

bool HasOpenSell()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) return true;
     }
   return false;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Read last closed bar (bespoke liquidity-sweep detection — perf-allowed).
   const double rsi1  = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   const double low1  = iLow (_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
   const double cls1  = iClose(_Symbol, PERIOD_CURRENT, 1);// perf-allowed
   const double atr1  = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);

   // ── LONG state machine ──────────────────────────────────────────────────
   switch(g_long_phase)
     {
      case 0: // IDLE: wait for RSI oversold candle
         if(rsi1 < strategy_rsi_oversold)
           {
            g_long_phase   = 1;
            g_long_ext_low = low1;
            g_long_ext_bar = 0;
           }
         break;

      case 1: // WATCH_SWEEP: RSI recovered → check if price sweeps below extreme low
         if(rsi1 < strategy_rsi_oversold)
           {
            // Still in oversold zone: update to freshest (lowest) extreme
            if(low1 < g_long_ext_low)
               g_long_ext_low = low1;
            g_long_ext_bar = 0;
           }
         else
           {
            g_long_ext_bar++;
            if(g_long_ext_bar > strategy_extreme_valid_bars)
              {
               g_long_phase = 0; // expired without sweep
               break;
              }
            // RSI has recovered — check if price swept below extreme low
            if(low1 < g_long_ext_low)
              {
               g_long_swept  = g_long_ext_low;
               g_long_phase  = 2;
               g_long_sw_bar = 0;
               // Immediate confirmation: same bar swept AND closed back above swept level
               if(cls1 > g_long_swept)
                 {
                  if(HasOpenSell())
                    { g_close_opposite = true; g_long_phase = 0; break; }
                  if(!HasOpenBuy())
                    {
                     const double sl  = g_long_swept - atr1 * strategy_sl_atr_mult;
                     const double sld = (cls1 - sl) / _Point;
                     if(sld > 1.0)
                       {
                        req.type        = QM_BUY;
                        req.price       = 0;
                        req.sl          = sl;
                        req.tp          = cls1 + strategy_rr * (cls1 - sl);
                        req.reason      = "rsi_sweep_long_imm";
                        req.symbol_slot = 0;
                        g_long_phase    = 0;
                        return true;
                       }
                    }
                  g_long_phase = 0;
                 }
               // else: no immediate confirm; stay in phase 2 for next bar
              }
           }
         break;

      case 2: // WATCH_CONFIRM: first bullish close above swept level → entry
         g_long_sw_bar++;
         if(cls1 > g_long_swept)
           {
            if(HasOpenSell())
              { g_close_opposite = true; g_long_phase = 0; break; }
            if(!HasOpenBuy())
              {
               const double sl  = g_long_swept - atr1 * strategy_sl_atr_mult;
               const double sld = (cls1 - sl) / _Point;
               if(sld > 1.0)
                 {
                  req.type        = QM_BUY;
                  req.price       = 0;
                  req.sl          = sl;
                  req.tp          = cls1 + strategy_rr * (cls1 - sl);
                  req.reason      = "rsi_sweep_long";
                  req.symbol_slot = 0;
                  g_long_phase    = 0;
                  return true;
                 }
              }
            g_long_phase = 0;
           }
         if(g_long_sw_bar > 3)
            g_long_phase = 0; // grace window expired
         break;
     }

   // ── SHORT state machine ─────────────────────────────────────────────────
   switch(g_short_phase)
     {
      case 0: // IDLE: wait for RSI overbought candle
         if(rsi1 > strategy_rsi_overbought)
           {
            g_short_phase    = 1;
            g_short_ext_high = high1;
            g_short_ext_bar  = 0;
           }
         break;

      case 1: // WATCH_SWEEP: RSI recovered → check if price sweeps above extreme high
         if(rsi1 > strategy_rsi_overbought)
           {
            // Still in overbought zone: update to freshest (highest) extreme
            if(high1 > g_short_ext_high)
               g_short_ext_high = high1;
            g_short_ext_bar = 0;
           }
         else
           {
            g_short_ext_bar++;
            if(g_short_ext_bar > strategy_extreme_valid_bars)
              {
               g_short_phase = 0;
               break;
              }
            // RSI has recovered — check if price swept above extreme high
            if(high1 > g_short_ext_high)
              {
               g_short_swept  = g_short_ext_high;
               g_short_phase  = 2;
               g_short_sw_bar = 0;
               // Immediate confirmation: same bar swept AND closed back below swept level
               if(cls1 < g_short_swept)
                 {
                  if(HasOpenBuy())
                    { g_close_opposite = true; g_short_phase = 0; break; }
                  if(!HasOpenSell())
                    {
                     const double sl  = g_short_swept + atr1 * strategy_sl_atr_mult;
                     const double sld = (sl - cls1) / _Point;
                     if(sld > 1.0)
                       {
                        req.type        = QM_SELL;
                        req.price       = 0;
                        req.sl          = sl;
                        req.tp          = cls1 - strategy_rr * (sl - cls1);
                        req.reason      = "rsi_sweep_short_imm";
                        req.symbol_slot = 0;
                        g_short_phase   = 0;
                        return true;
                       }
                    }
                  g_short_phase = 0;
                 }
              }
           }
         break;

      case 2: // WATCH_CONFIRM: first bearish close below swept level → entry
         g_short_sw_bar++;
         if(cls1 < g_short_swept)
           {
            if(HasOpenBuy())
              { g_close_opposite = true; g_short_phase = 0; break; }
            if(!HasOpenSell())
              {
               const double sl  = g_short_swept + atr1 * strategy_sl_atr_mult;
               const double sld = (sl - cls1) / _Point;
               if(sld > 1.0)
                 {
                  req.type        = QM_SELL;
                  req.price       = 0;
                  req.sl          = sl;
                  req.tp          = cls1 - strategy_rr * (sl - cls1);
                  req.reason      = "rsi_sweep_short";
                  req.symbol_slot = 0;
                  g_short_phase   = 0;
                  return true;
                 }
              }
            g_short_phase = 0;
           }
         if(g_short_sw_bar > 3)
            g_short_phase = 0;
         break;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Move SL to break-even after +1R move (trigger = SL distance in points).
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl    = PositionGetDouble(POSITION_SL);
      const int    trig  = (int)(MathAbs(entry - sl) / _Point);
      if(trig > 0)
         QM_TM_MoveToBreakEven(ticket, trig, 2);
     }
  }

bool Strategy_ExitSignal()
  {
   if(g_close_opposite)
     {
      g_close_opposite = false;
      return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework news filter
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
