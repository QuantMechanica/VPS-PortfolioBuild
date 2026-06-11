#property strict
#property version   "5.0"
#property description "QM5_9918 FF Alien RSIOMA Divergence H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9918 — ForexFactory Alien RSIOMA/DDS Divergence H1
// Source: forexalien, "Alien's Extraterrestrial Visual Systems", ForexFactory
//         2013-2026, ForexFactory thread 463573 (see card source_citation)
// Logic:  H1 fractal pivot (3-left/3-right on close) divergence between price
//         and RSI-proxy (RSIOMA) + DDS confirmation. Entry triggered by RSI
//         cross-30 or DDS cross-up/down. SL at pivot extreme ± 0.35*ATR.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9918;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker            = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_rsi_period      = 14;    // RSI period (RSIOMA proxy — RSI of close)
input int    strategy_dds_k           = 8;     // DDS Stochastic K period
input int    strategy_dds_d           = 3;     // DDS Stochastic D period
input int    strategy_dds_slow        = 3;     // DDS Stochastic slow period
input int    strategy_stoch_k         = 21;    // Confirmation Stochastic K
input int    strategy_stoch_d         = 10;    // Confirmation Stochastic D
input int    strategy_stoch_slow      = 10;    // Confirmation Stochastic slow
input int    strategy_adx_period      = 21;    // ADX period
input int    strategy_atr_period      = 14;    // ATR period
input int    strategy_fractal_n       = 3;     // Fractal bars each side (3-left/3-right)
input int    strategy_min_pivot_bars  = 12;    // Minimum bars between two pivots
input int    strategy_max_pivot_bars  = 60;    // Maximum bars between two pivots
input double strategy_rsi_os_zone     = 45.0;  // Both long RSI lows must be below this
input double strategy_rsi_extreme     = 30.0;  // At least one long RSI low must be below this
input double strategy_rsi_ob_zone     = 55.0;  // Both short RSI highs must be above this
input double strategy_rsi_extreme_hi  = 70.0;  // At least one short RSI high must be above this
input int    strategy_dds_window      = 5;     // DDS cross-confirmation window (bars after pivot)
input int    strategy_adx_fall_bars   = 4;     // Reject if ADX declining for this many bars
input double strategy_sl_atr_buf      = 0.35;  // SL offset from pivot extreme in ATR multiples
input double strategy_sl_min_atr      = 0.8;   // Reject setup if SL < this * ATR
input double strategy_sl_max_atr      = 3.0;   // Reject setup if SL > this * ATR
input double strategy_tp_r            = 1.8;   // Take profit in R multiples
input double strategy_exit_r          = 0.8;   // RSI mid-line exit enabled after this R profit
input int    strategy_time_stop_bars  = 18;    // Time stop in H1 bars
input double strategy_spread_atr_max  = 0.15;  // Max spread as fraction of ATR(14)

// ---------------------------------------------------------------------------
// File-scope state
// ---------------------------------------------------------------------------

struct QM9918_Pivot
  {
   double price_ext;   // iLow (for long pivots) or iHigh (for short pivots)
   double rsi_val;     // RSI at pivot bar
   double dds_k_val;   // DDS %K at pivot bar
   double dds_d_val;   // DDS %D at pivot bar
   int    bar_idx;     // Bar shift (1 = last closed bar)
  };

QM9918_Pivot g_lo[2];          // Low pivots: [0]=most recent, [1]=older
QM9918_Pivot g_hi[2];          // High pivots: [0]=most recent, [1]=older
bool         g_long_setup  = false;
bool         g_short_setup = false;
double       g_long_sl     = 0.0;
double       g_short_sl    = 0.0;

int  g_bars_in_trade  = 0;
bool g_reached_08r    = false;
bool g_is_long_trade  = false;
bool g_do_exit        = false;

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

bool HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      return true;
     }
   return false;
  }

bool CheckADXNotFalling()
  {
   // Returns false (block entry) when ADX has been declining for > strategy_adx_fall_bars bars
   int streak = 0;
   double prev = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   for(int i = 2; i <= strategy_adx_fall_bars + 2; i++)
     {
      double cur = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, i);
      if(cur > 0.0 && prev < cur)
        { streak++; prev = cur; }
      else
         break;
     }
   return (streak <= strategy_adx_fall_bars);
  }

bool CheckDDSCrossUp(const int anchor_bar)
  {
   // True if DDS K crossed above D at anchor_bar or within strategy_dds_window bars more recent
   for(int db = 0; db < strategy_dds_window; db++)
     {
      int b1 = anchor_bar - db;
      int b2 = b1 + 1;
      if(b1 < 1 || b2 < 1) break;
      double k1 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b1);
      double d1 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b1);
      double k2 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b2);
      double d2 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b2);
      if(k1 > d1 && k2 <= d2) return true;
     }
   return false;
  }

bool CheckDDSCrossDown(const int anchor_bar)
  {
   for(int db = 0; db < strategy_dds_window; db++)
     {
      int b1 = anchor_bar - db;
      int b2 = b1 + 1;
      if(b1 < 1 || b2 < 1) break;
      double k1 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b1);
      double d1 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b1);
      double k2 = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b2);
      double d2 = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, b2);
      if(k1 < d1 && k2 >= d2) return true;
     }
   return false;
  }

