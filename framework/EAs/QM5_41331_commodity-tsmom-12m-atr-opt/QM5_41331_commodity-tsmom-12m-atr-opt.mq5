#property strict
#property version   "5.0"
#property description "QM5_41331 WTI 12M TSMOM ATR Gate - DL-089 opt sibling"
// Strategy Card: QM5_41331 (commodity-tsmom-12m-atr-opt), G0 APPROVED 2026-09-03.
// DL-089 measurement sibling of parent QM5_12710 (commodity-tsmom-12m-atr).
// Parent entry/exit/sizing/news/Friday-close mechanics are byte-equivalent to the
// recompiled 2026-09-03 parent identity; the only delta is the six closed-D1
// pattern-permission veto inputs (opt_pp_buy1..3 / opt_pp_sell1..3). Zero disables
// a slot, so the shipped baseline is neutral. No live or pipeline verdict is
// authorized; this build exists only to run the DL-089 optimization census.

#define QM_PATTERN_PERMISSION_EA_MANAGED
#include <QM/QM_Common.mqh>
#include <QM/QM_PatternPermission.mqh>

// =============================================================================
// QM5_12710 - WTI 12-Month Time-Series Momentum ATR Gate (parent mechanics)
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - first D1 bar of each month only
//   - direction = sign of prior 12-month log return
//   - entry only when ATR% is inside a fixed volatility corridor
//   - monthly package exits at next rebalance or stale-position guard
// Runtime uses MT5 OHLC/broker calendar only; no curve, inventory, API, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41331;
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
input int    strategy_momentum_lookback_d1 = 252;
input double strategy_min_abs_return_pct   = 1.0;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.5;
input double strategy_min_atr_pct          = 0.75;
input double strategy_max_atr_pct          = 7.50;
input int    strategy_max_hold_days        = 31;
input int    strategy_max_spread_points    = 1000;

// DL-089 pattern measurement surface. Zero disables a slot.
input group "Optimization Pattern Profile"
input int opt_pp_buy1  = 0;
input int opt_pp_buy2  = 0;
input int opt_pp_buy3  = 0;
input int opt_pp_sell1 = 0;
input int opt_pp_sell2 = 0;
input int opt_pp_sell3 = 0;

const ENUM_TIMEFRAMES QM_PPC_REFERENCE_TF = PERIOD_D1;
const int             QM_PPC_CLOSED_SHIFT = 1;
QM_PatternProfile     g_pp_profile;
bool                  g_pp_active = false;
long                  g_pp_days_evaluated = 0;
long                  g_pp_fire_count = 0;
long                  g_pp_legs_suppressed = 0;
long                  g_pp_invalid_days = 0;

int g_last_entry_month_key = 0;

QM_PermissionResult Pattern_Permission()
  {
   QM_PermissionResult perm;
   if(!g_pp_active)
     {
      perm.allow_buy = true;
      perm.allow_sell = true;
      perm.valid = true;
      MqlRates reference_bar;
      perm.reference_bar_time = (QM_ReadBar(_Symbol, QM_PPC_REFERENCE_TF,
                                            QM_PPC_CLOSED_SHIFT, reference_bar)
                                 ? reference_bar.time : 0);
      perm.reason = "census_control";
      return perm;
     }
   return QM_PatternPermissionEvaluate(_Symbol, QM_PPC_REFERENCE_TF,
                                       QM_PPC_CLOSED_SHIFT, g_pp_profile);
  }

bool Opt_AddPattern(const int predicate_id, const bool buy_side, const string input_name)
  {
   if(predicate_id == 0)
      return true;
   if(predicate_id < 0)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\"input\":\"%s\",\"predicate_id\":%d}", input_name, predicate_id));
      return false;
     }
   const QM_PatternId pid = (QM_PatternId)predicate_id;
   const bool added = buy_side ? QM_PP_ProfileAddBuy(g_pp_profile, pid)
                               : QM_PP_ProfileAddSell(g_pp_profile, pid);
   if(!added)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\"input\":\"%s\",\"predicate_id\":%d}", input_name, predicate_id));
      return false;
     }
   g_pp_active = true;
   return true;
  }

