"""Generate an isolated review copy; never edits, compiles or stages an EA."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
PARENT=ROOT/'framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def generate(source):
    prefix=source[:source.index('int OnInit()')]
    result=source.replace('int OnInit()','''#include "execution_binding.mqh"
#include "QM11421_CanaryLifecycle.mqh"
int OnInit()''',1)
    old='   if(!QM_FrameworkInit(qm_ea_id,'
    new='''   QM_RuntimeExecutionContract contract;long generation=0;
   if(!QM11421_BoundContract(contract,generation) ||
      contract.target!="FTMO" || !contract.governor_required ||
      !contract.account_stop_risk_reservation_required)
      return INIT_FAILED;
   if(!QM_FrameworkInitV3(contract,generation,qm_ea_id,'''
    assert old in result;result=result.replace(old,new,1)
    start=result.index('   if(!QM_FrameworkDeclareExecutionContract(')
    end=result.index('   // Full optimization/tester bypass:',start)
    result=result[:start]+result[end:]
    result=result.replace('   QM_LogEvent(QM_INFO, "INIT_OK", "{}");','''   if(!EventSetMillisecondTimer(200)) return INIT_FAILED;
   g_qm_fw_timer_active=true;
   QM11421_CanaryBoundary();
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");''',1)
    result=result.replace('   if(!QM_KillSwitchCheck())\n      return;','   if(!QM11421_CanaryBoundary())\n      return;',1)
    result=result.replace('void OnTimer()\n  {','void OnTimer()\n  {\n   QM11421_CanaryBoundary();',1)
    # A later presentation retry must never downgrade the safety timer to 5s.
    result=result.replace('if(EventSetTimer(5))','if(EventSetMillisecondTimer(200))')
    assert result[:result.index('#include "execution_binding.mqh"')]==prefix
    return result
def closure(path,seen=None):
    seen={} if seen is None else seen
    path=path.resolve()
    if str(path) in seen:return seen
    seen[str(path)]=sha(path)
    for bracket,name in re.findall(r'#include\s*([<"])([^>"\n]+)[>"]',path.read_text(encoding='utf-8-sig')):
        p=ROOT/'framework/include'/name if bracket=='<' else path.parent/name
        if p.exists():closure(p,seen)
        else:seen[str(p)]='MISSING_PLATFORM_OR_EXTERNAL'
    return seen
def main():
    source=PARENT.read_text(encoding='utf-8-sig');p=OUT/'QM5_11421_execution_canary_review.mq5'
    p.write_text(generate(source),encoding='utf-8',newline='\n')
    r={'schema':'qm.ftmo-execution-canary-review/v1','task_id':'b7858771-ecdc-4bb5-9d2f-d428a12bc661','parent_source':str(PARENT),'parent_source_sha256':sha(PARENT),'parent_binary_sha256':sha(PARENT.with_suffix('.ex5')),'canary_source':str(p),'canary_source_sha256':sha(p),'canary_binary':None,'native_status':'NOT_RUN_BINDING_AND_ISOLATED_ACCOUNT_DRIVER_REQUIRED','strategy_prefix_unchanged':True,'include_closure':closure(p),'changed_economic_behavior':['V3 governor entry lock and risk scaling','shared stop-risk reservation required','timer cleanup at governor/news/session/quote failure','confirmed deletion/closure and retry before rearming'],'qualification_required':'fresh current-contract Q02 onward under active gate manifest; M01-M12 native account chain separately; no inherited PASS'}
    base=PARENT.parent/'sets'/f'{PARENT.stem}_EURUSD.DWX_D1_backtest.set'
    raw=base.read_bytes();settings=raw.decode('utf-16' if raw[:2]==b'\xff\xfe' else 'utf-8-sig')
    for key,value in {'RISK_FIXED':'1000','RISK_PERCENT':'0','qm_news_compliance':'2','qm_news_temporal':'3','qm_news_stale_max_hours':'336'}.items():
        settings,n=re.subn(rf'(?m)^{key}=.*$',f'{key}={value}',settings)
        assert n<=1,key
        if n==0:settings=settings.rstrip()+f'\n{key}={value}\n'
    candidate_set=OUT/'canary_FIXED_RISK_NOT_RUN.set';candidate_set.write_text(settings,encoding='utf-8',newline='\n')
    r.update(parent_setfile=str(base),parent_setfile_sha256=sha(base),canary_setfile=str(candidate_set),canary_setfile_sha256=sha(candidate_set),setfile_status='FIXED_RISK_STATIC_REVIEW_ONLY_RESERVATION_INIT_INTENTIONALLY_REJECTS_TESTER')
    (OUT/'manifest.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in r.items() if k!='include_closure'}))
if __name__=='__main__':main()