void ScanPivots()
  {
   // Detect 2 most-recent confirmed fractal lows and highs in H1 close series.
   // perf-allowed: bespoke fractal structural logic, called once per new H1 bar.
   const int N    = strategy_fractal_n;       // = 3
   const int SMAX = strategy_max_pivot_bars;  // = 60
   int lo_found = 0, hi_found = 0;

   for(int i = N + 1; i <= SMAX && (lo_found < 2 || hi_found < 2); i++)
     {
      double c_i = iClose(_Symbol, PERIOD_H1, i); // perf-allowed
      if(c_i <= 0.0) continue;
      bool is_lo = true, is_hi = true;
      for(int j = 1; j <= N; j++)
        {
         double c_r = iClose(_Symbol, PERIOD_H1, i - j); // perf-allowed
         double c_l = iClose(_Symbol, PERIOD_H1, i + j); // perf-allowed
         if(c_r <= 0.0 || c_l <= 0.0) { is_lo = is_hi = false; break; }
         if(c_i >= c_r || c_i >= c_l) is_lo = false;
         if(c_i <= c_r || c_i <= c_l) is_hi = false;
        }
      if(is_lo && lo_found < 2)
        {
         g_lo[lo_found].price_ext = iLow(_Symbol, PERIOD_H1, i);  // perf-allowed
         g_lo[lo_found].bar_idx   = i;
         g_lo[lo_found].rsi_val   = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, i);
         g_lo[lo_found].dds_k_val = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, i);
         g_lo[lo_found].dds_d_val = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, i);
         lo_found++;
        }
      if(is_hi && hi_found < 2)
        {
         g_hi[hi_found].price_ext = iHigh(_Symbol, PERIOD_H1, i); // perf-allowed
         g_hi[hi_found].bar_idx   = i;
         g_hi[hi_found].rsi_val   = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, i);
         g_hi[hi_found].dds_k_val = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, i);
         g_hi[hi_found].dds_d_val = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, i);
         hi_found++;
        }
     }

   g_long_setup  = false;
   g_short_setup = false;
   g_long_sl     = 0.0;
   g_short_sl    = 0.0;
   if(lo_found < 2 && hi_found < 2) return;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0) return;

   // --- Long divergence check ---
   if(lo_found == 2)
     {
      int span = g_lo[1].bar_idx - g_lo[0].bar_idx;
      if(span >= strategy_min_pivot_bars && span <= strategy_max_pivot_bars)
        {
         double c0 = iClose(_Symbol, PERIOD_H1, g_lo[0].bar_idx); // perf-allowed
         double c1 = iClose(_Symbol, PERIOD_H1, g_lo[1].bar_idx); // perf-allowed
         bool price_ll  = (c0 < c1);
         bool rsi_hl    = (g_lo[0].rsi_val > g_lo[1].rsi_val);
         bool both_os   = (g_lo[0].rsi_val < strategy_rsi_os_zone && g_lo[1].rsi_val < strategy_rsi_os_zone);
         bool one_ext   = (g_lo[0].rsi_val < strategy_rsi_extreme || g_lo[1].rsi_val < strategy_rsi_extreme);
         bool dds_ok    = (g_lo[0].dds_k_val > g_lo[1].dds_k_val) || CheckDDSCrossUp(g_lo[0].bar_idx);
         double stk1    = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
         double stk3    = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 3);
         bool stoch_ok  = (stk1 > stk3);
         bool adx_ok    = CheckADXNotFalling();
         if(price_ll && rsi_hl && both_os && one_ext && dds_ok && stoch_ok && adx_ok)
           {
            double sl_price = g_lo[0].price_ext - strategy_sl_atr_buf * atr;
            double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double sl_dist  = ask - sl_price;
            if(sl_dist >= strategy_sl_min_atr * atr && sl_dist <= strategy_sl_max_atr * atr)
              {
               g_long_setup = true;
               g_long_sl    = sl_price;
              }
           }
        }
     }

   // --- Short divergence check ---
   if(hi_found == 2)
     {
      int span = g_hi[1].bar_idx - g_hi[0].bar_idx;
      if(span >= strategy_min_pivot_bars && span <= strategy_max_pivot_bars)
        {
         double c0 = iClose(_Symbol, PERIOD_H1, g_hi[0].bar_idx); // perf-allowed
         double c1 = iClose(_Symbol, PERIOD_H1, g_hi[1].bar_idx); // perf-allowed
         bool price_hh  = (c0 > c1);
         bool rsi_lh    = (g_hi[0].rsi_val < g_hi[1].rsi_val);
         bool both_ob   = (g_hi[0].rsi_val > strategy_rsi_ob_zone && g_hi[1].rsi_val > strategy_rsi_ob_zone);
         bool one_ext   = (g_hi[0].rsi_val > strategy_rsi_extreme_hi || g_hi[1].rsi_val > strategy_rsi_extreme_hi);
         bool dds_ok    = (g_hi[0].dds_k_val < g_hi[1].dds_k_val) || CheckDDSCrossDown(g_hi[0].bar_idx);
         double stk1    = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
         double stk3    = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 3);
         bool stoch_ok  = (stk1 < stk3);
         bool adx_ok    = CheckADXNotFalling();
         if(price_hh && rsi_lh && both_ob && one_ext && dds_ok && stoch_ok && adx_ok)
           {
            double sl_price = g_hi[0].price_ext + strategy_sl_atr_buf * atr;
            double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sl_dist  = sl_price - bid;
            if(sl_dist >= strategy_sl_min_atr * atr && sl_dist <= strategy_sl_max_atr * atr)
              {
               g_short_setup = true;
               g_short_sl    = sl_price;
              }
           }
        }
     }
  }

