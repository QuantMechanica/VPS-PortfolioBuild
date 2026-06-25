#property strict
#property version   "5.0"
#property description "QM5_11882 connors-double-7s — Double 7's mean reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11882 connors-double-7s
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "Short Term Trading Strategies That
// Work — A Quantified Guide to Trading Stocks and ETFs", 2009 — "Double 7's".
// Card: artifacts/cards_approved/QM5_11882_connors-double-7s.md
//       (g0_status APPROVED). Sister of QM5_11497; built to THIS card's params.
//
// Mechanics (D1, closed-bar reads at shift 1; long + symmetric short):
//   Trend STATE  : LONG when close[1] > SMA(sma_period); SHORT when below.
//                  The SMA is a regime STATE, never a second event on the bar.
//   Entry EVENT  : LONG  fires when close[1] is the LOWEST close of the last
//                  `extreme_lookback` closed bars (a new 7-day closing low) —
//                  the SINGLE trigger. SHORT mirrors: close[1] is the HIGHEST
//                  close (new 7-day closing high). One trigger per side per bar,
//                  so the two-cross-same-bar zero-trade trap cannot occur.
//   Exit EVENT   : LONG  exits when close[1] is the new 7-day HIGHEST close.
//                  SHORT exits when close[1] is the new 7-day LOWEST close.
//                  (Dynamic TP via the opposite 7-day extreme — no fixed TP.)
//   Stop loss    : LONG  entry - sl_atr_mult * ATR(atr_period);
//                  SHORT entry + sl_atr_mult * ATR(atr_period).
//                  Skip the trade when the stop distance exceeds max_sl_pips.
//   Max hold     : exit at the close of the `max_hold_bars`-th bar if neither
//                  the 7-day-extreme exit nor the stop has triggered (14 bars).
//
// The 7-day extreme is computed in-EA from bounded closed-bar closes (shift
// 1..extreme_lookback) — a tiny fixed loop, no CopyRates, no raw indicator
// handles. Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11882;
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
input int    strategy_lookback          = 7;     // 7-day closing extreme (Double 7's)
input int    strategy_regime_sma_period = 200;   // SMA200 regime / trend filter
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR
input int    strategy_atr_period        = 14;    // ATR period for the protective stop
input int    strategy_max_holding_bars  = 14;    // force exit after this many D1 bars

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// TRUE if close[1] is the lowest close of bars [1 .. lookback] (a new 7-day
// closing low). Bounded fixed loop over closed bars — no handles, no CopyRates.
bool IsNewLowestClose(const int lookback)
  {
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(c1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double cs = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(cs <= 0.0)
         return false;
      if(cs < c1)
         return false; // an earlier bar closed lower -> not a new 7-day low
     }
   return true;
  }

// TRUE if close[1] is the highest close of bars [1 .. lookback].
bool IsNewHighestClose(const int lookback)
  {
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(c1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double cs = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(cs <= 0.0)
         return false;
      if(cs > c1)
         return false; // an earlier bar closed higher -> not a new 7-day high
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// The card does not define additional time/spread filters. Framework-level
// kill switch, news, and Friday-close checks run outside this hook.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// LONG  : close[1] > SMA AND close[1] is a new 7-day closing low.
// SHORT : close[1] < SMA AND close[1] is a new 7-day closing high.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(strategy_lookback < 2 || strategy_regime_sma_period < 2 ||
      strategy_atr_period < 1 || strategy_sl_atr_mult <= 0.0)
      return false;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: price vs SMA200 on the closed bar ---
   const double sma    = QM_SMA(_Symbol, _Period, strategy_regime_sma_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sma <= 0.0 || close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // LONG: uptrend (close > SMA200) + new 7-day closing low (mean-reversion buy).
   if(close1 > sma && IsNewLowestClose(strategy_lookback))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // dynamic exit: new 7-day high close (Strategy_ExitSignal)
      req.reason = "double7s_long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   // SHORT: downtrend (close < SMA200) + new 7-day closing high (symmetric sell).
   if(close1 < sma && IsNewHighestClose(strategy_lookback))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;   // dynamic exit: new 7-day low close (Strategy_ExitSignal)
      req.reason = "double7s_short";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. The 7-day-extreme exit
// and the max-hold time stop live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit:
//   LONG  -> close[1] is a new 7-day HIGHEST close, OR max-hold elapsed.
//   SHORT -> close[1] is a new 7-day LOWEST  close, OR max-hold elapsed.
// One closed-bar evaluation per call (driven once per new bar from OnTick).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's position to read its direction + open time.
   bool   is_long   = false;
   bool   have_pos  = false;
   datetime open_tm = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_tm  = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // Max-hold time stop: count closed D1 bars elapsed since the entry bar.
   if(strategy_max_holding_bars > 0)
     {
      const int bars_since = iBarShift(_Symbol, _Period, open_tm, false); // perf-allowed: time stop
      if(bars_since >= strategy_max_holding_bars)
         return true;
     }

   // 7-day-extreme exit (mean reversion completed).
   if(is_long)
      return IsNewHighestClose(strategy_lookback);
   else
      return IsNewLowestClose(strategy_lookback);
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
