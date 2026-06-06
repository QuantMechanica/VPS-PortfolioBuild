#property strict
#property version   "5.0"
#property description "QM5_10963 FTMO AMD Distribution Reversal (ftmo-amd-dist)"
// Strategy Card: QM5_10963_ftmo-amd-dist, G0 APPROVED 2026-05-22.
// Source: FTMO "How to use accumulation, manipulation and distribution in trading".

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — FTMO AMD Distribution Reversal
// -----------------------------------------------------------------------------
// M15 session strategy. Each London/NY session: measure an accumulation range
// over the first N M15 bars, wait for a liquidity sweep (manipulation) past the
// range edge, then enter on the failed-sweep reclaim/breakout (distribution)
// in the direction of the H1 trend bias, with volume confirmation.
//
// Heavy bar/volume math is BESPOKE STRUCTURAL logic (accumulation range, sweep,
// reclaim) that no QM_* reader covers. It is confined to Strategy_EntrySignal,
// which the framework only calls once per closed M15 bar (post QM_IsNewBar gate
// in OnTick). Per-tick paths (ManageOpenPosition / ExitSignal) are O(1): they
// read only cached file-scope state + the current quote. Raw i* series reads
// carry an explicit `// perf-allowed` tag per the Framework Corset.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10963;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Sessions (broker time, GMT+2/+3 NY-Close). M15 bars align to :00/:15/:30/:45.
input int    strat_sess1_start_hhmm     = 1000;  // London accumulation start (broker)
input int    strat_sess1_end_hhmm       = 1700;  // London time-exit (broker)
input int    strat_sess2_start_hhmm     = 1500;  // New York accumulation start (broker)
input int    strat_sess2_end_hhmm       = 2200;  // New York time-exit (broker)
input int    strat_acc_bars             = 8;     // accumulation window length (M15 bars)
input int    strat_setup_window_bars    = 6;     // sweep / reclaim search window (M15 bars)
input int    strat_atr_period           = 14;    // ATR(M15) period
input int    strat_vol_avg_period       = 20;    // tick-volume average window (M15 bars)
input double strat_acc_range_atr_max    = 1.2;   // accumulation range <= mult * ATR
input double strat_acc_range_atr_min    = 0.4;   // skip if range < mult * ATR
input double strat_acc_range_atr_cap    = 1.8;   // skip if range > mult * ATR
input double strat_sweep_atr_mult       = 0.25;  // sweep depth past range edge (* ATR)
input double strat_sl_atr_buffer        = 0.2;   // SL buffer past manipulation extreme (* ATR)
input double strat_vol_confirm_mult     = 1.2;   // breakout volume >= mult * 20-bar avg
input double strat_tp_r_mult            = 2.5;   // final TP at mult * R
input int    strat_ema_fast             = 50;    // H1 bias fast EMA
input int    strat_ema_slow             = 200;   // H1 bias slow EMA

// -----------------------------------------------------------------------------
// Cached AMD state machine — advanced ONCE per closed M15 bar inside
// Strategy_EntrySignal (the only QM_IsNewBar-gated hook). Never per tick.
// -----------------------------------------------------------------------------
#define AMD_IDLE         0
#define AMD_ACC          1
#define AMD_WAIT_SWEEP   2
#define AMD_WAIT_RECLAIM 3
#define AMD_DONE         4

int      g_phase              = AMD_IDLE;
datetime g_last_proc_bar      = 0;       // closed-bar dedupe guard
int      g_cur_session        = 0;       // 1 = London, 2 = NY, 0 = none
int      g_acc_count          = 0;
double   g_acc_high           = 0.0;
double   g_acc_low            = 0.0;
double   g_acc_vol_sum        = 0.0;
double   g_atr                = 0.0;     // ATR(M15) cached at accumulation close
double   g_vol20avg           = 0.0;     // 20-bar tick-vol avg cached at acc close
int      g_bias               = 0;       // +1 bullish, -1 bearish, 0 none
int      g_setup_count        = 0;       // bars since acc close (or since sweep)
double   g_manip_extreme      = 0.0;     // sweep low (long) / high (short)
bool     g_reclaimed          = false;   // closed back inside range after sweep
bool     g_attempted          = false;   // one AMD attempt per symbol/session

// Open-trade tracking (set at entry, read per tick by management/exit).
int      g_active_session     = 0;       // session the open trade belongs to
double   g_r_distance         = 0.0;     // 1R in price units, for break-even
bool     g_be_done            = false;   // SL already moved to break-even

int BrokerHhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

