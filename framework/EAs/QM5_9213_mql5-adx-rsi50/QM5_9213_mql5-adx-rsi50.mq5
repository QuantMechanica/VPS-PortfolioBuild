#property strict
#property version   "5.0"
#property description "QM5_9213 ADX Rise With RSI 50 Confirmation — H1 trend-following"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9213 mql5-adx-rsi50
// Source: Stephen Njuki, MQL5 Articles 2024-10-25, Pattern 8 (ADX+RSI).
// Entry: ADX(14) crosses above 25 AND RSI(14) crosses above/below 50 same bar.
// Exit:  RSI crosses back through 50, ADX drops below 20, or opposite signal.
// SL:    ATR(14)*1.8 or beyond signal-bar extreme, whichever is wider.
// TP:    2R (hard, set at entry).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9213;
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
input int    strategy_adx_period          = 14;   // ADX period
input double strategy_adx_threshold       = 25.0; // ADX cross-above level for entry
input double strategy_adx_exit_level      = 20.0; // ADX drop-below level for exit
input int    strategy_adx_max_above_bars  = 5;    // skip entry if ADX already above threshold this many bars
input int    strategy_rsi_period          = 14;   // RSI period
input double strategy_rsi_mid             = 50.0; // RSI midline for cross detection
input int    strategy_atr_period          = 14;   // ATR period for stop sizing
input double strategy_atr_sl_mult         = 1.8;  // ATR multiplier for stop distance
input double strategy_tp_rr               = 2.0;  // Take-profit as multiple of risk (R)

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false; // spread/news handled by framework
  }

// -----------------------------------------------------------------------------
// Entry Signal
// Fires once per closed bar (QM_IsNewBar gate in OnTick).
// Detects simultaneous ADX cross above threshold + RSI cross through midline.
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const double adx_curr = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double adx_prev = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 2);
   const double rsi_curr = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 2);

   // ADX must have crossed above threshold on the last closed bar
   if(adx_curr <= strategy_adx_threshold || adx_prev >= strategy_adx_threshold)
      return false;

   // Late-entry guard: ADX must not have been above threshold for too long
   // (with strict cross detection adx_prev < threshold, this loop returns 1 and never blocks)
   int consecutive = 1;
   for(int s = 2; s <= strategy_adx_max_above_bars + 1; s++)
     {
      if(QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, s) > strategy_adx_threshold)
         consecutive++;
      else
         break;
     }
   if(consecutive > strategy_adx_max_above_bars)
      return false;

   // RSI must cross through midline on the same bar
   const bool rsi_cross_up   = (rsi_curr > strategy_rsi_mid && rsi_prev <= strategy_rsi_mid);
   const bool rsi_cross_down = (rsi_curr < strategy_rsi_mid && rsi_prev >= strategy_rsi_mid);
   if(!rsi_cross_up && !rsi_cross_down)
      return false;

   // One position per magic
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t) && PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double atr_val = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   const double atr_sl  = atr_val * strategy_atr_sl_mult;

   req.symbol = _Symbol;
   req.magic  = magic;

   if(rsi_cross_up)
     {
      req.type       = ORDER_TYPE_BUY;
      req.price      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      // SL = wider of ATR-based and signal-bar low
      const double bar_low = iLow(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: single bar read inside new-bar gate
      const double sl_atr  = req.price - atr_sl;
      req.sl         = MathMin(sl_atr, bar_low - _Point);
      const double sl_dist = req.price - req.sl;
      req.tp         = req.price + sl_dist * strategy_tp_rr;
      req.lots       = QM_LotsForRisk(_Symbol, sl_dist / _Point);
     }
   else
     {
      req.type       = ORDER_TYPE_SELL;
      req.price      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // SL = wider of ATR-based and signal-bar high
      const double bar_high = iHigh(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: single bar read inside new-bar gate
      const double sl_atr   = req.price + atr_sl;
      req.sl         = MathMax(sl_atr, bar_high + _Point);
      const double sl_dist  = req.sl - req.price;
      req.tp         = req.price - sl_dist * strategy_tp_rr;
      req.lots       = QM_LotsForRisk(_Symbol, sl_dist / _Point);
     }

   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management — SL/TP set at entry; no trailing requested by card.
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   // No active management: hard SL and 2R TP are set at entry.
  }

// -----------------------------------------------------------------------------
// Exit Signal
// Evaluates on every tick; reads shift=1 (last closed bar) so value is stable
// between bars. Fires at first tick of the new bar whose close meets the condition.
// Handles: RSI crosses back through midline, ADX drops below exit_level,
// or opposite entry signal appears (enabling reversal via EntrySignal same tick).
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      const double rsi_curr = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
      const double adx_curr = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);

      if(pos_type == POSITION_TYPE_BUY)
        {
         // Exit: RSI back below mid, or ADX dropped below exit_level, or sell signal
         if(rsi_curr < strategy_rsi_mid || adx_curr < strategy_adx_exit_level)
            return true;
         // Sell signal: check for ADX cross + RSI cross down (allows reversal same tick)
         const double adx_prev = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 2);
         const double rsi_prev = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 2);
         if(adx_curr > strategy_adx_threshold && adx_prev < strategy_adx_threshold &&
            rsi_curr < strategy_rsi_mid && rsi_prev >= strategy_rsi_mid)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         // Exit: RSI back above mid, or ADX dropped below exit_level, or buy signal
         if(rsi_curr > strategy_rsi_mid || adx_curr < strategy_adx_exit_level)
            return true;
         // Buy signal check for reversal
         const double adx_prev = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 2);
         const double rsi_prev = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 2);
         if(adx_curr > strategy_adx_threshold && adx_prev < strategy_adx_threshold &&
            rsi_curr > strategy_rsi_mid && rsi_prev <= strategy_rsi_mid)
            return true;
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook — defer to framework's 2-axis check
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
