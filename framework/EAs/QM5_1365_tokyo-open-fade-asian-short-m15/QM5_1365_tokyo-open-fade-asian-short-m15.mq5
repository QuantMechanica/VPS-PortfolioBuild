#property strict
#property version   "5.0"
#property description "QM5_1365 Tokyo-Open Fade (Asian-Session, M15)"

// Tokyo-Open Fade (Asian-Session Short/Long-side, M15) — fade the post-open spike.
// Source: ForexFactory Asian-session "Tokyo open fade" cluster + Kathy Lien &
// Boris Schlossberg, Day Trading the Currency Market (Wiley 2008) Asian-session
// fade mechanic. Card: QM5_1365_tokyo-open-fade-asian-short-m15.
//
// MECHANIC
//   The Tokyo open is the NY-Close server DAY boundary = 00:00 BROKER-time. The
//   first hour 00:00-01:00 broker (four M15 bars) is the "Tokyo-open box":
//     tokyo_open_high / tokyo_open_low / tokyo_open_range, plus the session-open
//     price (open of the 00:00 bar). This box is a per-day STATE.
//   The single TRIGGER EVENT is the fade entry on a closed M15 bar inside the
//   01:00-04:00 broker fade window, when an oscillator-extreme (RSI) + a
//   bar-direction confirm that the meaningful opening spike is exhausting:
//     SELL (fade upside spike):
//       (1) upside spike meaningful: tokyo_open_high - session_open >= 0.6*ATR(D1)
//       (2) spike sustained: close@01:00 (end-of-box close) > low + 0.5*range
//       (3) RSI(14,M15)[1]>=75 AND RSI(14,M15)[2]>=75 AND bearish closed bar
//       (4) price near the extreme: high[1] >= tokyo_open_high - 0.2*ATR(M15)
//       (5) no prior SELL-fade today; (6) no open position; (7) fail-OPEN spread.
//     BUY = mirror (downside spike, RSI<=25 persistence, bullish closed bar).
//   Enter at market on the next M15 bar open.
//
// EXITS
//   - TP = spike-midpoint: low + 0.5*range (SELL) / equivalently high - 0.5*range
//     for BUY — the canonical "fade to half".
//   - One-time break-even shift once price advances 0.4*range in favour.
//   - MANDATORY end-of-Asian-session flat at 06:00 broker (before London).
//   - Intraday time-stop: 12 M15 bars (~3h) without TP/SL.
//
// STOP LOSS
//   SELL: tokyo_open_high + 0.3*ATR(M15); BUY: tokyo_open_low - 0.3*ATR(M15).
//   Capped at 1.5*ATR(M15). Hard SL, only the one-time BE shift widens nothing.
//
// BROKER-TIME / DST DISCIPLINE (.DWX invariant #5, #13):
//   The Tokyo-open anchor is the NY-Close SERVER day boundary (00:00 broker).
//   Under DXZ NY-Close convention that boundary is fixed to the NY close and is
//   the same calendar moment year-round even though the GMT offset shifts +2/+3
//   across US DST. We therefore frame the session in BROKER-LOCAL hours (the
//   natural frame for the NY-Close anchor) and derive the per-day key from
//   broker time. QM_BrokerToUTC() is used to obtain the DST-aware UTC instant of
//   the session anchor (audit / future news alignment); the server offset is
//   NEVER hardcoded.
//
// .DWX BACKTEST INVARIANTS honoured:
//   #1 Fail-OPEN spread guard (zero modelled spread never blocks; only a
//      genuinely WIDE positive spread does, scaled by ATR(M15)).
//   #2 No swap gate.
//   #3 QM_IsNewBar() consumed exactly ONCE per tick (framework OnTick).
//   #4 ONE trigger EVENT (the fade bar). Box high/low/range, session-open,
//      window-open, RSI-persistence and one-per-direction-per-day are STATES.
//   #5/#13 Session window framed in broker time matched to the JPY/Asian symbol.
//   #6 Uses prior CLOSE / session frame, never a gap on gapless .DWX CFDs.
//   #7 Spike-meaningfulness scales the opening move to a D1-ATR baseline.
//   #14 Pip-correct: SL/TP from ATR price distances + range prices, never raw points.
//   HR4 RISK_FIXED sizing; HR14 single position per magic, no ML, fixed rules.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1365;
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
// Session anchored to the NY-Close server day boundary (00:00 broker).
// Tokyo-open box = first hour [box_start, box_end) broker-local. Fade entries in
// [trade_start, trade_end) broker-local. Mandatory flat at session_close_hour.
input int    strategy_box_start_hour_broker   = 0;   // Tokyo-open box open hour (broker)
input int    strategy_box_end_hour_broker     = 1;   // box close hour (broker, exclusive)
input int    strategy_trade_start_hour_broker = 1;   // fade entries allowed from (broker, inclusive)
input int    strategy_trade_end_hour_broker   = 4;   // fade entries allowed until (broker, exclusive)
input int    strategy_session_close_hour_broker = 6; // mandatory flat at/after this broker hour

