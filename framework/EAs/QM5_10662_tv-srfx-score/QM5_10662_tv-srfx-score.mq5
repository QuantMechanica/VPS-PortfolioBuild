#property strict
#property version   "5.0"
#property description "QM5_10662 SRFX SMC Confluence Score — TradingView SMC Pro SRFX Market Mapper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10662 tv-srfx-score
// -----------------------------------------------------------------------------
// SRFX SMC Confluence Score (TradingView `SMC Pro SRFX - Market Mapper`, author
// SRFXGlobal). Invite-only source; this build implements TRANSPARENT,
// DETERMINISTIC definitions for each SMC component (liquidity sweep, order
// block / FVG proximity, premium/discount zone, candle confirmation, HTF bias,
// session/killzone, local trend) and converts them into a 0..9 confluence score.
//
// Entry (Balanced baseline): take the side whose directional components score
// >= score_threshold AND whose KEY conditions hold (a sweep in the trade
// direction, and price in the correct premium/discount zone). Long uses bullish
// components; short uses bearish components. Score is a CONFLUENCE — components
// are STATES read from the last closed bars, not simultaneous same-bar events.
//
// Exit: SL from the order-block structural extreme plus an ATR buffer; TP via a
// fixed reward:risk multiple (source default 1:2). Optional ATR trailing.
//
// All component math runs on CLOSED bars (shift >= 1) and is cached once per new
// closed bar (AdvanceState_OnNewBar). The per-tick path only reads cached state.
// Structural reads (iHigh/iLow/iClose/iOpen) are bespoke SMC logic that the
// pooled QM_* readers cannot express; they run once per closed bar under the
// new-bar gate.  // perf-allowed: structural SMC reads, gated by QM_IsNewBar.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10662;
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
// --- Confluence score gate -------------------------------------------------
input int    score_threshold        = 5;     // Balanced baseline: enter when side score >= this (max 9)
input bool   require_sweep_key      = true;   // KEY condition: a directional liquidity sweep must be present
input bool   require_zone_key       = true;   // KEY condition: price in the correct premium/discount zone
// --- Structure / lookbacks -------------------------------------------------
input int    struct_lookback        = 20;     // bars used for swing high/low (zone, OB, sweep reference)
input int    sweep_lookback         = 10;     // recent bars scanned for a liquidity sweep
input int    ob_lookback            = 12;     // bars scanned for the nearest order block / FVG
input double ob_proximity_atr       = 1.0;    // OB/FVG counts as "nearby" within this many ATR of price
// --- HTF / local trend -----------------------------------------------------
input int    htf_ema_period         = 50;     // HTF bias EMA (read on htf_timeframe)
input int    local_ema_period       = 20;     // local-trend EMA (read on chart timeframe)
// --- Session / killzone (broker time, DST-aware via UTC conversion) --------
input bool   use_session_filter     = true;   // award the session/killzone score component
input int    killzone_start_utc_h   = 7;      // killzone window start hour, UTC (London/NY overlap default)
input int    killzone_end_utc_h     = 16;     // killzone window end hour, UTC
// --- Exit ------------------------------------------------------------------
input int    atr_period             = 14;     // ATR period for SL buffer + trailing
input double sl_atr_buffer_mult     = 0.5;    // ATR buffer added beyond the OB structural stop
input double take_profit_rr         = 2.0;    // reward:risk for TP (source default 1:2)
input bool   use_atr_trail          = false;  // optional ATR trailing stop (P3 axis, default off)
input double trail_atr_mult         = 2.0;    // ATR multiple for the optional trail

// HTF timeframe for bias alignment. H1 chart -> H4 bias by default.
#define QM10662_HTF_TIMEFRAME PERIOD_H4

