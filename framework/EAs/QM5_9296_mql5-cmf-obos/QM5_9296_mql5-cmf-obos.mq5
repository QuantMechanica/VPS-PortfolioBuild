#property strict
#property version   "5.0"
#property description "QM5_9296 mql5-cmf-obos — CMF Overbought/Oversold Reversal (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9296 — mql5-cmf-obos
// CMF Overbought/Oversold Reversal: fade CMF extremes (>= +threshold short,
// <= -threshold long) with fixed SL/TP and optional CMF zero-cross exit.
// Source: Mohamed Abdelmaaboud, MQL5 Articles, 2024-12-17.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9296;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cmf_period    = 20;    // CMF lookback periods (card: 20)
input double strategy_cmf_threshold = 0.20;  // Overbought/oversold CMF level (card: 0.20)
input int    strategy_sl_points     = 300;   // Stop loss in points (card: 300)
input int    strategy_tp_points     = 900;   // Take profit in points (card: 900)

// ---------------------------------------------------------------------------
// File-scope closed-bar state — updated once per new bar in Strategy_EntrySignal
// ---------------------------------------------------------------------------
double g_cmf_value         = 0.0;
bool   g_state_initialized = false;

// ---------------------------------------------------------------------------
// Chaikin Money Flow: Sum(MFM * TickVolume, n) / Sum(TickVolume, n)
// MFM = ((close - low) - (high - close)) / (high - low)
// Called only from Strategy_EntrySignal which is gated by QM_IsNewBar().
// ---------------------------------------------------------------------------
double ComputeCMF(const string sym, const ENUM_TIMEFRAMES tf,
                  const int periods, const int shift)
  {
   MqlRates rates[];
   int copied = CopyRates(sym, tf, shift, periods, rates); // perf-allowed: bespoke OHLCV CMF; gated by QM_IsNewBar via caller
   if(copied < periods)
      return 0.0;

   double sum_mfv = 0.0, sum_vol = 0.0;
   for(int i = 0; i < copied; i++)
     {
      const double hl = rates[i].high - rates[i].low;
      if(hl < 1e-10)
         continue;
      const double mfm = ((rates[i].close - rates[i].low)
                         - (rates[i].high - rates[i].close)) / hl;
      const double vol = (double)rates[i].tick_volume;
      sum_mfv += mfm * vol;
      sum_vol  += vol;
     }
   return (sum_vol > 0.0) ? sum_mfv / sum_vol : 0.0;
  }

// ---------------------------------------------------------------------------
// Strategy hooks — implement the five required sections
// ---------------------------------------------------------------------------

// No Trade Filter: no session or regime filter; rely on framework news/Friday gates.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry Signal: called by framework only when QM_IsNewBar() is true.
// Advances closed-bar CMF state, then checks overbought/oversold threshold.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance closed-bar state (this hook is only called when QM_IsNewBar() is true)
   g_cmf_value = ComputeCMF(_Symbol, _Period, strategy_cmf_period, 1);
   g_state_initialized = true;

   // One active position per magic
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double sl_pts = (double)strategy_sl_points;
   const double tp_pts = (double)strategy_tp_points;

   if(g_cmf_value <= -strategy_cmf_threshold)
     {
      // CMF oversold: fade extreme selling — Long entry
      const double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type            = QM_BUY;
      req.price           = ask;
      req.sl              = ask - sl_pts * _Point;
      req.tp              = ask + tp_pts * _Point;
      req.symbol_slot     = qm_magic_slot_offset;
      req.reason          = "CMF_OBOS_LONG";
      req.expiration_seconds = 0;
      return true;
     }

   if(g_cmf_value >= strategy_cmf_threshold)
     {
      // CMF overbought: fade extreme buying — Short entry
      const double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type            = QM_SELL;
      req.price           = bid;
      req.sl              = bid + sl_pts * _Point;
      req.tp              = bid - tp_pts * _Point;
      req.symbol_slot     = qm_magic_slot_offset;
      req.reason          = "CMF_OBOS_SHORT";
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Trade Management: no active management; position rides to TP/SL or CMF zero-cross.
void Strategy_ManageOpenPosition()
  {
  }

// Exit Signal: close long when CMF returns above zero; close short when below zero.
// Provides early exit before TP/SL on CMF regime normalization.
bool Strategy_ExitSignal()
  {
   if(!g_state_initialized)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pt =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY  && g_cmf_value > 0.0)
         return true;
      if(pt == POSITION_TYPE_SELL && g_cmf_value < 0.0)
         return true;
     }
   return false;
  }

// News Filter Hook: defer entirely to framework two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
