#property strict
#property version   "5.0"
#property description "QM5_9219 Chaikin Volatility MA Crossover — H1 volatility+trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9219 mql5-chv-ma
// Source: Mohamed Abdelmaaboud, MQL5 Articles 2024-04-25 (CHV + MA Crossover).
// Entry: CHV > 0 AND close > SMA(20) → long;  CHV < 0 AND close < SMA(20) → short.
//        Volatility gate: ATR(14) >= vol_ratio * ATR(100).
// Exit:  CHV flips sign OR close crosses SMA(20), or 48-bar failsafe time stop.
// SL:    ATR(14) * 1.7.  TP: 2.1R hard target set at entry.
// =============================================================================

// -----------------------------------------------------------------------------
// Cached per-bar state — updated once per closed bar in AdvanceState_OnNewBar.
// ExitSignal reads these values every tick (O(1)); CopyRates only runs on new bar.
// -----------------------------------------------------------------------------
double g_chv         = 0.0;    // Chaikin Volatility at last closed bar
double g_sma20       = 0.0;    // SMA(period) at last closed bar
double g_last_close  = 0.0;    // Close of last completed bar
bool   g_state_ready = false;  // True after first successful AdvanceState call

// =============================================================================
// Inputs
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9219;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_chv_ema_period  = 10;   // EMA period for H-L range (Chaikin Volatility)
input int    strategy_chv_lookback    = 10;   // Bars back for CHV percentage comparison
input int    strategy_ma_period       = 20;   // SMA period for trend direction
input int    strategy_atr_period      = 14;   // ATR period for stop sizing
input int    strategy_atr_vol_period  = 100;  // ATR period for volatility regime filter
input double strategy_vol_ratio       = 0.6;  // Min ratio ATR(sl_period)/ATR(vol_period)
input double strategy_atr_sl_mult     = 1.7;  // ATR multiplier for initial stop distance
input double strategy_tp_r_mult       = 2.1;  // Take-profit as R multiple
input int    strategy_max_bars_held   = 48;   // Failsafe time exit in bars

// =============================================================================
// Chaikin Volatility helpers
// =============================================================================

// Compute EMA of (High-Low) from rates[oldest_idx] to rates[newest_idx].
// Rates array MUST be set as series (0=newest, N=oldest).
double ComputeHLEMARange(const MqlRates &rates[],
                         const int oldest_idx,
                         const int newest_idx,
                         const int period)
  {
   if(oldest_idx < newest_idx || period <= 0)
      return 0.0;
   const double k = 2.0 / (period + 1);
   double ema = rates[oldest_idx].high - rates[oldest_idx].low;
   for(int i = oldest_idx - 1; i >= newest_idx; i--)
      ema = (rates[i].high - rates[i].low) * k + ema * (1.0 - k);
   return ema;
  }

// =============================================================================
// Closed-bar state advancement (called once per new bar from OnTick)
// =============================================================================

void AdvanceState_OnNewBar()
  {
   const int chv_period   = strategy_chv_ema_period;
   const int chv_lookback = strategy_chv_lookback;
   // Warmup: 3 * EMA period gives >99% convergence; add lookback + 2 buffer.
   const int needed = chv_period * 3 + chv_lookback + 2;

   // perf-allowed: CopyRates called once per closed bar, inside QM_IsNewBar gate.
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int got = CopyRates(_Symbol, _Period, 1, needed, rates);
   if(got < chv_period + chv_lookback + 2)
      return; // insufficient history on init; keep previous state

   const int oldest = got - 1;

   // EMA of H-L at shift=1 (latest closed bar)
   const double ema_current = ComputeHLEMARange(rates, oldest, 0, chv_period);

   // EMA of H-L at shift=(chv_lookback+1) — the reference point for CHV %
   const int ref_idx = chv_lookback; // rates[chv_lookback] = shift = chv_lookback+1
   if(ref_idx > oldest)
      return;
   const double ema_ref = ComputeHLEMARange(rates, oldest, ref_idx, chv_period);

   if(ema_ref > 0.0)
      g_chv = (ema_current - ema_ref) / ema_ref * 100.0;
   else
      g_chv = 0.0;

   g_sma20      = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   g_last_close = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar scalar read
   g_state_ready = true;
  }

// =============================================================================
// No Trade Filter
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false; // spread and news handled by framework
  }

// =============================================================================
// Entry Signal
// Evaluated once per closed bar (inside QM_IsNewBar gate in OnTick).
// Reads cached g_chv / g_sma20 / g_last_close computed by AdvanceState_OnNewBar.
// =============================================================================

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_state_ready)
      return false;

   // Volatility regime filter: ATR(14) >= vol_ratio * ATR(100)
   const double atr14  = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double atr100 = QM_ATR(_Symbol, _Period, strategy_atr_vol_period, 1);
   if(atr14 <= 0.0 || atr100 <= 0.0)
      return false;
   if(atr14 < strategy_vol_ratio * atr100)
      return false;

   const double atr_sl_dist = atr14 * strategy_atr_sl_mult;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Long: CHV > 0 AND last-closed-bar close > SMA(20)
   if(g_chv > 0.0 && g_last_close > g_sma20)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl     = req.price - atr_sl_dist;
      req.tp     = req.price + atr_sl_dist * strategy_tp_r_mult;
      req.reason = "chv_ma_long";
      return true;
     }

   // Short: CHV < 0 AND last-closed-bar close < SMA(20)
   if(g_chv < 0.0 && g_last_close < g_sma20)
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl     = req.price + atr_sl_dist;
      req.tp     = req.price - atr_sl_dist * strategy_tp_r_mult;
      req.reason = "chv_ma_short";
      return true;
     }

   return false;
  }

// =============================================================================
// Trade Management
// Hard SL and TP set at entry; no trailing or break-even per card.
// =============================================================================

void Strategy_ManageOpenPosition()
  {
   // No active management: SL and TP set at entry cover the position.
  }

// =============================================================================
// Exit Signal
// Called every tick; reads cached state (O(1)).
// Handles: CHV sign flip, close crossing SMA, and 48-bar failsafe time stop.
// Note: g_chv / g_last_close / g_sma20 are updated inside QM_IsNewBar gate
// (AdvanceState_OnNewBar), so from bar tick 2+ exit reflects the latest closed bar.
// =============================================================================

bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;

   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Failsafe time stop: close after strategy_max_bars_held bars
      const datetime open_time    = (datetime)PositionGetInteger(POSITION_TIME);
      const long     period_secs  = (long)PeriodSeconds(_Period);
      if(period_secs > 0)
        {
         const long bars_elapsed = (long)((TimeCurrent() - open_time) / period_secs);
         if(bars_elapsed >= strategy_max_bars_held)
            return true;
        }

      const ENUM_POSITION_TYPE pos_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(pos_type == POSITION_TYPE_BUY)
        {
         // Exit long: CHV turned negative OR close dropped below SMA(20)
         if(g_chv < 0.0 || g_last_close < g_sma20)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         // Exit short: CHV turned positive OR close rose above SMA(20)
         if(g_chv > 0.0 || g_last_close > g_sma20)
            return true;
        }
     }
   return false;
  }

// =============================================================================
// News Filter Hook — defer to framework 2-axis check
// =============================================================================

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9219\",\"slug\":\"mql5-chv-ma\"}");
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

   // Advance closed-bar state (CHV, SMA, last-close) on first tick of each new bar.
   AdvanceState_OnNewBar();

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
