#property strict
#property version   "5.0"
#property description "QM5_9455 GK CE+ZLSMA Heikin Ashi Trend (3b3ec48a)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9455 — Geraked CE + ZLSMA Heikin Ashi Trend
// Card: 3b3ec48a-0755-5187-9331-afb36e174175
// Entry: Chandelier Exit direction flip confirmed by HA close vs ZLSMA
// Exit:  HA close crosses back through ZLSMA (non-negative profit) or 96-bar
//        time stop (24 h at M15)
// Stop:  CE level ± 650 points; lot sized via RISK_FIXED=$1000
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9455;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ce_atr_period       = 1;     // CE ATR period (card default: 1)
input double strategy_ce_atr_mult         = 0.75;  // CE ATR multiplier (card default: 0.75)
input int    strategy_zl_period           = 50;    // ZLSMA linear-regression period (card default: 50)
input int    strategy_sl_extra_pips       = 650;   // Points below/above CE level for SL (card: 650*point)
input int    strategy_time_exit_bars      = 96;    // Time exit in M15 bars; 96 * M15 = 24 h

// ---- ZLSMA computation buffers (fixed-size; avoids per-bar allocation) ----
#define ZLSMA_MAX_BARS 120
double g_close_buf[ZLSMA_MAX_BARS];
double g_lsma_buf[ZLSMA_MAX_BARS];

// ---- Chandelier Exit state machine ----
double g_ce_long_stop          = 0.0;   // ratcheting long trail stop
double g_ce_short_stop         = 0.0;   // ratcheting short trail stop
int    g_ce_dir                = 0;     // +1 = long trend, -1 = short trend, 0 = uninitialized
double g_entry_ce_long_stop    = 0.0;   // CE long stop at the most recent CE_B flip
double g_entry_ce_short_stop   = 0.0;   // CE short stop at the most recent CE_S flip

// ---- Per-bar signals written by AdvanceStateOnNewBar, read by hooks ----
bool   g_ce_b_signal           = false; // CE flipped bullish on last closed bar
bool   g_ce_s_signal           = false; // CE flipped bearish on last closed bar
bool   g_ha_above_zlsma        = false; // HA close > ZLSMA on last closed bar
bool   g_ha_above_zlsma_prev   = false; // HA close > ZLSMA on bar-before-last (cross detection)
bool   g_state_initialized     = false; // true after first successful AdvanceStateOnNewBar

// ============================================================
// LSMA helper
// Linear regression line value at the newest (rightmost) bar.
// buf[start_idx] = oldest, buf[start_idx + n - 1] = newest.
// ============================================================
double ComputeLSMA(const double &buf[], const int n, const int start_idx)
  {
   if(n <= 1)
      return (n == 1) ? buf[start_idx] : 0.0;
   double sx = 0.0, sx2 = 0.0, sy = 0.0, sxy = 0.0;
   for(int i = 0; i < n; i++)
     {
      const double x = (double)(i + 1); // x=1 (oldest) .. x=n (newest)
      const double y = buf[start_idx + i];
      sx  += x;
      sx2 += x * x;
      sy  += y;
      sxy += x * y;
     }
   const double d = (double)n * sx2 - sx * sx;
   if(d == 0.0)
      return buf[start_idx + n - 1];
   const double b = ((double)n * sxy - sx * sy) / d;
   const double a = (sy - b * sx) / (double)n;
   return a + b * (double)n; // value at x = n (newest)
  }

