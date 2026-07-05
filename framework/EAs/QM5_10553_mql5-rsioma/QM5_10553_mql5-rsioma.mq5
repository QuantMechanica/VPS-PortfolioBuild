#property strict
#property version   "5.0"
#property description "QM5_10553 MQL5 RSIOMA histogram signal"

#include <QM/QM_Common.mqh>

// Card: Exp_RSIOMA (Nikolay Kositsin, MQL5 CodeBase #17054). The CodeBase page
// documents the histogram/signal-line/level-break mechanics but not the exact
// OMA smoothing formula; QM_RSI has no primitive for "RSI of an already-smoothed
// series". Most literal buildable reading (HR9): RSIOMA proxy = RSI(period) on
// closed-bar close, signal line = SMA(RSI, signal_period). See open_questions.
//
// v2 2026-07-05: rebuilt in place (DL-069) to fix STRATEGY_HANG_RECURRENT —
// v1's Strategy_ExitSignal() recomputed the RSIOMA/signal average on every tick
// (uncached, ~40 QM_RSI buffer reads/tick). Now cached once per closed bar per
// the Performance/Intraday Discipline pattern; per-tick path is O(1).

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10553;
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
input int    strategy_rsi_period        = 14;    // RSIOMA proxy: RSI(period) on closed-bar close
input int    strategy_signal_period     = 9;     // signal line: SMA(RSIOMA, period)
input double strategy_support_level     = 30.0;  // support level (short breakout trigger)
input double strategy_resistance_level  = 70.0;  // resistance level (long breakout trigger)
input bool   strategy_use_signal_cross  = true;  // mode: histogram/signal direction change
input bool   strategy_use_level_break   = true;  // mode: support/resistance breakout
input int    strategy_atr_period        = 14;    // P2 baseline stop
input double strategy_atr_sl_mult       = 2.0;   // P2 baseline: ATR(14) x2.0 hard stop
input double strategy_reward_r_multiple = 1.5;   // P2 baseline: 1.5R target
input bool   strategy_ma_filter_enabled = false; // optional MA trend filter
input int    strategy_ma_fast_period    = 50;
input int    strategy_ma_slow_period    = 200;
input int    strategy_max_spread_points = 0;     // 0 = disabled

// -----------------------------------------------------------------------------
// Per-closed-bar cached state. Populated ONCE per new bar by
// AdvanceState_OnNewBar(); every per-tick hook below reads these only.
// -----------------------------------------------------------------------------
double g_rsioma_now   = 0.0;
double g_rsioma_prev  = 0.0;
double g_signal_now   = 0.0;
double g_signal_prev  = 0.0;
double g_atr_now      = 0.0;
double g_ma_fast      = 0.0;
double g_ma_slow      = 0.0;
bool   g_state_ready  = false;
bool   g_long_signal  = false;
bool   g_short_signal = false;

// Called only from AdvanceState_OnNewBar() — never from the per-tick path.
double Strategy_RSIOMA(const int shift)
  {
   if(strategy_rsi_period <= 1)
      return 0.0;
   return QM_RSI(_Symbol, _Period, strategy_rsi_period, shift, PRICE_CLOSE);
  }

// Called only from AdvanceState_OnNewBar() — never from the per-tick path.
double Strategy_RSIOMASignal(const int shift)
  {
   if(strategy_signal_period <= 1)
      return Strategy_RSIOMA(shift);

   double sum = 0.0;
   int samples = 0;
   for(int i = shift; i < shift + strategy_signal_period; ++i)
     {
      const double value = Strategy_RSIOMA(i);
      if(value <= 0.0)
         continue;
      sum += value;
      samples++;
     }

   if(samples <= 0)
      return 0.0;
   return sum / (double)samples;
  }

// Advances all cached strategy state by one closed bar. Caller guarantees
// QM_IsNewBar() == true. Bounded cost (~2 x signal_period QM_RSI reads),
// runs once per bar — never per tick.
void AdvanceState_OnNewBar()
  {
   g_rsioma_now  = Strategy_RSIOMA(1);
   g_rsioma_prev = Strategy_RSIOMA(2);
   g_signal_now  = Strategy_RSIOMASignal(1);
   g_signal_prev = Strategy_RSIOMASignal(2);
   g_atr_now     = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   if(strategy_ma_filter_enabled)
     {
      g_ma_fast = QM_EMA(_Symbol, _Period, strategy_ma_fast_period, 1, PRICE_CLOSE);
      g_ma_slow = QM_EMA(_Symbol, _Period, strategy_ma_slow_period, 1, PRICE_CLOSE);
     }

   g_long_signal  = false;
   g_short_signal = false;

   g_state_ready = (g_rsioma_now > 0.0 && g_rsioma_prev > 0.0 &&
                    g_signal_now > 0.0 && g_signal_prev > 0.0);
   if(!g_state_ready)
      return;

   const bool long_signal_cross = strategy_use_signal_cross &&
                                  g_rsioma_prev <= g_signal_prev &&
                                  g_rsioma_now  >  g_signal_now;
   const bool long_level_break  = strategy_use_level_break &&
                                  g_rsioma_prev <= strategy_resistance_level &&
                                  g_rsioma_now  >  strategy_resistance_level;
   bool long_ok = long_signal_cross || long_level_break;
   if(long_ok && strategy_ma_filter_enabled)
      long_ok = (g_ma_fast > 0.0 && g_ma_slow > 0.0 && g_ma_fast > g_ma_slow);
   g_long_signal = long_ok;

   const bool short_signal_cross = strategy_use_signal_cross &&
                                   g_rsioma_prev >= g_signal_prev &&
                                   g_rsioma_now  <  g_signal_now;
   const bool short_level_break  = strategy_use_level_break &&
                                   g_rsioma_prev >= strategy_support_level &&
                                   g_rsioma_now  <  strategy_support_level;
   bool short_ok = short_signal_cross || short_level_break;
   if(short_ok && strategy_ma_filter_enabled)
      short_ok = (g_ma_fast > 0.0 && g_ma_slow > 0.0 && g_ma_fast < g_ma_slow);
   g_short_signal = short_ok;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — per-tick path below reads only cached scalars, O(1).
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   if(!g_state_ready || (!g_long_signal && !g_short_signal))
      return false;

   const QM_OrderType side = g_long_signal ? QM_BUY : QM_SELL;
   const double entry = g_long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || g_atr_now <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_reward_r_multiple <= 0.0)
      return false;

   const double sl_distance = g_atr_now * strategy_atr_sl_mult;
   req.type = side;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, g_atr_now, strategy_atr_sl_mult);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, sl_distance * strategy_reward_r_multiple);
   req.reason = g_long_signal ? "RSIOMA_BULL_BREAK" : "RSIOMA_BEAR_BREAK";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or scale-in logic.
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && g_short_signal)
      return true;
   if(have_short && g_long_signal)
      return true;
   return false;
  }

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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Single-consume per tick (QM_IsNewBar rule): latch once, reuse below so
   // the entry gate doesn't call it a second time and eat the new-bar event.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (opposite-signal reversal). Separate from SL/TP.
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

   // News blackout gates NEW entries only (below). Management/exit above keep
   // running through news windows per the 2026-07-02 audit finding.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
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
