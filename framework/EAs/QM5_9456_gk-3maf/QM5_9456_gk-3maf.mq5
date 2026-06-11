#property strict
#property version   "5.0"
#property description "QM5_9456 — Geraked Three MA Fractal Pullback (gk-3maf)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9456 — gk-3maf
// Three-EMA trend alignment (EMA60/350/600) with Williams Fractal pullback
// entry on M15. Buy when EMAs stack bullish and Low[1] pulls back into EMA60
// with a confirmed lower fractal at bar[2]. Sell mirror. TP = 1.5R, SL at
// EMA350 or EMA600. Time exit at 96 bars (24 h). Opposite-signal exit.
// Source: Geraked/Rabist, geraked/metatrader5, 3MAF.mq5 (GitHub).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9456;
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
input int    strategy_ma1_period         = 60;    // Fast EMA period
input int    strategy_ma2_period         = 350;   // Medium EMA period
input int    strategy_ma3_period         = 600;   // Slow EMA period
input double strategy_tp_coef           = 1.5;   // TP as multiple of SL distance (R)
input int    strategy_time_exit_bars     = 96;    // Max hold time in M15 bars
input int    strategy_min_stop_points    = 100;   // Min SL distance in points

// -----------------------------------------------------------------------------
// File-scope cached signal state — updated once per new bar in EntrySignal,
// read per-tick in ExitSignal (O(1), no per-tick indicator recompute).
// -----------------------------------------------------------------------------
bool g_buy_signal  = false;
bool g_sell_signal = false;

// -----------------------------------------------------------------------------
// Fractals helper — reads through QM_Indicators wrappers.
// -----------------------------------------------------------------------------
bool QM_FracActive(const int buffer_idx, const int shift)
  {
   // buffer 0 = upper fractal (peaks), buffer 1 = lower fractal (valleys)
   const double val = (buffer_idx == 0)
                      ? QM_FractalUpper(_Symbol, _Period, shift)
                      : QM_FractalLower(_Symbol, _Period, shift);
   return (val != 0.0 && val != EMPTY_VALUE && val > 0.0);
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
   // Initialise req defaults
   req.type              = QM_BUY;
   req.price             = 0.0;
   req.sl                = 0.0;
   req.tp                = 0.0;
   req.reason            = "";
   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // ---- Compute indicator values on last closed bar ----
   const double ema60  = QM_EMA(_Symbol, _Period, strategy_ma1_period, 1);
   const double ema350 = QM_EMA(_Symbol, _Period, strategy_ma2_period, 1);
   const double ema600 = QM_EMA(_Symbol, _Period, strategy_ma3_period, 1);
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar structural read, gated by QM_IsNewBar
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar structural read, gated by QM_IsNewBar

   // Fractal buffers: 1 = lower fractal, 0 = upper fractal; check bar[2]
   const bool frac_down_2 = QM_FracActive(1, 2);
   const bool frac_up_2   = QM_FracActive(0, 2);

   // ---- Update cached signal state ----
   g_buy_signal  = (ema60 > ema350 && ema350 > ema600 &&
                    low1 > ema600 && low1 < ema60 && frac_down_2);
   g_sell_signal = (ema600 > ema350 && ema350 > ema60 &&
                    high1 < ema600 && high1 > ema60 && frac_up_2);

   // ---- One position per symbol/magic (framework also enforces via REJECTED_DUPLICATE) ----
   const long magic = (long)QM_FrameworkMagic();
   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t) && PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   if(g_buy_signal)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      // SL: EMA350[1] if Low[1] > EMA350[1], else EMA600[1]
      const double sl_price = (low1 > ema350) ? ema350 : ema600;
      const double dist     = ask - sl_price;
      if(dist < strategy_min_stop_points * _Point)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl_price;
      req.tp     = ask + dist * strategy_tp_coef;
      req.reason = "3MAF_BUY";
      return true;
     }

   if(g_sell_signal)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // SL: EMA350[1] if High[1] < EMA350[1], else EMA600[1]
      const double sl_price = (high1 < ema350) ? ema350 : ema600;
      const double dist     = sl_price - bid;
      if(dist < strategy_min_stop_points * _Point)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl_price;
      req.tp     = bid - dist * strategy_tp_coef;
      req.reason = "3MAF_SELL";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // TP and SL fixed at entry; no trailing per card spec.
  }

bool Strategy_ExitSignal()
  {
   const long magic             = (long)QM_FrameworkMagic();
   const int  time_exit_seconds = strategy_time_exit_bars * 15 * 60; // 96 bars × 15 min

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time exit: 96 M15 bars elapsed
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(TimeCurrent() - open_time > time_exit_seconds)
         return true;

      // Opposite-signal exit (uses cached state from last new bar)
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && g_sell_signal)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_buy_signal)
         return true;
     }
   return false;
  }

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
