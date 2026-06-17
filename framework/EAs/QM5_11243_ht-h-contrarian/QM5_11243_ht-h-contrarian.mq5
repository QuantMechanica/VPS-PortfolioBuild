#property strict
#property version   "5.0"
#property description "QM5_11243 Hudson Thames H-Contrarian Kagi Spread (D1, FX/metals pairs)"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11243 ht-h-contrarian
// -----------------------------------------------------------------------------
// Source: Hudson & Thames "H-Strategy" notebook (Bogomolov 2013, "Pairs trading
// based on statistical variability of the spread process"). Card:
// artifacts/cards_approved/QM5_11243_ht-h-contrarian.md (g0_status APPROVED).
//
// Mechanics (two-leg spread, D1, closed-bar reads only):
//   Spread        : s[i] = log(Close_A[i]) - log(Close_B[i]) over the formation
//                   window of `formation_bars` closed D1 bars.
//   H threshold   : H = h_mult * stdev(s) over the formation window (Bogomolov's
//                   H = spread standard deviation; the Kagi reversal magnitude).
//                   NOTE: "H" here is the Bogomolov H-construction statistic, NOT
//                   the Hurst exponent. It is fully deterministic (std-dev of a
//                   bounded rolling window of closed bars) — no ML, no external feed.
//   Kagi H-build  : Walk the spread chronologically tracking the running extreme
//                   of the current leg. A RECOGNITION POINT fires when the spread
//                   reverses by >= H from that extreme; direction flips and the
//                   extreme becomes the new turning point. Leg magnitudes feed
//                   H-volatility.
//   H-volatility  : stdev of realized Kagi leg magnitudes (the "statistical
//                   variability of the spread process"). Contrarian mode requires
//                   H_volatility < hvol_mult * H (default 2*H).
//   Contrarian    : If the LATEST recognition point (on the most recent closed
//                   bar) confirms the spread moved UP by H from its prior local
//                   minimum  -> SHORT spread (sell A, buy B).
//                   If it confirms a move DOWN by H from a prior local maximum
//                   -> LONG spread (buy A, sell B).
//   Exit          : opposite-direction recognition point; OR adverse spread move
//                   of adverse_h_stop * H from entry; OR max_hold_bars D1 bars; OR
//                   H-volatility regime failure (H_volatility >= hvol_mult * H).
//   Pair select   : Among the configured pairs, only those passing the H-volatility
//                   filter are tradable. Re-evaluated every new D1 bar (the
//                   semiannual reselection of the notebook is conservatively
//                   approximated by continuous per-bar qualification on a bounded
//                   formation window — no look-ahead).
//   Sizing        : Equal-notional two legs, each at half the per-symbol risk lot.
//                   One active spread per pair; no pyramiding.
//
// Only the strategy logic + inputs are EA-specific. Framework wiring (risk,
// magic, news, Friday-close, kill-switch) stays intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11243;
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
input int    strategy_formation_bars    = 252;   // formation window (closed D1 bars)
input double strategy_h_mult            = 1.0;    // H = h_mult * stdev(spread)
input int    strategy_max_hold_bars     = 60;     // time stop in D1 bars
input double strategy_adverse_h_stop    = 2.5;    // protective stop = mult * H
input double strategy_hvol_mult         = 2.0;    // contrarian if H_volatility < mult * H

#define STRATEGY_PAIR_COUNT 3
#define STRATEGY_SYMBOL_COUNT 6
#define STRATEGY_MAX_FORMATION 600

string g_pair_a[STRATEGY_PAIR_COUNT]      = {"EURUSD.DWX", "AUDUSD.DWX", "XAUUSD.DWX"};
string g_pair_b[STRATEGY_PAIR_COUNT]      = {"GBPUSD.DWX", "NZDUSD.DWX", "XAGUSD.DWX"};
int    g_pair_a_slot[STRATEGY_PAIR_COUNT] = {0, 2, 4};
int    g_pair_b_slot[STRATEGY_PAIR_COUNT] = {1, 3, 5};

string g_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX",
   "NZDUSD.DWX", "XAUUSD.DWX", "XAGUSD.DWX"
  };

