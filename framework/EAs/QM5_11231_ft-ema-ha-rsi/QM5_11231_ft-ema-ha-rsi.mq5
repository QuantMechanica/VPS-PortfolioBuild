#property strict
#property version   "5.0"
#property description "QM5_11231 ft-ema-ha-rsi — Freqtrade EMA/Heikin-Ashi/RSI profit-exit (long-only, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11231 ft-ema-ha-rsi
// -----------------------------------------------------------------------------
// Source: Freqtrade community Strategy001_custom_exit.py (Gerald Lonlas,
//   froggleston; repo freqtrade/freqtrade-strategies, commit dbd5b0b2…).
// Card: artifacts/cards_approved/QM5_11231_ft-ema-ha-rsi.md (g0_status APPROVED).
//
// Mechanics (long-only, M5, closed-bar reads at shift >= 1):
//   Entry TRIGGER (event): EMA(fast=20) crosses above EMA(mid=50) at shift 1.
//   Entry STATE filters   : Heikin-Ashi close(1) > EMA(20)   AND
//                           Heikin-Ashi candle green: ha_open(1) < ha_close(1).
//   One open position per magic.
//
//   Exits (any of the following closes the position):
//     a) Signal exit STATE : EMA(50) > EMA(100)  AND  HA close(1) < EMA(20)
//                            AND HA candle red: ha_open(1) > ha_close(1).
//                            (Per .DWX invariant #4 the EMA50/EMA100 relation is
//                            a STATE, not a second same-bar cross event.)
//     b) RSI custom exit   : RSI(14,1) > rsi_exit_level AND open PnL > 0.
//     c) ROI table         : time-decaying min-profit target (source ROI
//                            {0:0.05, 20:0.04, 30:0.03, 60:0.01} minutes->frac).
//   Protective stop (broker SL): min(source pct-stop distance, sl_atr_mult*ATR).
//
//   Heikin-Ashi is reconstructed deterministically from raw OHLC over a bounded
//   seeded window once per closed bar (no HA reader exists in the framework).
//
// Only the 5 Strategy_* hooks + the HA reconstruction + Strategy inputs are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11231;
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
input int    strategy_ema_fast_period   = 20;     // entry trigger fast EMA
input int    strategy_ema_mid_period    = 50;     // entry trigger / exit slow EMA
input int    strategy_ema_slow_period   = 100;    // signal-exit reference EMA
input int    strategy_rsi_period        = 14;     // RSI lookback period
input double strategy_rsi_exit_level    = 70.0;   // RSI profit-exit threshold
input int    strategy_atr_period        = 14;     // ATR period for protective stop
input double strategy_sl_atr_mult       = 3.0;    // emergency stop = mult * ATR
input double strategy_source_stop_pct   = 10.0;   // source percentage stop (-0.10)
input int    strategy_ha_seed_bars      = 200;    // bounded HA reconstruction window
// Source ROI table, minutes->min-profit-fraction {0:0.05,20:0.04,30:0.03,60:0.01}.
input double strategy_roi_0_frac        = 0.05;   // immediate profit target
input double strategy_roi_20_frac       = 0.04;   // after 20 min
input double strategy_roi_30_frac       = 0.03;   // after 30 min
input double strategy_roi_60_frac       = 0.01;   // after 60 min

// -----------------------------------------------------------------------------
// Heikin-Ashi closed-bar reconstruction (deterministic, bounded window).
// Cached once per closed bar. ha[1] = last closed bar, ha[2] = one before.
// -----------------------------------------------------------------------------
double g_ha_open_1  = 0.0;
double g_ha_close_1 = 0.0;
double g_ha_open_2  = 0.0;
double g_ha_close_2 = 0.0;
bool   g_ha_valid   = false;