input int    strategy_atr_m15_period          = 20;  // ATR(20,M15) — SL sizing + spread cap
input int    strategy_atr_d1_period           = 20;  // ATR(20,D1) — spike-meaningfulness baseline
input int    strategy_rsi_period              = 14;  // RSI(14,M15) — extreme-zone fade trigger
input double strategy_rsi_overbought          = 75.0; // SELL-fade RSI floor (persistence on [1]&[2])
input double strategy_rsi_oversold            = 25.0; // BUY-fade RSI ceiling

input double strategy_spike_min_atr_d1_frac   = 0.6;  // opening spike >= this * ATR(D1) to be meaningful
input double strategy_spike_sustain_frac      = 0.5;  // end-of-box close must hold this fraction of range
input double strategy_near_extreme_atr_frac   = 0.2;  // fade bar high/low within this * ATR(M15) of extreme
input double strategy_tp_range_frac           = 0.5;  // TP = mean-revert to this fraction of the box range
input double strategy_sl_atr_buffer_mult      = 0.3;  // SL beyond the box extreme by this * ATR(M15)
input double strategy_sl_atr_cap_mult         = 1.5;  // cap initial-SL distance at this * ATR(M15)
input double strategy_be_advance_range_frac   = 0.4;  // move SL to BE once price advances this * range
input int    strategy_max_hold_bars           = 12;   // intraday time-stop (M15 bars ~3h)
input double strategy_max_spread_atr_frac     = 0.4;  // fail-OPEN wide-spread cap (* ATR(M15))

// -----------------------------------------------------------------------------
// File-scope per-Tokyo-session state (advanced once per closed M15 bar).
// -----------------------------------------------------------------------------
int      g_box_day_key       = 0;      // broker-local YYYYMMDD the box belongs to
bool     g_box_ready         = false;  // box finalised for g_box_day_key
double   g_box_high          = 0.0;    // tokyo_open_high
double   g_box_low           = 0.0;    // tokyo_open_low
double   g_box_open          = 0.0;    // session-open price (open of the box-start bar)
double   g_box_close         = 0.0;    // close of the last box bar (~01:00 broker)

int      g_traded_day_key    = 0;      // day key on which a fade was taken
bool     g_did_sell_today    = false;  // one SELL-fade per session
bool     g_did_buy_today     = false;  // one BUY-fade per session

int      g_entry_bar_index   = 0;      // M15 bars since entry (time-stop)
bool     g_be_done           = false;  // one-time break-even shift applied
int      g_entry_direction   = 0;      // +1 long, -1 short, 0 flat

// =============================================================================
// Broker-time helpers. The Tokyo-open anchor IS the NY-Close server day
// boundary, so the broker-local clock is the correct session frame. We still
// route through QM_BrokerToUTC for the DST-aware UTC instant (audit) and never
// hardcode a server offset.
// =============================================================================
int BrokerDayKey(const datetime broker_time)
  {
   MqlDateTime b;
   ZeroMemory(b);
   TimeToStruct(broker_time, b);
   return b.year * 10000 + b.mon * 100 + b.day;
  }

