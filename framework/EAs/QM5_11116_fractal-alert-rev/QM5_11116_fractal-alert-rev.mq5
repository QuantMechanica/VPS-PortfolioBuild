#property strict
#property version   "5.0"
#property description "QM5_11116 Fractal Alert Reversal (EarnForex Fractals-Alert)"
// Strategy Card: QM5_11116_fractal-alert-rev, G0 APPROVED 2026-05-23.
// Source: EarnForex Fractals-Alert (GitHub: EarnForex/Fractals-Alert); see SPEC.md.
// Confirmed Bill Williams fractal reversal on completed H4 bars.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11116;
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
// Card §Entry: Bill Williams fractal half-width (bars each side of the centre bar).
// Standard iFractals uses 2 → a 5-bar fractal confirmed by 2 right-side bars.
input int    strategy_fractal_half      = 2;
// Card §Stop Loss: ATR period and the 0.5*ATR offset beyond the fractal level.
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 0.5;
// Card §Exit: time stop after N completed H4 bars in trade.
input int    strategy_max_hold_bars     = 18;

// -----------------------------------------------------------------------------
// Cached closed-bar fractal state. Advanced exactly once per closed bar inside
// Strategy_EntrySignal (the framework calls it once per QM_IsNewBar). No per-EA
// new-bar timestamp gate is maintained here — cadence is owned by the framework.
// -----------------------------------------------------------------------------
double g_last_top_price            = 0.0;  // most recent confirmed top-fractal high
double g_last_bottom_price         = 0.0;  // most recent confirmed bottom-fractal low
double g_last_close                = 0.0;  // last completed bar close (shift 1)
bool   g_top_confirmed_this_bar    = false;
bool   g_bottom_confirmed_this_bar = false;
int    g_bars_in_trade             = 0;

// Return TRUE if there is an open position for this EA's magic on this symbol,
// and report its direction. Cheap O(PositionsTotal) scan.
bool GetOurPosition(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
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

// Advance cached fractal state by ONE closed bar. Detects a Bill Williams
// fractal whose centre bar is at shift (half+1) — the first bar at which the
// required right-side bars have completed (finalized fractal, never a
// first-detected one that can still disappear). Runs once per closed bar.
void AdvanceFractalState()
  {
   g_top_confirmed_this_bar    = false;
   g_bottom_confirmed_this_bar = false;

   const int n = (strategy_fractal_half > 0) ? strategy_fractal_half : 2;
   const int centre = n + 1;                 // 2 right bars completed at shift 1..n

   // Bespoke fractal structural detection over (2n+1) bars, executed once per
   // closed bar (caller is the framework new-bar gate).
   const double hc = iHigh(_Symbol, _Period, centre);  // perf-allowed: bespoke fractal structure
   const double lc = iLow(_Symbol, _Period, centre);   // perf-allowed: bespoke fractal structure
   g_last_close    = iClose(_Symbol, _Period, 1);       // perf-allowed: cached closed-bar close

   if(hc > 0.0 && lc > 0.0)
     {
      bool is_top    = true;
      bool is_bottom = true;
      for(int k = 1; k <= n; ++k)
        {
         const double hl = iHigh(_Symbol, _Period, centre - k);  // perf-allowed: bespoke fractal structure
         const double hr = iHigh(_Symbol, _Period, centre + k);  // perf-allowed: bespoke fractal structure
         const double ll = iLow(_Symbol, _Period, centre - k);   // perf-allowed: bespoke fractal structure
         const double lr = iLow(_Symbol, _Period, centre + k);   // perf-allowed: bespoke fractal structure
         if(hl <= 0.0 || hr <= 0.0 || ll <= 0.0 || lr <= 0.0)
           {
            is_top = false; is_bottom = false; break;
           }
         if(!(hc > hl) || !(hc > hr))
            is_top = false;
         if(!(lc < ll) || !(lc < lr))
            is_bottom = false;
        }

      if(is_top)
        {
         g_last_top_price            = hc;
         g_top_confirmed_this_bar    = true;
        }
      if(is_bottom)
        {
         g_last_bottom_price         = lc;
         g_bottom_confirmed_this_bar = true;
        }
     }

   // Bars-in-trade counter for the time stop: advanced per closed bar.
   ENUM_POSITION_TYPE pt;
   if(GetOurPosition(pt))
      g_bars_in_trade++;
   else
      g_bars_in_trade = 0;
  }

// Return TRUE to BLOCK trading this tick. Cheap O(1). News/Friday/kill-switch
// are handled by the framework wiring; no extra regime filter for this card.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Fire a new reversal entry on a freshly confirmed fractal. Caller guarantees
// QM_IsNewBar()==true, so this runs once per closed bar — used to advance the
// cached fractal state before evaluating the entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceFractalState();

   // One active position per symbol/magic (card §Zusaetzliche Filter).
   ENUM_POSITION_TYPE pt;
   if(GetOurPosition(pt))
      return false;

   // Both directions confirming on the same bar is contradictory — skip.
   if(g_top_confirmed_this_bar && g_bottom_confirmed_this_bar)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.price              = 0.0;   // market: enter at next bar open
   req.tp                 = 0.0;   // exits are signal/structure/time based
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Long on a confirmed bottom fractal (swing-low reversal up).
   if(g_bottom_confirmed_this_bar && g_last_bottom_price > 0.0)
     {
      req.type   = QM_BUY;
      req.sl     = g_last_bottom_price - strategy_atr_sl_mult * atr;
      req.reason = "QM5_11116_FRACTAL_LONG";
      return (req.sl > 0.0);
     }

   // Short on a confirmed top fractal (swing-high reversal down).
   if(g_top_confirmed_this_bar && g_last_top_price > 0.0)
     {
      req.type   = QM_SELL;
      req.sl     = g_last_top_price + strategy_atr_sl_mult * atr;
      req.reason = "QM5_11116_FRACTAL_SHORT";
      return true;
     }

   return false;
  }

// No trailing/partial/break-even logic in the card; exits are discrete.
void Strategy_ManageOpenPosition()
  {
  }

// Close on opposite confirmed fractal, on close beyond the last opposite
// fractal level, or after the max-hold time stop. Reads cached state only (O(1)).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pt;
   if(!GetOurPosition(pt))
      return false;

   if(g_bars_in_trade >= strategy_max_hold_bars)
      return true;

   if(pt == POSITION_TYPE_BUY)
     {
      if(g_top_confirmed_this_bar)
         return true;
      if(g_last_bottom_price > 0.0 && g_last_close > 0.0 && g_last_close < g_last_bottom_price)
         return true;
     }
   else
     {
      if(g_bottom_confirmed_this_bar)
         return true;
      if(g_last_top_price > 0.0 && g_last_close > 0.0 && g_last_close > g_last_top_price)
         return true;
     }
   return false;
  }

// Defer to the central QM news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11116_fractal_alert_rev\"}");
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
