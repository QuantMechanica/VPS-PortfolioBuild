#property strict
#property version   "5.0"
#property description "QM5_1518 Hopwood Wilders Stoch Donchian H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1518;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf       = PERIOD_H4;
input int    strategy_ema_period        = 200;
input int    strategy_ema_slope_bars    = 5;
input int    strategy_donchian_period   = 20;
input int    strategy_pullback_bars     = 3;
input int    strategy_stoch_k_period    = 14;
input int    strategy_wilder_k_period   = 7;
input int    strategy_wilder_d_period   = 3;
input double strategy_oversold          = 25.0;
input double strategy_overbought        = 75.0;
input int    strategy_atr_period        = 14;
input int    strategy_atr_mean_bars     = 100;
input double strategy_atr_active_mult   = 0.5;
input double strategy_atr_sl_mult       = 1.5;
input int    strategy_cooldown_bars     = 16;
input int    strategy_time_stop_bars    = 30;
input double strategy_tp1_close_pct     = 0.60;
input int    strategy_warmup_bars       = 220;
input double strategy_spread_median_mult = 1.5;

datetime g_last_long_entry_bar = 0;
datetime g_last_short_entry_bar = 0;
datetime g_last_exit_eval_bar = 0;
bool     g_last_exit_signal = false;
double   g_pending_tp1 = 0.0;
datetime g_pending_entry_bar = 0;
ulong    g_managed_ticket = 0;
double   g_managed_tp1 = 0.0;
bool     g_managed_tp1_done = false;

double NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool OurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &volume, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

double DonchianUpper(const int shift)
  {
   double hi = -DBL_MAX;
   for(int i = shift; i < shift + strategy_donchian_period; ++i)
      hi = MathMax(hi, iHigh(_Symbol, strategy_tf, i));
   return (hi == -DBL_MAX) ? 0.0 : hi;
  }

double DonchianLower(const int shift)
  {
   double lo = DBL_MAX;
   for(int i = shift; i < shift + strategy_donchian_period; ++i)
      lo = MathMin(lo, iLow(_Symbol, strategy_tf, i));
   return (lo == DBL_MAX) ? 0.0 : lo;
  }

double DonchianMid(const int shift)
  {
   const double upper = DonchianUpper(shift);
   const double lower = DonchianLower(shift);
   if(upper <= 0.0 || lower <= 0.0)
      return 0.0;
   return (upper + lower) * 0.5;
  }

double RawStochK(const int shift)
  {
   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = shift; i < shift + strategy_stoch_k_period; ++i)
     {
      hi = MathMax(hi, iHigh(_Symbol, strategy_tf, i));
      lo = MathMin(lo, iLow(_Symbol, strategy_tf, i));
     }
   const double close = iClose(_Symbol, strategy_tf, shift);
   if(hi <= lo || close <= 0.0)
      return 50.0;
   return 100.0 * (close - lo) / (hi - lo);
  }

bool WilderStoch(const int shift, double &slow_k, double &slow_d)
  {
   const int warm = MathMax(strategy_warmup_bars, 60);
   const int oldest = shift + warm;
   double rma_k = 0.0;
   double rma_d = 0.0;
   bool seeded = false;

   for(int s = oldest; s >= shift; --s)
     {
      const double raw_k = RawStochK(s);
      if(!seeded)
        {
         rma_k = raw_k;
         rma_d = rma_k;
         seeded = true;
         continue;
        }
      rma_k = (rma_k * (strategy_wilder_k_period - 1) + raw_k) / strategy_wilder_k_period;
      rma_d = (rma_d * (strategy_wilder_d_period - 1) + rma_k) / strategy_wilder_d_period;
     }

   slow_k = rma_k;
   slow_d = rma_d;
   return seeded;
  }

double MeanATR()
  {
   if(strategy_atr_mean_bars <= 0)
      return 0.0;
   double sum = 0.0;
   int n = 0;
   for(int i = 1; i <= strategy_atr_mean_bars; ++i)
     {
      const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, i);
      if(atr <= 0.0)
         continue;
      sum += atr;
      ++n;
     }
   return (n > 0) ? (sum / n) : 0.0;
  }

bool RecentOppositeEntry(const bool bullish, const datetime bar_time)
  {
   const datetime opposite = bullish ? g_last_short_entry_bar : g_last_long_entry_bar;
   if(opposite <= 0)
      return false;
   const int bars = iBarShift(_Symbol, strategy_tf, opposite, false) - iBarShift(_Symbol, strategy_tf, bar_time, false);
   return (bars >= 0 && bars <= strategy_cooldown_bars);
  }

bool PullbackTagged(const bool bullish)
  {
   for(int s = 1; s <= strategy_pullback_bars; ++s)
     {
      const double mid = DonchianMid(s);
      if(mid <= 0.0)
         continue;
      if(bullish && iLow(_Symbol, strategy_tf, s) <= mid)
         return true;
      if(!bullish && iHigh(_Symbol, strategy_tf, s) >= mid)
         return true;
     }
   return false;
  }

bool SpreadAllowed()
  {
   long spreads[20];
   for(int i = 0; i < 20; ++i)
      spreads[i] = (long)iSpread(_Symbol, strategy_tf, i + 1);
   ArraySort(spreads);
   const double median = (spreads[9] + spreads[10]) * 0.5;
   const long current = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median <= 0.0 || current <= 0)
      return true;
   return ((double)current <= strategy_spread_median_mult * median);
  }

void RefreshManagedPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   datetime open_time;
   if(!OurPosition(ticket, ptype, open_price, volume, open_time))
     {
      g_managed_ticket = 0;
      g_managed_tp1 = 0.0;
      g_managed_tp1_done = false;
      return;
     }

   if(g_managed_ticket == ticket)
      return;

   g_managed_ticket = ticket;
   g_managed_tp1_done = false;
   if(g_pending_tp1 > 0.0)
      g_managed_tp1 = g_pending_tp1;
   else
     {
      const int shift = MathMax(1, iBarShift(_Symbol, strategy_tf, open_time, false));
      g_managed_tp1 = (ptype == POSITION_TYPE_BUY) ? DonchianUpper(shift) : DonchianLower(shift);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: warm-up, time availability, spread, and news hook are explicit V5 sections.
   if(Bars(_Symbol, strategy_tf) < strategy_warmup_bars)
      return true;
   if(!SpreadAllowed())
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime bar_time = iTime(_Symbol, strategy_tf, 1);
   if(bar_time <= 0)
      return false;

   double unused_volume;
   double unused_open;
   datetime unused_time;
   ulong unused_ticket;
   ENUM_POSITION_TYPE unused_type;
   if(OurPosition(unused_ticket, unused_type, unused_open, unused_volume, unused_time))
      return false;

   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double ema1 = QM_EMA(_Symbol, strategy_tf, strategy_ema_period, 1);
   const double ema_slope = QM_EMA(_Symbol, strategy_tf, strategy_ema_period, 1 + strategy_ema_slope_bars);
   const double donchian_upper = DonchianUpper(1);
   const double donchian_lower = DonchianLower(1);
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double atr_mean = MeanATR();
   if(close1 <= 0.0 || ema1 <= 0.0 || ema_slope <= 0.0 || donchian_upper <= 0.0 || donchian_lower <= 0.0 || atr <= 0.0 || atr_mean <= 0.0)
      return false;
   if(atr < strategy_atr_active_mult * atr_mean)
      return false;

   double k1, d1, k2, d2;
   if(!WilderStoch(1, k1, d1) || !WilderStoch(2, k2, d2))
      return false;

   const bool bullish =
      close1 > ema1 &&
      ema1 > ema_slope &&
      PullbackTagged(true) &&
      close1 < donchian_upper &&
      k2 < strategy_oversold &&
      k1 > k2 &&
      k1 > d1 &&
      k2 <= d2 &&
      !RecentOppositeEntry(true, bar_time);

   if(bullish)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizePrice(ask - strategy_atr_sl_mult * atr);
      req.tp = 0.0;
      req.reason = "WSTOCH_DONCHIAN_LONG";
      g_pending_tp1 = NormalizePrice(donchian_upper);
      g_pending_entry_bar = bar_time;
      g_last_long_entry_bar = bar_time;
      return (req.sl > 0.0);
     }

   const bool bearish =
      close1 < ema1 &&
      ema1 < ema_slope &&
      PullbackTagged(false) &&
      close1 > donchian_lower &&
      k2 > strategy_overbought &&
      k1 < k2 &&
      k1 < d1 &&
      k2 >= d2 &&
      !RecentOppositeEntry(false, bar_time);

   if(bearish)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizePrice(bid + strategy_atr_sl_mult * atr);
      req.tp = 0.0;
      req.reason = "WSTOCH_DONCHIAN_SHORT";
      g_pending_tp1 = NormalizePrice(donchian_lower);
      g_pending_entry_bar = bar_time;
      g_last_short_entry_bar = bar_time;
      return (req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   RefreshManagedPosition();
   if(g_managed_ticket == 0 || g_managed_tp1 <= 0.0 || g_managed_tp1_done)
      return;
   if(!PositionSelectByTicket(g_managed_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const bool tp1_hit = (ptype == POSITION_TYPE_BUY) ? (bid >= g_managed_tp1) : (ask <= g_managed_tp1);
   if(!tp1_hit || volume <= 0.0)
      return;

   if(QM_TM_PartialClose(g_managed_ticket, volume * strategy_tp1_close_pct, QM_EXIT_PARTIAL))
      g_managed_tp1_done = true;
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double volume;
   datetime open_time;
   if(!OurPosition(ticket, ptype, open_price, volume, open_time))
      return false;

   const int open_shift = iBarShift(_Symbol, strategy_tf, open_time, false);
   if(open_shift >= strategy_time_stop_bars && !g_managed_tp1_done)
      return true;

   const datetime bar0 = iTime(_Symbol, strategy_tf, 0);
   if(bar0 <= 0)
      return false;
   if(bar0 == g_last_exit_eval_bar)
      return g_last_exit_signal;
   g_last_exit_eval_bar = bar0;
   g_last_exit_signal = false;

   double k1, d1, k2, d2;
   if(!WilderStoch(1, k1, d1) || !WilderStoch(2, k2, d2))
      return false;

   if(ptype == POSITION_TYPE_BUY && k2 > strategy_overbought && k1 < k2)
      g_last_exit_signal = true;
   if(ptype == POSITION_TYPE_SELL && k2 < strategy_oversold && k1 > k2)
      g_last_exit_signal = true;

   return g_last_exit_signal;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: central V5 news engine handles the 60-minute NFP/ECB/FOMC blackout via QM_NEWS_PAUSE.
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
