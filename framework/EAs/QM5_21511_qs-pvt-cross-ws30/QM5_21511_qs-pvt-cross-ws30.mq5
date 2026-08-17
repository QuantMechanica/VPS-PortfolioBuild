#property strict
#property version   "5.0"
#property description "QM5_21511 qs-pvt-cross-ws30 — PVT vs SMA cross (D1, WS30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_21511 qs-pvt-cross-ws30
// -----------------------------------------------------------------------------
// Source: QuantifiedStrategies.com "Price and Volume Trend (PVT) - Backtest
//   Strategy, Trading Rules, Settings, Returns (82% Win Rate)".
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_21511_qs-pvt-cross-ws30.md
//   (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1):
//   PVT    : cumulative index, seeded at 0 on the oldest bar of the compute
//            window, updates EVERY bar weighted by the % magnitude of the
//            price move: PVT[1] = PVT[2] + pct_change[1] * volume[1].
//            Recomputed fully from history once per new closed D1 bar (cheap:
//            <= pvt_ma_period+warmup_buffer iterations, gated so it never
//            repeats inside the same bar).
//   SMA_PVT: SMA(strategy_pvt_ma_period) of the PVT series itself, a plain
//            rolling-window mean (no seed/recursion needed, unlike an EMA).
//   Long EVENT : PVT crosses from <= SMA_PVT to > SMA_PVT, no position open.
//   Short EVENT: PVT crosses from >= SMA_PVT to < SMA_PVT, no position open.
//   Stop   : strategy_atr_sl_mult * ATR(strategy_atr_period) hard SL.
//   Exit   : opposite PVT/SMA cross (signal reversal, may flip same bar),
//            ATR stop, strategy_max_hold_bars time stop, framework Friday
//            close. No take-profit, no trailing, no partial close (v1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 21511;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pvt_ma_period     = 20;    // SMA period applied to the PVT series
input int    strategy_warmup_buffer     = 10;    // extra bars beyond the SMA period before trading
input int    strategy_atr_period        = 14;    // ATR period for the hard stop
input double strategy_atr_sl_mult       = 2.5;   // hard SL distance = mult * ATR
input int    strategy_max_hold_bars     = 45;    // stale-position time stop (D1 bars)
input double strategy_max_spread_points = 500;   // skip entry if spread exceeds this (points)

// -----------------------------------------------------------------------------
// PVT state — recomputed fully from history once per new closed D1 bar (cheap:
// pvt_ma_period+warmup_buffer iterations, gated by g_pvt_last_bar so it never
// repeats inside the same bar). Caches current (shift 1) and prior (shift 2)
// PVT and SMA(PVT) values for the cross checks used by both entry and exit.
// -----------------------------------------------------------------------------
double   g_pvt1 = 0.0, g_pvt2 = 0.0;
double   g_sma1 = 0.0, g_sma2 = 0.0;
bool     g_pvt_ready    = false;
datetime g_pvt_last_bar = 0;

// Recompute PVT and SMA(PVT) at shift 1 and shift 2 from
// `strategy_pvt_ma_period + strategy_warmup_buffer` bars of history. Seeds
// PVT at 0 on the oldest bar in the window (per card); SMA is a plain
// rolling-window mean, no recursive seeding needed. Idempotent per closed bar.
bool PVT_AdvanceClosedBar()
  {
   const datetime bar1_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar timestamp
   if(bar1_time <= 0)
      return false;
   if(bar1_time == g_pvt_last_bar)
      return g_pvt_ready; // already computed for this closed bar

   g_pvt_last_bar = bar1_time;
   g_pvt_ready    = false;

   const int period = strategy_pvt_ma_period;
   const int window  = period + strategy_warmup_buffer;
   if(period < 2 || window < 2 || strategy_warmup_buffer < 1)
      return false;
   if(Bars(_Symbol, _Period) < window + 2) // perf-allowed: gated once per closed bar, bounded window
      return false; // insufficient history for the seed + recursion window

   double pvt[];
   if(ArrayResize(pvt, window) != window)
      return false;

   pvt[0] = 0.0; // seed, per card: PVT[N] = 0 on the first bar after warm-up
   for(int k = 1; k < window; k++)
     {
      const int shift = window - k; // walks from (window-1) down to 1 as k increases
      const double close_now  = iClose(_Symbol, _Period, shift); // perf-allowed: bounded PVT recompute window
      const double close_prev = iClose(_Symbol, _Period, shift + 1); // perf-allowed: bounded PVT recompute window
      const double vol_now    = (double)iVolume(_Symbol, _Period, shift); // perf-allowed: bounded PVT recompute window
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;

      const double pct = (close_now - close_prev) / close_prev;
      pvt[k] = pvt[k - 1] + pct * vol_now;
     }

   double sma1 = 0.0;
   for(int i = window - period; i < window; i++)
      sma1 += pvt[i];
   sma1 /= period;

   double sma2 = 0.0;
   for(int i = window - 1 - period; i < window - 1; i++)
      sma2 += pvt[i];
   sma2 /= period;

   g_pvt1 = pvt[window - 1];
   g_pvt2 = pvt[window - 2];
   g_sma1 = sma1;
   g_sma2 = sma2;
   g_pvt_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread_points = (ask - bid) / _Point;
   if(spread_points > strategy_max_spread_points)
      return true;

   return false;
  }

// Entry. PVT/SMA state is advanced exactly once per closed bar here (single-
// consume, no re-sum); Strategy_ExitSignal reads the same cached values.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!PVT_AdvanceClosedBar())
      return false;

   // One open position per magic (both long and short share this cap).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const bool cross_up   = (g_pvt2 <= g_sma2 && g_pvt1 > g_sma1);
   const bool cross_down = (g_pvt2 >= g_sma2 && g_pvt1 < g_sma1);

   if(cross_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no take-profit in v1 (card)
      req.reason = "pvt_sma_cross_long";
      return true;
     }

   if(cross_down)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "pvt_sma_cross_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop / time stop / reversal
// exit, all handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite PVT/SMA cross (signal reversal) or stale-position
// time stop. Reads the PVT state cached by the entry hook — no re-sum.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const bool cross_up   = g_pvt_ready && (g_pvt2 <= g_sma2 && g_pvt1 > g_sma1);
   const bool cross_down = g_pvt_ready && (g_pvt2 >= g_sma2 && g_pvt1 < g_sma1);

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
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;

      if(strategy_max_hold_bars > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int open_shift = iBarShift(_Symbol, _Period, opened, false);
         if(open_shift >= strategy_max_hold_bars)
            return true;
        }
     }

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   g_pvt1 = 0.0; g_pvt2 = 0.0;
   g_sma1 = 0.0; g_sma2 = 0.0;
   g_pvt_ready    = false;
   g_pvt_last_bar = 0;

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