// Reconstruct Heikin-Ashi open/close for shifts 1 and 2 from raw OHLC.
// HA_close = (O+H+L+C)/4 ; HA_open = (prev_HA_open + prev_HA_close)/2,
// seeded at the window start with (O+C)/2. Bounded by strategy_ha_seed_bars.
void HA_Recompute_OnNewBar()
  {
   g_ha_valid = false;

   int seed = strategy_ha_seed_bars;
   if(seed < 30)
      seed = 30;

   // Need shifts 1..(seed+1) available. Highest shift we read is seed+1.
   const int highest_shift = seed + 1;
   if(Bars(_Symbol, _Period) < highest_shift + 2)
      return;

   // Iterate from the oldest seed bar forward to shift 1. perf-allowed:
   // bespoke HA structural reconstruction, gated to once per closed bar.
   double prev_ha_open  = 0.0;
   double prev_ha_close = 0.0;
   bool   have_prev     = false;

   for(int s = highest_shift; s >= 1; --s)
     {
      const double o = iOpen(_Symbol, _Period, s);   // perf-allowed: HA seed window
      const double h = iHigh(_Symbol, _Period, s);   // perf-allowed
      const double l = iLow(_Symbol, _Period, s);    // perf-allowed
      const double c = iClose(_Symbol, _Period, s);  // perf-allowed
      if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
         return;

      const double ha_close = (o + h + l + c) / 4.0;
      double ha_open;
      if(!have_prev)
         ha_open = (o + c) / 2.0;                     // deterministic seed
      else
         ha_open = (prev_ha_open + prev_ha_close) / 2.0;

      if(s == 2)
        {
         g_ha_open_2  = ha_open;
         g_ha_close_2 = ha_close;
        }
      else if(s == 1)
        {
         g_ha_open_1  = ha_open;
         g_ha_close_1 = ha_close;
        }

      prev_ha_open  = ha_open;
      prev_ha_close = ha_close;
      have_prev     = true;
     }

   g_ha_valid = true;
  }

// -----------------------------------------------------------------------------
// ROI table: minimum profit fraction required to exit, given minutes held.
// -----------------------------------------------------------------------------
double ROI_MinFraction(const int minutes_held)
  {
   if(minutes_held >= 60)
      return strategy_roi_60_frac;
   if(minutes_held >= 30)
      return strategy_roi_30_frac;
   if(minutes_held >= 20)
      return strategy_roi_20_frac;
   return strategy_roi_0_frac;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard required by the card; fail-open on
// .DWX zero modeled spread (never block on zero spread).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_ha_valid)
      return false;

   // --- Trigger EVENT: EMA(fast) crosses above EMA(mid) at shift 1 ---
   const double fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double mid_1  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double mid_2  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 2);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || mid_1 <= 0.0 || mid_2 <= 0.0)
      return false;

   const bool crossed_up = (fast_2 <= mid_2 && fast_1 > mid_1);
   if(!crossed_up)
      return false;

   // --- STATE filter: Heikin-Ashi close(1) above EMA(fast=20) ---
   if(!(g_ha_close_1 > fast_1))
      return false;

   // --- STATE filter: Heikin-Ashi candle green (ha_open < ha_close) ---
   if(!(g_ha_open_1 < g_ha_close_1))
      return false;

   // --- Build the long entry. Framework sizes lots (NO lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   // Protective stop = min(source pct stop distance, sl_atr_mult * ATR).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double atr_distance = strategy_sl_atr_mult * atr_value;
   const double pct_distance  = (strategy_source_stop_pct / 100.0) * entry;
   double stop_distance = atr_distance;
   if(pct_distance > 0.0 && pct_distance < stop_distance)
      stop_distance = pct_distance;
   if(stop_distance <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, stop_distance, 1.0);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // exits via ROI / RSI / signal-state, not a fixed TP
   req.reason = "ft_ema_ha_rsi_long";
   return true;
  }

// ROI-table profit harvest. Runs every tick on the open position; reads cached
// HA/EMA state only (no history scans). Closes when elapsed-minute ROI met.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(open_price <= 0.0)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int minutes_held = (int)((TimeCurrent() - opened) / 60);
      if(minutes_held < 0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         continue;

      // Long-only: profit fraction relative to entry.
      const double profit_frac = (bid - open_price) / open_price;
      const double roi_target  = ROI_MinFraction(minutes_held);
      if(profit_frac >= roi_target)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         return;
        }
     }
  }

// Discretionary exits: (a) signal-exit STATE, (b) RSI profit exit.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // --- RSI custom profit exit: RSI(1) > level AND open PnL > 0 ---
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now > 0.0 && rsi_now > strategy_rsi_exit_level && QM_TM_OpenPnL(magic) > 0.0)
      return true;

   // --- Signal exit STATE: EMA(50) > EMA(100) AND HA close(1) < EMA(20)
   //     AND HA candle red (ha_open(1) > ha_close(1)) ---
   if(!g_ha_valid)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool mid_above_slow = (ema_mid > ema_slow);
   const bool ha_below_fast  = (g_ha_close_1 < ema_fast);
   const bool ha_red         = (g_ha_open_1 > g_ha_close_1);

   return (mid_above_slow && ha_below_fast && ha_red);
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

   // Advance closed-bar Heikin-Ashi reconstruction once per new closed bar.
   HA_Recompute_OnNewBar();

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
