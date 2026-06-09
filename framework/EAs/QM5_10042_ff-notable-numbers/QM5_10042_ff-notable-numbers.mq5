#property strict
#property version   "5.0"
#property description "QM5_10042 Notable Numbers FX Reversal"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// Framework inputs
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10042;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// All symbol-specific params are hard-coded from the card in InitSymbolParams().
// No user-tunable strategy inputs.
input int    strategy_reserved = 0;

// =============================================================================
// Symbol-specific parameters (populated by InitSymbolParams in OnInit)
// =============================================================================

int    g_lookback_days   = 22;
double g_tp_pct          = 0.004;
double g_sl_pct          = 0.004;
int    g_session_start_h = 0;      // broker-hour session start; -1 = any time
int    g_session_end_h   = 8;      // broker-hour session end;   -1 = no time exit
double g_level_grid      = 0.0100; // spacing between notable levels (price units)
double g_level_offset    = 0.0000; // fractional offset of level within each grid cell
bool   g_valid_symbol    = false;  // false = unknown symbol; block all trading

// Per-bar cached notable levels (recomputed on each new closed M15 bar)
double g_notable_below   = 0.0;
double g_notable_above   = 0.0;

// Trade dedup: one entry per (day, level) pair; stored as YYYYMMDD key
int    g_last_trade_date  = -1;    // YYYYMMDD of last trade
double g_last_trade_level = 0.0;

// Session exit: when to close the open position on time (0 = no pending exit)
datetime g_session_exit_time = 0;

// =============================================================================
// Helpers
// =============================================================================

// Return the greatest notable level at or below price.
// Levels are spaced g_level_grid apart with fractional offset g_level_offset
// within each cell (e.g., 0.0066 targets ".66" endings in 4-decimal prices).
double NotableLevelBelow(const double price)
  {
   // perf-allowed: bespoke notable-number grid math (not a QM_* framework helper)
   const double base = MathFloor((price - g_level_offset) / g_level_grid)
                       * g_level_grid + g_level_offset;
   return NormalizeDouble((base > price) ? base - g_level_grid : base, _Digits);
  }

double NotableLevelAbove(const double price)
  {
   return NormalizeDouble(NotableLevelBelow(price) + g_level_grid, _Digits);
  }

// Return the next wall-clock datetime when broker-time hour == hour_h.
datetime NextHourOccurrence(const int hour_h, const datetime from_time)
  {
   MqlDateTime dt;
   TimeToStruct(from_time, dt);
   dt.hour = hour_h;
   dt.min  = 0;
   dt.sec  = 0;
   datetime candidate = StructToTime(dt);
   if(candidate <= from_time)
      candidate += 86400;
   return candidate;
  }

// Set per-symbol parameters from the card spec. Returns false for unknown symbols.
bool InitSymbolParams()
  {
   const string s = _Symbol;

   if(s == "GBPUSD.DWX")
     {
      // Card: ".00" endings, 22-day lookback, Sydney session broker 00-08, TP 0.4%, SL 0.4%
      g_lookback_days   = 22;
      g_tp_pct          = 0.004;
      g_sl_pct          = 0.004;
      g_session_start_h = 0;
      g_session_end_h   = 8;
      g_level_grid      = 0.0100;
      g_level_offset    = 0.0000;
      return true;
     }
   if(s == "EURGBP.DWX")
     {
      // Card: ".66" endings, 13-day lookback, Tokyo-to-Sydney broker 02-08, TP 0.35%, SL 0.9%
      g_lookback_days   = 13;
      g_tp_pct          = 0.0035;
      g_sl_pct          = 0.009;
      g_session_start_h = 2;
      g_session_end_h   = 8;
      g_level_grid      = 0.0100;
      g_level_offset    = 0.0066;
      return true;
     }
   if(s == "AUDUSD.DWX")
     {
      // Card: ".33" endings, 42-day lookback, Tokyo-to-London broker 02-18, TP 0.85%, SL 0.55%
      g_lookback_days   = 42;
      g_tp_pct          = 0.0085;
      g_sl_pct          = 0.0055;
      g_session_start_h = 2;
      g_session_end_h   = 18;
      g_level_grid      = 0.0100;
      g_level_offset    = 0.0033;
      return true;
     }
   if(s == "USDJPY.DWX")
     {
      // Card: ".444" endings, 20-day lookback, any time, TP 0.25%, SL 0.25%
      g_lookback_days   = 20;
      g_tp_pct          = 0.0025;
      g_sl_pct          = 0.0025;
      g_session_start_h = -1;
      g_session_end_h   = -1;
      g_level_grid      = 1.0000;
      g_level_offset    = 0.444;
      return true;
     }
   return false;
  }

// =============================================================================
// No Trade Filter — block trading outside the allowed session window.
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   if(!g_valid_symbol)
      return true;
   if(g_session_start_h < 0)
      return false;                    // any-time symbol: never block on session
   return QM_Sig_Session(TimeCurrent(), g_session_start_h, g_session_end_h) == 0;
  }

