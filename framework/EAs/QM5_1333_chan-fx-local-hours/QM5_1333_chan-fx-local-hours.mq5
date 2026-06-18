#property strict
#property version   "5.0"
#property description "QM5_1333 Chan FX Local-Hours Depreciation"

// Ernie Chan "time-of-day effects in FX trading" (epchan.blogspot.com 2011-05-10):
// a currency tends to DEPRECIATE during its own domestic trading hours. The EA
// shorts the base currency at the START of that currency's local session and
// flattens at the END of the same session (no overnight hold).
//
// .DWX BACKTEST INVARIANTS honoured:
//  - Session windows are defined in UTC (per card) and compared against
//    QM_BrokerToUTC(TimeCurrent()) — DST-aware via the framework, NO hardcoded
//    server offset. (DXZ broker = NY-Close GMT+2 / GMT+3 during US DST.)
//  - Entry is ONE trigger EVENT: the first new bar at-or-after session start on
//    a given UTC day. The session WINDOW is a STATE used only for the exit.
//  - QM_IsNewBar() is consumed exactly once per tick (in the framework OnTick).
//  - Fail-OPEN spread guard (only blocks a genuinely wide positive spread).
//  - No swap gate. RISK_FIXED sizing. One position per magic.
//  - Catastrophic stop = strategy_atr_sl_mult * ATR(period, H1) from entry
//    (card baseline 1.5 * ATR(14,H1), swept in P3). No TP — exit is time-based
//    at session end.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1333;
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
// Local-session window in UTC. -1 => auto-pick from the symbol's base currency
// (EUR/GBP=London 07-16, JPY=Tokyo 00-09, AUD=Sydney 22-07, USD/CAD=NY 12-21).
// The per-symbol P2 setfiles set these explicitly; the auto default keeps the
// single binary correct on any registered symbol before the sweep.
input int    strategy_session_start_utc      = -1;     // session open hour [0..23], -1=auto
input int    strategy_session_end_utc        = -1;     // session close hour [0..24], -1=auto
// Trade the BASE currency's local-hours depreciation: -1=short base (card
// default), +1=long base. For X/USD pairs base is the LEFT currency, so short
// base = SELL the pair; for USD/X pairs base is USD.
input int    strategy_base_direction         = -1;     // -1 short base, +1 long base
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;     // catastrophic stop, card baseline
input int    strategy_min_sessions           = 90;      // require >=90 prior local sessions
input double strategy_max_spread_atr_frac     = 0.30;   // fail-OPEN wide-spread cap

// File-scope state (advanced once per closed bar via the framework new-bar gate).
int      g_last_entry_utc_yyyymmdd = 0;   // UTC day key of the last entry (one/day)
int      g_session_count           = 0;   // observed local-session opens so far (warmup)
int      g_last_counted_utc_day    = 0;   // de-dupe the session counter per UTC day

// Resolve the symbol's base currency (the LEFT currency of the pair, e.g. EUR in
// EURUSD, USD in USDJPY). Falls back to SYMBOL_CURRENCY_BASE when available.
string BaseCurrency()
  {
   string b = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   if(StringLen(b) >= 3)
      return StringSubstr(b, 0, 3);
   // Fallback: strip ".DWX" / suffix and take the first 3 chars.
   string s = _Symbol;
   if(StringLen(s) >= 3)
      return StringSubstr(s, 0, 3);
   return "";
  }

// Auto session window (UTC) for a base currency, per the card's defaults.
// Returns true and fills start/end when a default exists.
bool AutoSessionUTC(const string base, int &start_h, int &end_h)
  {
   if(base == "EUR" || base == "GBP") { start_h = 7;  end_h = 16; return true; }  // London/Europe 07-16
   if(base == "JPY")                  { start_h = 0;  end_h = 9;  return true; }  // Tokyo 00-09
   if(base == "AUD")                  { start_h = 22; end_h = 7;  return true; }  // Sydney/Tokyo 22-07 (wraps)
   if(base == "USD" || base == "CAD") { start_h = 12; end_h = 21; return true; }  // New York 12-21
   return false;
  }

// Effective session window (UTC hours) after applying inputs / auto-resolution.
bool EffectiveSessionUTC(int &start_h, int &end_h)
  {
   if(strategy_session_start_utc >= 0 && strategy_session_end_utc >= 0)
     {
      start_h = strategy_session_start_utc;
      end_h   = strategy_session_end_utc;
      return true;
     }
   return AutoSessionUTC(BaseCurrency(), start_h, end_h);
  }