double TickVolAvg(const int count)
  {
   if(count <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= count; ++i)
      sum += (double)iVolume(_Symbol, _Period, i);   // perf-allowed: bespoke 20-bar tick-vol avg, new-bar gated
   return sum / count;
  }

int H1Bias()
  {
   const double ema_fast = QM_EMA(_Symbol, PERIOD_H1, strat_ema_fast, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_H1, strat_ema_slow, 1);
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1);   // perf-allowed: last closed H1 bias close
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || h1_close <= 0.0)
      return 0;
   if(h1_close > ema_fast && ema_fast > ema_slow)
      return 1;
   if(h1_close < ema_fast && ema_fast < ema_slow)
      return -1;
   return 0;
  }

bool FindOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price)
  {
   ticket = 0;
   open_price = 0.0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket = t;
      return true;
     }
   return false;
  }

void StartSession(const int session_id, const double bar_high, const double bar_low, const double bar_vol)
  {
   g_phase        = AMD_ACC;
   g_cur_session  = session_id;
   g_acc_count    = 1;
   g_acc_high     = bar_high;
   g_acc_low      = bar_low;
   g_acc_vol_sum  = bar_vol;
   g_bias         = 0;
   g_setup_count  = 0;
   g_manip_extreme = 0.0;
   g_reclaimed    = false;
   g_attempted    = false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time / spread / news). Session gating lives inside the entry
// state machine, NOT here: returning TRUE would also halt per-tick trade
// management and the session time-exit. Keep permissive so exits always run.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry. Called once per closed M15 bar (QM_IsNewBar-gated by OnTick).
// Advances the AMD state machine on the just-closed bar and fires an entry on
// the volume-confirmed reclaim/breakout.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   const datetime bar_t = iTime(_Symbol, _Period, 1);   // perf-allowed: closed-bar timestamp for session gating
   if(bar_t <= 0 || bar_t == g_last_proc_bar)
      return false;
   g_last_proc_bar = bar_t;
   const double bar_high  = iHigh(_Symbol, _Period, 1);    // perf-allowed: bespoke AMD range, new-bar gated
   const double bar_low   = iLow(_Symbol, _Period, 1);     // perf-allowed: bespoke AMD range, new-bar gated
   const double bar_close = iClose(_Symbol, _Period, 1);   // perf-allowed: bespoke AMD reclaim, new-bar gated
   const double bar_vol   = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: bespoke AMD volume confirm
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;

   const int hhmm = BrokerHhmm(bar_t);

   // Session start resets the machine and begins a fresh accumulation window.
   bool started_this_bar = false;
   if(hhmm == strat_sess1_start_hhmm)
     {
      StartSession(1, bar_high, bar_low, bar_vol);
      started_this_bar = true;
     }
   else if(hhmm == strat_sess2_start_hhmm)
     {
      StartSession(2, bar_high, bar_low, bar_vol);
      started_this_bar = true;
     }

   if(g_phase == AMD_IDLE || g_phase == AMD_DONE)
      return false;

   // ---- Accumulation phase ----
   if(g_phase == AMD_ACC)
     {
      if(!started_this_bar)
        {
         g_acc_count++;
         if(bar_high > g_acc_high) g_acc_high = bar_high;
         if(bar_low  < g_acc_low)  g_acc_low  = bar_low;
         g_acc_vol_sum += bar_vol;
        }

      if(g_acc_count < strat_acc_bars)
         return false;

      // Accumulation window complete — validate it.
      g_atr = QM_ATR(_Symbol, _Period, strat_atr_period, 1);
      if(g_atr <= 0.0)
        {
         g_phase = AMD_DONE;
         return false;
        }

      const double acc_range   = g_acc_high - g_acc_low;
      const double acc_avg_vol = g_acc_vol_sum / strat_acc_bars;
      g_vol20avg = TickVolAvg(strat_vol_avg_period);
      g_bias = H1Bias();

      const bool range_ok = (acc_range <= strat_acc_range_atr_max * g_atr) &&
                            (acc_range >= strat_acc_range_atr_min * g_atr) &&
                            (acc_range <= strat_acc_range_atr_cap * g_atr);
      const bool vol_ok   = (g_vol20avg > 0.0 && acc_avg_vol <= g_vol20avg);

      if(!range_ok || !vol_ok || g_bias == 0)
        {
         g_phase = AMD_DONE;   // no valid AMD setup this session
         return false;
        }

      g_phase = AMD_WAIT_SWEEP;
      g_setup_count = 0;
      g_reclaimed = false;
      return false;
     }

   // ---- Wait for the manipulation sweep ----
   if(g_phase == AMD_WAIT_SWEEP)
     {
      g_setup_count++;
      if(g_setup_count > strat_setup_window_bars)
        {
         g_phase = AMD_DONE;
         return false;
        }

      if(g_bias > 0 && bar_low <= g_acc_low - strat_sweep_atr_mult * g_atr)
        {
         g_manip_extreme = bar_low;
         g_phase = AMD_WAIT_RECLAIM;
         g_setup_count = 0;
         g_reclaimed = false;
        }
      else if(g_bias < 0 && bar_high >= g_acc_high + strat_sweep_atr_mult * g_atr)
        {
         g_manip_extreme = bar_high;
         g_phase = AMD_WAIT_RECLAIM;
         g_setup_count = 0;
         g_reclaimed = false;
        }
      return false;
     }

   // ---- Wait for reclaim + volume-confirmed breakout ----
   if(g_phase == AMD_WAIT_RECLAIM)
     {
      g_setup_count++;
      if(g_setup_count > strat_setup_window_bars)
        {
         g_phase = AMD_DONE;
         return false;
        }

      const double brk_vol_avg = TickVolAvg(strat_vol_avg_period);
      const bool vol_confirm = (brk_vol_avg > 0.0 && bar_vol >= strat_vol_confirm_mult * brk_vol_avg);

      if(g_bias > 0)
        {
         if(bar_low < g_manip_extreme) g_manip_extreme = bar_low;
         if(!g_reclaimed && bar_close > g_acc_low)
            g_reclaimed = true;
         if(g_reclaimed && bar_close > g_acc_high && vol_confirm)
           {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            const double sl  = g_manip_extreme - strat_sl_atr_buffer * g_atr;
            if(ask <= 0.0 || sl <= 0.0 || ask <= sl)
              { g_phase = AMD_DONE; return false; }
            const double r = ask - sl;
            req.type   = QM_BUY;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = ask + strat_tp_r_mult * r;
            req.reason = "AMD_LONG_DIST";
            g_active_session = g_cur_session;
            g_r_distance = r;
            g_be_done = false;
            g_attempted = true;
            g_phase = AMD_DONE;
            return true;
           }
        }
      else if(g_bias < 0)
        {
         if(bar_high > g_manip_extreme) g_manip_extreme = bar_high;
         if(!g_reclaimed && bar_close < g_acc_high)
            g_reclaimed = true;
         if(g_reclaimed && bar_close < g_acc_low && vol_confirm)
           {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            const double sl  = g_manip_extreme + strat_sl_atr_buffer * g_atr;
            if(bid <= 0.0 || sl <= bid)
              { g_phase = AMD_DONE; return false; }
            const double r = sl - bid;
            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = bid - strat_tp_r_mult * r;
            req.reason = "AMD_SHORT_DIST";
            g_active_session = g_cur_session;
            g_r_distance = r;
            g_be_done = false;
            g_attempted = true;
            g_phase = AMD_DONE;
            return true;
           }
        }
      return false;
     }

   return false;
  }

