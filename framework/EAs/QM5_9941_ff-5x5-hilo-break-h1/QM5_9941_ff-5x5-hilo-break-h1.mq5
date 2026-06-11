#property strict
#property version   "5.0"
#property description "QM5_9941 ForexFactory 5x5 Hi-Lo Break H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9941 — ForexFactory 5x5 High-Low Break H1
// Source: jamesagnew, "1 hour system trade with stochastics", ForexFactory, 2025
// Strategy: H1 EMA(5) channel on High/Low prices, forward-shifted 5 bars.
//           Long when a completed H1 bar opens AND closes above the high channel
//           as a fresh break (prior bar did not close above). Short mirrors.
//           Exit: 2R TP (set at entry), 10-bar time stop, or opposite-side
//           channel breach (completed bar opens+closes on opposite side).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9941;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                 = 336;
input string qm_news_min_impact                      = "high";
input QM_NewsMode qm_news_mode_legacy                = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled                 = true;
input int    qm_friday_close_hour_broker             = 21;

input group "Stress"
input double qm_stress_reject_probability            = 0.0;

input group "Strategy"
input int    strategy_ema_period                     = 5;    // EMA period for H/L channel
input int    strategy_ema_shift                      = 5;    // Forward shift (bars) for the channel
input int    strategy_sl_pips                        = 40;   // Fixed SL in pips (source: 40 pip)
input bool   strategy_use_atr_sl                     = false; // true = volatility-port ATR SL
input int    strategy_atr_period                     = 14;   // ATR period when use_atr_sl=true
input double strategy_atr_sl_mult                    = 0.8;  // ATR multiplier for SL floor
input double strategy_atr_sl_cap_mult                = 1.5;  // ATR cap multiplier for SL ceiling
input double strategy_tp_rr                          = 2.0;  // TP = tp_rr * SL distance
input int    strategy_max_hold_bars                  = 10;   // Time stop: max H1 bars held
input double strategy_spread_pct_max                 = 12.0; // Max spread as % of SL distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

double CalcSLDist()
  {
   const double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   // 5-digit FX (e.g. EURUSD 1.23456) and 3-digit JPY (e.g. USDJPY 123.456):
   // 1 pip = 10 × SYMBOL_POINT. For 2/4-digit: 1 pip = SYMBOL_POINT.
   const double pip_size = (digits == 3 || digits == 5) ? point * 10.0 : point;

   if(strategy_use_atr_sl)
     {
      const double atr     = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      const double atr_sl  = MathMax(strategy_atr_sl_mult * atr, 40.0 * pip_size);
      return MathMin(atr_sl, strategy_atr_sl_cap_mult * atr);
     }
   return (double)strategy_sl_pips * pip_size;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — no session or regime gate required by the card.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry Signal — fires once per closed H1 bar (called after QM_IsNewBar gate).
// Implements 5x5 Hi/Lo channel fresh break with spread and one-position guards.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Channel values for last completed bar: EMA(5,H/L) read at buffer index
   // (ema_shift + 1) because QM_IndMA uses ma_shift=0; the forward-shift is
   // emulated by reading further back in the buffer.
   const int    sh1       = strategy_ema_shift + 1; // bar 1 channel
   const int    sh2       = strategy_ema_shift + 2; // bar 2 channel (prior)
   const double ch_high   = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, sh1, PRICE_HIGH);
   const double ch_low    = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, sh1, PRICE_LOW);
   const double ch_high_p = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, sh2, PRICE_HIGH);
   const double ch_low_p  = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, sh2, PRICE_LOW);

   if(ch_high <= 0.0 || ch_low <= 0.0 || ch_high_p <= 0.0 || ch_low_p <= 0.0)
      return false;

   // OHLC of last two completed bars — perf-allowed: single structural OHLC reads
   const double open1  = iOpen(_Symbol,  PERIOD_H1, 1);  // perf-allowed
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);  // perf-allowed
   const double close2 = iClose(_Symbol, PERIOD_H1, 2);  // perf-allowed

   if(open1 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double sl_dist = CalcSLDist();
   if(sl_dist <= 0.0)
      return false;

   // Spread gate: spread must be <= strategy_spread_pct_max% of SL distance
   const double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) *
                         SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(spread > strategy_spread_pct_max / 100.0 * sl_dist)
      return false;

   // Signal: fresh break above high channel
   const bool is_long  = (open1 > ch_high && close1 > ch_high && close2 <= ch_high_p);
   // Signal: fresh break below low channel
   const bool is_short = (!is_long) &&
                         (open1 < ch_low && close1 < ch_low && close2 >= ch_low_p);

   if(!is_long && !is_short)
      return false;

   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(is_long)
     {
      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = NormalizeDouble(ask - sl_dist, _Digits);
      req.tp     = NormalizeDouble(ask + strategy_tp_rr * sl_dist, _Digits);
      req.reason = "FF5X5_LONG_BREAK";
     }
   else
     {
      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = NormalizeDouble(bid + sl_dist, _Digits);
      req.tp     = NormalizeDouble(bid - strategy_tp_rr * sl_dist, _Digits);
      req.reason = "FF5X5_SHORT_BREAK";
     }

   return true;
  }

// Manage Open Position — no trailing or partials; exit fully managed by SL/TP
// and Strategy_ExitSignal below.
void Strategy_ManageOpenPosition()
  {
  }

// Exit Signal — fires on every tick.
// Closes the position on: (a) 10-bar time stop, or (b) opposite-side channel
// breach where a completed H1 bar opens AND closes on the opposite side.
bool Strategy_ExitSignal()
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

      // (a) Time stop: 10 H1 bars
      const datetime open_time    = (datetime)PositionGetInteger(POSITION_TIME);
      const int      bars_elapsed = (int)((TimeCurrent() - open_time) / PeriodSeconds(PERIOD_H1));
      if(bars_elapsed >= strategy_max_hold_bars)
         return true;

      // (b) Opposite-side channel breach on last completed bar (bar 1)
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open1  = iOpen(_Symbol,  PERIOD_H1, 1);  // perf-allowed
      const double close1 = iClose(_Symbol, PERIOD_H1, 1);  // perf-allowed

      const double ch_high = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period,
                                    strategy_ema_shift + 1, PRICE_HIGH);
      const double ch_low  = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period,
                                    strategy_ema_shift + 1, PRICE_LOW);

      if(ptype == POSITION_TYPE_BUY  && open1 < ch_low  && close1 < ch_low)  return true;
      if(ptype == POSITION_TYPE_SELL && open1 > ch_high && close1 > ch_high) return true;
     }
   return false;
  }

// News Filter Hook — defer to framework's two-axis news filter.
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
