#property strict
#property version   "5.0"
#property description "QM5_11019 the5ers-ema-tunnel — EMA-tunnel multi-TF swing (D1-native)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11019 the5ers-ema-tunnel
// -----------------------------------------------------------------------------
// Source: The5ers blog interview with Kiel.R, "Take The Time And Effort to
//   Learn Yourself" (https://the5ers.com/...). Card:
//   artifacts/cards_approved/QM5_11019_the5ers-ema-tunnel.md (g0_status APPROVED).
//
// Mechanics (D1-native realization, closed-bar reads at shift 1):
//   The source is a daily-timeframe swing routine: wait for price to PIERCE an
//   EMA "tunnel" (EMA 144 / EMA 169) and close back outside it, in the direction
//   of higher-timeframe (H1/D1/W1/MN1) trend alignment, with a tight fast-EMA
//   compression filter; then ride it with a partial at 1R and a fast-EMA trail.
//
//   MTF realization note (DWX invariant #10): MN1 yields 0 bars in the DWX
//   tester and W1 is sparse, so the multi-timeframe ALIGNMENT is proxied with
//   D1 EMAs of scaled length on the base D1 chart (a longer D1 EMA stands in for
//   the slower-TF trend), as the card's R2/R3 PASS reasoning instructs. This
//   keeps the EA D1-native and deterministically testable while preserving the
//   "long-only-with-the-bigger-trend" edge.
//
//   Long bias  : close > EMA(tunnel_slow) AND EMA(align_proxy) rising stack
//                (EMA(tunnel_fast) > EMA(tunnel_slow) > EMA(align_proxy)).
//   Short bias : mirror (close < tunnel, EMAs in descending stack).
//   Pierce EVENT (long) : the LAST closed D1 bar low dipped into/below the tunnel
//                (low <= max(ema144,ema169)) and the bar closed back above both
//                tunnel EMAs. Mirror for short. One event per closed bar.
//   Compression STATE   : |EMA(fast) - nearest tunnel EMA| <=
//                max(compress_pips, 0.15 * ATR).
//   Stop  : long  -> pierce-bar low  - sl_atr_mult * ATR.
//           short -> pierce-bar high + sl_atr_mult * ATR.
//   Manage: partial-close 50% at +1R, then ATR-trail the remainder (fast-EMA
//           proxy: ATR trail with trail_atr_mult buffer).
//   Exit  : hard time stop after max_hold_bars closed D1 bars.
//   Spread guard: fail-OPEN on .DWX zero modeled spread; only a genuinely wide
//           spread (> spread_pct_of_stop of the stop distance) blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11019;
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
input int    strategy_tunnel_fast_period = 144;   // tunnel fast EMA (EMA 144)
input int    strategy_tunnel_slow_period = 169;   // tunnel slow EMA (EMA 169)
input int    strategy_fast_ema_period    = 12;    // compression fast EMA (EMA 12)
input int    strategy_align_proxy_period = 300;   // D1 proxy for slower-TF trend alignment
input int    strategy_atr_period         = 14;    // ATR period (compression / stop)
input double strategy_compress_pips      = 5.0;   // base compression threshold, in pips
input double strategy_compress_atr_frac  = 0.15;  // compression also allowed up to frac*ATR
input double strategy_sl_atr_mult        = 0.5;   // stop buffer beyond pierce extreme = mult*ATR
input double strategy_partial_rr         = 1.0;   // partial-close trigger in R multiples
input double strategy_partial_fraction   = 0.5;   // fraction of position to close at the partial
input double strategy_trail_atr_mult     = 0.5;   // ATR-trail buffer for the runner
input int    strategy_max_hold_bars      = 20;    // hard time stop, in closed D1 bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// File-scope flag: ensures the partial-close at +1R fires only once per trade.
bool g_partial_done = false;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on a zero price

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate, base D1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic — no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Tunnel + alignment EMAs (closed D1 bar, shift 1) ---
   const double ema_t_fast = QM_EMA(_Symbol, _Period, strategy_tunnel_fast_period, 1);
   const double ema_t_slow = QM_EMA(_Symbol, _Period, strategy_tunnel_slow_period, 1);
   const double ema_fast   = QM_EMA(_Symbol, _Period, strategy_fast_ema_period, 1);
   const double ema_align  = QM_EMA(_Symbol, _Period, strategy_align_proxy_period, 1);
   if(ema_t_fast <= 0.0 || ema_t_slow <= 0.0 || ema_fast <= 0.0 || ema_align <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Closed pierce bar (shift 1) OHLC — perf-allowed single-bar reads on the
   // base D1 chart for the candle-piercing pattern (gapless .DWX: prior close).
   const double bar_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double bar_low   = iLow(_Symbol, _Period, 1);   // perf-allowed
   const double bar_close = iClose(_Symbol, _Period, 1); // perf-allowed
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;

   const double tunnel_top = MathMax(ema_t_fast, ema_t_slow);
   const double tunnel_bot = MathMin(ema_t_fast, ema_t_slow);

   // Compression threshold: max(compress_pips, frac*ATR) around the nearest
   // tunnel EMA, measured against the fast EMA.
   const double pip_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_compress_pips);
   const double compress_thresh = MathMax(pip_dist, strategy_compress_atr_frac * atr_value);
   const double dist_to_top = MathAbs(ema_fast - tunnel_top);
   const double dist_to_bot = MathAbs(ema_fast - tunnel_bot);
   const double dist_nearest = MathMin(dist_to_top, dist_to_bot);
   const bool compressed = (dist_nearest <= compress_thresh);
   if(!compressed)
      return false;

   // --- LONG setup ---
   // Alignment: bullish stack, price above the tunnel.
   const bool long_align = (ema_t_fast > ema_t_slow && ema_t_slow > ema_align &&
                            bar_close > tunnel_top);
   // Pierce EVENT: last closed bar low dipped into/below the tunnel and closed
   // back above both tunnel EMAs.
   const bool long_pierce = (bar_low <= tunnel_top && bar_close > tunnel_top);

   if(long_align && long_pierce)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Stop below the pierce-bar low by sl_atr_mult * ATR.
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                           bar_low - strategy_sl_atr_mult * atr_value);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // managed exit (partial + trail + time stop), no fixed TP
      req.reason = "ema_tunnel_long";
      g_partial_done = false;
      return true;
     }

   // --- SHORT setup (mirror) ---
   const bool short_align = (ema_t_fast < ema_t_slow && ema_t_slow < ema_align &&
                             bar_close < tunnel_bot);
   const bool short_pierce = (bar_high >= tunnel_bot && bar_close < tunnel_bot);

   if(short_align && short_pierce)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                           bar_high + strategy_sl_atr_mult * atr_value);
      if(sl <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "ema_tunnel_short";
      g_partial_done = false;
      return true;
     }

   return false;
  }

