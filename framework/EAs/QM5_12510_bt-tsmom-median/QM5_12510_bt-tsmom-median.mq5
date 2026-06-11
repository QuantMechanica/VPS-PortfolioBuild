#property strict
#property version   "5.0"
#property description "QM5_12510 bt 12-Month Median TS-Momentum (D1, long-flat)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12510 bt-tsmom-median
// 12-month rolling median trend filter on D1 closes.
// Long when close[1] > median(close[2..253]); emergency stop 3.5*ATR(20,D1).
// Source: pmorissette/bt, Trend Example 1, commit 2630651f.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12510;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_median_period      = 252;   // rolling median lookback (D1 bars)
input int    strategy_warmup_bars        = 270;   // min completed D1 bars before first trade
input int    strategy_atr_period         = 20;    // ATR period for emergency stop
input double strategy_stop_atr_mult      = 3.5;   // emergency stop = mult * ATR(period, D1)

// -----------------------------------------------------------------------------
// Per-bar cached state — updated once per new D1 bar via AdvanceState_OnNewBar()
// -----------------------------------------------------------------------------
double g_close1        = 0.0;   // close of the just-completed D1 bar (shift=1)
double g_median_close  = 0.0;   // shifted 252-bar rolling median of D1 closes
double g_spread2x      = 0.0;   // 2 * median spread over last 60 bars (price units)
bool   g_ready         = false; // true after strategy_warmup_bars bars seen

#define SPREAD_WIN 60
double g_spread_buf[SPREAD_WIN];
int    g_spread_cnt = 0;
int    g_spread_pos = 0;

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar — called exactly ONCE per closed D1 bar.
// Uses CopyRates to fetch bar history; all heavy work happens here.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   int need_median  = strategy_median_period + 2;           // 254: shift-1 close + 252 median bars
   int need_warmup  = strategy_warmup_bars + 1;             // 271
   int need         = MathMax(need_median, need_warmup);

   MqlRates rates[];
   // perf-allowed: CopyRates called ONCE per new bar (not per tick)
   int copied = CopyRates(_Symbol, PERIOD_D1, 1, need, rates);

   g_ready = (copied >= strategy_warmup_bars);
   if(copied < need_median)
      return;

   // rates[0] = just-closed bar (shift=1); rates[1..252] = 252-bar median window
   g_close1 = rates[0].close;

   double med[];
   ArrayResize(med, strategy_median_period);
   for(int i = 0; i < strategy_median_period; i++)
      med[i] = rates[i + 1].close;
   ArraySort(med);
   int n = strategy_median_period;
   g_median_close = (n % 2 == 0)
                    ? (med[n / 2 - 1] + med[n / 2]) * 0.5
                    : med[n / 2];

   // Spread sample: record current spread at bar boundary (price units)
   double pt          = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double cur_spread  = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * pt;
   g_spread_buf[g_spread_pos] = cur_spread;
   g_spread_pos = (g_spread_pos + 1) % SPREAD_WIN;
   if(g_spread_cnt < SPREAD_WIN) g_spread_cnt++;

   // Compute spread median for threshold
   double stmp[];
   ArrayResize(stmp, g_spread_cnt);
   int start = (g_spread_cnt < SPREAD_WIN) ? 0 : g_spread_pos;
   for(int i = 0; i < g_spread_cnt; i++)
      stmp[i] = g_spread_buf[(start + i) % SPREAD_WIN];
   ArraySort(stmp);
   int sn   = g_spread_cnt;
   double sm = (sn % 2 == 0) ? (stmp[sn / 2 - 1] + stmp[sn / 2]) * 0.5 : stmp[sn / 2];
   g_spread2x = 2.0 * sm;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — spread and warmup guards are in EntrySignal to avoid
// blocking exit logic.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry: long when close[1] > shifted 252-bar median.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_ready) return false;

   // Spread filter: skip if current spread exceeds 2× 60-bar median spread
   if(g_spread2x > 0.0)
     {
      double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double cur = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * pt;
      if(cur > g_spread2x) return false;
     }

   // Trend signal: prior close above shifted 252-bar median → long
   if(g_close1 <= g_median_close) return false;

   double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period);
   if(atr <= 0.0) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = ask - strategy_stop_atr_mult * atr;
   if(sl <= 0.0) return false;

   req.type  = QM_BUY;
   req.price = ask;
   req.sl    = sl;
   req.tp    = 0.0;
   return true;
  }

// Trade management — no active trailing; emergency SL set at entry is primary.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: close long when prior close drops to or below the shifted median.
bool Strategy_ExitSignal()
  {
   if(!g_ready || g_close1 <= 0.0) return false;
   return (g_close1 <= g_median_close);
  }

// News filter hook — defer to framework two-axis check.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   // Advance closed-bar state before any hook reads cached values.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      AdvanceState_OnNewBar();

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

   if(!new_bar)
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
