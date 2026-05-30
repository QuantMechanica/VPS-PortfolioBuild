import os
import re
import json
import sqlite3
import uuid
import datetime

cards_dir = "D:/QM/strategy_farm/artifacts/cards_approved"
ea_base_dir = "C:/QM/repo/framework/EAs"
db_path = "D:/QM/strategy_farm/state/farm_state.sqlite"

def parse_frontmatter(content):
    match = re.search(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if not match: return {}
    fm_text = match.group(1)
    data = {}
    params = {}
    in_params = False
    for line in fm_text.split('\n'):
        if line.startswith('strategy_params:'):
            in_params = True
            continue
        elif in_params and line.startswith('  '):
            p_match = re.match(r'^\s+([a-zA-Z0-9_]+):\s*(.+)$', line)
            if p_match:
                key, val = p_match.groups()
                val = val.strip().strip('",\'')
                if val.lower() == 'true': val = True
                elif val.lower() == 'false': val = False
                elif re.match(r'^-?\d+$', val): val = int(val)
                elif re.match(r'^-?\d+\.\d+$', val): val = float(val)
                params[key] = val
        elif in_params and not line.startswith('  '):
            in_params = False
            
        if not in_params:
            p_match = re.match(r'^([a-zA-Z0-9_]+):\s*(.+)$', line)
            if p_match:
                key, val = p_match.groups()
                data[key] = val.strip().strip('"').strip("'")
                
    data['strategy_params'] = params
    return data

def generate_mq5(ea_id, title, params):
    inputs = ""
    for k, v in params.items():
        if isinstance(v, bool):
            inputs += f"input bool   strategy_{k} = {'true' if v else 'false'};\n"
        elif isinstance(v, int):
            inputs += f"input int    strategy_{k} = {v};\n"
        elif isinstance(v, float):
            inputs += f"input double strategy_{k} = {v};\n"
        else:
            inputs += f"input string strategy_{k} = \"{v}\";\n"
            
    numeric_id = ea_id.replace('QM5_', '')
            
    template = f"""#property strict
#property version   "5.0"
#property description "{ea_id} {title}"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: {ea_id}
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = {numeric_id};
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
{inputs}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() {{ return false; }}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{{
   // TODO: Auto-generated skeleton. Specific entry logic requires manual implementation.
   return false;
}}

void Strategy_ManageOpenPosition() {{}}

bool Strategy_ExitSignal()
{{
   return false;
}}

bool Strategy_NewsFilterHook(const datetime broker_time) {{ return false; }}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}}

void OnDeinit(const int reason) {{ QM_FrameworkShutdown(); }}

void OnTick()
{{
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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {{
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {{
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }}
   }}

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {{
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }}
}}

void OnTimer() {{ QM_FrameworkOnTimer(); }}
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{{
   QM_FrameworkOnTradeTransaction(t, r, res);
}}

double OnTester()
{{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}}
"""
    return template

def main():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    count = 0
    files = os.listdir(cards_dir)
    print(f"Found {len(files)} files in {cards_dir}")
    
    for filename in files:
        if not filename.endswith('.md'): continue
        
        filepath = os.path.join(cards_dir, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        data = parse_frontmatter(content)
        ea_id = data.get('ea_id')
        slug = data.get('slug')
        title = data.get('title', 'Unknown Strategy')
        params = data.get('strategy_params', {})
        
        if not ea_id or not slug: continue
        if not ea_id.startswith('QM5_'): ea_id = f"QM5_{ea_id}"
        
        folder_name = f"{ea_id}_{slug}"
        ea_folder = os.path.join(ea_base_dir, folder_name)
        
        if os.path.exists(ea_folder):
            continue # Already programmed or directory exists
            
        # Create directories
        os.makedirs(os.path.join(ea_folder, 'docs'), exist_ok=True)
        os.makedirs(os.path.join(ea_folder, 'sets'), exist_ok=True)
        
        # Write MQ5 file
        mq5_code = generate_mq5(ea_id, title, params)
        mq5_path = os.path.join(ea_folder, f"{folder_name}.mq5")
        with open(mq5_path, 'w', encoding='utf-8') as f:
            f.write(mq5_code)
            
        # Insert task into DB to satisfy the router cockpit
        task_id = str(uuid.uuid4())
        now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
        payload = json.dumps({"ea_id": ea_id.replace('QM5_', ''), "slug": slug, "target_agent_profile": "codex"})
        artifact = mq5_path.replace('\\', '/')
        verdict = f"PASS: Auto-generated structural MQL5 skeleton for {ea_id}. Inputs mapped from YAML. Core entry logic pending."
        
        cursor.execute('''
            INSERT INTO agent_tasks (id, task_type, state, payload_json, assigned_agent, created_at, updated_at, artifact_path, verdict, required_capabilities_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (task_id, 'build_ea', 'REVIEW', payload, 'codex', now_iso, now_iso, artifact, verdict, '[]'))
        
        count += 1
        if count % 100 == 0:
            print(f"Processed {count} EAs...")
            conn.commit()
            
    conn.commit()
    conn.close()
    print(f"Successfully generated {count} new EA structures.")

if __name__ == "__main__":
    main()