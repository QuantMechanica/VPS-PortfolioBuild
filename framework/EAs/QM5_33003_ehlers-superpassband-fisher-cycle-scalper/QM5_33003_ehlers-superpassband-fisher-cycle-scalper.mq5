#property strict
#property version   "5.0"
#property description "QM5_33003 Ehlers SuperPassBand & Fisher Transform DSP Scalper"
// Strategy Card: QM5_33003 (ehlers-superpassband-fisher-cycle-scalper), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_33003
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 33003;
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
input int    strategy_fast_period         = 10;
input int    strategy_slow_period         = 40;
input double strategy_fisher_threshold    = 1.50;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_atr_tp_mult         = 3.0;
input double strategy_spread_atr_mult     = 1.8;
input int    strategy_warmup_bars         = 120;

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced on new H1 bar)
// -----------------------------------------------------------------------------
double g_fisher_1     = 0.0;
double g_fisher_2     = 0.0;
double g_fisher_3     = 0.0;
double g_trigger_1    = 0.0;
double g_trigger_2    = 0.0;
double g_atr_1        = 0.0;
bool   g_state_valid  = false;

void AdvanceState_OnNewBar()
{
   g_state_valid = false;
   if(strategy_fast_period <= 0 || strategy_slow_period <= 0 || strategy_atr_period <= 0)
      return;

   const int total_bars = iBars(_Symbol, PERIOD_H1);
   const int needed_bars = strategy_warmup_bars + strategy_slow_period + 10;
   if(total_bars < needed_bars)
      return;

   const double a1 = 5.45 / (double)strategy_slow_period;
   const double a2 = 5.45 / (double)strategy_fast_period;

   double hp[];
   double super_pb[];
   double x[];
   double fisher[];
   double p[];

   const int N = strategy_warmup_bars;
   if(ArrayResize(hp, N + 1) < 0 ||
      ArrayResize(super_pb, N + 1) < 0 ||
      ArrayResize(x, N + 1) < 0 ||
      ArrayResize(fisher, N + 1) < 0 ||
      ArrayResize(p, N + 2) < 0)
      return;

   ArrayInitialize(hp, 0.0);
   ArrayInitialize(super_pb, 0.0);
   ArrayInitialize(x, 0.0);
   ArrayInitialize(fisher, 0.0);

   // Populate price series chronologically: k = N down to 1 (k is shift)
   for(int k = N + 1; k >= 1; --k)
   {
      const double h = iHigh(_Symbol, PERIOD_H1, k); // perf-allowed: closed-H1 DSP construction behind QM_IsNewBar()
      const double l = iLow(_Symbol, PERIOD_H1, k);  // perf-allowed: closed-H1 DSP construction behind QM_IsNewBar()
      if(h <= 0.0 || l <= 0.0) return;
      p[k] = (h + l) * 0.5;
   }

   // Compute DSP filters chronologically: index N down to 1
   for(int k = N; k >= 1; --k)
   {
      const double prev_hp = (k == N) ? 0.0 : hp[k + 1];
      const double prev_spb = (k == N) ? 0.0 : super_pb[k + 1];
      const double prev_x = (k == N) ? 0.0 : x[k + 1];
      const double prev_fish = (k == N) ? 0.0 : fisher[k + 1];

      // HighPass filter
      hp[k] = (1.0 - a1 * 0.5) * (p[k] - p[k + 1]) + (1.0 - a1) * prev_hp;

      // SuperPassBand filter
      super_pb[k] = (a2 * 0.5) * (hp[k] + prev_hp) + (1.0 - a2) * prev_spb;

      // Fisher Transform normalization over fast period lookback
      double max_h = -DBL_MAX;
      double min_l = DBL_MAX;
      for(int j = 0; j < strategy_fast_period; ++j)
      {
         const int lookback_idx = k + j;
         if(lookback_idx <= N)
         {
            if(super_pb[lookback_idx] > max_h) max_h = super_pb[lookback_idx];
            if(super_pb[lookback_idx] < min_l) min_l = super_pb[lookback_idx];
         }
      }

      double val = 0.0;
      if(max_h > min_l)
      {
         val = (super_pb[k] - min_l) / (max_h - min_l);
         val = 2.0 * (val - 0.5);
      }

      x[k] = 0.33 * val + 0.67 * prev_x;
      if(x[k] > 0.999) x[k] = 0.999;
      if(x[k] < -0.999) x[k] = -0.999;

      fisher[k] = 0.5 * MathLog((1.0 + x[k]) / (1.0 - x[k])) + 0.5 * prev_fish;
   }

   g_fisher_1 = fisher[1];
   g_fisher_2 = fisher[2];
   g_fisher_3 = fisher[3];

   g_trigger_1 = fisher[2];
   g_trigger_2 = fisher[3];

   g_atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(g_atr_1 <= 0.0)
      return;

   g_state_valid = true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!g_state_valid)
      return true;

   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   const int hhmm = dt.hour * 100 + dt.min;
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && g_atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = g_atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Long: Fisher[2] < Trigger[2] && Fisher[1] >= Trigger[1] && Fisher[1] <= -strategy_fisher_threshold
   if(g_fisher_2 < g_trigger_2 && g_fisher_1 >= g_trigger_1 && g_fisher_1 <= -strategy_fisher_threshold)
   {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, g_atr_1, strategy_atr_sl_mult);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, ask, g_atr_1 * strategy_atr_tp_mult);
      req.reason = "QM5_33003_DSP_BUY";
      return true;
   }

   // Short: Fisher[2] > Trigger[2] && Fisher[1] <= Trigger[1] && Fisher[1] >= strategy_fisher_threshold
   if(g_fisher_2 > g_trigger_2 && g_fisher_1 <= g_trigger_1 && g_fisher_1 >= strategy_fisher_threshold)
   {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, g_atr_1, strategy_atr_sl_mult);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, QM_SELL, bid, g_atr_1 * strategy_atr_tp_mult);
      req.reason = "QM5_33003_DSP_SELL";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !g_state_valid)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Cycle Exit: Fisher crossing zero
      if(ptype == POSITION_TYPE_BUY)
      {
         if(g_fisher_1 >= 0.0)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         if(g_fisher_1 <= 0.0)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   AdvanceState_OnNewBar();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
   {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
   }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!is_new_bar) return;

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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