// Per-pair cached state (advanced once per new closed D1 bar).
bool     g_pair_valid[STRATEGY_PAIR_COUNT];        // formation stats computable
bool     g_pair_tradable[STRATEGY_PAIR_COUNT];     // H-volatility filter passes
double   g_pair_H[STRATEGY_PAIR_COUNT];            // reversal threshold
double   g_pair_hvol[STRATEGY_PAIR_COUNT];         // H-volatility statistic
double   g_pair_spread_now[STRATEGY_PAIR_COUNT];   // latest closed-bar spread
double   g_pair_entry_spread[STRATEGY_PAIR_COUNT]; // spread at entry (for stop)
int      g_pair_signal[STRATEGY_PAIR_COUNT];       // +1 long-spread / -1 short / 0 none (fresh)
datetime g_pair_entry_time[STRATEGY_PAIR_COUNT];
int      g_active_pair = -1;
bool     g_state_ready = false;

int Strategy_PairIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(symbol == g_pair_a[i] || symbol == g_pair_b[i])
         return i;
     }
   return -1;
  }

bool Strategy_IsPairLeg(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   return (symbol == g_pair_a[pair_index] || symbol == g_pair_b[pair_index]);
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   if(symbol == g_pair_a[pair_index])
      return g_pair_a_slot[pair_index];
   if(symbol == g_pair_b[pair_index])
      return g_pair_b_slot[pair_index];
   return qm_magic_slot_offset;
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_11243_H_CONTRARIAN";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// Copy `count` closed D1 closes (shift 1 = last closed bar), oldest-first into
// out[0..count-1]. perf-allowed: called only from the D1 new-bar refresh path.
bool Strategy_CopyCloses(const string symbol, const int count, double &out[])
  {
   if(count < 20 || count > STRATEGY_MAX_FORMATION)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   double raw[];
   ArraySetAsSeries(raw, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, count, raw); // perf-allowed: D1 new-bar path only
   if(copied != count)
      return false;

   // Re-order to oldest-first so the Kagi walk is chronological.
   ArrayResize(out, count);
   for(int i = 0; i < count; ++i)
     {
      const double v = raw[count - 1 - i];
      if(v <= 0.0 || !MathIsValidNumber(v))
         return false;
      out[i] = v;
     }
   return true;
  }

double Strategy_StdDev(const double &values[], const int count)
  {
   if(count < 2)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < count; ++i)
      sum += values[i];
   const double mean = sum / (double)count;
   double var_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = values[i] - mean;
      var_sum += d * d;
     }
   const double v = var_sum / (double)(count - 1);
   if(v <= 0.0 || !MathIsValidNumber(v))
      return 0.0;
   return MathSqrt(v);
  }

