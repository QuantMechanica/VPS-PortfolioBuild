#property strict
#property version   "5.0"
#property description "QM5_10209 TradingView ATR EMA Session Volatility Switch"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10209 TradingView ATR EMA Session Volatility Switch
// -----------------------------------------------------------------------------
// Source: TradingView `ATR EMA Strategy` (whitebear28). Mechanical rules:
//   * Compute ATR(25) and EMA(50) on the signal timeframe (M15/M30).
//   * Only act inside the configured intraday session.
//   * Long  : ATR(25) below long threshold  AND price crosses above EMA(50).
//   * Short : ATR(25) above short threshold AND price crosses below EMA(50).
//   * Exit  : first of TP (+/- tp_mult*ATR), SL (-/+ sl_mult*ATR), or session end.
//   * Respect a max-daily-trades cap.
//
// .DWX BACKTEST INVARIANTS honoured here:
//   * Session windows are BROKER time and DST-aware (TimeCurrent() is broker
//     time; DXZ broker = NY-Close GMT+2/+3, DST follows the US calendar). The
//     per-symbol default windows below are expressed in BROKER clock already
//     (US-index cash open 09:30 ET == broker ~16:30; DAX 09:00 CET == broker
//     ~10:00; London/FX/gold liquid hours == broker ~09:00). An exchange-clock
//     09:00-17:30 window applied raw to a US index would build the session in
//     dead hours -> zero trades, so we map per symbol. Overridable per setfile.
//   * Spread guard NEVER fails closed on zero spread: .DWX quotes ask==bid in
//     the tester. Only a genuinely wide spread blocks.
//   * QM_IsNewBar() is consumed once (framework OnTick), entry gated on closed
//     bars; EMA cross uses ONE trigger (the cross) + ATR regime as a STATE.
//   * ATR thresholds are price-unit dependent: defaults map to broker price
//     POINTS via ATR/point so per-symbol setfile thresholds stay scale-correct.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10209;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_CURRENT; // M15/M30 base TF from chart/setfile
input int    strategy_atr_period               = 25;            // ATR(25), source default
input int    strategy_ema_period               = 50;            // EMA(50), source default
input double strategy_long_atr_points_max       = 20.0;         // long allowed when ATR(points) < this
input double strategy_short_atr_points_min      = 25.0;         // short allowed when ATR(points) > this
input double strategy_sl_atr_mult              = 10.0;          // stop = sl_mult * ATR (source default)
input double strategy_tp_atr_mult              = 5.0;           // take = tp_mult * ATR (source default)
input int    strategy_max_daily_trades         = 3;             // source default daily cap
input double strategy_spread_atr_fraction      = 0.10;          // spread must be <= 10% of ATR stop distance
// Session window in BROKER time. -1 on all four => use per-symbol default
// (already broker-clock, DST-aware via TimeCurrent()). Override per setfile.
input int    strategy_session_start_hour       = -1;
input int    strategy_session_start_min        = -1;
input int    strategy_session_end_hour         = -1;
input int    strategy_session_end_min          = -1;

// -----------------------------------------------------------------------------
// Session helpers — all clock math on BROKER time (TimeCurrent()).
// -----------------------------------------------------------------------------

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   if(strategy_signal_tf == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)_Period;
   return strategy_signal_tf;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

// Per-symbol BROKER-time liquid session. The card's "09:00-17:30 exchange/server
// mapped to target symbol local liquid hours" maps to these broker windows.
// Returned hours/minutes are already broker-clock; TimeCurrent() supplies the
// DST-aware broker time directly (no further offset needed). A non-default
// setfile override (any field >= 0) takes precedence and is used verbatim.
void Strategy_ResolveSession(int &start_hour, int &start_min, int &end_hour, int &end_min)
  {
   start_hour = strategy_session_start_hour;
   start_min  = strategy_session_start_min;
   end_hour   = strategy_session_end_hour;
   end_min    = strategy_session_end_min;

   if(start_hour >= 0 && start_min >= 0 && end_hour >= 0 && end_min >= 0)
      return;

   // DAX cash session 09:00-17:30 CET == broker ~10:00-18:30.
   if(_Symbol == "GDAXI.DWX" || _Symbol == "GER40.DWX" || _Symbol == "DE30.DWX")
     {
      start_hour = 10; start_min = 0;
      end_hour   = 18; end_min   = 30;
      return;
     }

   // US index cash session 09:30-16:00 ET == broker ~16:30-23:00.
   if(_Symbol == "NDX.DWX" || _Symbol == "WS30.DWX" || _Symbol == "SP500.DWX")
     {
      start_hour = 16; start_min = 30;
      end_hour   = 23; end_min   = 0;
      return;
     }

   // FX / gold: London-into-NY liquid hours, broker ~09:00-17:30.
   start_hour = 9;  start_min = 0;
   end_hour   = 17; end_min   = 30;
  }

