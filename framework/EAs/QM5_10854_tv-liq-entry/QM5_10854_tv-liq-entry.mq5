#property strict
#property version   "5.0"
#property description "QM5_10854 TradingView Liquidity Entry Logic Execution Engine (tv-liq-entry)"
// Strategy Card: QM5_10854_tv-liq-entry, G0 APPROVED 2026-05-22.
// Mechanical Asian-range liquidity-sweep reclaim + triple-EMA / HTF / displacement,
// New York session entry, fixed 2R target with session-end + EMA-flip exits.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_10854 tv-liq-entry
// -----------------------------------------------------------------------------
// Strategy state is advanced ONCE per closed bar inside Strategy_EntrySignal
// (the framework guarantees QM_IsNewBar()==true before calling it). All raw
// OHLC reads are fixed-shift (shift 1) closed-bar reads tagged `// perf-allowed`
// for the bespoke liquidity-sweep structural logic that no QM_* reader covers.
// The per-tick path (ManageOpenPosition / ExitSignal) is O(1): a magic scan
// plus, only while a position is open, three pooled EMA reads.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10854;
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
// --- Triple-EMA execution stack (card: 9/21/50, P3 sweeps 20/50/200) ---
input int    strategy_ema_fast          = 9;       // fast EMA on execution TF
input int    strategy_ema_mid           = 21;      // mid EMA on execution TF
input int    strategy_ema_slow          = 50;      // slow EMA on execution TF
// --- Higher-timeframe bias (card: H4 or D1) ---
input ENUM_TIMEFRAMES strategy_htf      = PERIOD_H4; // HTF bias frame
input int    strategy_htf_ema           = 50;      // HTF EMA; price>EMA = long bias
// --- Sweep / stop / target ---
input int    strategy_atr_period        = 14;      // ATR period for stop buffer + range filter
input double strategy_atr_sl_buffer     = 0.25;    // stop = sweep extreme -/+ ATR*buffer
input double strategy_displacement_min  = 0.60;    // reclaim-candle body/range minimum
input double strategy_target_r          = 2.0;     // fixed target at R multiple of initial risk
input double strategy_spread_guard_pct  = 0.15;    // skip if spread > pct of stop distance
// --- Asian-range filter (multiples of ATR) ---
input double strategy_range_min_atr     = 0.25;    // skip if Asian range < this * ATR
input double strategy_range_max_atr     = 2.50;    // skip if Asian range > this * ATR
// The Asian range spans ~9h, so it must be scaled against a session-sized ATR,
// not a single execution-TF bar's ATR (the latter rejected every range -> 0
// trades). D1 ATR(14) is the card's "ATR(14)" read on a session-relevant frame.
input ENUM_TIMEFRAMES strategy_range_atr_tf = PERIOD_D1; // TF for the range-width ATR
// --- Session windows (broker time, NY-Close server GMT+2/+3) ---
input int    strategy_asian_start_hour  = 0;       // Asian build window start (inclusive)
input int    strategy_asian_end_hour    = 9;       // Asian build window end (exclusive)
input int    strategy_ny_start_hour     = 15;      // NY entry window start (inclusive)
input int    strategy_ny_end_hour       = 18;      // NY entry window end (exclusive)
input int    strategy_session_close_hour = 21;     // force-close hour if target/stop not hit

// -----------------------------------------------------------------------------
// File-scope cached strategy state — advanced once per closed bar.
// -----------------------------------------------------------------------------
int      g_cur_doy        = -1;     // day-of-year of the session currently tracked
double   g_asian_high     = 0.0;    // Asian-session high (frozen after window)
double   g_asian_low      = 0.0;    // Asian-session low  (frozen after window)
bool     g_asian_started  = false;  // saw at least one Asian-window bar today
bool     g_asian_frozen   = false;  // Asian window closed; range frozen + validated
bool     g_range_valid    = false;  // Asian range passed the ATR width filter
bool     g_swept_low      = false;  // price has swept below Asian low this session
bool     g_swept_high     = false;  // price has swept above Asian high this session
double   g_sweep_low_px   = 0.0;    // lowest low of the down-sweep (long stop ref)
double   g_sweep_high_px  = 0.0;    // highest high of the up-sweep (short stop ref)
bool     g_traded_long    = false;  // one long per session in P2 baseline
bool     g_traded_short   = false;  // one short per session in P2 baseline