// Deterministic Kagi H-construction over the chronological spread series.
// On success sets:
//   H            = h_mult * stdev(spread)
//   hvol         = stdev of realized Kagi leg magnitudes (statistical variability)
//   signal       = +1 long / -1 short / 0 none — non-zero ONLY when the latest
//                  recognition point landed on the final (most-recent) bar.
//   spread_now   = latest closed-bar spread value.
bool Strategy_ComputePairStats(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const int bars = MathMin(MathMax(strategy_formation_bars, 20), STRATEGY_MAX_FORMATION);

   double closes_a[];
   double closes_b[];
   if(!Strategy_CopyCloses(g_pair_a[pair_index], bars, closes_a))
      return false;
   if(!Strategy_CopyCloses(g_pair_b[pair_index], bars, closes_b))
      return false;

   double spread[];
   ArrayResize(spread, bars);
   for(int i = 0; i < bars; ++i)
     {
      const double s = MathLog(closes_a[i]) - MathLog(closes_b[i]);
      if(!MathIsValidNumber(s))
         return false;
      spread[i] = s;
     }

   const double stdev = Strategy_StdDev(spread, bars);
   if(stdev <= 0.0)
      return false;

   const double H = strategy_h_mult * stdev;
   if(H <= 0.0 || !MathIsValidNumber(H))
      return false;

   // --- Kagi H-construction walk (chronological) ---
   // dir: current leg direction (+1 up, -1 down). extreme: running high/low of
   // the current leg. A recognition point fires when the spread reverses by >= H
   // from `extreme`. `leg_mag` collects realized leg magnitudes for H-volatility.
   int    dir = 0;
   double extreme = spread[0];           // running turning point of current leg
   double leg_mags[];
   int    leg_count = 0;
   ArrayResize(leg_mags, bars);

   int    last_recog_bar = -1;           // index of the most recent recognition point
   int    last_recog_dir = 0;            // direction of the move that triggered it

   for(int i = 1; i < bars; ++i)
     {
      const double s = spread[i];

      if(dir == 0)
        {
         // Seed direction once the spread first moves by H from the start point.
         if(s - extreme >= H)
           { dir = 1;  last_recog_bar = i; last_recog_dir = 1;
             leg_mags[leg_count++] = s - extreme; extreme = s; }
         else if(extreme - s >= H)
           { dir = -1; last_recog_bar = i; last_recog_dir = -1;
             leg_mags[leg_count++] = extreme - s; extreme = s; }
         else
           {
            if(s > extreme && dir >= 0) extreme = MathMax(extreme, s);
            // keep tracking the wider start extreme until H is breached
            if(s < extreme) extreme = s;
           }
         continue;
        }

      if(dir > 0)
        {
         // Extend the up-leg; record a reversal when price falls H below the high.
         if(s > extreme)
            extreme = s;
         else if(extreme - s >= H)
           {
            leg_mags[leg_count++] = extreme - s;   // magnitude of the down reversal
            dir = -1;
            extreme = s;
            last_recog_bar = i;
            last_recog_dir = -1;                   // confirmed DOWN move by H
           }
        }
      else // dir < 0
        {
         if(s < extreme)
            extreme = s;
         else if(s - extreme >= H)
           {
            leg_mags[leg_count++] = s - extreme;   // magnitude of the up reversal
            dir = 1;
            extreme = s;
            last_recog_bar = i;
            last_recog_dir = 1;                    // confirmed UP move by H
           }
        }
     }

   // H-volatility = statistical variability of the spread process, proxied by the
   // std-dev of realized Kagi leg magnitudes. Needs >= 2 legs to be meaningful.
   double hvol = 0.0;
   if(leg_count >= 2)
     {
      double mags[];
      ArrayResize(mags, leg_count);
      for(int i = 0; i < leg_count; ++i)
         mags[i] = leg_mags[i];
      hvol = Strategy_StdDev(mags, leg_count);
     }

   // Signal is fresh ONLY when the latest recognition point landed on the final
   // (most-recent closed) bar. Contrarian: a confirmed UP move (+1) -> SHORT
   // spread (-1); a confirmed DOWN move (-1) -> LONG spread (+1).
   int signal = 0;
   if(last_recog_bar == (bars - 1) && last_recog_dir != 0)
      signal = -last_recog_dir;

   g_pair_H[pair_index]          = H;
   g_pair_hvol[pair_index]       = hvol;
   g_pair_spread_now[pair_index] = spread[bars - 1];
   g_pair_signal[pair_index]     = signal;
   return true;
  }

void Strategy_RefreshState()
  {
   g_state_ready = false;
   g_active_pair = Strategy_PairIndexForSymbol(_Symbol);

   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      g_pair_valid[i]    = Strategy_ComputePairStats(i);
      g_pair_tradable[i] = false;
      if(g_pair_valid[i])
        {
         // Contrarian mode filter: H_volatility < hvol_mult * H. A pair with no
         // realized legs yet (hvol == 0) is treated as not-yet-qualified.
         const double H = g_pair_H[i];
         if(g_pair_hvol[i] > 0.0 && g_pair_hvol[i] < strategy_hvol_mult * H)
            g_pair_tradable[i] = true;
        }
     }

   if(g_active_pair < 0)
      return;
   g_state_ready = g_pair_valid[g_active_pair];
  }

