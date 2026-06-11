#property strict
#property version   "5.0"
#property description "QM5_9522 MQL5 Order Block Inducement BOS (mql5-ob-induce)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9522 — Order Block / Inducement / Break-of-Structure / FVG
// Source: Allan Munene Mutiiria, MQL5 Article #22078, 2026-04-28
// Card:   artifacts/cards_approved/QM5_9522_mql5-ob-induce.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9522;
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
input int    strategy_ob_range_candles  = 7;     // consolidation window before OB
input int    strategy_ob_max_dev_pts    = 50;    // max consolidation range in points
input int    strategy_ob_wait_bars      = 3;     // bars after OB candle to allow for impulse
input double strategy_ob_impulse_thresh = 1.0;   // impulse body >= this * ATR(14)
input int    strategy_atr_period        = 14;    // ATR period for impulse filter
input int    strategy_ob_lookback       = 30;    // max bars to scan for OB zones
input int    strategy_min_ind_depth_pts = 20;    // min inducement depth in points
input int    strategy_min_fvg_pts       = 10;    // min FVG size in points
input int    strategy_sl_offset_pts     = 10;    // SL offset beyond OB edge in points
input double strategy_rr_ratio          = 4.0;   // TP = rr_ratio * SL distance
input int    strategy_htf_sma_period    = 50;    // H4 SMA period for trend filter