// -----------------------------------------------------------------------------
// Cached closed-bar state (advanced once per new bar by AdvanceState_OnNewBar).
// -----------------------------------------------------------------------------
int    g_long_score      = 0;       // bullish confluence score (0..9)
int    g_short_score     = 0;       // bearish confluence score (0..9)
bool   g_long_key_ok     = false;   // long KEY conditions satisfied (sweep + zone)
bool   g_short_key_ok    = false;   // short KEY conditions satisfied
double g_long_ob_level   = 0.0;     // bullish OB structural low (for SL anchor)
double g_short_ob_level  = 0.0;     // bearish OB structural high (for SL anchor)
double g_atr_cached      = 0.0;     // ATR value at the last closed bar
bool   g_state_ready     = false;   // false until first AdvanceState populates state

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard is FAIL-OPEN on .DWX zero spread:
// only a genuinely wide spread blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      // Cap a pathological spread at ~3x ATR if ATR is known; never block on
      // zero spread (the .DWX tester models ask==bid).
      if(g_atr_cached > 0.0 && (ask - bid) > 3.0 * g_atr_cached)
         return true;
     }
   return false;
  }

// --- Component helpers (CLOSED bars only; called inside AdvanceState) --------

// Premium/discount zone over the swing range. Buys want price in the lower
// (discount) half, sells in the upper (premium) half. Returns +1 for discount,
// -1 for premium, 0 if range is degenerate.
int Zone_Direction(const double swing_high, const double swing_low, const double ref_close)
  {
   const double range = swing_high - swing_low;
   if(range <= 0.0)
      return 0;
   const double mid = swing_low + 0.5 * range;
   if(ref_close <= mid)
      return 1;   // discount -> favours longs
   return -1;     // premium  -> favours shorts
  }

// Bullish/bearish candle confirmation on the last closed bar.
// +1 bullish close, -1 bearish close, 0 doji.
int Candle_Confirmation()
  {
   const double o = iOpen(_Symbol, _Period, 1);   // perf-allowed: 1 closed-bar read, new-bar gated
   const double c = iClose(_Symbol, _Period, 1);  // perf-allowed
   if(c > o)
      return 1;
   if(c < o)
      return -1;
   return 0;
  }

// Liquidity sweep: last closed bar pierced a recent swing extreme then closed
// back inside (stop-run + rejection). Returns +1 for a bullish sweep (took out
// recent low, closed back up), -1 for a bearish sweep (took out recent high,
// closed back down), 0 for none.
int Sweep_Direction(const int lookback)
  {
   double prior_low  = 0.0;
   double prior_high = 0.0;
   bool   have       = false;
   for(int s = 2; s <= lookback + 1; s++)        // perf-allowed: structural scan, new-bar gated
     {
      const double lo = iLow(_Symbol, _Period, s);
      const double hi = iHigh(_Symbol, _Period, s);
      if(lo <= 0.0 || hi <= 0.0)
         continue;
      if(!have)
        {
         prior_low  = lo;
         prior_high = hi;
         have       = true;
        }
      else
        {
         if(lo < prior_low)  prior_low  = lo;
         if(hi > prior_high) prior_high = hi;
        }
     }
   if(!have)
      return 0;

   const double bar_low   = iLow(_Symbol, _Period, 1);   // perf-allowed
   const double bar_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double bar_close = iClose(_Symbol, _Period, 1); // perf-allowed

   // Bullish sweep: wicked below the prior low but closed back above it.
   if(bar_low < prior_low && bar_close > prior_low)
      return 1;
   // Bearish sweep: wicked above the prior high but closed back below it.
   if(bar_high > prior_high && bar_close < prior_high)
      return -1;
   return 0;
  }