bool Strategy_IsRegisteredPairPosition(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(!Strategy_IsPairLeg(pair_index, symbol))
      return false;

   const int slot = Strategy_SlotForSymbol(pair_index, symbol);
   const int expected_magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   return (expected_magic > 0 && (int)PositionGetInteger(POSITION_MAGIC) == expected_magic);
  }

int Strategy_OpenPairLegCount(const int pair_index)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredPairPosition(pair_index))
         count++;
     }
   return count;
  }

datetime Strategy_EarliestPairOpenTime(const int pair_index)
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsRegisteredPairPosition(pair_index))
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

void Strategy_ClosePair(const int pair_index, const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredPairPosition(pair_index))
         QM_TM_ClosePosition(ticket, reason);
     }
  }

// Build one leg request. Protective stop sized from adverse_h_stop * H mapped
// from log-spread space to the leg's price space via the leg's own close.
bool Strategy_PrepareLegRequest(const int pair_index,
                                const string symbol,
                                const bool buy_leg,
                                QM_BasketOrderRequest &breq)
  {
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   // Adverse spread move in log space -> approximate price move on this leg:
   // d(price) ~= price * d(log-spread). Use the full adverse_h_stop * H budget on
   // each leg so the per-leg stop is conservative (each leg can fully absorb the
   // adverse spread excursion independently).
   const double H = g_pair_H[pair_index];
   const double log_move = strategy_adverse_h_stop * H;
   double stop_dist = entry * log_move;
   if(stop_dist < point * 10.0)
      stop_dist = point * 10.0; // floor so the stop is broker-valid
   if(!MathIsValidNumber(stop_dist) || stop_dist <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                             : NormalizeDouble(entry + stop_dist, digits);
   const double sl_points = MathAbs(entry - sl) / point;
   if(sl_points <= 0.0)
      return false;

   const double lots = QM_LotsForRisk(symbol, sl_points) * 0.5; // equal-notional, half risk per leg
   if(lots <= 0.0)
      return false;

   breq.symbol = symbol;
   breq.type = buy_leg ? QM_BUY : QM_SELL;
   breq.price = 0.0;
   breq.sl = sl;
   breq.tp = 0.0;
   breq.lots = lots;
   breq.reason = buy_leg ? "QM5_11243_H_CONTRARIAN_BUY_LEG"
                         : "QM5_11243_H_CONTRARIAN_SELL_LEG";
   breq.symbol_slot = Strategy_SlotForSymbol(pair_index, symbol);
   breq.expiration_seconds = 0;
   return true;
  }

// spread_direction: +1 long spread (buy A, sell B); -1 short spread (sell A, buy B).
bool Strategy_OpenPair(const int pair_index, const int spread_direction)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || spread_direction == 0)
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;

   const bool buy_a = (spread_direction > 0);
   const bool buy_b = !buy_a;

   QM_BasketOrderRequest req_a;
   QM_BasketOrderRequest req_b;
   if(!Strategy_PrepareLegRequest(pair_index, g_pair_a[pair_index], buy_a, req_a))
      return false;
   if(!Strategy_PrepareLegRequest(pair_index, g_pair_b[pair_index], buy_b, req_b))
      return false;

   ulong ticket_a = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req_a, ticket_a))
      return false;

   ulong ticket_b = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req_b, ticket_b))
     {
      // Roll back the orphan first leg — never run a single-leg spread.
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
      return false;
     }

   g_pair_entry_time[pair_index]   = TimeCurrent();
   g_pair_entry_spread[pair_index] = g_pair_spread_now[pair_index];
   return true;
  }

