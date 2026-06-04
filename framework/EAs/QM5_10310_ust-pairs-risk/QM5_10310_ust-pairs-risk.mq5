#property strict
#property version   "5.0"
#property description "QM5_10310 Treasury-style pairs risk-control EA"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10310;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf                  = PERIOD_M15;
input int    strategy_formation_days               = 60;
input int    strategy_z_days                       = 20;
input int    strategy_exit_corr_days               = 10;
input double strategy_min_entry_corr               = 0.75;
input double strategy_min_exit_corr                = 0.50;
input double strategy_entry_z                      = 1.75;
input double strategy_exit_z                       = 0.20;
input double strategy_hard_stop_z                  = 3.0;
input int    strategy_max_hold_days                = 3;
input int    strategy_cooldown_hours_after_stop    = 24;
input double strategy_max_cost_fraction            = 0.10;
input int    strategy_atr_period                   = 14;
input double strategy_atr_sl_mult                  = 2.0;
input int    strategy_min_stop_points              = 50;

double   g_last_z = 0.0;
double   g_last_spread_sd = 0.0;
double   g_last_entry_corr = 0.0;
double   g_last_exit_corr = 0.0;
bool     g_pair_state_ready = false;
datetime g_last_hard_stop_time = 0;
int      g_last_hard_stop_direction = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == "USDJPY.DWX") return 0;
   if(symbol == "USDCAD.DWX") return 1;
   if(symbol == "EURUSD.DWX") return 2;
   if(symbol == "GBPUSD.DWX") return 3;
   if(symbol == "XAUUSD.DWX") return 4;
   if(symbol == "SP500.DWX")  return 5;
   if(symbol == "NDX.DWX")    return 6;
   if(symbol == "WS30.DWX")   return 7;
   return -1;
  }

string Strategy_PeerSymbol()
  {
   if(_Symbol == "USDJPY.DWX") return "USDCAD.DWX";
   if(_Symbol == "USDCAD.DWX") return "USDJPY.DWX";
   if(_Symbol == "EURUSD.DWX") return "GBPUSD.DWX";
   if(_Symbol == "GBPUSD.DWX") return "EURUSD.DWX";
   if(_Symbol == "XAUUSD.DWX") return "USDJPY.DWX";
   if(_Symbol == "SP500.DWX")  return "NDX.DWX";
   if(_Symbol == "NDX.DWX")    return "SP500.DWX";
   if(_Symbol == "WS30.DWX")   return "NDX.DWX";
   return "";
  }

bool Strategy_IsPackagePosition()
  {
   const string peer = Strategy_PeerSymbol();
   if(peer == "")
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int magic = (int)PositionGetInteger(POSITION_MAGIC);
   const int slot_a = Strategy_SlotForSymbol(_Symbol);
   const int slot_b = Strategy_SlotForSymbol(peer);

   if(symbol == _Symbol && slot_a >= 0 && magic == QM_MagicChecked(qm_ea_id, slot_a, _Symbol))
      return true;
   if(symbol == peer && slot_b >= 0 && magic == QM_MagicChecked(qm_ea_id, slot_b, peer))
      return true;
   return false;
  }

bool Strategy_CurrentPackage(datetime &opened, int &direction, double &profit)
  {
   opened = 0;
   direction = 0;
   profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(!Strategy_IsPackagePosition())
         continue;

      const datetime pos_opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened == 0 || pos_opened < opened)
         opened = pos_opened;
      profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
        }
     }
   return (opened > 0);
  }

int Strategy_ClosePackage(const QM_ExitReason reason)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPackagePosition())
         continue;
      if(QM_TM_ClosePosition(ticket, reason))
         ++closed;
     }
   return closed;
  }

bool Strategy_ReturnCorrelation(const double &a[], const double &b[], const int bars, double &corr)
  {
   corr = 0.0;
   if(bars < 2)
      return false;

   double sum_a = 0.0;
   double sum_b = 0.0;
   double sum_a2 = 0.0;
   double sum_b2 = 0.0;
   double sum_ab = 0.0;
   int n = 0;
   for(int i = bars - 1; i >= 1; --i)
     {
      if(a[i] <= 0.0 || a[i - 1] <= 0.0 || b[i] <= 0.0 || b[i - 1] <= 0.0)
         return false;
      const double ra = MathLog(a[i - 1] / a[i]);
      const double rb = MathLog(b[i - 1] / b[i]);
      sum_a += ra;
      sum_b += rb;
      sum_a2 += ra * ra;
      sum_b2 += rb * rb;
      sum_ab += ra * rb;
      ++n;
     }

   const double cov = sum_ab - (sum_a * sum_b / n);
   const double var_a = sum_a2 - (sum_a * sum_a / n);
   const double var_b = sum_b2 - (sum_b * sum_b / n);
   if(var_a <= 0.0 || var_b <= 0.0)
      return false;

   corr = cov / MathSqrt(var_a * var_b);
   return MathIsValidNumber(corr);
  }