// Nearest order block / FVG to current price. A deterministic OB proxy: the
// most recent opposing candle before a displacement move. We approximate via
// the nearest closed-bar swing extreme within ob_lookback that sits within
// ob_proximity_atr of the reference close. out_level receives the structural
// price (low for a bullish OB, high for a bearish OB). Returns +1 bullish OB
// nearby, -1 bearish OB nearby, 0 none.
int OB_FVG_Nearby(const int lookback, const double atr_val, const double ref_close,
                  const double prox_mult, double &out_bull_level, double &out_bear_level)
  {
   out_bull_level = 0.0;
   out_bear_level = 0.0;
   if(atr_val <= 0.0)
      return 0;
   const double tol = prox_mult * atr_val;

   double best_bull = 0.0;   // highest qualifying bullish OB low at/below price
   double best_bear = 0.0;   // lowest qualifying bearish OB high at/above price
   bool   has_bull  = false;
   bool   has_bear  = false;

   for(int s = 1; s <= lookback; s++)            // perf-allowed: structural scan, new-bar gated
     {
      const double o = iOpen(_Symbol, _Period, s);
      const double c = iClose(_Symbol, _Period, s);
      const double lo = iLow(_Symbol, _Period, s);
      const double hi = iHigh(_Symbol, _Period, s);
      if(o <= 0.0 || c <= 0.0 || lo <= 0.0 || hi <= 0.0)
         continue;

      // Bearish candle -> bullish OB demand zone (its low). Nearby if its low
      // is within tolerance below the reference close.
      if(c < o && lo <= ref_close && (ref_close - lo) <= tol)
        {
         if(!has_bull || lo > best_bull)
           {
            best_bull = lo;
            has_bull  = true;
           }
        }
      // Bullish candle -> bearish OB supply zone (its high). Nearby if its high
      // is within tolerance above the reference close.
      if(c > o && hi >= ref_close && (hi - ref_close) <= tol)
        {
         if(!has_bear || hi < best_bear)
           {
            best_bear = hi;
            has_bear  = true;
           }
        }
     }

   if(has_bull) out_bull_level = best_bull;
   if(has_bear) out_bear_level = best_bear;
   if(has_bull && !has_bear) return 1;
   if(has_bear && !has_bull) return -1;
   if(has_bull && has_bear)
     {
      // Both present: pick the closer one.
      return ((ref_close - best_bull) <= (best_bear - ref_close)) ? 1 : -1;
     }
   return 0;
  }

// Session / killzone active at the last closed bar's open time. Window is in
// UTC; the last closed bar's broker open time is converted to UTC first so the
// window is DST-correct. Returns true if inside [start,end) UTC hours.
bool Killzone_Active()
  {
   if(!use_session_filter)
      return false;
   const datetime broker_bar = iTime(_Symbol, _Period, 1);  // perf-allowed: 1 closed-bar read
   if(broker_bar <= 0)
      return false;
   const datetime utc = QM_BrokerToUTC(broker_bar);
   MqlDateTime dt;
   TimeToStruct(utc, dt);
   const int h = dt.hour;
   if(killzone_start_utc_h <= killzone_end_utc_h)
      return (h >= killzone_start_utc_h && h < killzone_end_utc_h);
   // Wrap-around window (e.g. 22 -> 6).
   return (h >= killzone_start_utc_h || h < killzone_end_utc_h);
  }

// Recompute the full confluence state once per closed bar.
void AdvanceState_OnNewBar()
  {
   g_long_score    = 0;
   g_short_score   = 0;
   g_long_key_ok   = false;
   g_short_key_ok  = false;
   g_long_ob_level = 0.0;
   g_short_ob_level = 0.0;

   g_atr_cached = QM_ATR(_Symbol, _Period, atr_period, 1);

   const double ref_close = iClose(_Symbol, _Period, 1);  // perf-allowed: 1 closed-bar read
   if(ref_close <= 0.0)
     {
      g_state_ready = true;
      return;
     }

   // Swing range for zone.
   double swing_low  = 0.0;
   double swing_high = 0.0;
   const bool have_swing = QM_StopRulesReadStructureExtremes(_Symbol, struct_lookback, swing_low, swing_high);

   // --- Directional component states ---
   const int sweep   = Sweep_Direction(sweep_lookback);                  // +1 bull / -1 bear
   const int zone    = have_swing ? Zone_Direction(swing_high, swing_low, ref_close) : 0; // +1 discount / -1 premium
   const int candle  = Candle_Confirmation();                            // +1 bull / -1 bear
   double bull_ob = 0.0, bear_ob = 0.0;
   const int ob      = OB_FVG_Nearby(ob_lookback, g_atr_cached, ref_close, ob_proximity_atr, bull_ob, bear_ob);
   const bool kz     = Killzone_Active();

   // HTF bias: price vs HTF EMA (closed bar on HTF).
   const double htf_ema = QM_EMA(_Symbol, QM10662_HTF_TIMEFRAME, htf_ema_period, 1);
   const double htf_close = iClose(_Symbol, QM10662_HTF_TIMEFRAME, 1);   // perf-allowed: 1 closed-bar HTF read
   int htf_bias = 0;
   if(htf_ema > 0.0 && htf_close > 0.0)
      htf_bias = (htf_close > htf_ema) ? 1 : ((htf_close < htf_ema) ? -1 : 0);

   // Local trend: ref close vs local EMA.
   const double loc_ema = QM_EMA(_Symbol, _Period, local_ema_period, 1);
   int loc_trend = 0;
   if(loc_ema > 0.0)
      loc_trend = (ref_close > loc_ema) ? 1 : ((ref_close < loc_ema) ? -1 : 0);

   // --- Long score (bullish components) ---
   if(sweep   == 1) g_long_score += 2;
   if(ob      == 1) { g_long_score += 2; g_long_ob_level = bull_ob; }
   if(zone    == 1) g_long_score += 1;   // discount favours longs
   if(candle  == 1) g_long_score += 1;
   if(htf_bias == 1) g_long_score += 1;
   if(kz)            g_long_score += 1;
   if(loc_trend == 1) g_long_score += 1;

   // --- Short score (bearish components) ---
   if(sweep   == -1) g_short_score += 2;
   if(ob      == -1) { g_short_score += 2; g_short_ob_level = bear_ob; }
   if(zone    == -1) g_short_score += 1;  // premium favours shorts
   if(candle  == -1) g_short_score += 1;
   if(htf_bias == -1) g_short_score += 1;
   if(kz)             g_short_score += 1;
   if(loc_trend == -1) g_short_score += 1;

   // KEY conditions: a directional sweep AND correct zone (each optional via input).
   const bool long_sweep_ok = (!require_sweep_key) || (sweep == 1);
   const bool long_zone_ok  = (!require_zone_key)  || (zone  == 1);
   g_long_key_ok = long_sweep_ok && long_zone_ok;

   const bool short_sweep_ok = (!require_sweep_key) || (sweep == -1);
   const bool short_zone_ok  = (!require_zone_key)  || (zone  == -1);
   g_short_key_ok = short_sweep_ok && short_zone_ok;

   g_state_ready = true;
  }

