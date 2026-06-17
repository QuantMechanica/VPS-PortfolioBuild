#property strict
#property version   "5.0"
#property description "QM5_11069 han-invert — Heiken Ashi Naive Inversion (D1 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11069 han-invert
// -----------------------------------------------------------------------------
// Source: EarnForex "Heiken Ashi Naive" (https://github.com/EarnForex/Heiken-Ashi-Naive)
// Card: artifacts/cards_approved/QM5_11069_han-invert.md (g0_status APPROVED).
//
// Mechanics (Inverted=true, D1, decisions on COMPLETED bars at shift 1/2):
//   Heiken Ashi candles are reconstructed deterministically from raw OHLC over a
//   bounded closed-bar window (ha_window bars), cached once per new D1 bar:
//     HAClose[s] = (O+H+L+C)/4
//     HAOpen[s]  = (HAOpen[s+1] + HAClose[s+1]) / 2   (seeded at window tail)
//     HAHigh[s]  = max(H, HAOpen[s], HAClose[s])
//     HALow[s]   = min(L, HAOpen[s], HAClose[s])
//
//   Entry (because Inverted=true the raw signal direction is flipped):
//     SHORT when HA[1] bullish (HAOpen<HAClose), HA[1] has no lower wick
//       (HALow==HAOpen within tol), body[1] > body[2], and HA[2] also bullish.
//     LONG  when HA[1] bearish (HAOpen>HAClose), HA[1] has no upper wick
//       (HAHigh==HAOpen within tol), body[1] > body[2], and HA[2] also bearish.
//
//   Exit (inverted close signal; reverse handled by closing then re-entering on
//   a later bar):
//     Close LONG  on a bullish-close signal: HA[1] & HA[2] both bullish AND
//       HA[1] has no lower wick.
//     Close SHORT on a bearish-close signal: HA[1] & HA[2] both bearish AND
//       HA[1] has no upper wick.
//
//   Stop: catastrophic ATR(atr_period) * atr_sl_mult hard stop (card V5 default;
//         the source places no hard SL — this bounds P2/P3 risk). No fixed TP;
//         the position is managed out by the HA close signal.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11069;
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
input int    strategy_ha_window         = 60;    // bounded HA reconstruction window (closed bars)
input double strategy_wick_tol_pct      = 0.0001;// "no wick" tolerance as % of price (HALow==HAOpen)
input int    strategy_atr_period        = 20;    // ATR period for catastrophic stop
input double strategy_atr_sl_mult       = 3.0;   // catastrophic stop = mult * ATR

// -----------------------------------------------------------------------------
// File-scope cached Heiken Ashi state (advanced once per closed D1 bar).
// Index convention mirrors raw-bar shifts: g_ha_*[s] = HA value at shift s.
// -----------------------------------------------------------------------------
double g_ha_open[];
double g_ha_high[];
double g_ha_low[];
double g_ha_close[];
bool   g_ha_ready = false;