// Trade Management. Per-tick, O(1): once price reaches +1R, move SL to
// break-even (card: "move SL to breakeven after TP1 touch"). Final TP (2.5R)
// is carried on the order itself.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   if(!FindOurPosition(ticket, ptype, open_price))
     {
      g_active_session = 0;   // flat — clear trade tracking
      return;
     }
   if(g_be_done || g_r_distance <= 0.0 || open_price <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > 0.0 && (bid - open_price) >= g_r_distance)
        {
         if(QM_TM_MoveSL(ticket, open_price, "BE_after_1R"))
            g_be_done = true;
        }
     }
   else
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask > 0.0 && (open_price - ask) >= g_r_distance)
        {
         if(QM_TM_MoveSL(ticket, open_price, "BE_after_1R"))
            g_be_done = true;
        }
     }
  }

// Trade Close. Per-tick, O(1): time-exit at end of the active session. The
// framework closes our magic positions when this returns TRUE.
bool Strategy_ExitSignal()
  {
   if(g_active_session == 0)
      return false;
   const int hhmm = BrokerHhmm(TimeCurrent());
   const int end  = (g_active_session == 1) ? strat_sess1_end_hhmm : strat_sess2_end_hhmm;
   return (hhmm >= end);
  }

// News Filter Hook (callable for the P8 News Impact phase). Defer to the central
// two-axis QM news filter (qm_news_temporal / qm_news_compliance) configured in
// OnInit — the card's "skip high-impact news windows" maps to that filter.
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10963_ftmo-amd-dist\"}");
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
