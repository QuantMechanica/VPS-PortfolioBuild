#property strict
#property version   "5.0"
#property description "QM5_9361 Ichimoku Kumo Bounce with ADX/DI (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9361 — Ichimoku Kumo Bounce (M30)
// Source: Stephen Njuki, MQL5 Wizard Techniques Part 73 (Pattern 3)
// Three-bar cloud-bounce with ADX/DI trend confirmation
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9361;
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
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_ichi_tenkan    = 9;     // Ichimoku Tenkan-sen period
input int    strategy_ichi_kijun     = 26;    // Ichimoku Kijun-sen / Senkou shift
input int    strategy_ichi_senkou_b  = 52;    // Ichimoku Senkou Span B lookback
input int    strategy_adx_period     = 14;    // ADX / DI period (also used for ATR SL)
input double strategy_adx_threshold  = 25.0;  // Minimum ADX to trade
input double strategy_sl_atr_mult    = 0.5;   // ATR multiplier beyond Senkou B for SL
input int    strategy_time_exit_bars = 64;    // Time-exit after N closed M30 bars

// =============================================================================
// Ichimoku helpers — use QM_Indicators.mqh pooled handles.
//
// Senkou Span A is plotted kijun bars FORWARD.  Buffer[N] holds the value
// COMPUTED at bar N, which is DISPLAYED on the chart at bar N - kijun.
// To read the DISPLAYED value at chart bar M (M=1 = last closed bar):
//   shift = kijun + M
// =============================================================================

double _SpanA(const int chart_bar)
  {
   return QM_Ichimoku_SenkouSpanA(_Symbol, PERIOD_CURRENT,
                                  strategy_ichi_tenkan,
                                  strategy_ichi_kijun,
                                  strategy_ichi_senkou_b,
                                  strategy_ichi_kijun + chart_bar);
  }

double _SpanB(const int chart_bar)
  {
   return QM_Ichimoku_SenkouSpanB(_Symbol, PERIOD_CURRENT,
                                  strategy_ichi_tenkan,
                                  strategy_ichi_kijun,
                                  strategy_ichi_senkou_b,
                                  strategy_ichi_kijun + chart_bar);
  }

// Three-bar Pattern 3 long: c2 above cloud → c1 dips to/below SpanA → c0 recovers
// above SpanA; DI+ > DI-, ADX >= threshold.
bool _IsLongPattern()
  {
   // perf-allowed: bespoke structural three-bar close comparison (O(1), M30 tick rate)
   const double c0  = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double c1  = iClose(_Symbol, PERIOD_CURRENT, 2);
   const double c2  = iClose(_Symbol, PERIOD_CURRENT, 3);
   const double sa0 = _SpanA(1);
   const double sa1 = _SpanA(2);
   const double sa2 = _SpanA(3);
   const double adx = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double diP = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double diM = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   return (c2 > c1) && (c1 < c0) &&
          (c2 > sa2) && (c0 > sa0) && (c1 <= sa1) &&
          (diP > diM) && (adx >= strategy_adx_threshold);
  }

// Three-bar Pattern 3 short: mirror of long.
bool _IsShortPattern()
  {
   // perf-allowed: bespoke structural three-bar close comparison (O(1), M30 tick rate)
   const double c0  = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double c1  = iClose(_Symbol, PERIOD_CURRENT, 2);
   const double c2  = iClose(_Symbol, PERIOD_CURRENT, 3);
   const double sa0 = _SpanA(1);
   const double sa1 = _SpanA(2);
   const double sa2 = _SpanA(3);
   const double adx = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double diP = QM_ADX_PlusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double diM = QM_ADX_MinusDI(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   return (c2 < c1) && (c1 > c0) &&
          (c2 < sa2) && (c0 < sa0) && (c1 >= sa1) &&
          (diP < diM) && (adx >= strategy_adx_threshold);
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.price              = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double atr   = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   const double spanB = _SpanB(1);
   if(atr <= 0.0 || spanB <= 0.0)
      return false;

   if(_IsLongPattern())
     {
      req.type   = QM_BUY;
      req.sl     = spanB - strategy_sl_atr_mult * atr;
      req.reason = "ichi_kumo_bounce_long";
      return true;
     }
   if(_IsShortPattern())
     {
      req.type   = QM_SELL;
      req.sl     = spanB + strategy_sl_atr_mult * atr;
      req.reason = "ichi_kumo_bounce_short";
      return true;
     }
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card: no trailing or break-even specified; SL-only management.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))                   continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)       continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);

      // Time-stop: 64 M30 bars
      if(TimeCurrent() - open_time >=
         (datetime)((long)strategy_time_exit_bars * PeriodSeconds(PERIOD_CURRENT)))
         return true;

      // SpanA close-through exit (perf-allowed: O(1) reads, M30 tick rate)
      const double c0  = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: structural
      const double sa0 = _SpanA(1);
      if(pos_type == POSITION_TYPE_BUY  && c0 < sa0) return true;
      if(pos_type == POSITION_TYPE_SELL && c0 > sa0) return true;

      // Opposite-pattern exit; enables immediate reversal via EntrySignal
      if(pos_type == POSITION_TYPE_BUY  && _IsShortPattern()) return true;
      if(pos_type == POSITION_TYPE_SELL && _IsLongPattern())  return true;

      break; // one position per magic/symbol
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 in OnTick
  }

// =============================================================================
// Framework wiring — do NOT edit below this line unless you know why.
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
