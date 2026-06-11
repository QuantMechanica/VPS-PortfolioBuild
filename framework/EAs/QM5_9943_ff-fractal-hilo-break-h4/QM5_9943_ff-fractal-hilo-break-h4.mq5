#property strict
#property version   "5.0"
#property description "QM5_9943 ForexFactory Fractal High-Low Break H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// Framework inputs
// =============================================================================
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9943;
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
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker            = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

// =============================================================================
// Strategy inputs
// =============================================================================
input group "Strategy"
input int    strategy_fractal_lookback    = 80;    // max H4 bars for prior confirmed fractal search
input int    strategy_entry_offset_pips   = 5;     // pips past fractal high/low for stop entry
input double strategy_sl_atr_mult_min     = 1.0;   // minimum SL as ATR(14,H4) multiple
input double strategy_sl_atr_buffer       = 0.15;  // ATR buffer added to fractal-to-entry range
input double strategy_sl_atr_cap          = 2.2;   // maximum SL as ATR(14,H4) multiple
input int    strategy_tp_pips             = 100;   // TP in pips for FX; metals auto-use 2R
input int    strategy_expire_bars         = 6;     // H4 bars before pending stop order expires
input int    strategy_time_stop_bars      = 12;    // H4 bars before open position force-closed
input double strategy_stale_filter_r      = 0.25;  // skip entry if price within this R of entry price

// =============================================================================
// File-scope state — exit flags cached per new bar from Strategy_EntrySignal
// =============================================================================
bool g_new_long_setup  = false;
bool g_new_short_setup = false;

// =============================================================================
// Helpers
// =============================================================================

double PipSize()
  {
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pt     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 5 || digits == 3)
      return pt * 10.0;
   return pt;
  }

bool IsMetal()
  {
   return (StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "XAG") >= 0);
  }