int BrokerHour(const datetime broker_time)
  {
   MqlDateTime b;
   ZeroMemory(b);
   TimeToStruct(broker_time, b);
   return b.hour;
  }

int BrokerMinute(const datetime broker_time)
  {
   MqlDateTime b;
   ZeroMemory(b);
   TimeToStruct(broker_time, b);
   return b.min;
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
// Box computation — runs once per closed M15 bar. Resets the per-session state
// at the start of a new broker day (inside the box window) and finalises the
// Tokyo-open box on the close of the last box bar (open-hour == box_end-1,
// open-minute == 45 → that M15 bar closes exactly at box_end:00 broker).
// Reads box bars by fixed shift (perf-allowed structural OHLC, post new-bar gate).
// -----------------------------------------------------------------------------
void AdvanceBoxState_OnNewBar()
  {
   const datetime bar1_open = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: fixed closed-bar open time, post QM_IsNewBar gate
   if(bar1_open <= 0)
      return;

   const int day_key = BrokerDayKey(bar1_open);
   const int hour     = BrokerHour(bar1_open);
   const int minute   = BrokerMinute(bar1_open);

   // New broker day (seen while still inside / before the box window) → reset.
   if(day_key != g_box_day_key && hour < strategy_box_end_hour_broker)
     {
      g_box_day_key    = day_key;
      g_box_ready      = false;
      g_box_high       = 0.0;
      g_box_low        = 0.0;
      g_box_open       = 0.0;
      g_box_close      = 0.0;
      g_did_sell_today = false;
      g_did_buy_today  = false;
     }

   // Finalise the box when the just-closed bar is the LAST box bar: its open
   // local hour == box_end-1 and open minute == 45 (M15), so it closes at
   // box_end:00 broker. The box spans [box_start:00, box_end:00) = the first
   // hour after the Tokyo open. On M15 that is four bars: shifts 4,3,2,1.
   if(!g_box_ready && day_key == g_box_day_key)
     {
      const bool is_last_box_bar = (hour == strategy_box_end_hour_broker - 1 && minute == 45);
      if(is_last_box_bar)
        {
         const int box_bars = (strategy_box_end_hour_broker - strategy_box_start_hour_broker) * 4; // M15 bars per hour
         if(box_bars >= 1)
           {
            double hi = -1.0;
            double lo = -1.0;
            // shift `box_bars` = the box-start (00:00) bar … shift 1 = last box bar.
            for(int s = box_bars; s >= 1; --s)
              {
               const double h = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, s); // perf-allowed: fixed box-bar high, post new-bar gate
               const double l = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, s);  // perf-allowed: fixed box-bar low
               if(h <= 0.0 || l <= 0.0)
                  continue;
               if(hi < 0.0 || h > hi) hi = h;
               if(lo < 0.0 || l < lo) lo = l;
              }
            const double box_open  = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, box_bars); // perf-allowed: session-open price
            const double box_close = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);        // perf-allowed: end-of-box close
            if(hi > 0.0 && lo > 0.0 && hi > lo && box_open > 0.0 && box_close > 0.0)
              {
               g_box_high  = hi;
               g_box_low   = lo;
               g_box_open  = box_open;
               g_box_close = box_close;
               g_box_ready = true;
              }
           }
        }
     }
  }