// -----------------------------------------------------------------------------
// Strategy_NoTradeFilter — cheap per-tick session gate
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false; // framework news/friday-close gates are sufficient
  }

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar — called once per closed M30 bar from Strategy_EntrySignal
// Scans history for a valid OB+Inducement+BOS+FVG setup and returns true if found.
// Fills ob_top / ob_bottom / is_bull and entry prices.
// -----------------------------------------------------------------------------
bool FindOBSetup(double &ob_top, double &ob_bottom, bool &is_bull,
                 double &entry_sl, double &entry_tp)
  {
   const double atr         = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double min_impulse = strategy_ob_impulse_thresh * atr;
   const double max_consol  = strategy_ob_max_dev_pts * _Point;
   const double min_ind     = strategy_min_ind_depth_pts * _Point;
   const double min_fvg     = strategy_min_fvg_pts * _Point;
   const double sl_off      = strategy_sl_offset_pts * _Point;

   if(atr <= 0.0 || min_impulse <= 0.0)
      return false;

   // HTF trend via H4 SMA
   const double htf_sma   = QM_SMA(_Symbol, PERIOD_H4, strategy_htf_sma_period, 1);
   const double htf_close = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: single HTF bar read
   const bool   htf_bull  = (htf_close > htf_sma);
   const bool   htf_bear  = (htf_close < htf_sma);
   if(!htf_bull && !htf_bear)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const int    lookback = strategy_ob_lookback;

   // Scan from oldest to newest; take the most recent qualifying OB
   // perf-allowed: OHLC calls below are bespoke structural logic inside QM_IsNewBar gate
   for(int i = lookback; i >= strategy_ob_wait_bars + 2; i--)
     {
      // --- Consolidation check: ob_range_candles bars BEFORE the OB candle ---
      double c_hi = 0.0, c_lo = DBL_MAX;
      bool   c_ok = true;
      for(int j = 1; j <= strategy_ob_range_candles; j++)
        {
         const int b = i + j;
         if(b > lookback + 10) { c_ok = false; break; }
         const double h = iHigh(_Symbol, _Period, b); // perf-allowed: bespoke OB structural scan, once per bar
         const double l = iLow(_Symbol, _Period, b);  // perf-allowed
         if(h <= 0.0 || l <= 0.0) { c_ok = false; break; }
         c_hi = MathMax(c_hi, h);
         c_lo = MathMin(c_lo, l);
        }
      if(!c_ok || c_hi <= c_lo || (c_hi - c_lo) > max_consol)
         continue;

      // --- OB candle = bar i ---
      const double ob_o = iOpen(_Symbol, _Period, i);  // perf-allowed
      const double ob_c = iClose(_Symbol, _Period, i); // perf-allowed
      const double ob_h = iHigh(_Symbol, _Period, i);  // perf-allowed
      const double ob_l = iLow(_Symbol, _Period, i);   // perf-allowed
      if(ob_o <= 0.0 || ob_c <= 0.0 || ob_h <= 0.0 || ob_l <= 0.0)
         continue;

      // --- Impulse candle = bar i-1 ---
      const double imp_o = iOpen(_Symbol, _Period, i - 1);  // perf-allowed
      const double imp_c = iClose(_Symbol, _Period, i - 1); // perf-allowed
      const double imp_h = iHigh(_Symbol, _Period, i - 1);  // perf-allowed
      const double imp_l = iLow(_Symbol, _Period, i - 1);   // perf-allowed
      if(imp_o <= 0.0 || imp_c <= 0.0) continue;
      const double imp_body = MathAbs(imp_c - imp_o);
      if(imp_body < min_impulse) continue;

      // Bullish OB: last bearish candle before bullish impulse
      // Bearish OB: last bullish candle before bearish impulse
      const bool is_bull_ob = (ob_c < ob_o) && (imp_c > imp_o);
      const bool is_bear_ob = (ob_c > ob_o) && (imp_c < imp_o);
      if(!is_bull_ob && !is_bear_ob) continue;

      // HTF alignment
      if(is_bull_ob && !htf_bull) continue;
      if(is_bear_ob && !htf_bear) continue;

      // --- FVG: gap between bar before OB (i+1) and impulse candle (i-1) ---
      const double prev_h = iHigh(_Symbol, _Period, i + 1); // perf-allowed
      const double prev_l = iLow(_Symbol, _Period, i + 1);  // perf-allowed
      bool fvg_ok = false;
      if(is_bull_ob)
         fvg_ok = (imp_l - prev_h) >= min_fvg;   // gap above pre-OB bar
      else
         fvg_ok = (prev_l - imp_h) >= min_fvg;   // gap below pre-OB bar
      if(!fvg_ok) continue;

      // --- Inducement + BOS scan: bars i-2 down to bar 2 ---
      bool   bos_found  = false;
      bool   ind_found  = false;
      double track_hi   = imp_h;
      double track_lo   = imp_l;

      for(int k = i - 2; k >= 2; k--)
        {
         const double kh = iHigh(_Symbol, _Period, k);  // perf-allowed
         const double kl = iLow(_Symbol, _Period, k);   // perf-allowed
         const double kc = iClose(_Symbol, _Period, k); // perf-allowed
         if(kh <= 0.0 || kl <= 0.0) break;

         if(is_bull_ob)
           {
            if(!ind_found && (track_hi - kl) >= min_ind)
               ind_found = true;
            if(ind_found && kc > track_hi)
              { bos_found = true; break; }
            track_hi = MathMax(track_hi, kh);
           }
         else
           {
            if(!ind_found && (kh - track_lo) >= min_ind)
               ind_found = true;
            if(ind_found && kc < track_lo)
              { bos_found = true; break; }
            track_lo = MathMin(track_lo, kl);
           }
        }
      if(!bos_found) continue;

      // --- Retest check: current price inside OB zone ---
      if(is_bull_ob)
        {
         // Price inside bullish OB → long
         if(bid < ob_l || bid > ob_h)
            continue;
         const double sl_price = ob_l - sl_off;
         const double rr_dist  = ask - sl_price;
         if(rr_dist <= 0.0) continue;
         ob_top    = ob_h;
         ob_bottom = ob_l;
         is_bull   = true;
         entry_sl  = sl_price;
         entry_tp  = ask + strategy_rr_ratio * rr_dist;
         return true;
        }
      else
        {
         // Price inside bearish OB → short
         if(bid < ob_l || bid > ob_h)
            continue;
         const double sl_price = ob_h + sl_off;
         const double rr_dist  = sl_price - bid;
         if(rr_dist <= 0.0) continue;
         ob_top    = ob_h;
         ob_bottom = ob_l;
         is_bull   = false;
         entry_sl  = sl_price;
         entry_tp  = bid - strategy_rr_ratio * rr_dist;
         return true;
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_EntrySignal — called once per closed bar by framework
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   double ob_top = 0.0, ob_bottom = 0.0, entry_sl = 0.0, entry_tp = 0.0;
   bool   is_bull = false;

   if(!FindOBSetup(ob_top, ob_bottom, is_bull, entry_sl, entry_tp))
      return false;

   req.symbol_slot       = qm_magic_slot_offset;
   req.price             = 0.0; // market order
   req.expiration_seconds = 0;

   if(is_bull)
     {
      req.type   = QM_BUY;
      req.sl     = entry_sl;
      req.tp     = entry_tp;
      req.reason = "OB_BULL_RETEST";
     }
   else
     {
      req.type   = QM_SELL;
      req.sl     = entry_sl;
      req.tp     = entry_tp;
      req.reason = "OB_BEAR_RETEST";
     }

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy_ManageOpenPosition — no trailing for V5 P2 baseline
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   // Card default: exits via SL/TP only; no trailing or BE for first P2.
  }

// -----------------------------------------------------------------------------
// Strategy_ExitSignal — no discretionary exit
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy_NewsFilterHook — defer to framework
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"a120af9a-fb72-526c-bb80-d1d098a617b5\",\"ea\":\"QM5_9522_mql5-ob-induce\"}");
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
