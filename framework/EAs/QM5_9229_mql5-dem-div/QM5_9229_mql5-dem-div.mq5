#property strict
#property version   "5.0"
#property description "QM5_9229 DeMarker One-Bar Divergence — H1 mean-reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_9229 mql5-dem-div
// Strategy: DeMarker(14) one-bar price/indicator divergence on H1.
// Source: Mohamed Abdelmaaboud, MQL5 Articles 2022-09-08, Strategy Three.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9229;
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
input int    strategy_dem_period        = 14;   // DeMarker lookback period
input int    strategy_atr_period        = 14;   // ATR period for SL distance
input int    strategy_atr_vol_period    = 100;  // ATR period for volatility filter
input double strategy_atr_sl_mult       = 0.5;  // SL = structure ± ATR * this
input double strategy_tp_r_mult         = 1.8;  // TP distance = 1R * this
input double strategy_dem_exit_hi       = 0.70; // Close long when DeMarker >= this
input double strategy_dem_exit_lo       = 0.30; // Close short when DeMarker <= this
input int    strategy_max_bars_hold     = 30;   // Failsafe: exit after N H1 bars

// =============================================================================
// DeMarker pooled handle — follows QM_Indicators pool protocol.
// iDeMarker is not in the standard QM_* set; we register it using the same
// QM_IndicatorsLookup / QM_IndicatorsRegister / QM_IndicatorReadBuffer API.
// =============================================================================

int QM_IndDeMarker(const string sym, const ENUM_TIMEFRAMES tf, const int period)
  {
   const string key = StringFormat("DEM|%s|%d|%d", sym, (int)tf, period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iDeMarker(sym, tf, period);
   return QM_IndicatorsRegister(key, h);
  }

double QM_DeMarker(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
  {
   return QM_IndicatorReadBuffer(QM_IndDeMarker(sym, tf, period), 0, shift);
  }

// =============================================================================
// File-scope state cached once per new closed bar.
// All strategy hooks read from these — no per-tick indicator recalculation.
// =============================================================================

double g_dem_cur   = 0.0;  // DeMarker(14) shift=1 (current closed bar)
double g_dem_prev  = 0.0;  // DeMarker(14) shift=2 (previous closed bar)
double g_low_cur   = 0.0;  // Low shift=1
double g_low_prev  = 0.0;  // Low shift=2
double g_high_cur  = 0.0;  // High shift=1
double g_high_prev = 0.0;  // High shift=2
double g_atr14     = 0.0;  // ATR(14) shift=1
double g_atr100    = 0.0;  // ATR(100) shift=1
int    g_bars_held = 0;    // Closed bars since current position opened

// Called once per new H1 closed bar, inside Strategy_EntrySignal (which is
// guarded by QM_IsNewBar in the framework's OnTick).
void AdvanceState_OnNewBar()
  {
   g_dem_cur  = QM_DeMarker(_Symbol, PERIOD_H1, strategy_dem_period, 1);
   g_dem_prev = QM_DeMarker(_Symbol, PERIOD_H1, strategy_dem_period, 2);
   g_atr14    = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   g_atr100   = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_vol_period, 1);

   // CopyRates once per bar — allowed per perf discipline for bespoke OHLC math.
   MqlRates bars[2];
   if(CopyRates(_Symbol, PERIOD_H1, 1, 2, bars) == 2) // perf-allowed: called only from Strategy_EntrySignal, which runs under QM_IsNewBar gate
     {
      g_low_cur   = bars[0].low;
      g_low_prev  = bars[1].low;
      g_high_cur  = bars[0].high;
      g_high_prev = bars[1].high;
     }

   // Track bars held for time-exit gate.
   const int magic = QM_FrameworkMagic();
   bool pos_exists = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL)  == _Symbol)
        {
         pos_exists = true;
         break;
        }
     }
   if(pos_exists)
      g_bars_held++;
   else
      g_bars_held = 0;
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   // Volatility filter: require ATR(14) >= 0.5 * ATR(100).
   // Cached values may be zero on startup (no bars yet) — don't block in that case.
   if(g_atr100 > 0.0 && g_atr14 < 0.5 * g_atr100)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance per-bar state first (framework guarantees QM_IsNewBar == true here).
   AdvanceState_OnNewBar();

   // One position per magic — skip if already in trade.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Bullish divergence: price makes lower low but DeMarker makes higher value.
   const bool bull_div = (g_low_cur < g_low_prev) && (g_dem_cur > g_dem_prev);
   // Bearish divergence: price makes higher high but DeMarker makes lower value.
   const bool bear_div = (g_high_cur > g_high_prev) && (g_dem_cur < g_dem_prev);

   if(!bull_div && !bear_div)
      return false;

   ZeroMemory(req);
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(bull_div)
     {
      const double sl_price = MathMin(g_low_cur, g_low_prev) - g_atr14 * strategy_atr_sl_mult;
      const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0 || ask <= sl_price)
         return false;
      const double sl_pts = (ask - sl_price) / point;
      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = sl_price;
      req.tp     = ask + sl_pts * strategy_tp_r_mult * point;
      req.reason = "DEM_BULL_DIV";
      return true;
     }

   // bear_div
   const double sl_price = MathMax(g_high_cur, g_high_prev) + g_atr14 * strategy_atr_sl_mult;
   const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || bid >= sl_price)
      return false;
   const double sl_pts = (sl_price - bid) / point;
   req.type   = QM_SELL;
   req.price  = bid;
   req.sl     = sl_price;
   req.tp     = bid - sl_pts * strategy_tp_r_mult * point;
   req.reason = "DEM_BEAR_DIV";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No dynamic management — SL/TP set at entry; time/signal exit handled in ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Time exit: failsafe after strategy_max_bars_hold closed H1 bars.
      if(g_bars_held >= strategy_max_bars_hold)
         return true;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
        {
         // Long exit: DeMarker target reached.
         if(g_dem_cur >= strategy_dem_exit_hi)
            return true;
         // Long exit: opposite bearish divergence.
         if((g_high_cur > g_high_prev) && (g_dem_cur < g_dem_prev))
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         // Short exit: DeMarker target reached.
         if(g_dem_cur <= strategy_dem_exit_lo)
            return true;
         // Short exit: opposite bullish divergence.
         if((g_low_cur < g_low_prev) && (g_dem_cur > g_dem_prev))
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2
  }

// =============================================================================
// Framework wiring — do NOT edit below this line.
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
