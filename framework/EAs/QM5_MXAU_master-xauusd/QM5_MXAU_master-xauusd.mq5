#property strict
#property version   "5.0"
#property description "QM5_MXAU XAUUSD symbol-master skeleton (ea_id 20001)"

#include <QM/QM_Common.mqh>
#include <QM/QM_StrategyModule.mqh>
#include <QM/modules/QM_Mod_Template.mqh>
#include <QM/modules/QM_Mod_CumRsi2Commodity.mqh>

// =============================================================================
// QuantMechanica V5 — XAUUSD symbol-master skeleton
// -----------------------------------------------------------------------------
// This host is a dispatcher and shared framework corset, not a strategy.  It
// never opens under host magic 200010000.  Phase-3 modules retain their
// original standalone identities and must enter through the explicit
// magic/risk arguments of QM_TM_OpenPosition.
// =============================================================================

#define QM_MASTER_MODULE_COUNT 5

const int    QM_MASTER_EA_ID                  = 20001;
const int    QM_MASTER_MAGIC_SLOT             = 0;
const double QM_MASTER_BOOTSTRAP_RISK_PERCENT = 1.0;
const string QM_MASTER_SYMBOL                 = "XAUUSD.DWX";

// Closed allowlist for the five XAU pilot sleeves.  These are identities only;
// no strategy signal, exit, or management logic is present in Phase 2.
const long QM_MASTER_ALLOWED_MAGICS[QM_MASTER_MODULE_COUNT] =
  {
   104030002L, // strategy1: QM5_10403, slot 2, D1
   105130003L, // strategy2: QM5_10513, slot 3, D1
   125670003L, // strategy3: QM5_12567, slot 3, D1
   129890003L, // strategy4: QM5_12989, slot 3, H4
   15560004L   // strategy5: QM5_1556,  slot 4, D1
  };

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20001;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy 1 — QM5_10403 et-turtle20x (D1)"
input bool   strategy1_enabled            = false;
input double strategy1_risk_percent       = 0.0;

input group "Strategy 2 — QM5_10513 mql5-ichimoku (D1)"
input bool   strategy2_enabled            = false;
input double strategy2_risk_percent       = 0.0;

input group "Strategy 3 — QM5_12567 cum-rsi2-commodity (D1)"
input bool        strategy3_enabled       = false;
// Phase-3 dual-mode: PERCENT/0.794 is the deployed live sub-sleeve risk;
// backtest regression sets FIXED/1000 via the regression set file.
input QM_RiskMode strategy3_risk_mode     = QM_RISK_MODE_PERCENT;
input double      strategy3_risk_value    = 0.794;

input group "Strategy 4 — QM5_12989 grimes-nested-pb-v2 (H4)"
input bool   strategy4_enabled            = false;
input double strategy4_risk_percent       = 0.0;

input group "Strategy 5 — QM5_1556 aa-zak-mom12 (D1)"
input bool   strategy5_enabled            = false;
input double strategy5_risk_percent       = 0.0;

// Phase-2 slot binding: it exposes input-backed module metadata while all
// inherited hooks remain no-ops.  Phase 3 replaces each instance with its real
// module class; the dispatcher and lifecycle below remain unchanged.
class CQMMasterSlotModule : public CQMStrategyModule
  {
private:
   bool            m_enabled;
   long            m_magic;
   ENUM_TIMEFRAMES m_tf;
   double          m_risk_percent;

public:
   void Configure(const bool enabled,
                  const long magic,
                  const ENUM_TIMEFRAMES tf,
                  const double risk_percent)
     {
      m_enabled = enabled;
      m_magic = magic;
      m_tf = tf;
      m_risk_percent = risk_percent;
     }

   virtual bool            Enabled()     const { return m_enabled; }
   virtual long            Magic()       const { return m_magic; }
   virtual ENUM_TIMEFRAMES TF()          const { return m_tf; }
   virtual double          RiskPercent() const { return m_risk_percent; }
  };

CQMMasterSlotModule    g_strategy1_module;
CQMMasterSlotModule    g_strategy2_module;
CQMModCumRsi2Commodity g_strategy3_module;
CQMMasterSlotModule    g_strategy4_module;
CQMMasterSlotModule    g_strategy5_module;

CQMStrategyModule *g_master_modules[QM_MASTER_MODULE_COUNT];
bool                g_master_module_initialized[QM_MASTER_MODULE_COUNT];
bool                g_master_framework_started = false;

struct QMMasterTickTfState
  {
   ENUM_TIMEFRAMES tf;
   bool            is_new_bar;
  };