// Recompute the bounded HA window from raw OHLC. Called ONCE per closed bar
// inside the QM_IsNewBar gate. Deterministic: the recursion is seeded at the
// oldest bar in the window with the conventional (open+close)/2.
void AdvanceState_OnNewBar()
  {
   g_ha_ready = false;
   const int win = strategy_ha_window;
   if(win < 4)
      return;
   if(Bars(_Symbol, _Period) < win + 2)
      return;

   if(ArraySize(g_ha_open) != win + 2)
     {
      ArrayResize(g_ha_open,  win + 2);
      ArrayResize(g_ha_high,  win + 2);
      ArrayResize(g_ha_low,   win + 2);
      ArrayResize(g_ha_close, win + 2);
     }

   // Seed at the deepest shift (oldest bar in the window).
   const int seed = win + 1;
   const double o_seed = iOpen(_Symbol, _Period, seed);   // perf-allowed: bounded closed-bar HA reconstruction
   const double c_seed = iClose(_Symbol, _Period, seed);  // perf-allowed
   if(o_seed <= 0.0 || c_seed <= 0.0)
      return;
   double ha_open_prev  = (o_seed + c_seed) / 2.0;
   double ha_close_prev = (o_seed + iHigh(_Symbol, _Period, seed) + iLow(_Symbol, _Period, seed) + c_seed) / 4.0;

   // Walk forward from the seed toward the most recent closed bar (shift 1).
   for(int s = seed - 1; s >= 1; --s)
     {
      const double o = iOpen(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar HA reconstruction
      const double h = iHigh(_Symbol, _Period, s);   // perf-allowed
      const double l = iLow(_Symbol, _Period, s);    // perf-allowed
      const double c = iClose(_Symbol, _Period, s);  // perf-allowed
      if(o <= 0.0 || c <= 0.0)
         return;

      const double ha_close = (o + h + l + c) / 4.0;
      const double ha_open  = (ha_open_prev + ha_close_prev) / 2.0;
      double ha_high = h;
      if(ha_open  > ha_high) ha_high = ha_open;
      if(ha_close > ha_high) ha_high = ha_close;
      double ha_low = l;
      if(ha_open  < ha_low) ha_low = ha_open;
      if(ha_close < ha_low) ha_low = ha_close;

      g_ha_open[s]  = ha_open;
      g_ha_high[s]  = ha_high;
      g_ha_low[s]   = ha_low;
      g_ha_close[s] = ha_close;

      ha_open_prev  = ha_open;
      ha_close_prev = ha_close;
     }

   g_ha_ready = true;
  }

// "No lower wick": HALow == HAOpen (bullish candle) within a price-scaled tol.
bool HA_NoLowerWick(const int s)
  {
   const double tol = (strategy_wick_tol_pct / 100.0) * g_ha_open[s];
   return (MathAbs(g_ha_low[s] - g_ha_open[s]) <= tol);
  }

// "No upper wick": HAHigh == HAOpen (bearish candle) within a price-scaled tol.
bool HA_NoUpperWick(const int s)
  {
   const double tol = (strategy_wick_tol_pct / 100.0) * g_ha_open[s];
   return (MathAbs(g_ha_high[s] - g_ha_open[s]) <= tol);
  }

bool HA_Bullish(const int s) { return (g_ha_open[s] < g_ha_close[s]); }
bool HA_Bearish(const int s) { return (g_ha_open[s] > g_ha_close[s]); }
double HA_Body(const int s)  { return MathAbs(g_ha_close[s] - g_ha_open[s]); }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No session/spread restriction for this D1 swing EA. Fail-open by design on
// .DWX zero modeled spread (no spread gate at all). News handled by framework.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Inverted Heiken Ashi naive entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_ha_ready)
      return false;

   const double body1 = HA_Body(1);
   const double body2 = HA_Body(2);
   if(!(body1 > body2))
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || entry_bid <= 0.0)
      return false;

   // SHORT: HA[1] bullish, no lower wick, HA[2] bullish (inverted -> sell).
   if(HA_Bullish(1) && HA_NoLowerWick(1) && HA_Bullish(2))
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry_bid, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP; HA close signal manages the exit
      req.reason = "han_invert_short";
      return true;
     }

   // LONG: HA[1] bearish, no upper wick, HA[2] bearish (inverted -> buy).
   if(HA_Bearish(1) && HA_NoUpperWick(1) && HA_Bearish(2))
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_sl_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "han_invert_long";
      return true;
     }

   return false;
  }

// No active trade management beyond the catastrophic ATR stop. Exit is the
// inverted HA close signal in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Inverted HA close signal, direction-aware:
//   Close LONG  on bullish-close: HA[1] & HA[2] bullish AND HA[1] no lower wick.
//   Close SHORT on bearish-close: HA[1] & HA[2] bearish AND HA[1] no upper wick.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ha_ready)
      return false;

   // Determine the direction of this EA's open position.
   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   if(have_long)
     {
      if(HA_Bullish(1) && HA_Bullish(2) && HA_NoLowerWick(1))
         return true;
     }
   if(have_short)
     {
      if(HA_Bearish(1) && HA_Bearish(2) && HA_NoUpperWick(1))
         return true;
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

   // Advance the bounded HA window once per closed bar (cheap, gated).
   AdvanceState_OnNewBar();

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
