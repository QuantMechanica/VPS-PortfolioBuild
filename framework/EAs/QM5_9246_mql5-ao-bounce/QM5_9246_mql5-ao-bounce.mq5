#property strict
#property version   "5.00"
#property description "QM5_9246 mql5-ao-bounce — Awesome Oscillator zero-line bounce, H4 trend continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9246 mql5-ao-bounce
// Card: artifacts/cards_approved/QM5_9246_mql5-ao-bounce.md
// Source: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
//   Njuki, "MQL5 Wizard Techniques Part 50: Awesome Oscillator", 2024-11-29
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9246;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ao_sma_fast         = 5;      // AO fast SMA period
input int    strategy_ao_sma_slow         = 34;     // AO slow SMA period
input int    strategy_sma_trend           = 50;     // Trend SMA period (H4 close)
input int    strategy_atr_period          = 14;     // ATR period for stop sizing
input double strategy_sl_atr_mult         = 1.7;    // Stop = entry ± ATR × this
input double strategy_tp_rr_mult          = 2.0;    // TP = stop_dist × this
input int    strategy_max_bars_held       = 28;     // Failsafe time-exit in H4 bars

// -----------------------------------------------------------------------------
// Per-bar cached state (updated once per H4 bar in the new-bar gate)
// -----------------------------------------------------------------------------
double   g_ao[3];             // [0]=shift1 (card AO[0]), [1]=shift2, [2]=shift3
bool     g_ao_valid = false;
double   g_sma_trend = 0.0;   // SMA(strategy_sma_trend) of H4 close at shift 1
double   g_close1    = 0.0;   // H4 close at shift 1 (from CopyRates buffer)
int      g_bars_held = 0;     // H4 bars elapsed since current position opened

// Reusable CopyRates buffer (AS_SERIES=true: [0]=shift 1, [1]=shift 2, ...)
MqlRates g_rates_buf[];

// =============================================================================
// AdvanceBarState — called once per new H4 bar (inside QM_IsNewBar gate).
// Computes AO for shifts 1, 2, 3 using the standard formula:
//   AO[shift] = SMA(5, MedianPrice)[shift] - SMA(34, MedianPrice)[shift]
//   MedianPrice = (High + Low) / 2
// Also caches close[shift 1] and SMA_trend[shift 1] for the entry filter.
// =============================================================================
void AdvanceBarState()
{
   const int to_copy = strategy_ao_sma_slow + 6; // covers shifts 1..slow+3
   ArraySetAsSeries(g_rates_buf, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, to_copy, g_rates_buf); // perf-allowed: called only inside QM_IsNewBar gate in OnTick
   if(copied < strategy_ao_sma_slow + 2)
     {
      g_ao_valid = false;
      return;
     }
   // g_rates_buf[s] = bar at shift s+1 (AS_SERIES, start=1)
   // AO index s (s=0,1,2) corresponds to card AO[s] = MT5 shift s+1
   for(int s = 0; s < 3; s++)
     {
      double sma_f = 0.0, sma_s = 0.0;
      for(int k = 0; k < strategy_ao_sma_fast; k++)
         sma_f += (g_rates_buf[s + k].high + g_rates_buf[s + k].low) * 0.5;
      for(int k = 0; k < strategy_ao_sma_slow; k++)
         sma_s += (g_rates_buf[s + k].high + g_rates_buf[s + k].low) * 0.5;
      g_ao[s] = sma_f / strategy_ao_sma_fast - sma_s / strategy_ao_sma_slow;
     }
   g_ao_valid  = true;
   g_close1    = g_rates_buf[0].close;
   g_sma_trend = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_trend, 1);
}

// =============================================================================
// UpdateBarCount — called once per new H4 bar.
// Increments g_bars_held while a position is open; resets when none found.
// =============================================================================
void UpdateBarCount()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) { g_bars_held = 0; return; }
   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      g_bars_held++;
      return;
     }
   g_bars_held = 0;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No custom session or regime filter — framework handles spread/news gates.
bool Strategy_NoTradeFilter()
{
   return false;
}

// Populate req and return true when a new H4 bounce entry is valid.
// Called only on new bars (QM_IsNewBar gate in OnTick).
bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(!g_ao_valid) return false;
   if(strategy_sl_atr_mult <= 0.0 || strategy_tp_rr_mult <= 0.0) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0) return false;
   const double sl_dist = atr * strategy_sl_atr_mult;

   // Trend filter: close[shift 1] vs SMA(trend, shift 1)
   const bool long_ok  = (g_sma_trend > 0.0 && g_close1 > g_sma_trend);
   const bool short_ok = (g_sma_trend > 0.0 && g_close1 < g_sma_trend);

   // AO zero-line bounce signals (card notation: [0]=shift1, [1]=shift2, [2]=shift3)
   // Long: AO declined toward zero then started rising (above zero)
   const bool ao_long  = (g_ao[2] > g_ao[1]) && (g_ao[1] >= 0.0) && (g_ao[1] < g_ao[0]);
   // Short: AO rose toward zero then started falling (below zero)
   const bool ao_short = (g_ao[2] < g_ao[1]) && (g_ao[1] <= 0.0) && (g_ao[1] > g_ao[0]);

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(ao_long && long_ok)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = ask - sl_dist;
      req.tp     = ask + sl_dist * strategy_tp_rr_mult;
      req.reason = "AO_BOUNCE_LONG";
      return true;
     }

   if(ao_short && short_ok)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = bid + sl_dist;
      req.tp     = bid - sl_dist * strategy_tp_rr_mult;
      req.reason = "AO_BOUNCE_SHORT";
      return true;
     }

   return false;
}

// SL/TP fixed at entry; no trailing or break-even per card spec.
void Strategy_ManageOpenPosition()
{
}

// Returns true to close the open position: AO direction reversal, zero-cross,
// or failsafe 28-bar time exit.
bool Strategy_ExitSignal()
{
   if(!g_ao_valid) return false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      // Failsafe time exit
      if(g_bars_held >= strategy_max_bars_held) return true;

      const bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(is_long)
        {
         // Close long: AO crosses below zero OR two consecutive declining bars
         if(g_ao[0] < 0.0) return true;
         if(g_ao[0] < g_ao[1] && g_ao[1] < g_ao[2]) return true;
        }
      else
        {
         // Close short: AO crosses above zero OR two consecutive rising bars
         if(g_ao[0] > 0.0) return true;
         if(g_ao[0] > g_ao[1] && g_ao[1] > g_ao[2]) return true;
        }
      return false; // position found, no exit condition met
     }
   return false;
}

// Defer to framework 2-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// OnTick is modified from the skeleton to advance per-bar cached state
// BEFORE ExitSignal runs, so exits react to the just-closed bar immediately.
// -----------------------------------------------------------------------------

int OnInit()
{
   ArraySetAsSeries(g_rates_buf, true);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9246_mql5-ao-bounce\"}");
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

   // Advance per-bar cached state before exit/entry evaluation.
   // QM_IsNewBar() returns true exactly once per closed bar (on the first tick of the new bar).
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      AdvanceBarState();
      UpdateBarCount();
     }

   // Per-tick: manage and exit
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

   if(!is_new_bar)
      return;

   // FW6: daily equity snapshot on new bar
   QM_EquityStreamOnNewBar();

   // Per-closed-bar: entry
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
      if(out_ticket > 0)
         g_bars_held = 0; // reset counter for the new position
     }
}

void OnTimer()
{
   QM_FrameworkOnTimer();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest      &request,
                        const MqlTradeResult       &result)
{
   QM_FrameworkOnTradeTransaction(trans, request, result);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