bool Strategy_CalcPairState(double &z, double &spread_sd, double &entry_corr, double &exit_corr)
  {
   z = 0.0;
   spread_sd = 0.0;
   entry_corr = 0.0;
   exit_corr = 0.0;

   const string peer = Strategy_PeerSymbol();
   if(peer == "")
      return false;
   SymbolSelect(peer, true);

   const int bars_per_day = 96;
   const int formation_bars = MathMax(50, strategy_formation_days * bars_per_day);
   const int z_bars = MathMax(20, strategy_z_days * bars_per_day);
   const int exit_corr_bars = MathMax(20, strategy_exit_corr_days * bars_per_day);
   const int bars = MathMax(formation_bars, MathMax(z_bars, exit_corr_bars)) + 1;
   if(z_bars > formation_bars)
      return false;

   double a[];
   double b[];
   ArraySetAsSeries(a, true);
   ArraySetAsSeries(b, true);
   if(CopyClose(_Symbol, strategy_tf, 1, bars, a) < bars) // perf-allowed: Strategy_EntrySignal is framework-gated by QM_IsNewBar().
      return false;
   if(CopyClose(peer, strategy_tf, 1, bars, b) < bars) // perf-allowed: Strategy_EntrySignal is framework-gated by QM_IsNewBar().
      return false;

   if(!Strategy_ReturnCorrelation(a, b, formation_bars, entry_corr))
      return false;
   if(!Strategy_ReturnCorrelation(a, b, exit_corr_bars, exit_corr))
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_y2 = 0.0;
   for(int i = formation_bars - 1; i >= 0; --i)
     {
      if(a[i] <= 0.0 || b[i] <= 0.0)
         return false;
      const double x = MathLog(a[i]);
      const double y = MathLog(b[i]);
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_y2 += y * y;
     }

   const double beta_den = sum_y2 - (sum_y * sum_y / formation_bars);
   if(beta_den <= 0.0)
      return false;
   const double beta = (sum_xy - (sum_x * sum_y / formation_bars)) / beta_den;
   if(!MathIsValidNumber(beta))
      return false;

   double sum_s = 0.0;
   double sum_s2 = 0.0;
   for(int i = z_bars - 1; i >= 0; --i)
     {
      const double spread = MathLog(a[i]) - beta * MathLog(b[i]);
      sum_s += spread;
      sum_s2 += spread * spread;
     }

   const double mean = sum_s / z_bars;
   const double variance = (sum_s2 - (sum_s * sum_s / z_bars)) / (z_bars - 1);
   if(variance <= 0.0)
      return false;

   spread_sd = MathSqrt(variance);
   const double current_spread = MathLog(a[0]) - beta * MathLog(b[0]);
   z = (current_spread - mean) / spread_sd;
   return MathIsValidNumber(z);
  }

bool Strategy_RefreshPairState()
  {
   double z;
   double spread_sd;
   double entry_corr;
   double exit_corr;

   g_pair_state_ready = Strategy_CalcPairState(z, spread_sd, entry_corr, exit_corr);
   if(!g_pair_state_ready)
      return false;

   g_last_z = z;
   g_last_spread_sd = spread_sd;
   g_last_entry_corr = entry_corr;
   g_last_exit_corr = exit_corr;
   return true;
  }

bool Strategy_SpreadCostOK(const double abs_z, const double spread_sd)
  {
   const string peer = Strategy_PeerSymbol();
   if(peer == "" || abs_z <= 0.0 || spread_sd <= 0.0)
      return false;

   const double bid_a = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask_a = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid_b = SymbolInfoDouble(peer, SYMBOL_BID);
   const double ask_b = SymbolInfoDouble(peer, SYMBOL_ASK);
   if(bid_a <= 0.0 || ask_a <= 0.0 || bid_b <= 0.0 || ask_b <= 0.0)
      return false;

   const double cost = ((ask_a - bid_a) / bid_a) + ((ask_b - bid_b) / bid_b);
   const double entry_to_mean = abs_z * spread_sd;
   return (cost <= entry_to_mean * strategy_max_cost_fraction);
  }

bool Strategy_StopCooldownAllows(const int direction)
  {
   if(g_last_hard_stop_time <= 0 || direction == 0)
      return true;
   if(g_last_hard_stop_direction != direction)
      return true;
   return (TimeCurrent() - g_last_hard_stop_time >= strategy_cooldown_hours_after_stop * 3600);
  }

void Strategy_MarkHardStop(const int direction)
  {
   g_last_hard_stop_time = TimeCurrent();
   g_last_hard_stop_direction = direction;
  }