// True if the given UTC hour is inside [start, end) — wrap-safe for windows that
// cross UTC midnight (e.g. Sydney 22-07).
bool HourInWindow(const int hour, const int start_h, const int end_h)
  {
   if(start_h == end_h)
      return false;
   if(start_h < end_h)
      return (hour >= start_h && hour < end_h);
   // wrap (e.g. 22..07): inside if >= start OR < end
   return (hour >= start_h || hour < end_h);
  }

// UTC "session day" key. For a wrapping window the session belongs to the UTC
// day on which it OPENS, so hours past midnight that are still in the wrapped
// window inherit the previous calendar day's key.
int SessionDayKeyUTC(const datetime utc_now, const int start_h, const int end_h)
  {
   datetime ref = utc_now;
   MqlDateTime u;
   ZeroMemory(u);
   TimeToStruct(ref, u);
   if(start_h > end_h && u.hour < end_h)
     {
      // post-midnight tail of a window that opened "yesterday": shift back a day
      ref -= 24 * 3600;
      TimeToStruct(ref, u);
     }
   return u.year * 10000 + u.mon * 100 + u.day;
  }

int MagicForThisEA() { return QM_FrameworkMagic(); }

bool HasOpenPosition()
  {
   const int magic = MagicForThisEA();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// No Trade Filter — cheap O(1). Time/session/observation gates live in the entry
// signal so they cannot suppress the time-based exit. Only the wide-spread
// fail-OPEN guard is applied here.
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   // Fail-OPEN: zero modelled spread (.DWX) must NOT block. Only a genuinely
   // wide positive spread does. Scale the cap by ATR so it is symbol-agnostic.
   if(ask > bid)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > (atr * strategy_max_spread_atr_frac))
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Entry — fire ONCE per UTC day, on the first new bar at-or-after session start.
// Direction = short the base currency during its local hours (card default).
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_base_direction != 1 && strategy_base_direction != -1)
      return false;
   if(strategy_atr_period <= 0)
      return false;

   int start_h = 0, end_h = 0;
   if(!EffectiveSessionUTC(start_h, end_h))
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime u;
   ZeroMemory(u);
   TimeToStruct(utc_now, u);

   // Count one local-session open per UTC session-day (warmup gate).
   const int session_key = SessionDayKeyUTC(utc_now, start_h, end_h);
   if(HourInWindow(u.hour, start_h, end_h) && g_last_counted_utc_day != session_key)
     {
      g_last_counted_utc_day = session_key;
      if(g_session_count < 1000000) g_session_count++;
     }
   if(g_session_count < strategy_min_sessions)
      return false;

   if(HasOpenPosition())
      return false;
   if(g_last_entry_utc_yyyymmdd == session_key)
      return false;

   // TRIGGER EVENT: the entry bar must open inside the session AND be the first
   // session bar of this UTC session-day (no prior entry recorded for this key).
   if(!HourInWindow(u.hour, start_h, end_h))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // base currency is the LEFT leg of the pair. base_direction = -1 (short base):
   //   X/USD pair (base=X)  -> SELL pair
   //   USD/X pair (base=USD)-> SELL pair (short USD)
   // The pair-side equals the base-direction in both layouts because the base is
   // always the left leg, so SELL pair == short base, BUY pair == long base.
   const QM_OrderType side = (strategy_base_direction < 0) ? QM_SELL : QM_BUY;
   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;   // no fixed TP — exit at session end (time-based)
   req.reason = (side == QM_SELL) ? "CHAN_LOCALHRS_SHORT_BASE" : "CHAN_LOCALHRS_LONG_BASE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0)
      return false;

   g_last_entry_utc_yyyymmdd = session_key;
   return true;
  }

// No trailing / BE / partial — fixed catastrophic SL plus session-end time exit.
void Strategy_ManageOpenPosition() {}

// -----------------------------------------------------------------------------
// Exit — flat at the END of the same local trading window (no overnight hold).
// The session WINDOW is a STATE: when the current UTC hour leaves [start,end),
// close the position.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition())
      return false;

   int start_h = 0, end_h = 0;
   if(!EffectiveSessionUTC(start_h, end_h))
      return true;   // window unknown -> do not hold overnight

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime u;
   ZeroMemory(u);
   TimeToStruct(utc_now, u);

   if(!HourInWindow(u.hour, start_h, end_h))
      return true;   // session ended -> flatten

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1333\",\"strategy\":\"chan-fx-local-hours\"}");
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

   // Per-tick: trade management (none for this EA).
   Strategy_ManageOpenPosition();

   // Per-tick: session-end time exit. Separate from SL.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   // Per-closed-bar: entry-signal evaluation. Single QM_IsNewBar consume.
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
