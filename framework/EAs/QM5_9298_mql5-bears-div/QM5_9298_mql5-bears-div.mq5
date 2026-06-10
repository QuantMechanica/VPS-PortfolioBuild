#property strict
#property version   "5.0"
#property description "QM5_9298 mql5-bears-div — Bear's Power Bullish Divergence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9298 — Bear's Power Bullish Divergence
// Source: Mohamed Abdelmaaboud, MQL5 Articles 2022-08-10
//   "Learn how to design a trading system by Bear's Power"
//   Source ID: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
//
// Logic: Long when current bar has a lower low than the previous bar, but
// Bear's Power (Low - EMA(close,13)) is HIGHER than on the previous bar
// (bullish divergence). Entry filtered by close > EMA(13). Exit on two
// consecutive Bears Power declines or price close below the signal low.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9298;
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
input int    strategy_bp_period         = 13;   // Bears Power EMA period
input int    strategy_sl_atr_period     = 14;   // ATR period for stop loss
input double strategy_sl_atr_mult      = 0.5;  // Stop = signal_low - mult * ATR(14)
input int    strategy_ema_filter_period = 13;   // EMA trend filter: prefer close > EMA

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
double g_entry_signal_low = 0.0; // low of the divergence bar that triggered entry
bool   g_exit_flag        = false; // set on new-bar exit evaluation; read every tick

// -----------------------------------------------------------------------------
// Helper: Bears Power = Low(shift) - EMA(close, period, shift)
// Bears Power is not wrapped in QM_Indicators; implemented directly.
// iLow used with // perf-allowed comment per corset exceptions.
// -----------------------------------------------------------------------------
double BearsPower(const string sym, const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   const double ema = QM_EMA(sym, tf, period, shift);
   const double low = iLow(sym, tf, shift); // perf-allowed: bespoke Bears Power = Low - EMA; no QM_ wrapper for iBearsPower
   return low - ema;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic
   const long magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   // Bears Power divergence: price makes lower low but BP makes higher value
   const double bp_curr  = BearsPower(_Symbol, _Period, strategy_bp_period, 1);
   const double bp_prev  = BearsPower(_Symbol, _Period, strategy_bp_period, 2);
   const double low_curr = iLow(_Symbol, _Period, 1); // perf-allowed: divergence signal bar low
   const double low_prev = iLow(_Symbol, _Period, 2); // perf-allowed: divergence reference bar low

   if(!(low_curr < low_prev && bp_curr > bp_prev))
      return false;

   // EMA(13) trend filter: close of signal bar must be above EMA
   const double close_curr = iClose(_Symbol, _Period, 1); // perf-allowed: trend filter check
   const double ema_filter  = QM_EMA(_Symbol, _Period, strategy_ema_filter_period, 1);
   if(close_curr <= ema_filter)
      return false;

   // Build entry request
   const double atr = QM_ATR(_Symbol, _Period, strategy_sl_atr_period, 1);
   const double sl  = low_curr - strategy_sl_atr_mult * atr;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(sl >= ask) return false; // degenerate SL above entry

   req.type               = QM_BUY;
   req.price              = 0.0; // market order
   req.sl                 = sl;
   req.tp                 = 0.0; // exit via signal
   req.reason             = "BEARS_POWER_DIV";
   req.symbol_slot        = 0;
   req.expiration_seconds = 0;

   g_entry_signal_low = low_curr;
   g_exit_flag        = false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Exit condition re-evaluated once per closed bar only
   if(!QM_IsNewBar()) return;

   // If no position exists, reset flag
   const long magic = QM_FrameworkMagic();
   bool has_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic) { has_pos = true; break; }
     }
   if(!has_pos) { g_exit_flag = false; return; }

   // Condition A: two consecutive Bears Power declines
   const double bp1 = BearsPower(_Symbol, _Period, strategy_bp_period, 1);
   const double bp2 = BearsPower(_Symbol, _Period, strategy_bp_period, 2);
   const double bp3 = BearsPower(_Symbol, _Period, strategy_bp_period, 3);
   const bool two_declines = (bp1 < bp2 && bp2 < bp3);

   // Condition B: bar close returned below the divergence signal low
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: exit vs stored signal low
   const bool below_signal_low = (g_entry_signal_low > 0.0 && close1 < g_entry_signal_low);

   g_exit_flag = two_declines || below_signal_low;
  }

bool Strategy_ExitSignal()
  {
   return g_exit_flag;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2
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
