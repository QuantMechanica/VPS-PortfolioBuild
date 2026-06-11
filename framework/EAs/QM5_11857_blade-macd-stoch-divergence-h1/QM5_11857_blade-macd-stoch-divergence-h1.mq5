#property strict
#property version   "5.0"
#property description "QM5_11857 Blade MACD Divergence + Stochastic Counter-Trend H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// Strategy: MACD divergence (bearish/bullish) on H1 confirmed by Stochastic
// overbought/oversold cross-back. Counter-trend reversal. SL behind recent
// swing high/low (5-bar), TP = 2×risk, BE when profit ≥ risk AND Stoch mid-side.
// Card: QM5_11857_blade-macd-stoch-divergence-h1
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 11857;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_macd_fast            = 12;
input int    strategy_macd_slow            = 26;
input int    strategy_macd_signal          = 9;
input int    strategy_stoch_k              = 9;
input int    strategy_stoch_d              = 3;
input int    strategy_stoch_slow           = 3;
input double strategy_stoch_overbought     = 80.0;
input double strategy_stoch_oversold      = 20.0;
input int    strategy_swing_lookback       = 50;   // bars to search for swing high/low pairs
input int    strategy_sl_bars              = 5;    // bars for SL reference (highest high / lowest low)
input int    strategy_sl_min_pips          = 20;   // minimum SL distance in pips
input int    strategy_sl_max_pips          = 35;   // maximum SL distance; skip if larger
input int    strategy_div_window           = 10;   // bars divergence stays valid after detection

// -----------------------------------------------------------------------------
// File-scope state: divergence tracking (updated once per new H1 bar)
// -----------------------------------------------------------------------------

bool   g_bear_div_active     = false;
int    g_bear_div_bars_left  = 0;

bool   g_bull_div_active     = false;
int    g_bull_div_bars_left  = 0;

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar — called exactly once per closed H1 bar (from OnTick
// after QM_IsNewBar() returns true). Scans for MACD divergence + updates state.
// perf-allowed: iHigh/iLow/QM_MACD_Main calls gated by new-bar, O(lookback).
// -----------------------------------------------------------------------------

void AdvanceState_OnNewBar()
  {
   // Decrement divergence expiry windows
   if(g_bear_div_active)
     {
      g_bear_div_bars_left--;
      if(g_bear_div_bars_left <= 0)
         g_bear_div_active = false;
     }
   if(g_bull_div_active)
     {
      g_bull_div_bars_left--;
      if(g_bull_div_bars_left <= 0)
         g_bull_div_active = false;
     }

   const int max_scan = strategy_swing_lookback - 1;  // i+1 <= swing_lookback

   // --- Bearish divergence scan: find 2 most-recent swing highs ---
   // perf-allowed: bespoke structural swing detection gated by QM_IsNewBar
   int sh_idx[2] = { -1, -1 };
   int sh_count = 0;
   for(int i = 2; i <= max_scan && sh_count < 2; ++i)
     {
      const double h_prev = iHigh(_Symbol, PERIOD_H1, i - 1);  // perf-allowed
      const double h_curr = iHigh(_Symbol, PERIOD_H1, i);       // perf-allowed
      const double h_next = iHigh(_Symbol, PERIOD_H1, i + 1);   // perf-allowed
      if(h_curr > h_prev && h_curr > h_next)
        {
         sh_idx[sh_count] = i;
         sh_count++;
        }
     }

   if(sh_count == 2)
     {
      const int idx_new = sh_idx[0];   // smaller shift = more recent swing high
      const int idx_old = sh_idx[1];   // larger shift = older swing high

      const double price_new = iHigh(_Symbol, PERIOD_H1, idx_new);  // perf-allowed
      const double price_old = iHigh(_Symbol, PERIOD_H1, idx_old);  // perf-allowed

      const double macd_new   = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_new);
      const double macd_old   = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_old);
      const double macd_new_m1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_new - 1);
      const double macd_new_p1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_new + 1);
      const double macd_old_m1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_old - 1);
      const double macd_old_p1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_old + 1);

      // Both MACD peaks must be visible hills
      const bool macd_hill_new = (macd_new > macd_new_m1 && macd_new > macd_new_p1);
      const bool macd_hill_old = (macd_old > macd_old_m1 && macd_old > macd_old_p1);

      // Bearish div: price higher high + MACD lower high
      if(price_new > price_old && macd_new < macd_old && macd_hill_new && macd_hill_old)
        {
         g_bear_div_active    = true;
         g_bear_div_bars_left = strategy_div_window;
        }
     }

   // --- Bullish divergence scan: find 2 most-recent swing lows ---
   int sl_idx[2] = { -1, -1 };
   int sl_count = 0;
   for(int i = 2; i <= max_scan && sl_count < 2; ++i)
     {
      const double l_prev = iLow(_Symbol, PERIOD_H1, i - 1);  // perf-allowed
      const double l_curr = iLow(_Symbol, PERIOD_H1, i);       // perf-allowed
      const double l_next = iLow(_Symbol, PERIOD_H1, i + 1);   // perf-allowed
      if(l_curr < l_prev && l_curr < l_next)
        {
         sl_idx[sl_count] = i;
         sl_count++;
        }
     }

   if(sl_count == 2)
     {
      const int idx_new = sl_idx[0];
      const int idx_old = sl_idx[1];

      const double price_new = iLow(_Symbol, PERIOD_H1, idx_new);  // perf-allowed
      const double price_old = iLow(_Symbol, PERIOD_H1, idx_old);  // perf-allowed

      const double macd_new    = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_new);
      const double macd_old    = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_old);
      const double macd_new_m1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_new - 1);
      const double macd_new_p1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_new + 1);
      const double macd_old_m1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_old - 1);
      const double macd_old_p1 = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, idx_old + 1);

      // Both MACD valleys must be visible troughs (inverse hills)
      const bool macd_trough_new = (macd_new < macd_new_m1 && macd_new < macd_new_p1);
      const bool macd_trough_old = (macd_old < macd_old_m1 && macd_old < macd_old_p1);

      // Bullish div: price lower low + MACD higher low
      if(price_new < price_old && macd_new > macd_old && macd_trough_new && macd_trough_old)
        {
         g_bull_div_active    = true;
         g_bull_div_bars_left = strategy_div_window;
        }
     }
  }