// =============================================================================
// Entry Signal — called once per new closed M15 bar via QM_IsNewBar gate.
// =============================================================================

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_valid_symbol)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double mid = (ask + bid) * 0.5;

   g_notable_below = NotableLevelBelow(mid);
   g_notable_above = NotableLevelAbove(mid);

   // One position per magic at a time (framework also guards this in QM_Entry).
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)magic)
         return false;
     }

   // D1 positional filter: last g_lookback_days complete daily bars.
   bool all_above = true;    // all D1 lows  > g_notable_below  → LONG setup valid
   bool all_below = true;    // all D1 highs < g_notable_above  → SHORT setup valid

   for(int i = 1; i <= g_lookback_days; i++)
     {
      const double dh = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed: D1 structural lookback, once per new M15 bar
      const double dl = iLow(_Symbol,  PERIOD_D1, i); // perf-allowed: D1 structural lookback, once per new M15 bar
      if(dh <= 0.0 || dl <= 0.0)
        { all_above = false; all_below = false; break; }
      if(dl <= g_notable_below) all_above = false;
      if(dh >= g_notable_above) all_below = false;
      if(!all_above && !all_below) break;
     }

   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int today_date = (dt.year * 10000) + (dt.mon * 100) + dt.day;
   const bool same_day  = (today_date == g_last_trade_date);

   // --- LONG: all D1 bars above notable_below; M15 bar opened above and touched level ---
   if(all_above)
     {
      const double bar_open = iOpen(_Symbol, PERIOD_M15, 1); // perf-allowed: M15 closed-bar touch detection, gated by QM_IsNewBar
      const double bar_low  = iLow(_Symbol,  PERIOD_M15, 1); // perf-allowed: M15 closed-bar touch detection, gated by QM_IsNewBar

      if(bar_open > g_notable_below && bar_low <= g_notable_below)
        {
         const bool already_traded = same_day &&
                                     MathAbs(g_notable_below - g_last_trade_level) < _Point * 2;
         if(!already_traded)
           {
            const double spread  = ask - bid;
            const double sl_dist = ask * g_sl_pct;
            if(sl_dist < 3.0 * spread)
               return false;

            req.type         = QM_BUY;
            req.price        = ask;
            req.sl           = NormalizeDouble(ask - sl_dist, _Digits);
            req.tp           = NormalizeDouble(ask + ask * g_tp_pct, _Digits);
            req.reason       = "nn_long";
            req.symbol_slot  = qm_magic_slot_offset;

            g_last_trade_date  = today_date;
            g_last_trade_level = g_notable_below;
            g_session_exit_time = (g_session_end_h >= 0)
                                  ? NextHourOccurrence(g_session_end_h, broker_now) : 0;
            return true;
           }
        }
     }

   // --- SHORT: all D1 bars below notable_above; M15 bar opened below and touched level ---
   if(all_below)
     {
      const double bar_open = iOpen(_Symbol, PERIOD_M15, 1); // perf-allowed: M15 closed-bar touch detection, gated by QM_IsNewBar
      const double bar_high = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed: M15 closed-bar touch detection, gated by QM_IsNewBar

      if(bar_open < g_notable_above && bar_high >= g_notable_above)
        {
         const bool already_traded = same_day &&
                                     MathAbs(g_notable_above - g_last_trade_level) < _Point * 2;
         if(!already_traded)
           {
            const double spread  = ask - bid;
            const double sl_dist = bid * g_sl_pct;
            if(sl_dist < 3.0 * spread)
               return false;

            req.type         = QM_SELL;
            req.price        = bid;
            req.sl           = NormalizeDouble(bid + sl_dist, _Digits);
            req.tp           = NormalizeDouble(bid - bid * g_tp_pct, _Digits);
            req.reason       = "nn_short";
            req.symbol_slot  = qm_magic_slot_offset;

            g_last_trade_date  = today_date;
            g_last_trade_level = g_notable_above;
            g_session_exit_time = (g_session_end_h >= 0)
                                  ? NextHourOccurrence(g_session_end_h, broker_now) : 0;
            return true;
           }
        }
     }

   return false;
  }

// =============================================================================
// Manage Open Position — TP/SL and session exit handle all exits.
// =============================================================================

void Strategy_ManageOpenPosition()
  {
  }

// =============================================================================
// Exit Signal — session-end time exit (per tick, O(1) fast path).
// =============================================================================

bool Strategy_ExitSignal()
  {
   if(g_session_exit_time == 0 || TimeCurrent() < g_session_exit_time)
      return false;

   g_session_exit_time = 0;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)magic)
         return true;
     }
   return false;
  }

// =============================================================================
// News Filter Hook — defer to framework default.
// =============================================================================

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
// =============================================================================

int OnInit()
  {
   g_valid_symbol = InitSymbolParams();

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

   QM_LogEvent(QM_INFO, "INIT_OK", StringFormat("{\"valid_symbol\":%s,\"symbol\":\"%s\"}",
               g_valid_symbol ? "true" : "false", _Symbol));
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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