bool Strategy_InSession(const datetime broker_t)
  {
   int sh, sm, eh, em;
   Strategy_ResolveSession(sh, sm, eh, em);
   const int now_min   = Strategy_MinuteOfDay(broker_t);
   const int start_min = MathMax(0, MathMin(1439, sh * 60 + sm));
   const int end_min   = MathMax(0, MathMin(1439, eh * 60 + em));
   if(start_min == end_min)
      return true;
   if(start_min < end_min)
      return (now_min >= start_min && now_min < end_min);
   return (now_min >= start_min || now_min < end_min);
  }

bool Strategy_SessionEnded(const datetime broker_t)
  {
   int sh, sm, eh, em;
   Strategy_ResolveSession(sh, sm, eh, em);
   const int now_min   = Strategy_MinuteOfDay(broker_t);
   const int start_min = MathMax(0, MathMin(1439, sh * 60 + sm));
   const int end_min   = MathMax(0, MathMin(1439, eh * 60 + em));
   if(start_min == end_min)
      return false;
   if(start_min < end_min)
      return (now_min >= end_min);
   return (now_min >= end_min && now_min < start_min);
  }

// -----------------------------------------------------------------------------
// Position / daily-cap accounting.
// -----------------------------------------------------------------------------

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

int Strategy_TodayEntryCount()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   const datetime now = TimeCurrent();
   if(!HistorySelect(Strategy_DayStart(now), now))
      return Strategy_HasOpenPosition() ? 1 : 0;

   int count = 0;
   for(int i = 0; i < HistoryDealsTotal(); ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         ++count;
     }
   // Count the currently-open trade too (its closing deal isn't in history yet).
   if(Strategy_HasOpenPosition())
      ++count;
   return count;
  }

// Spread must be <= spread_atr_fraction * (sl_mult * ATR) price distance.
// NEVER fail-closed on zero spread: .DWX quotes ask==bid (zero modeled spread)
// in the tester, which is a VALID, tradeable condition.
bool Strategy_SpreadAllowed(const double atr_value)
  {
   if(atr_value <= 0.0 || strategy_sl_atr_mult <= 0.0 || strategy_spread_atr_fraction < 0.0)
      return false;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)        // zero-PRICE check is fine
      return false;
   if(ask <= bid)                      // ask==bid (zero spread) => allowed
      return true;
   const double max_spread = atr_value * strategy_sl_atr_mult * strategy_spread_atr_fraction;
   return ((ask - bid) <= max_spread);
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news). Entry-only gates: leaving them out of
// the exit path keeps EOD/session-end closes live even after the window ends.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_InSession(broker_now))
      return true;

   const double atr_value = QM_ATR(_Symbol, Strategy_Timeframe(), strategy_atr_period, 1);
   if(!Strategy_SpreadAllowed(atr_value))
      return true;

   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar() == true. EMA cross is the single
// trigger event; ATR regime is a concurrent STATE (per .DWX invariant: do not
// require two cross events on the same bar). Lots are sized by the framework
// risk model inside QM_TM_OpenPosition -> never computed inline here.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const ENUM_TIMEFRAMES tf = Strategy_Timeframe();
   const datetime broker_now = TimeCurrent();
   if(!Strategy_InSession(broker_now))
      return false;
   if(strategy_max_daily_trades > 0 && Strategy_TodayEntryCount() >= strategy_max_daily_trades)
      return false;

   const double atr_value = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(!Strategy_SpreadAllowed(atr_value))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || atr_value <= 0.0)
      return false;
   const double atr_points = atr_value / point;

   // Closed-bar EMA cross: bar 2 -> bar 1 transition relative to EMA(50).
   const double close_1 = iClose(_Symbol, tf, 1);
   const double close_2 = iClose(_Symbol, tf, 2);
   const double ema_1   = QM_EMA(_Symbol, tf, strategy_ema_period, 1);
   const double ema_2   = QM_EMA(_Symbol, tf, strategy_ema_period, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0 || ema_1 <= 0.0 || ema_2 <= 0.0)
      return false;

   const bool cross_up   = (close_2 <= ema_2 && close_1 > ema_1);
   const bool cross_down = (close_2 >= ema_2 && close_1 < ema_1);

   // Long: low-volatility regime permits longs on a bullish EMA cross.
   if(cross_up && atr_points < strategy_long_atr_points_max)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_sl_atr_mult);
      req.tp     = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_tp_atr_mult);
      req.reason = "ATR_EMA_SESSION_LONG";
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   // Short: high-volatility regime permits shorts on a bearish EMA cross.
   if(cross_down && atr_points > strategy_short_atr_points_min)
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_sl_atr_mult);
      req.tp     = QM_TakeATRFromValue(_Symbol, req.type, req.price, atr_value, strategy_tp_atr_mult);
      req.reason = "ATR_EMA_SESSION_SHORT";
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Trade Management. Card specifies fixed ATR SL/TP only — no trail/BE/partial.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close. Exit on the first of TP, SL (both broker-managed), or session end.
bool Strategy_ExitSignal()
  {
   return (Strategy_HasOpenPosition() && Strategy_SessionEnded(TimeCurrent()));
  }

// News Filter Hook (callable for Q09 News Impact phase). Defer to central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10209_tv-atr-ema-session\"}");
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (session end). Separate from broker SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Single-consume of QM_IsNewBar().
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled.
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