// -----------------------------------------------------------------------------
// No Trade Filter — no extra filters beyond framework news/news/friday
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Entry Signal — fires on closed H1 bars; reads only cached state + indicators
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return false;

   // 1 pip = 10 points on 5-digit brokers (DWX standard)
   const double pip = 10.0 * pt;
   const double sl_min_dist = strategy_sl_min_pips * pip;
   const double sl_max_dist = strategy_sl_max_pips * pip;

   // --- SHORT entry: bearish divergence active + Stoch K crossed below overbought ---
   if(g_bear_div_active)
     {
      const double k1 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
      const double k2 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);

      // Cross: K was at/above overbought on bar[2], now below on bar[1]
      if(k2 >= strategy_stoch_overbought && k1 < strategy_stoch_overbought)
        {
         // SL = highest high of last strategy_sl_bars bars + 10-point buffer
         double highest_high = -DBL_MAX;
         for(int j = 1; j <= strategy_sl_bars; ++j)           // perf-allowed
            highest_high = MathMax(highest_high, iHigh(_Symbol, PERIOD_H1, j));

         const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double sl_price = NormalizeDouble(highest_high + 10.0 * pt, _Digits);
         const double sl_dist  = sl_price - bid;

         if(sl_dist < sl_min_dist || sl_dist > sl_max_dist)
            return false;

         req.type              = QM_SELL;
         req.price             = 0.0;                           // market order at bid
         req.sl                = sl_price;
         req.tp                = NormalizeDouble(bid - 2.0 * sl_dist, _Digits);
         req.reason            = "BLADE_BEAR_DIV";
         req.symbol_slot       = qm_magic_slot_offset;
         req.expiration_seconds = 0;

         g_bear_div_active = false;  // consumed; reset so no double-entry
         return true;
        }
     }

   // --- LONG entry: bullish divergence active + Stoch K crossed above oversold ---
   if(g_bull_div_active)
     {
      const double k1 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
      const double k2 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);

      // Cross: K was at/below oversold on bar[2], now above on bar[1]
      if(k2 <= strategy_stoch_oversold && k1 > strategy_stoch_oversold)
        {
         double lowest_low = DBL_MAX;
         for(int j = 1; j <= strategy_sl_bars; ++j)            // perf-allowed
            lowest_low = MathMin(lowest_low, iLow(_Symbol, PERIOD_H1, j));

         const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double sl_price = NormalizeDouble(lowest_low - 10.0 * pt, _Digits);
         const double sl_dist  = ask - sl_price;

         if(sl_dist < sl_min_dist || sl_dist > sl_max_dist)
            return false;

         req.type              = QM_BUY;
         req.price             = 0.0;                           // market order at ask
         req.sl                = sl_price;
         req.tp                = NormalizeDouble(ask + 2.0 * sl_dist, _Digits);
         req.reason            = "BLADE_BULL_DIV";
         req.symbol_slot       = qm_magic_slot_offset;
         req.expiration_seconds = 0;

         g_bull_div_active = false;
         return true;
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management — break-even when profit >= initial risk AND stoch mid-side
// Runs per tick on the per-tick path; reads only cached indicator + live prices.
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return;

   // Stoch K at last closed bar (O(1) pooled read — fine per tick)
   const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype    = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double             open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double             current_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_SELL)
        {
         // BE not yet applied: original SL is above entry
         if(current_sl <= open_price)
            continue;

         const double risk      = current_sl - open_price;
         const double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double profit    = open_price - bid;

         // BE trigger: profit >= initial risk AND stoch has moved below 50
         if(profit >= risk && stoch_k < 50.0)
           {
            // Lock in 10 points (1 pip) profit — covers spread for short
            const double new_sl = NormalizeDouble(open_price - 10.0 * pt, _Digits);
            QM_TM_MoveSL(ticket, new_sl, "BLADE_BE_BEAR");
           }
        }
      else if(ptype == POSITION_TYPE_BUY)
        {
         // BE not yet applied: original SL is below entry
         if(current_sl >= open_price)
            continue;

         const double risk      = open_price - current_sl;
         const double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double profit    = ask - open_price;

         // BE trigger: profit >= initial risk AND stoch has moved above 50
         if(profit >= risk && stoch_k > 50.0)
           {
            const double new_sl = NormalizeDouble(open_price + 10.0 * pt, _Digits);
            QM_TM_MoveSL(ticket, new_sl, "BLADE_BE_BULL");
           }
        }
     }
  }

// -----------------------------------------------------------------------------
// Exit Signal — no discretionary exit; SL/TP + framework Friday close handle it
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook — defer to framework's 2-axis filter
// -----------------------------------------------------------------------------

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11857\",\"strategy\":\"blade-macd-stoch-divergence-h1\"}");
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

   // Per-tick: trade management (BE checks against live prices)
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != (long)magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: divergence state advance + entry signal
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   AdvanceState_OnNewBar();

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