bool Pattern_AllowsRequest(const QM_EntryRequest &req)
  {
   const QM_PermissionResult perm = Pattern_Permission();
   g_pp_days_evaluated++;
   if(!perm.valid)
     {
      g_pp_invalid_days++;
      QM_LogEvent(QM_WARN, "PP_CENSUS_BLOCK", "{\"reason\":\"permission_invalid\"}");
      return false;
     }
   const bool buy_side = QM_OrderTypeIsBuy(req.type);
   const bool allowed = buy_side ? perm.allow_buy : perm.allow_sell;
   if(!allowed)
     {
      g_pp_fire_count++;
      g_pp_legs_suppressed++;
      QM_LogEvent(QM_INFO, "PP_CENSUS_BLOCK",
                  StringFormat("{\"side\":\"%s\",\"bar\":\"%s\",\"reason\":\"%s\"}",
                               (buy_side ? "BUY" : "SELL"),
                               TimeToString(perm.reference_bar_time), perm.reason));
     }
   return allowed;
  }

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate behind framework new-bar.
   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 calendar gate behind framework new-bar.
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return Strategy_MonthKey(current_bar) != Strategy_MonthKey(prior_bar);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_LoadMomentum(double &momentum, int &direction)
  {
   momentum = 0.0;
   direction = 0;

   const int lookback = MathMax(21, strategy_momentum_lookback_d1);
   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, lookback + 1, closes); // perf-allowed: bounded D1 12M momentum sample behind new-bar gate.
   if(copied < lookback + 1)
      return false;

   const double close_recent = closes[0];
   const double close_past = closes[lookback];
   if(close_recent <= 0.0 || close_past <= 0.0)
      return false;

   momentum = MathLog(close_recent / close_past);
   if(!MathIsValidNumber(momentum))
      return false;

   const double threshold = MathMax(0.0, strategy_min_abs_return_pct) / 100.0;
   if(momentum > threshold)
      direction = 1;
   else if(momentum < -threshold)
      direction = -1;
   else
      direction = 0;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const bool monthly_rebalance = Strategy_IsMonthlyRebalanceBar();
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = monthly_rebalance;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_momentum_lookback_d1 < 21)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_min_atr_pct < 0.0 || strategy_max_atr_pct <= strategy_min_atr_pct)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12710_WTI_TSMOM12M_ATR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 monthly de-dupe behind new-bar gate.
   const int month_key = Strategy_MonthKey(current_bar);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double momentum = 0.0;
   int direction = 0;
   if(!Strategy_LoadMomentum(momentum, direction))
      return false;
   if(direction == 0)
      return false;

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0)
      return false;
   const double close_last = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   if(close_last <= 0.0)
      return false;
   const double atr_pct = 100.0 * atr_last / close_last;
   if(!MathIsValidNumber(atr_pct))
      return false;
   if(atr_pct < strategy_min_atr_pct || atr_pct > strategy_max_atr_pct)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "WTI_TSMOM12M_ATR_LONG" : "WTI_TSMOM12M_ATR_SHORT";
   g_last_entry_month_key = month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   g_pp_active = false;
   QM_PP_ProfileInit(g_pp_profile, "DL089_OPT", QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT);
   if(!Opt_AddPattern(opt_pp_buy1, true, "opt_pp_buy1") ||
      !Opt_AddPattern(opt_pp_buy2, true, "opt_pp_buy2") ||
      !Opt_AddPattern(opt_pp_buy3, true, "opt_pp_buy3") ||
      !Opt_AddPattern(opt_pp_sell1, false, "opt_pp_sell1") ||
      !Opt_AddPattern(opt_pp_sell2, false, "opt_pp_sell2") ||
      !Opt_AddPattern(opt_pp_sell3, false, "opt_pp_sell3"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_41331_commodity-tsmom-12m-atr-opt\",\"parent\":\"QM5_12710\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "PP_CENSUS_SUMMARY",
               StringFormat("{\"profile_key\":\"%s\",\"enabled\":%s,\"days_evaluated\":%I64d,\"fire_count\":%I64d,\"legs_suppressed\":%I64d,\"invalid_days\":%I64d}",
                            QM_PP_ProfileKey(g_pp_profile), (g_pp_active ? "true" : "false"),
                            g_pp_days_evaluated, g_pp_fire_count, g_pp_legs_suppressed, g_pp_invalid_days));
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req) && Pattern_AllowsRequest(req))
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
