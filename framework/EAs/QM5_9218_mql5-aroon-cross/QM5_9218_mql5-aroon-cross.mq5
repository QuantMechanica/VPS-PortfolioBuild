#property strict
#property version   "5.0"
#property description "QM5_9218 MQL5 Aroon Cross (ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9218 — MQL5 Aroon Up/Down Crossover
// Source: Mohamed Abdelmaaboud, MQL5 Articles 2024-01-19
// Card: cards_approved/QM5_9218_mql5-aroon-cross.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9218;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_aroon_period       = 25;   // Aroon Up/Down lookback period
input int    strategy_atr_period         = 14;   // ATR period for stop sizing
input double strategy_sl_atr_mult        = 1.8;  // SL = ATR * this multiplier
input double strategy_tp_rr              = 2.3;  // TP = SL * this risk-reward ratio
input double strategy_min_aroon_spread   = 5.0;  // minimum Aroon spread at entry (points)
input int    strategy_max_hold_bars      = 60;   // failsafe time-exit in H1 bars

// -----------------------------------------------------------------------------
// File-scope cached state — updated once per new H1 bar in RefreshAroonState()
// -----------------------------------------------------------------------------

static double   g_aroon_up_1    = 0.0;   // Aroon Up  last closed bar (shift 1)
static double   g_aroon_dn_1    = 0.0;   // Aroon Down last closed bar (shift 1)
static double   g_aroon_up_2    = 0.0;   // Aroon Up  bar before last (shift 2)
static double   g_aroon_dn_2    = 0.0;   // Aroon Down bar before last (shift 2)
static datetime g_last_bar      = 0;     // bar time of last state update
static int      g_bars_held     = 0;     // bars elapsed with open position
static bool     g_exit_checked  = false; // one-shot exit guard per bar

// -----------------------------------------------------------------------------
// Aroon handle — pooled via QM_Indicators infrastructure
// -----------------------------------------------------------------------------

int GetAroonHandle()
  {
   const string key = StringFormat("AROON|%s|%d|%d", _Symbol, (int)PERIOD_H1,
                                   strategy_aroon_period);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iAroon(_Symbol, PERIOD_H1, strategy_aroon_period);
   return QM_IndicatorsRegister(key, h);
  }

// Called every tick from Strategy_ManageOpenPosition; advances state at most
// once per closed bar (iTime shift-1 read is O(1) — perf-allowed).
void RefreshAroonState()
  {
   const datetime t1 = iTime(_Symbol, PERIOD_H1, 1); // perf-allowed: single bar-time, O(1)
   if(t1 <= 0 || t1 == g_last_bar)
      return;

   const int h = GetAroonHandle();
   // Advance rolling window: previous becomes "2-bars-ago"
   g_aroon_up_2 = g_aroon_up_1;
   g_aroon_dn_2 = g_aroon_dn_1;
   // Read freshly closed bar (shift 1) — QM_IndicatorReadBuffer wraps CopyBuffer
   g_aroon_up_1 = QM_IndicatorReadBuffer(h, 0, 1);
   g_aroon_dn_1 = QM_IndicatorReadBuffer(h, 1, 1);

   // Update bar-hold counter for any open position under our magic
   const int magic = QM_FrameworkMagic();
   bool has_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)magic)
        {
         has_pos = true;
         break;
        }
     }
   if(has_pos)
      g_bars_held++;
   else
      g_bars_held = 0;

   g_last_bar     = t1;
   g_exit_checked = false; // reset one-shot for new bar
  }

// Returns true when this EA's magic has an open position; sets ptype.
bool HasOwnPosition(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — spread/news handled by framework; session is 24h.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry Signal — called only on new closed bar (QM_IsNewBar gate in skeleton).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic — framework also guards, but early-exit is cheap.
   ENUM_POSITION_TYPE existing_type;
   if(HasOwnPosition(existing_type))
      return false;

   // Need at least two bars of data (both cross bars populated).
   if(g_aroon_up_1 <= 0.0 && g_aroon_dn_1 <= 0.0)
      return false;

   // Cross detection: shift-1 vs shift-2 (last closed vs bar before that)
   const double spread_now  = g_aroon_up_1 - g_aroon_dn_1;
   const double spread_prev = g_aroon_up_2 - g_aroon_dn_2;

   // Long: Aroon Up crosses above Aroon Down AND spread >= min filter
   const bool long_cross  = (spread_now  >=  strategy_min_aroon_spread) &&
                             (spread_prev <= 0.0);
   // Short: Aroon Down crosses above Aroon Up AND spread >= min filter (Dn-Up >= min)
   const bool short_cross = (-spread_now >=  strategy_min_aroon_spread) &&
                             (spread_prev >= 0.0);

   if(!long_cross && !short_cross)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * atr;
   const double tp_dist = sl_dist * strategy_tp_rr;

   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(long_cross)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type   = QM_BUY;
      req.price  = 0.0;                  // market order — fills at ask
      req.sl     = ask - sl_dist;
      req.tp     = ask + tp_dist;
      req.reason = "AROON_LONG_CROSS";
     }
   else
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type   = QM_SELL;
      req.price  = 0.0;                  // market order — fills at bid
      req.sl     = bid + sl_dist;
      req.tp     = bid - tp_dist;
      req.reason = "AROON_SHORT_CROSS";
     }

   g_bars_held = 0; // reset counter; position will be counted from next bar
   return true;
  }

// Trade Management — no active management (SL/TP handles it per card spec).
// RefreshAroonState() is called here so the state is current for both
// ExitSignal and EntrySignal on the same tick.
void Strategy_ManageOpenPosition()
  {
   RefreshAroonState();
  }

// Exit Signal — fires at most once per new bar (guarded by g_exit_checked).
bool Strategy_ExitSignal()
  {
   if(g_exit_checked)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(!HasOwnPosition(ptype))
     {
      g_exit_checked = true;
      return false;
     }

   // Failsafe: close after strategy_max_hold_bars H1 bars
   if(g_bars_held >= strategy_max_hold_bars)
     {
      g_exit_checked = true;
      return true;
     }

   // Aroon reverse-cross exit (symmetrical to entry logic)
   bool cross_exit = false;
   const double spread_now  = g_aroon_up_1 - g_aroon_dn_1;
   const double spread_prev = g_aroon_up_2 - g_aroon_dn_2;

   if(ptype == POSITION_TYPE_BUY)
     {
      // Exit long when Aroon Down crosses back above Aroon Up
      cross_exit = (spread_now <= 0.0) && (spread_prev > 0.0);
     }
   else
     {
      // Exit short when Aroon Up crosses back above Aroon Down
      cross_exit = (spread_now >= 0.0) && (spread_prev < 0.0);
     }

   g_exit_checked = true;
   return cross_exit;
  }

// News Filter Hook — defers to framework two-axis check.
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"ea\":\"QM5_9218\",\"slug\":\"mql5-aroon-cross\"}");
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
