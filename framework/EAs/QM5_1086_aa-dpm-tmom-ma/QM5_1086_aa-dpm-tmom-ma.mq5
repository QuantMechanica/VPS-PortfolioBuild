#property strict
#property version   "5.0"
#property description "QM5_1086 Alpha Architect Downside Protection TMOM/MA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1086;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_months       = 12;
input double strategy_cash_return_12m_pct   = 0.0;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 4.0;
input int    strategy_max_spread_points     = 5000;

#define QM5_1086_SYMBOL_COUNT 13

string Strategy_SymbolForSlot(const int slot)
  {
   if(slot == 0) return "SP500.DWX";
   if(slot == 1) return "NDX.DWX";
   if(slot == 2) return "WS30.DWX";
   if(slot == 3) return "GDAXI.DWX";
   if(slot == 4) return "XAUUSD.DWX";
   if(slot == 5) return "XTIUSD.DWX";
   if(slot == 6) return "EURUSD.DWX";
   if(slot == 7) return "GBPUSD.DWX";
   if(slot == 8) return "USDJPY.DWX";
   if(slot == 9) return "AUDUSD.DWX";
   if(slot == 10) return "USDCAD.DWX";
   if(slot == 11) return "USDCHF.DWX";
   if(slot == 12) return "NZDUSD.DWX";
   return "";
  }

bool Strategy_SymbolSlotAllowed()
  {
   return (_Symbol == Strategy_SymbolForSlot(qm_magic_slot_offset));
  }

bool Strategy_IsMonthRolloverBar()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);   // perf-allowed: month boundary detection only
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);  // perf-allowed: month boundary detection only
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon);
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

double Strategy_TargetExposure()
  {
   if(strategy_lookback_months <= 0)
      return 0.0;

   const int recent_shift = 1;
   const int lookback_shift = recent_shift + strategy_lookback_months;
   const double recent_close = QM_SMA(_Symbol, PERIOD_MN1, 1, recent_shift, PRICE_CLOSE);
   const double lookback_close = QM_SMA(_Symbol, PERIOD_MN1, 1, lookback_shift, PRICE_CLOSE);
   const double ma_12m = QM_SMA(_Symbol, PERIOD_MN1, strategy_lookback_months, recent_shift, PRICE_CLOSE);
   if(recent_close <= 0.0 || lookback_close <= 0.0 || ma_12m <= 0.0)
      return 0.0;

   const double total_return_pct = 100.0 * ((recent_close / lookback_close) - 1.0);
   const bool tmom_positive = (total_return_pct > strategy_cash_return_12m_pct);
   const bool ma_positive = (recent_close > ma_12m);

   if(tmom_positive && ma_positive)
      return 1.0;
   if(tmom_positive || ma_positive)
      return 0.5;
   return 0.0;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points <= 0)
      return true;
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_ConfigureRiskForExposure(const double exposure)
  {
   const double weight = PORTFOLIO_WEIGHT * exposure;
   if(weight <= 0.0 || weight > 1.0)
      return false;

   QM_RiskMode mode = QM_RISK_MODE_PERCENT;
   if(RISK_FIXED > 0.0)
      mode = QM_RISK_MODE_FIXED;
   const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
   return QM_RiskSizerConfigure(mode, RISK_PERCENT, RISK_FIXED, weight, risk_cap_money);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(!Strategy_SymbolSlotAllowed())
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthRolloverBar())
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const double target_exposure = Strategy_TargetExposure();
   if(target_exposure <= 0.0)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_ConfigureRiskForExposure(target_exposure))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.reason = (target_exposure >= 1.0) ? "DPM_TMOM_MA_FULL" : "DPM_TMOM_MA_HALF";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Signal-only monthly rebalance. No trailing stop, break-even, or partials.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_HasOpenPosition())
      return false;
   if(!QM_IsNewBar(_Symbol, PERIOD_MN1))
      return false;

   return true;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1086\",\"ea\":\"aa-dpm-tmom-ma\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