void CheckExits(const bool is_long)
  {
   // Called once per new bar when position is open.
   double rsi1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   double rsi2 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);
   double k1   = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 1);
   double d1   = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 1);
   double k2   = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 2);
   double d2   = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 2);
   if(is_long)
     {
      // RSI crossed back below 50 after reaching 0.8R profit
      if(g_reached_08r && rsi1 < 50.0 && rsi2 >= 50.0)
        { g_do_exit = true; return; }
      // DDS crossed down before reaching 0.8R
      if(!g_reached_08r && k1 < d1 && k2 >= d2)
        { g_do_exit = true; return; }
     }
   else
     {
      // RSI crossed back above 50 after reaching 0.8R profit
      if(g_reached_08r && rsi1 > 50.0 && rsi2 <= 50.0)
        { g_do_exit = true; return; }
      // DDS crossed up before reaching 0.8R
      if(!g_reached_08r && k1 > d1 && k2 <= d2)
        { g_do_exit = true; return; }
     }
  }

void AdvanceState_OnNewBar()
  {
   bool has_pos = HasOwnPosition();
   if(!has_pos)
     {
      g_bars_in_trade = 0;
      g_reached_08r   = false;
      g_do_exit       = false;
      ScanPivots();
      return;
     }

   // Determine position direction
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      g_is_long_trade = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }

   g_bars_in_trade++;
   if(g_bars_in_trade >= strategy_time_stop_bars)
     { g_do_exit = true; return; }

   CheckExits(g_is_long_trade);
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

// No Trade Filter — spread check is deferred to EntrySignal to avoid blocking
// position management on wide-spread ticks.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceState_OnNewBar();

   if(HasOwnPosition()) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   // Spread filter
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)
                        * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(spread > strategy_spread_atr_max * atr) return false;

   double rsi1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   double rsi2 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);
   double k1   = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 1);
   double d1   = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 1);
   double k2   = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 2);
   double d2   = QM_Stoch_D(_Symbol, PERIOD_H1, strategy_dds_k, strategy_dds_d, strategy_dds_slow, 2);

   // Long entry: RSI crossed above 30 OR DDS crossed up
   if(g_long_setup && g_long_sl > 0.0)
     {
      bool rsi_trig = (rsi1 > strategy_rsi_extreme && rsi2 <= strategy_rsi_extreme);
      bool dds_trig = (k1 > d1 && k2 <= d2);
      if(rsi_trig || dds_trig)
        {
         double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl_dist = ask - g_long_sl;
         if(sl_dist > 0.0)
           {
            req.type               = QM_BUY;
            req.price              = ask;
            req.sl                 = g_long_sl;
            req.tp                 = ask + strategy_tp_r * sl_dist;
            req.reason             = "RSIOMA_DIV_LONG";
            req.symbol_slot        = 0;
            req.expiration_seconds = 0;
            return true;
           }
        }
     }

   // Short entry: RSI crossed below 70 OR DDS crossed down
   if(g_short_setup && g_short_sl > 0.0)
     {
      bool rsi_trig = (rsi1 < strategy_rsi_extreme_hi && rsi2 >= strategy_rsi_extreme_hi);
      bool dds_trig = (k1 < d1 && k2 >= d2);
      if(rsi_trig || dds_trig)
        {
         double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl_dist = g_short_sl - bid;
         if(sl_dist > 0.0)
           {
            req.type               = QM_SELL;
            req.price              = bid;
            req.sl                 = g_short_sl;
            req.tp                 = bid - strategy_tp_r * sl_dist;
            req.reason             = "RSIOMA_DIV_SHORT";
            req.symbol_slot        = 0;
            req.expiration_seconds = 0;
            return true;
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Update g_reached_08r per tick from live position data
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      const double open_p = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_p   = PositionGetDouble(POSITION_SL);
      if(sl_p <= 0.0) break;
      const double r_dist = MathAbs(open_p - sl_p);
      if(r_dist <= 0.0) break;

      const bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double cur  = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((is_buy ? (cur - open_p) : (open_p - cur)) >= strategy_exit_r * r_dist)
         g_reached_08r = true;
      break;
     }
  }

bool Strategy_ExitSignal()
  {
   if(!g_do_exit) return false;
   g_do_exit = false;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to QM_NewsAllowsTrade framework logic
  }

// ---------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// ---------------------------------------------------------------------------

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