// ============================================================
// Per-bar state advance — called once per closed bar.
// Reads shift=1 (last closed bar) data; updates CE + ZLSMA + HA state.
// ============================================================
void AdvanceStateOnNewBar()
  {
   const int zp         = strategy_zl_period;
   const int total_bars = 2 * zp - 1; // bars of history needed for ZLSMA
   if(total_bars > ZLSMA_MAX_BARS || total_bars < 3 || zp < 2)
      return;

   // Fill close buffer oldest-first: g_close_buf[0] = bar[total_bars], ..., g_close_buf[total_bars-1] = bar[1]
   // perf-allowed: ZLSMA requires (2*period-1) iClose reads; gated by QM_IsNewBar — once per closed bar
   for(int i = 0; i < total_bars; i++)
      g_close_buf[i] = iClose(_Symbol, _Period, total_bars - i); // perf-allowed

   // Heikin Ashi close at bar[1]: (O + H + L + C) / 4
   const double o1 = iOpen(_Symbol,  _Period, 1); // perf-allowed: HA formula (O+H+L+C)/4
   const double h1 = iHigh(_Symbol,  _Period, 1); // perf-allowed: HA formula (O+H+L+C)/4
   const double l1 = iLow(_Symbol,   _Period, 1); // perf-allowed: HA formula (O+H+L+C)/4
   const double c1 = g_close_buf[total_bars - 1]; // close[1] already in ZLSMA buffer — no extra call
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return;
   const double ha_close_1 = (o1 + h1 + l1 + c1) / 4.0;

   // ZLSMA: compute LSMA series then LSMA-of-LSMA
   // g_lsma_buf[k] = LSMA at shift = (zp - k):
   //   k = 0 → window close[zp+zp-1 .. zp] (oldest LSMA)
   //   k = zp-1 → window close[zp .. 1]   (newest LSMA = lsma1)
   for(int k = 0; k < zp; k++)
      g_lsma_buf[k] = ComputeLSMA(g_close_buf, zp, k);

   const double lsma1 = g_lsma_buf[zp - 1];             // LSMA at bar[1]
   const double lsma2 = ComputeLSMA(g_lsma_buf, zp, 0); // LSMA-of-LSMA at bar[1]
   const double zlsma = 2.0 * lsma1 - lsma2;

   // Update HA vs ZLSMA state (carry previous value for cross detection)
   g_ha_above_zlsma_prev = g_ha_above_zlsma;
   g_ha_above_zlsma      = (ha_close_1 > zlsma);

   // Chandelier Exit update using QM_ATR (framework-pooled handle, no raw iATR)
   const double atr1 = QM_ATR(_Symbol, _Period, strategy_ce_atr_period, 1);
   if(atr1 <= 0.0)
      return;
   const double ce_long_cand  = c1 - atr1 * strategy_ce_atr_mult;
   const double ce_short_cand = c1 + atr1 * strategy_ce_atr_mult;

   g_ce_b_signal = false;
   g_ce_s_signal = false;

   if(g_ce_dir == 0) // first bar: initialise direction, no signal
     {
      g_ce_long_stop      = ce_long_cand;
      g_ce_short_stop     = ce_short_cand;
      g_ce_dir            = 1;
      g_state_initialized = true;
     }
   else if(g_ce_dir == 1) // in long trend: ratchet stop upward; flip on close < stop
     {
      g_ce_long_stop = MathMax(g_ce_long_stop, ce_long_cand);
      if(c1 < g_ce_long_stop)
        {
         g_ce_dir              = -1;
         g_ce_short_stop       = ce_short_cand;
         g_entry_ce_short_stop = g_ce_short_stop;
         g_ce_s_signal         = true;
        }
     }
   else // g_ce_dir == -1: in short trend: ratchet stop downward; flip on close > stop
     {
      g_ce_short_stop = MathMin(g_ce_short_stop, ce_short_cand);
      if(c1 > g_ce_short_stop)
        {
         g_ce_dir             = 1;
         g_ce_long_stop       = ce_long_cand;
         g_entry_ce_long_stop = g_ce_long_stop;
         g_ce_b_signal        = true;
        }
     }
  }

// ============================================================
// Framework strategy hooks
// ============================================================

bool Strategy_NoTradeFilter()
  {
   return false; // framework handles news + Friday close; no custom session filter
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceStateOnNewBar(); // advance CE/ZLSMA/HA state for the just-closed bar

   if(!g_state_initialized)
      return false;

   // One position per symbol/magic (MultipleOpenPos = false per card)
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   // Buy: CE_B signal (direction just flipped bullish) AND HA close > ZLSMA
   if(g_ce_b_signal && g_ha_above_zlsma)
     {
      const double sl  = g_entry_ce_long_stop - (double)strategy_sl_extra_pips * point;
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(sl <= 0.0 || sl >= ask - point)
         return false;
      req.type        = QM_BUY;
      req.price       = 0.0;
      req.sl          = NormalizeDouble(sl, _Digits);
      req.tp          = 0.0;
      req.reason      = "CE_B_HA_ABOVE_ZLSMA";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   // Sell: CE_S signal (direction just flipped bearish) AND HA close < ZLSMA
   if(g_ce_s_signal && !g_ha_above_zlsma)
     {
      const double sl  = g_entry_ce_short_stop + (double)strategy_sl_extra_pips * point;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(sl <= bid + point)
         return false;
      req.type        = QM_SELL;
      req.price       = 0.0;
      req.sl          = NormalizeDouble(sl, _Digits);
      req.tp          = 0.0;
      req.reason      = "CE_S_HA_BELOW_ZLSMA";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing stop or break-even per card spec
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_initialized)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype    = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double             profit   = PositionGetDouble(POSITION_PROFIT);
      const datetime           ot       = (datetime)PositionGetInteger(POSITION_TIME);
      const int                max_secs = strategy_time_exit_bars * (int)PeriodSeconds(_Period);

      // Time exit: 96 M15 bars = 24 h
      if((int)(TimeCurrent() - ot) >= max_secs)
         return true;

      // Signal exit (closed-bar cross, non-negative profit)
      if(ptype == POSITION_TYPE_BUY)
        {
         // Exit long when HA crossed from above to below ZLSMA on last closed bar
         if(profit >= 0.0 && g_ha_above_zlsma_prev && !g_ha_above_zlsma)
            return true;
        }
      else
        {
         // Exit short when HA crossed from below to above ZLSMA on last closed bar
         if(profit >= 0.0 && !g_ha_above_zlsma_prev && g_ha_above_zlsma)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 in framework wiring
  }

// ============================================================
// Framework wiring — do NOT edit below this line unless you know why.
// ============================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"3b3ec48a\",\"ea\":\"QM5_9455_gk-ce-zlsma\"}");
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