// Manage the open position: partial-close 50% at +1R, then ATR-trail the runner.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_partial_done = false;
      return;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type   = PositionGetInteger(POSITION_TYPE);
      const double open_px  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_px    = PositionGetDouble(POSITION_SL);
      const double cur_vol  = PositionGetDouble(POSITION_VOLUME);
      if(open_px <= 0.0 || sl_px <= 0.0)
         continue;

      const double r_dist = MathAbs(open_px - sl_px); // initial 1R distance
      if(r_dist <= 0.0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Partial close at +1R (once per trade).
      if(!g_partial_done)
        {
         bool hit_1r = false;
         if(pos_type == POSITION_TYPE_BUY)
            hit_1r = (bid >= open_px + strategy_partial_rr * r_dist);
         else
            hit_1r = (ask <= open_px - strategy_partial_rr * r_dist);

         if(hit_1r)
           {
            const double part_lots = QM_TM_NormalizeVolume(_Symbol,
                                         cur_vol * strategy_partial_fraction);
            if(part_lots > 0.0 && part_lots < cur_vol)
              {
               if(QM_TM_PartialClose(ticket, part_lots, QM_EXIT_STRATEGY))
                  g_partial_done = true;
              }
            else
              {
               // Volume too small to split — just flag so we move to trailing.
               g_partial_done = true;
              }
           }
        }

      // Trail the remainder by ATR once the partial has been taken.
      if(g_partial_done)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Hard time stop: close after max_hold_bars closed base-TF (D1) bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;

      // Elapsed closed bars = number of base-TF periods since the open time.
      const long secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar <= 0)
         continue;
      const long elapsed_bars = (long)((TimeCurrent() - open_time) / secs_per_bar);
      if(elapsed_bars >= (long)strategy_max_hold_bars)
         return true;
     }

   return false;
  }

// Defer to the central news filter (no EA-specific override).
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