QMMasterTickTfState g_master_tick_tf_state[QM_MASTER_MODULE_COUNT];
int                 g_master_tick_tf_count = 0;

void QM_MasterConfigureModules()
  {
   g_strategy1_module.Configure(strategy1_enabled, QM_MASTER_ALLOWED_MAGICS[0], PERIOD_D1, strategy1_risk_percent);
   g_strategy2_module.Configure(strategy2_enabled, QM_MASTER_ALLOWED_MAGICS[1], PERIOD_D1, strategy2_risk_percent);
   g_strategy3_module.Configure(strategy3_enabled, strategy3_risk_mode, strategy3_risk_value);
   g_strategy4_module.Configure(strategy4_enabled, QM_MASTER_ALLOWED_MAGICS[3], PERIOD_H4, strategy4_risk_percent);
   g_strategy5_module.Configure(strategy5_enabled, QM_MASTER_ALLOWED_MAGICS[4], PERIOD_D1, strategy5_risk_percent);

   g_master_modules[0] = GetPointer(g_strategy1_module);
   g_master_modules[1] = GetPointer(g_strategy2_module);
   g_master_modules[2] = GetPointer(g_strategy3_module);
   g_master_modules[3] = GetPointer(g_strategy4_module);
   g_master_modules[4] = GetPointer(g_strategy5_module);

   for(int i = 0; i < QM_MASTER_MODULE_COUNT; ++i)
      g_master_module_initialized[i] = false;
  }

void QM_MasterDeinitModules()
  {
   for(int i = QM_MASTER_MODULE_COUNT - 1; i >= 0; --i)
     {
      if(!g_master_module_initialized[i] || g_master_modules[i] == NULL)
         continue;
      g_master_modules[i].Deinit();
      g_master_module_initialized[i] = false;
     }
  }

bool QM_MasterInitModules()
  {
   for(int i = 0; i < QM_MASTER_MODULE_COUNT; ++i)
     {
      CQMStrategyModule *module = g_master_modules[i];
      if(module == NULL)
        {
         QM_LogEvent(QM_ERROR, "MASTER_MODULE_MISSING", StringFormat("{\"slot\":%d}", i + 1));
         return false;
        }
      if(!module.Enabled())
         continue;

      const long magic = module.Magic();
      const ENUM_TIMEFRAMES tf = module.TF();
      const QM_RiskMode risk_mode = module.RiskMode();
      const double risk_value = module.RiskValue();
      if(magic != QM_MASTER_ALLOWED_MAGICS[i])
        {
         QM_LogEvent(QM_ERROR, "MASTER_MODULE_MAGIC_NOT_ALLOWED",
                     StringFormat("{\"slot\":%d,\"magic\":%I64d,\"expected\":%I64d}",
                                  i + 1, magic, QM_MASTER_ALLOWED_MAGICS[i]));
         return false;
        }
      if(tf == PERIOD_CURRENT)
        {
         QM_LogEvent(QM_ERROR, "MASTER_MODULE_TF_CURRENT", StringFormat("{\"slot\":%d}", i + 1));
         return false;
        }
      if(risk_mode != QM_RISK_MODE_PERCENT && risk_mode != QM_RISK_MODE_FIXED)
        {
         QM_LogEvent(QM_ERROR, "MASTER_MODULE_RISK_MODE_INVALID",
                     StringFormat("{\"slot\":%d,\"risk_mode\":%d}", i + 1, (int)risk_mode));
         return false;
        }
      if(risk_value <= 0.0)
        {
         QM_LogEvent(QM_ERROR, "MASTER_MODULE_RISK_NOT_POSITIVE",
                     StringFormat("{\"slot\":%d,\"risk_value\":%.8f}", i + 1, risk_value));
         return false;
        }
      if(!module.Init(_Symbol))
        {
         QM_LogEvent(QM_ERROR, "MASTER_MODULE_INIT_FAILED", StringFormat("{\"slot\":%d}", i + 1));
         return false;
        }
      g_master_module_initialized[i] = true;

      // Resolve through the registry-backed Phase-1 API.  This both records
      // framework/q08 ownership and registers the foreign magic with KS.
      const int sub_ea_id = (int)(magic / 10000L);
      const int sub_slot = (int)(magic % 10000L);
      const int registered_magic = QM_MagicFor(sub_ea_id, sub_slot);
      if(registered_magic <= 0 || (long)registered_magic != magic || !QM_KillSwitchOwnsMagic(magic))
        {
         QM_LogEvent(QM_ERROR, "MASTER_MODULE_MAGIC_REGISTRATION_FAILED",
                     StringFormat("{\"slot\":%d,\"ea_id\":%d,\"sub_slot\":%d,\"magic\":%I64d}",
                                  i + 1, sub_ea_id, sub_slot, magic));
         return false;
        }

      QM_LogEvent(QM_INFO, "MASTER_MODULE_INIT_OK",
                  StringFormat("{\"slot\":%d,\"magic\":%I64d,\"tf\":%d,\"risk_mode\":%d,\"risk_value\":%.8f}",
                               i + 1, magic, (int)tf, (int)risk_mode, risk_value));
     }
   return true;
  }