void ResetDailyState()
  {
   g_asian_high    = 0.0;
   g_asian_low     = 0.0;
   g_asian_started = false;
   g_asian_frozen  = false;
   g_range_valid   = false;
   g_swept_low     = false;
   g_swept_high    = false;
   g_sweep_low_px  = 0.0;
   g_sweep_high_px = 0.0;
   g_traded_long   = false;
   g_traded_short  = false;
  }

// Find this EA's open position for the current symbol; returns its type via out.
bool OurOpenPosition(ENUM_POSITION_TYPE &ptype)
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-Trade Filter (time / spread / news): the session window, spread guard and
// Asian-range filter are direction-aware and price-dependent, so they are
// enforced inside Strategy_EntrySignal where the entry price exists. This hook
// stays a non-blocking O(1) pass so it can never trap an open position out of
// the per-tick exit path (session-end / EMA-flip close).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry — advance the closed-bar state machine, then test the reclaim setup.
// Caller guarantees QM_IsNewBar()==true (one new closed bar per call).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;          // market order; framework resolves Ask/Bid
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Single closed-bar fetch (shift 1): time + OHLC for the bespoke
   // liquidity-sweep / displacement logic. Runs once per closed bar — the
   // caller (OnTick) gates Strategy_EntrySignal behind QM_IsNewBar(), so this
   // is never a per-tick recompute.
   MqlRates bar[];
   if(CopyRates(_Symbol, _Period, 1, 1, bar) < 1) // perf-allowed: single gated closed-bar fetch
      return false;
   const datetime bar_t     = bar[0].time;
   const double   bar_open  = bar[0].open;
   const double   bar_high  = bar[0].high;
   const double   bar_low   = bar[0].low;
   const double   bar_close = bar[0].close;

   MqlDateTime dt;
   TimeToStruct(bar_t, dt);
   const int hour = dt.hour;

   // New broker day → reset the session state machine.
   if(dt.day_of_year != g_cur_doy)
     {
      ResetDailyState();
      g_cur_doy = dt.day_of_year;
     }

   // --- Phase 1: accumulate the Asian range during its build window. ---
   if(hour >= strategy_asian_start_hour && hour < strategy_asian_end_hour)
     {
      if(!g_asian_started)
        {
         g_asian_high = bar_high;
         g_asian_low  = bar_low;
         g_asian_started = true;
        }
      else
        {
         g_asian_high = MathMax(g_asian_high, bar_high);
         g_asian_low  = MathMin(g_asian_low, bar_low);
        }
      return false;   // never enter during the Asian build
     }

   // --- Phase 2: freeze + validate the range once the window has closed. ---
   if(g_asian_started && !g_asian_frozen && hour >= strategy_asian_end_hour)
     {
      g_asian_frozen = true;
      const double atr_f = QM_ATR(_Symbol, strategy_range_atr_tf, strategy_atr_period, 1);
      const double range = g_asian_high - g_asian_low;
      g_range_valid = (atr_f > 0.0 &&
                       range >= strategy_range_min_atr * atr_f &&
                       range <= strategy_range_max_atr * atr_f);
     }

   if(!g_asian_frozen || !g_range_valid)
      return false;

   // --- Phase 3a: track sweeps across the whole post-Asian session, so a
   // sweep that prints before the NY window still arms a later NY reclaim. ---
   if(hour >= strategy_asian_end_hour && hour < strategy_session_close_hour)
     {
      if(bar_low < g_asian_low)
        {
         g_swept_low = true;
         if(g_sweep_low_px <= 0.0 || bar_low < g_sweep_low_px)
            g_sweep_low_px = bar_low;
        }
      if(bar_high > g_asian_high)
        {
         g_swept_high = true;
         if(bar_high > g_sweep_high_px)
            g_sweep_high_px = bar_high;
        }
     }

   // --- Phase 3b: only fire entries inside the NY volatility window. ---
   if(hour < strategy_ny_start_hour || hour >= strategy_ny_end_hour)
      return false;

   const double bar_range = bar_high - bar_low;
   if(bar_range <= 0.0)
      return false;
   const double body_frac = MathAbs(bar_close - bar_open) / bar_range;
   const bool   displaced = (body_frac >= strategy_displacement_min);

   // Triple-EMA structure on the execution timeframe.
   const double ema_f = QM_EMA(_Symbol, _Period, strategy_ema_fast, 1);
   const double ema_m = QM_EMA(_Symbol, _Period, strategy_ema_mid, 1);
   const double ema_s = QM_EMA(_Symbol, _Period, strategy_ema_slow, 1);
   const bool   stack_long  = (ema_f > ema_m && ema_m > ema_s);
   const bool   stack_short = (ema_f < ema_m && ema_m < ema_s);

   // Higher-timeframe directional confirmation.
   MqlRates htf_bar[];
   if(CopyRates(_Symbol, strategy_htf, 1, 1, htf_bar) < 1) // perf-allowed: single gated closed-bar HTF close
      return false;
   const double htf_ema = QM_EMA(_Symbol, strategy_htf, strategy_htf_ema, 1);
   int htf_bias = 0;
   if(htf_bar[0].close > htf_ema)
      htf_bias = +1;
   else if(htf_bar[0].close < htf_ema)
      htf_bias = -1;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;

   // --- LONG: swept below Asian low, displacement reclaim back above it. ---
   if(g_swept_low && !g_traded_long &&
      bar_close > g_asian_low && bar_close > bar_open && displaced &&
      stack_long && htf_bias > 0)
     {
      const double stop = g_sweep_low_px - atr * strategy_atr_sl_buffer;
      const double risk = ask - stop;
      if(risk > 0.0 && spread <= strategy_spread_guard_pct * risk)
        {
         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = stop;
         req.tp     = ask + strategy_target_r * risk;
         req.reason = "tv-liq-entry_LONG_RECLAIM";
         g_traded_long = true;
         return true;
        }
     }

   // --- SHORT: swept above Asian high, displacement reclaim back below it. ---
   if(g_swept_high && !g_traded_short &&
      bar_close < g_asian_high && bar_close < bar_open && displaced &&
      stack_short && htf_bias < 0)
     {
      const double stop = g_sweep_high_px + atr * strategy_atr_sl_buffer;
      const double risk = stop - bid;
      if(risk > 0.0 && spread <= strategy_spread_guard_pct * risk)
        {
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = stop;
         req.tp     = bid - strategy_target_r * risk;
         req.reason = "tv-liq-entry_SHORT_RECLAIM";
         g_traded_short = true;
         return true;
        }
     }

   return false;
  }