bool Strategy_CheckPairNews(const int pair_index, const datetime broker_time)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   for(int leg = 0; leg < 2; ++leg)
     {
      const string symbol = (leg == 0) ? g_pair_a[pair_index] : g_pair_b[pair_index];
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance))
            return false;
        }
      else if(!QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

// No Trade Filter (time, regime). Restrict the engine to D1 and ensure exactly
// one host chart per pair runs the entry path (the leg-A slot). Fail-open on
// .DWX zero modeled spread — no spread/swap gating here.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   // Only the leg-A slot host drives entries, to avoid double-firing the pair.
   const int expected_slot = g_pair_a_slot[pair_index];
   if(qm_magic_slot_offset != expected_slot)
      return true;

   if(!g_state_ready)
      return true;

   // Regime filter: contrarian mode requires H-volatility < hvol_mult * H.
   if(!g_pair_tradable[pair_index])
      return true;

   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar() on this closed D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   if(!g_state_ready || g_active_pair < 0)
      return false;
   if(!g_pair_tradable[g_active_pair])
      return false;
   if(Strategy_OpenPairLegCount(g_active_pair) > 0)
      return false;

   const int signal = g_pair_signal[g_active_pair];
   if(signal == 0)
      return false;

   // Open the two-leg spread directly via the basket helper. The framework
   // single-entry path is not used for the two-leg send; return false so the
   // caller does not also try QM_TM_OpenPosition on the host symbol.
   Strategy_OpenPair(g_active_pair, signal);
   return false;
  }

// Trade Management — flatten any orphan single leg.
void Strategy_ManageOpenPosition()
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return;
   if(Strategy_OpenPairLegCount(pair_index) == 1)
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
  }

// Trade Close — opposite recognition point, adverse-H stop, regime failure, time stop.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || g_active_pair < 0)
      return false;
   if(Strategy_OpenPairLegCount(g_active_pair) <= 0)
      return false;

   const double H = g_pair_H[g_active_pair];
   if(H <= 0.0)
      return false;

   // Determine current spread-position direction from the entry spread vs now.
   const double entry_spread = g_pair_entry_spread[g_active_pair];
   const double spread_now   = g_pair_spread_now[g_active_pair];
   const double move         = spread_now - entry_spread; // + = spread widened up

   // 1) Protective stop: adverse spread move of adverse_h_stop * H from entry.
   //    A long-spread position (entered after a DOWN recognition, expecting the
   //    spread to rise) is hurt by a further fall; a short-spread by a rise.
   //    We don't store the entry direction separately — derive it from the open
   //    leg-A side.
   int pos_dir = 0; // +1 long spread (A bought), -1 short spread (A sold)
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsRegisteredPairPosition(g_active_pair))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == g_pair_a[g_active_pair])
        {
         pos_dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
         break;
        }
     }

   if(pos_dir != 0)
     {
      const double adverse = (pos_dir > 0) ? -move : move; // adverse excursion magnitude
      if(adverse >= strategy_adverse_h_stop * H)
        {
         Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
         return false;
        }
     }

   // 2) Opposite recognition point: a fresh recognition that flips against the
   //    held spread direction. g_pair_signal is the CONTRARIAN target direction
   //    of the latest recognition; if it opposes the current position, close.
   const int fresh = g_pair_signal[g_active_pair];
   if(fresh != 0 && pos_dir != 0 && fresh == -pos_dir)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_OPPOSITE_SIGNAL);
      return false;
     }

   // 3) Regime failure: H-volatility no longer supports contrarian mode.
   if(g_pair_hvol[g_active_pair] >= strategy_hvol_mult * H)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   // 4) Time stop: max_hold_bars D1 bars without an opposite recognition.
   datetime opened = g_pair_entry_time[g_active_pair];
   if(opened <= 0)
      opened = Strategy_EarliestPairOpenTime(g_active_pair);
   if(strategy_max_hold_bars > 0 && opened > 0 &&
      (TimeCurrent() - opened) >= strategy_max_hold_bars * PeriodSeconds(PERIOD_D1))
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_TIME_STOP);
      return false;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase). Also flattens on Friday close.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   if(QM_FrameworkFridayCloseNow(broker_time))
      Strategy_ClosePair(pair_index, QM_EXIT_FRIDAY_CLOSE);

   return !Strategy_CheckPairNews(pair_index, broker_time);
  }

// =============================================================================
// Framework wiring
// =============================================================================

int OnInit()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1,
                          MathMin(MathMax(strategy_formation_bars + 5, 300), STRATEGY_MAX_FORMATION + 5));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11243\",\"strategy\":\"ht-h-contrarian\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_RefreshState();
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if(!is_new_bar)
      return;

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