bool QM_MasterNewsAllowsEntries(const datetime now)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol, now, qm_news_temporal, qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, now, qm_news_mode_legacy);
  }

bool QM_MasterModuleTfNewBar(const ENUM_TIMEFRAMES tf)
  {
   for(int i = 0; i < g_master_tick_tf_count; ++i)
      if(g_master_tick_tf_state[i].tf == tf)
         return g_master_tick_tf_state[i].is_new_bar;

   if(g_master_tick_tf_count >= QM_MASTER_MODULE_COUNT)
      return false;

   const bool is_new_bar = QM_IsNewBar(_Symbol, tf);
   g_master_tick_tf_state[g_master_tick_tf_count].tf = tf;
   g_master_tick_tf_state[g_master_tick_tf_count].is_new_bar = is_new_bar;
   ++g_master_tick_tf_count;
   return is_new_bar;
  }

int OnInit()
  {
   if(_Symbol != QM_MASTER_SYMBOL)
     {
      PrintFormat("MASTER_SYMBOL_MISMATCH: symbol=%s expected_symbol=%s", _Symbol, QM_MASTER_SYMBOL);
      return INIT_FAILED;
     }
   if(qm_ea_id != QM_MASTER_EA_ID || qm_magic_slot_offset != QM_MASTER_MAGIC_SLOT)
     {
      PrintFormat("MASTER_IDENTITY_MISMATCH: ea_id=%d slot=%d expected_ea_id=%d expected_slot=%d",
                  qm_ea_id, qm_magic_slot_offset, QM_MASTER_EA_ID, QM_MASTER_MAGIC_SLOT);
      return INIT_FAILED;
     }

   QM_MasterConfigureModules();

   // The host risk exists only because the shared risk sizer must be configured
   // before explicit per-module sizing can run.  No host entry path exists.
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        QM_MASTER_BOOTSTRAP_RISK_PERCENT,
                        0.0,
                        1.0,
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

   g_master_framework_started = true;
   if(!QM_MasterInitModules())
     {
      QM_MasterDeinitModules();
      QM_FrameworkShutdown();
      g_master_framework_started = false;
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO, "MASTER_INIT_OK",
               StringFormat("{\"host_magic\":%d,\"active_modules\":%d}",
                            QM_FrameworkMagic(), QM_FrameworkMagicContextCount()));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(!g_master_framework_started)
      return;
   QM_LogEvent(QM_INFO, "MASTER_DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_MasterDeinitModules();
   QM_FrameworkShutdown();
   g_master_framework_started = false;
  }

void OnTick()
  {
   const datetime now = TimeCurrent();
   bool entries_blocked = false;

   // Shared symbol corset: exactly once and in the required order.
   if(!QM_KillSwitchCheck())
      entries_blocked = true;
   if(!QM_MasterNewsAllowsEntries(now))
      entries_blocked = true;
   if(QM_FrameworkHandleFridayClose())
      entries_blocked = true;

   // Cache NewBar once per distinct module TF for this tick.  All modules on
   // the same TF see the same latched result; chart TF is never consulted.
   g_master_tick_tf_count = 0;

   for(int i = 0; i < QM_MASTER_MODULE_COUNT; ++i)
     {
      CQMStrategyModule *module = g_master_modules[i];
      if(module == NULL || !module.Enabled())
         continue;

      // Management and exits always run, including during corset blocks.
      module.ManageOpen();
      module.CheckExit();

      // Consume the module-TF transition even while entries are blocked.  If
      // the corset clears later in the same bar, that must not become a late
      // entry masquerading as a new-bar event.
      const bool module_new_bar = QM_MasterModuleTfNewBar(module.TF());
      if(entries_blocked)
         continue;
      if(!module_new_bar)
         continue;
      if(module.NoTrade(now))
         continue;
      module.CheckEntry();
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