// Trade management: card specifies a fixed 2R target (order TP) with no
// trailing / break-even / partial. Nothing to adjust per tick.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: close at session end if neither target nor stop was hit,
// or early if the triple-EMA structure flips against the open position.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!OurOpenPosition(ptype))
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hour = dt.hour;

   // Session-end flat: hold only through the NY window into the close hour;
   // anything still open at/after the close hour (or overnight) is flattened.
   if(hour >= strategy_session_close_hour || hour < strategy_ny_start_hour)
      return true;

   // Early exit on EMA-structure flip against the position.
   const double ema_f = QM_EMA(_Symbol, _Period, strategy_ema_fast, 1);
   const double ema_m = QM_EMA(_Symbol, _Period, strategy_ema_mid, 1);
   const double ema_s = QM_EMA(_Symbol, _Period, strategy_ema_slow, 1);
   const bool stack_long  = (ema_f > ema_m && ema_m > ema_s);
   const bool stack_short = (ema_f < ema_m && ema_m < ema_s);

   if(ptype == POSITION_TYPE_BUY && stack_short)
      return true;
   if(ptype == POSITION_TYPE_SELL && stack_long)
      return true;

   return false;
  }

// News-filter hook — defer to the central QM_NewsAllowsTrade two-axis filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10854_tv_liq_entry\"}");
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