// -----------------------------------------------------------------------------
// No Trade Filter — cheap O(1). Only the fail-OPEN wide-spread guard. Session /
// box / window gates live in EntrySignal so they cannot suppress the time-based
// session-close exit.
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   // Fail-OPEN: zero modelled .DWX spread must NOT block; only a genuinely WIDE
   // positive spread does. Scale the cap by ATR(M15) so it is symbol-agnostic.
   if(ask > bid)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_m15_period, 1);
      if(atr > 0.0 && (ask - bid) > (atr * strategy_max_spread_atr_frac))
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Entry — on a closed M15 bar, after the Tokyo-open box has finalised and inside
// the fade window. The fade bar (RSI-extreme persistence + bar-direction at the
// spike extreme) is the single TRIGGER EVENT. One fade per direction per session.
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_box_ready)
      return false;
   if(HasOpenPosition())
      return false;

   const datetime now_broker = TimeCurrent();
   const int day_key  = BrokerDayKey(now_broker);
   const int hour     = BrokerHour(now_broker);

   // Box must belong to TODAY (broker-local) — no carry-over to the next day.
   if(day_key != g_box_day_key)
      return false;

   // Fade trading window [trade_start, trade_end) broker-local.
   if(hour < strategy_trade_start_hour_broker || hour >= strategy_trade_end_hour_broker)
      return false;

   const double box_range = g_box_high - g_box_low;
   if(box_range <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_d1_period, 1);
   const double atr_m15 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_m15_period, 1);
   if(atr_d1 <= 0.0 || atr_m15 <= 0.0)
      return false;

   // RSI persistence on the two just-closed bars (oscillator STATE).
   const double rsi1 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi2 = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 2, PRICE_CLOSE);
   if(rsi1 <= 0.0 || rsi2 <= 0.0)
      return false;

   // Just-closed fade bar OHLC (the single trigger bar is bar shift 1).
   const double open1  = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);  // perf-allowed: fixed closed-bar OHLC, post new-bar gate
   const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed
   const double high1  = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);  // perf-allowed
   const double low1   = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);   // perf-allowed
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   // -------- SELL: fade an upside spike --------
   if(!g_did_sell_today)
     {
      const bool spike_meaningful = (g_box_high - g_box_open) >= strategy_spike_min_atr_d1_frac * atr_d1;
      const bool spike_sustained  = g_box_close > (g_box_low + strategy_spike_sustain_frac * box_range);
      const bool rsi_overbought   = (rsi1 >= strategy_rsi_overbought && rsi2 >= strategy_rsi_overbought);
      const bool bar_bearish      = (close1 < open1);
      const bool near_extreme     = (high1 >= g_box_high - strategy_near_extreme_atr_frac * atr_m15);

      if(spike_meaningful && spike_sustained && rsi_overbought && bar_bearish && near_extreme)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            return false;
         const double entry = bid;

         // SL beyond the box high; cap distance at sl_atr_cap_mult * ATR(M15).
         double sl = g_box_high + strategy_sl_atr_buffer_mult * atr_m15;
         const double cap_sl = entry + strategy_sl_atr_cap_mult * atr_m15;
         if(sl > cap_sl) sl = cap_sl;
         sl = QM_StopRulesNormalizePrice(_Symbol, sl);

         // TP = mean-revert to box-range midpoint (fade-to-half).
         double tp = g_box_low + strategy_tp_range_frac * box_range;
         tp = QM_StopRulesNormalizePrice(_Symbol, tp);

         // Sanity: SL above, TP below the SELL entry.
         if(!(sl > entry) || !(tp < entry))
            return false;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "TOKYO_FADE_SELL";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;

         g_traded_day_key  = day_key;
         g_did_sell_today  = true;
         g_entry_bar_index = 0;
         g_be_done         = false;
         g_entry_direction = -1;
         return true;
        }
     }

   // -------- BUY: fade a downside spike (mirror) --------
   if(!g_did_buy_today)
     {
      const bool spike_meaningful = (g_box_open - g_box_low) >= strategy_spike_min_atr_d1_frac * atr_d1;
      const bool spike_sustained  = g_box_close < (g_box_high - strategy_spike_sustain_frac * box_range);
      const bool rsi_oversold     = (rsi1 <= strategy_rsi_oversold && rsi2 <= strategy_rsi_oversold);
      const bool bar_bullish      = (close1 > open1);
      const bool near_extreme     = (low1 <= g_box_low + strategy_near_extreme_atr_frac * atr_m15);

      if(spike_meaningful && spike_sustained && rsi_oversold && bar_bullish && near_extreme)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            return false;
         const double entry = ask;

         // SL beyond the box low; cap distance at sl_atr_cap_mult * ATR(M15).
         double sl = g_box_low - strategy_sl_atr_buffer_mult * atr_m15;
         const double cap_sl = entry - strategy_sl_atr_cap_mult * atr_m15;
         if(sl < cap_sl) sl = cap_sl;
         sl = QM_StopRulesNormalizePrice(_Symbol, sl);

         // TP = mean-revert to box-range midpoint (fade-to-half).
         double tp = g_box_high - strategy_tp_range_frac * box_range;
         tp = QM_StopRulesNormalizePrice(_Symbol, tp);

         // Sanity: SL below, TP above the BUY entry.
         if(!(sl < entry) || !(tp > entry))
            return false;

         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "TOKYO_FADE_BUY";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = 0;

         g_traded_day_key  = day_key;
         g_did_buy_today   = true;
         g_entry_bar_index = 0;
         g_be_done         = false;
         g_entry_direction = 1;
         return true;
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade management — one-time break-even shift once price advances
// be_advance_range_frac * box_range in favour. No trailing / no widening.
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   if(g_be_done)
      return;
   if(!g_box_ready)
      return;

   const double box_range = g_box_high - g_box_low;
   if(box_range <= 0.0)
      return;
   const double advance = strategy_be_advance_range_frac * box_range;

   const int magic = MagicForThisEA();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);

      if(ptype == POSITION_TYPE_SELL)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && (entry - bid) >= advance)
           {
            // BE: entry - 1 pip (in profit direction for a short → SL below entry).
            const double be = entry - QM_StopRulesPipsToPriceDistance(_Symbol, 1);
            if(QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, be), "BE_SHIFT"))
               g_be_done = true;
           }
        }
      else if(ptype == POSITION_TYPE_BUY)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && (ask - entry) >= advance)
           {
            const double be = entry + QM_StopRulesPipsToPriceDistance(_Symbol, 1);
            if(QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, be), "BE_SHIFT"))
               g_be_done = true;
           }
        }
     }
  }