double Strategy_StopDistance(const string symbol)
  {
   const double atr = QM_ATR(symbol, strategy_tf, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const double min_dist = strategy_min_stop_points * point;
   if(atr <= 0.0)
      return min_dist;
   return MathMax(atr * strategy_atr_sl_mult, min_dist);
  }

bool Strategy_OpenLeg(const string symbol,
                      const int slot,
                      const QM_OrderType type,
                      const double weight,
                      const double weight_sum,
                      const string reason)
  {
   if(symbol != _Symbol)
      return false;
   if(MathAbs(weight) <= 0.0 || weight_sum <= 0.0)
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_dist = Strategy_StopDistance(symbol);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || stop_dist <= 0.0 || point <= 0.0)
      return false;

   QM_EntryRequest req;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? entry - stop_dist : entry + stop_dist;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_TM_OpenPosition(req, ticket);
  }

bool Strategy_OpenPackage(const int direction)
  {
   const string peer = Strategy_PeerSymbol();
   const int slot_a = Strategy_SlotForSymbol(_Symbol);
   const int slot_b = Strategy_SlotForSymbol(peer);
   if(peer == "" || slot_a < 0 || slot_b < 0)
      return false;

   const double weight_a = 1.0;
   const double weight_b = 1.0;
   const double weight_sum = MathAbs(weight_a) + MathAbs(weight_b);

   const QM_OrderType type_a = (direction > 0) ? QM_BUY : QM_SELL;
   const QM_OrderType type_b = (direction > 0) ? QM_SELL : QM_BUY;
   const string reason = (direction > 0) ? "UST_PAIRS_LONG_A_SHORT_B" : "UST_PAIRS_SHORT_A_LONG_B";

   bool opened = false;
   if(Strategy_OpenLeg(_Symbol, slot_a, type_a, weight_a, weight_sum, reason))
      opened = true;
   if(Strategy_OpenLeg(peer, slot_b, type_b, weight_b, weight_sum, reason))
      opened = true;
   return opened;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return (_Period != strategy_tf || Strategy_PeerSymbol() == "");
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime opened;
   int current_direction;
   double current_profit;
   if(Strategy_CurrentPackage(opened, current_direction, current_profit))
      return false;

   if(!Strategy_RefreshPairState())
      return false;

   if(g_last_entry_corr < strategy_min_entry_corr)
      return false;
   if(!Strategy_SpreadCostOK(MathAbs(g_last_z), g_last_spread_sd))
      return false;

   if(g_last_z >= strategy_entry_z)
     {
      if(!Strategy_StopCooldownAllows(-1))
         return false;
      Strategy_OpenPackage(-1);
      return false;
     }

   if(g_last_z <= -strategy_entry_z)
     {
      if(!Strategy_StopCooldownAllows(1))
         return false;
      Strategy_OpenPackage(1);
      return false;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no averaging down, trailing stop, break-even move, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   datetime opened;
   int direction;
   double profit;
   if(!Strategy_CurrentPackage(opened, direction, profit))
      return false;

   if(g_pair_state_ready)
     {
      if(MathAbs(g_last_z) <= strategy_exit_z)
        {
         Strategy_ClosePackage(QM_EXIT_STRATEGY);
         return false;
        }
      if(MathAbs(g_last_z) >= strategy_hard_stop_z)
        {
         Strategy_MarkHardStop(direction);
         Strategy_ClosePackage(QM_EXIT_STRATEGY);
         return false;
        }
      if(g_last_exit_corr < strategy_min_exit_corr)
        {
         Strategy_ClosePackage(QM_EXIT_STRATEGY);
         return false;
        }
     }

   const int max_hold_seconds = strategy_max_hold_days * 24 * 60 * 60;
   if(max_hold_seconds > 0 && TimeCurrent() - opened >= max_hold_seconds)
     {
      Strategy_ClosePackage(QM_EXIT_TIME_STOP);
      return false;
     }

   const double loss_cap = (RISK_FIXED > 0.0) ? MathMin(RISK_FIXED, 1000.0) : 1000.0;
   if(profit <= -loss_cap)
     {
      Strategy_MarkHardStop(direction);
      Strategy_ClosePackage(QM_EXIT_STRATEGY);
      return false;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const string peer = Strategy_PeerSymbol();
   if(peer == "")
      return true;

   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return !QM_NewsAllowsTrade2(peer, broker_time, qm_news_temporal, qm_news_compliance);
   return !QM_NewsAllowsTrade(peer, broker_time, qm_news_mode_legacy);
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

   string basket_symbols[8] = {"USDJPY.DWX", "USDCAD.DWX", "EURUSD.DWX", "GBPUSD.DWX",
                               "XAUUSD.DWX", "SP500.DWX", "NDX.DWX", "WS30.DWX"};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, strategy_tf, 600);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10310_ust_pairs_risk\"}");
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   const bool is_new_bar = QM_IsNewBar(_Symbol, strategy_tf);
   if(is_new_bar)
     {
      Strategy_RefreshPairState();
      QM_EquityStreamOnNewBar();
     }

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   if(!is_new_bar)
      return;

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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
