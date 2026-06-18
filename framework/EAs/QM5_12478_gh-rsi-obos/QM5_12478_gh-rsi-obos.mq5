#property strict
#property version   "5.0"
#property description "QM5_12478 gh-rsi-obos — RSI Overbought/Oversold mean-reversion (symmetric long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12478 gh-rsi-obos
// -----------------------------------------------------------------------------
// Source: je-suis-tm, quant-trading "RSI Pattern Recognition backtest.py"
//   https://github.com/je-suis-tm/quant-trading/blob/master/RSI%20Pattern%20Recognition%20backtest.py
// Card: artifacts/cards_approved/QM5_12478_gh-rsi-obos.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, daily, closed-bar reads at shift 1):
//   Entry EVENT (long) : RSI crosses DOWN through the oversold level
//                        (rsi@2 >= os_level AND rsi@1 < os_level).
//   Entry EVENT (short): RSI crosses UP through the overbought level
//                        (rsi@2 <= ob_level AND rsi@1 > ob_level).
//   The cross is ONE trigger event per bar — never a level STATE — so the
//   two-cross-same-bar zero-trade trap cannot fire (long and short triggers
//   are mutually exclusive by construction).
//   Exit STATE (long) : RSI@1 >= exit_level (midpoint, default 50).
//   Exit STATE (short): RSI@1 <= exit_level.
//   Emergency stop     : stop_atr_mult * ATR(atr_period) from entry (hard SL).
//   Time stop          : close after time_stop_bars completed bars if RSI has
//                        not yet normalized through the midpoint.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12478;
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
input int    strategy_rsi_period        = 14;     // RSI lookback (Wilder smoothing)
input double strategy_rsi_oversold      = 30.0;   // long entry: RSI crosses down through this
input double strategy_rsi_overbought    = 70.0;   // short entry: RSI crosses up through this
input double strategy_rsi_exit_level    = 50.0;   // midpoint exit level (RSI normalized)
input int    strategy_atr_period        = 20;     // ATR period for the emergency stop
input double strategy_stop_atr_mult     = 2.5;    // emergency stop distance = mult * ATR
input int    strategy_time_stop_bars    = 10;     // close after N completed bars if not normalized
input int    strategy_warmup_bars       = 50;     // minimum bars before any entry
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — RSI/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric long/short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Warmup guard: enough closed history for stable RSI/ATR.
   if(Bars(_Symbol, _Period) < strategy_warmup_bars)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // RSI at the last closed bar (shift 1) and the bar before it (shift 2).
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   // --- Long EVENT: RSI crosses DOWN into oversold (one event per bar) ---
   const bool crossed_oversold = (rsi_prev >= strategy_rsi_oversold &&
                                  rsi_now  <  strategy_rsi_oversold);
   // --- Short EVENT: RSI crosses UP into overbought ---
   const bool crossed_overbought = (rsi_prev <= strategy_rsi_overbought &&
                                    rsi_now  >  strategy_rsi_overbought);

   // Mutually exclusive (os_level < ob_level), so no two-cross-same-bar trap.
   if(crossed_oversold)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP; exit on midpoint normalization / time stop
      req.reason = "rsi_obos_long";
      return true;
     }

   if(crossed_overbought)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "rsi_obos_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. Midpoint + time-stop
// exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: RSI normalized through the midpoint (STATE), or time stop exceeded.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   // Locate this EA's open position to read its direction + open time.
   bool   is_long      = false;
   bool   have_pos     = false;
   datetime open_time  = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // Midpoint normalization (STATE), direction-aware.
   if(is_long && rsi_now >= strategy_rsi_exit_level)
      return true;
   if(!is_long && rsi_now <= strategy_rsi_exit_level)
      return true;

   // Time stop: number of completed bars since the entry bar.
   // Bar 1 is the last closed bar; the entry-bar open time is <= open_time.
   const datetime last_closed = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(open_time > 0 && last_closed > 0)
     {
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const int bars_held = (int)((last_closed - open_time) / secs_per_bar);
         if(bars_held >= strategy_time_stop_bars)
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