// -----------------------------------------------------------------------------
// Exit — STATE-driven discretionary exits beyond SL/TP:
//   (1) MANDATORY end-of-Asian-session flat at/after session_close_hour broker.
//   (2) Intraday time-stop: max_hold_bars M15 bars without TP/SL.
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition())
      return false;

   const int hour = BrokerHour(TimeCurrent());

   // (1) Mandatory end-of-Asian-session flat (before London opens).
   if(hour >= strategy_session_close_hour_broker)
      return true;

   // (2) Intraday time-stop.
   if(g_entry_bar_index >= strategy_max_hold_bars)
      return true;

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

   g_box_day_key     = 0;
   g_box_ready       = false;
   g_box_high        = 0.0;
   g_box_low         = 0.0;
   g_box_open        = 0.0;
   g_box_close       = 0.0;
   g_traded_day_key  = 0;
   g_did_sell_today  = false;
   g_did_buy_today   = false;
   g_entry_bar_index = 0;
   g_be_done         = false;
   g_entry_direction = 0;

   // DST-aware UTC instant of today's Tokyo-open anchor (audit; never hardcode offset).
   const datetime anchor_utc = QM_BrokerToUTC(TimeCurrent());
   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"card\":\"QM5_1365\",\"strategy\":\"tokyo-open-fade-asian-short-m15\",\"anchor_utc\":%d}",
                            (int)anchor_utc));
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

   // Per-tick: trade management (one-time BE shift).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exits (session-close flat, time-stop).
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

   // Per-closed-bar: single QM_IsNewBar consume gates ALL closed-bar work.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Advance the per-session Tokyo-open box STATE on the new closed bar.
   AdvanceBoxState_OnNewBar();

   // Advance the open-position bar counter for the intraday time-stop.
   if(HasOpenPosition())
      g_entry_bar_index++;
   else
     {
      g_entry_bar_index = 0;
      g_be_done         = false;
      g_entry_direction = 0;
     }

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