// Build an entry from the cached confluence state. Caller guarantees new bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_ready)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;   // one position per magic (framework also enforces)

   const bool long_ok  = (g_long_score  >= score_threshold) && g_long_key_ok;
   const bool short_ok = (g_short_score >= score_threshold) && g_short_key_ok;

   // If both sides qualify (rare), take the higher-scoring side; tie -> no trade.
   bool go_long  = false;
   bool go_short = false;
   if(long_ok && short_ok)
     {
      if(g_long_score > g_short_score)      go_long  = true;
      else if(g_short_score > g_long_score) go_short = true;
      else                                   return false;
     }
   else
     {
      go_long  = long_ok;
      go_short = short_ok;
     }
   if(!go_long && !go_short)
      return false;

   const double atr_val = (g_atr_cached > 0.0) ? g_atr_cached : QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   if(go_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL below the bullish OB low (or structure) minus an ATR buffer.
      double anchor = (g_long_ob_level > 0.0 && g_long_ob_level < entry) ? g_long_ob_level : 0.0;
      double sl;
      if(anchor > 0.0)
         sl = QM_StopRulesNormalizePrice(_Symbol, anchor - sl_atr_buffer_mult * atr_val);
      else
         sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_val, 1.0 + sl_atr_buffer_mult);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // market
      req.sl     = sl;
      req.tp     = QM_TakeRR(_Symbol, QM_BUY, entry, sl, take_profit_rr);
      req.reason = "srfx_score_long";
      return true;
     }

   // go_short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   double anchor = (g_short_ob_level > 0.0 && g_short_ob_level > entry) ? g_short_ob_level : 0.0;
   double sl;
   if(anchor > 0.0)
      sl = QM_StopRulesNormalizePrice(_Symbol, anchor + sl_atr_buffer_mult * atr_val);
   else
      sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_val, 1.0 + sl_atr_buffer_mult);
   if(sl <= 0.0 || sl <= entry)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = QM_TakeRR(_Symbol, QM_SELL, entry, sl, take_profit_rr);
   req.reason = "srfx_score_short";
   return true;
  }

// Optional ATR trailing once in profit.
void Strategy_ManageOpenPosition()
  {
   if(!use_atr_trail)
      return;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailATR(ticket, atr_period, trail_atr_mult);
     }
  }

// No discretionary exit beyond SL/TP and the optional trail. The card's
// "close opposite before reverse" is handled by one-position-per-magic plus the
// new-bar entry gate (a reverse entry cannot fire while a position is open).
bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