bool HasPendingOrderForMagic(const int magic)
  {
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool GetOpenPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype     = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// Returns shift of most recent confirmed down fractal (5-bar Williams pattern)
// starting at start_shift, searching up to count bars.  Returns -1 if not found.
// Confirmed = both right-side bars (i-1, i-2) are closed → start_shift >= 3.
int FindDownFractal(const int start_shift, const int count)
  {
   const int end = start_shift + count;
   for(int i = start_shift; i <= end; ++i)
     {
      const double lo = iLow(_Symbol, PERIOD_H4, i);  // perf-allowed: fractal structural scan, closed-bar gate
      if(lo <= 0.0)
         break;
      if(iLow(_Symbol, PERIOD_H4, i - 2) > lo &&  // perf-allowed
         iLow(_Symbol, PERIOD_H4, i - 1) > lo &&  // perf-allowed
         iLow(_Symbol, PERIOD_H4, i + 1) > lo &&  // perf-allowed
         iLow(_Symbol, PERIOD_H4, i + 2) > lo)    // perf-allowed
         return i;
     }
   return -1;
  }

// Returns shift of most recent confirmed up fractal, starting at start_shift.
int FindUpFractal(const int start_shift, const int count)
  {
   const int end = start_shift + count;
   for(int i = start_shift; i <= end; ++i)
     {
      const double hi = iHigh(_Symbol, PERIOD_H4, i);  // perf-allowed: fractal structural scan, closed-bar gate
      if(hi <= 0.0)
         break;
      if(iHigh(_Symbol, PERIOD_H4, i - 2) < hi &&  // perf-allowed
         iHigh(_Symbol, PERIOD_H4, i - 1) < hi &&  // perf-allowed
         iHigh(_Symbol, PERIOD_H4, i + 1) < hi &&  // perf-allowed
         iHigh(_Symbol, PERIOD_H4, i + 2) < hi)    // perf-allowed
         return i;
     }
   return -1;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Detects confirmed fractal higher-low (long) or lower-high (short) setups.
// Updates g_new_long_setup / g_new_short_setup for use by Strategy_ExitSignal.
// Called per new H4 bar (inside QM_IsNewBar gate in OnTick).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   g_new_long_setup  = false;
   g_new_short_setup = false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
   if(atr <= 0.0)
      return false;

   const double pip    = PipSize();
   const double offset = strategy_entry_offset_pips * pip;
   const double close1 = iClose(_Symbol, PERIOD_H4, 1);  // perf-allowed: reference close for stale filter
   if(close1 <= 0.0)
      return false;

   // ---------- Long setup: confirmed down fractal higher-low ----------
   // Both fractals must fall within strategy_fractal_lookback bars of current bar.
   const int f1_dn = FindDownFractal(3, strategy_fractal_lookback);
   if(f1_dn >= 3)
     {
      const int remaining_dn = strategy_fractal_lookback - f1_dn;
      if(remaining_dn > 0)
        {
         const int f2_dn = FindDownFractal(f1_dn + 1, remaining_dn);
         if(f2_dn > f1_dn)
           {
            const double low1  = iLow(_Symbol, PERIOD_H4, f1_dn);   // perf-allowed
            const double low2  = iLow(_Symbol, PERIOD_H4, f2_dn);   // perf-allowed
            const double high1 = iHigh(_Symbol, PERIOD_H4, f1_dn);  // perf-allowed
            if(low1 > low2 && high1 > 0.0)  // higher low confirmed
              {
               g_new_long_setup = true;

               const double entry = NormalizeDouble(high1 + offset, _Digits);
               const double fdist = entry - low1;
               double sl_dist = MathMax(atr * strategy_sl_atr_mult_min,
                                        fdist + atr * strategy_sl_atr_buffer);
               sl_dist = MathMin(sl_dist, atr * strategy_sl_atr_cap);

               // Stale filter: skip if entry price is too close to current close
               if(MathAbs(close1 - entry) >= strategy_stale_filter_r * sl_dist)
                 {
                  if(!HasPendingOrderForMagic(magic))
                    {
                     const double tp = IsMetal()
                                       ? entry + 2.0 * sl_dist
                                       : entry + strategy_tp_pips * pip;

                     req.type               = QM_BUY_STOP;
                     req.price              = entry;
                     req.sl                 = NormalizeDouble(entry - sl_dist, _Digits);
                     req.tp                 = NormalizeDouble(tp, _Digits);
                     req.reason             = "FF_FRACTAL_HILO_LONG";
                     req.symbol_slot        = qm_magic_slot_offset;
                     req.expiration_seconds = strategy_expire_bars * 4 * 3600;
                     return true;
                    }
                 }
              }
           }
        }
     }

   // ---------- Short setup: confirmed up fractal lower-high ----------
   const int f1_up = FindUpFractal(3, strategy_fractal_lookback);
   if(f1_up >= 3)
     {
      const int remaining_up = strategy_fractal_lookback - f1_up;
      if(remaining_up > 0)
        {
         const int f2_up = FindUpFractal(f1_up + 1, remaining_up);
         if(f2_up > f1_up)
           {
            const double hi1 = iHigh(_Symbol, PERIOD_H4, f1_up);  // perf-allowed
            const double hi2 = iHigh(_Symbol, PERIOD_H4, f2_up);  // perf-allowed
            const double lo1 = iLow(_Symbol, PERIOD_H4, f1_up);   // perf-allowed
            if(hi1 < hi2 && lo1 > 0.0)  // lower high confirmed
              {
               g_new_short_setup = true;

               const double entry = NormalizeDouble(lo1 - offset, _Digits);
               const double fdist = hi1 - entry;
               double sl_dist = MathMax(atr * strategy_sl_atr_mult_min,
                                        fdist + atr * strategy_sl_atr_buffer);
               sl_dist = MathMin(sl_dist, atr * strategy_sl_atr_cap);

               if(MathAbs(close1 - entry) >= strategy_stale_filter_r * sl_dist)
                 {
                  if(!HasPendingOrderForMagic(magic))
                    {
                     const double tp = IsMetal()
                                       ? entry - 2.0 * sl_dist
                                       : entry - strategy_tp_pips * pip;

                     req.type               = QM_SELL_STOP;
                     req.price              = entry;
                     req.sl                 = NormalizeDouble(entry + sl_dist, _Digits);
                     req.tp                 = NormalizeDouble(tp, _Digits);
                     req.reason             = "FF_FRACTAL_HILO_SHORT";
                     req.symbol_slot        = qm_magic_slot_offset;
                     req.expiration_seconds = strategy_expire_bars * 4 * 3600;
                     return true;
                    }
                 }
              }
           }
        }
     }

   return false;
  }

// Called every tick. Manages open positions (no trailing or BE for this strategy).
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop or partial close.
  }

// Called every tick. Returns true to force-close the open position.
// Handles: (1) time stop — 12 H4 bars elapsed, (2) opposite fractal exit.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime           open_time;
   if(!GetOpenPosition(ptype, open_time))
      return false;

   // Time stop: 12 H4 bars = 12 * 14400 seconds
   if(TimeCurrent() - open_time >= (datetime)(strategy_time_stop_bars * 14400))
      return true;

   // Opposite confirmed fractal exit (cached from last Strategy_EntrySignal run)
   if(ptype == POSITION_TYPE_BUY  && g_new_short_setup)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_new_long_setup)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9943\",\"slug\":\"ff-fractal-hilo-break-h4\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
