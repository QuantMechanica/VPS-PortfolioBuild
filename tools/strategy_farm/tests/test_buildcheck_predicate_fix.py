from pathlib import Path
import json
import subprocess
import sys
import pytest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/strategy_farm'))
import build_gate_hardening as gate
from bounded_arrays import Proof


def findings(code):
    return gate.check_indicator_buffer_bounds(gate.SourceFile(Path('test.mq5'),code,
                                     gate.strip_comments_preserve_lines(code)))


@pytest.mark.parametrize('code',[
    'double F(int i,bool b){double a[];ArrayResize(a,4);if(i<0 || i>=ArraySize(a) && b)return 0;return a[i];}',
    'double F(int i,bool b){double a[];ArrayResize(a,4);if(b){if(i<0||i>=ArraySize(a))return 0;}return a[i];}',
    'double F(int i){double a[];ArrayResize(a,4);if(i<0||i>=ArraySize(a))return 0;i=5;return a[i];}',
    'double F(int i){double a[];ArrayResize(a,4);if(i<0||i>=ArraySize(a))return 0;ArrayResize(a,1);return a[i];}',
    'double F(){double a[];if(ArrayResize(a,4)!=4)return 0;return a[4];}',
    'double F(){double a[];if(ArrayResize(a,4)!=4)return 0;for(int i=0;i<4;++i){a[i+1]=0;}return 0;}',
    'double F(int i){double a[];if(ArrayResize(a,4)!=4)return 0;return a[i*2];}',
    'double F(){double a[];if(ArrayResize(a,4)!=4)return 0;int k=0;while(k<4){while(true){a[k]=0;++k;}}return 0;}',
    'double F(){double a[];if(ArrayResize(a,4)!=4)return 0;int k=0;while(k<4){++k;a[k]=0;}return 0;}',
    'double F(int i){double a[];if(ArrayResize(a,4)!=4)return 0;if(i<0||i>=4)return 0;Mutate(i);return a[i];}',
    'double F(){double a[];ArrayResize(a,4);for(int i=-1;i<4;++i){a[i]=0;}return 0;}',
    'double F(){double a[];ArrayResize(a,4);for(int i=0;i<4;--i){a[i]=0;}return 0;}',
    'double F(){double a[];ArrayResize(a,4);for(int i=0;i<4;++i){i=7;a[i]=0;}return 0;}',
])
def test_unsafe_or_nondominating_bounds_still_fail(code):
    assert findings('// qm-build-generation: bounded-arrays-v2\n' + code)


def test_bounded_nested_counter_requires_inner_exit():
    code='double F(){double a[];if(ArrayResize(a,4)!=4)return 0;int k=0;while(k<4){while(true){a[k]=0;++k;break;}}return 0;}'
    assert not findings(code)


def test_genuinely_unbounded_growth_is_not_proven_safe():
    code='// qm-build-generation: bounded-arrays-v2\ndouble F(){double a[];int count=0;while(true){++count;if(ArrayResize(a,count)!=count)return 0;a[count-1]=0;}return 0;}'
    assert findings(code)


def test_default_rollout_is_monotone_against_legacy_findings():
    samples = [
        'double F(int i){double a[];ArrayResize(a,4);return a[i+1];}',
        'double F(){double a[];ArrayResize(a,4);for(int i=-1;i<4;++i)a[i]=0;return 0;}',
        'double F(){double a[];ArrayResize(a,4);for(int i=0;i<4;--i)a[i]=0;return 0;}',
        'double F(int h){double a[];int n=CopyBuffer(h,0,0,4,a);return a[2];}',
    ]
    for code in samples:
        source = gate.SourceFile(
            Path('test.mq5'), code, gate.strip_comments_preserve_lines(code)
        )
        before = set(gate._check_indicator_buffer_bounds_legacy(source))
        after = set(gate.check_indicator_buffer_bounds(source))
        assert after <= before


def test_parser_no_scalar_default_assumption():
    body='int n=4; if(flag){n=10;} double a[]; if(ArrayResize(a,4)!=4)return 0; return a[n-1];'
    assert not Proof(body).bounded('a','n-1',body.index('a[n-1]'))


def test_nested_index_keeps_balanced_expression():
    assert gate.array_accesses('a[counts[bucket[i]]-1]', 'a')[0].index == 'counts[bucket[i]]-1'


def test_power_shell_ml_scoping_with_real_frozen_and_negative_inputs(tmp_path):
    ea_root=tmp_path/'framework/EAs';ea_root.mkdir(parents=True)
    include_root=tmp_path/'framework/include';include_root.mkdir(parents=True)
    symbol_tool=tmp_path/'tools/strategy_farm/ea_symbol_literal_inventory.py';symbol_tool.parent.mkdir(parents=True)
    symbol_tool.write_text(
      'import json\nprint(json.dumps({"summary":{"symbol_literal_sources":0,"symbol_literal_occurrences":0,"non_chart_market_data_sources":0},"findings":[]}))\n',
      encoding='utf-8')
    sources={
      'coefficients.mq5':'void F(){double weights[4];weights[0]=1;for(int k=1;k<4;++k)weights[k]=-weights[k-1]*(.3-k+1)/k;}',
      'comment.mq5':'// tensorflow weights[i]+=learning_rate*error;\nvoid F(){Print("weights[i]+=learning_rate*error;");}',
      'include.mq5':'#include <ML/NeuralNetwork.mqh>\nvoid F(){}',
      'root_include.mq5':'#include <ML.mqh>\nvoid F(){}',
      'online.mq5':'void OnTick(){weights[i] +=\n learning_rate * (target-prediction);}',
      'onnx.mq5':'void F(){OnnxRun(handle,0,features);}',
    }
    for name,code in sources.items():(ea_root/name).write_text(code,encoding='utf-8')
    source=(ROOT/'framework/scripts/build_check.ps1').read_text(encoding='utf-8-sig')
    function=source[source.index('function Invoke-ForbiddenScan {'):source.index('function Invoke-InputGroupCheck {')]
    harness=tmp_path/'scan.ps1'
    harness.write_text("$ErrorActionPreference='Stop'\n$EALabel=$null\n$script:found=New-Object 'System.Collections.Generic.List[string]'\nfunction Add-Failure {param([string]$Message) $script:found.Add($Message)}\nfunction Add-Warning {param([string]$Message)}\n"+function+"\nInvoke-ForbiddenScan -ResolvedRepoRoot '"+str(tmp_path).replace("'","''")+"'\nConvertTo-Json -InputObject @($script:found) -Compress\n",encoding='utf-8')
    run=subprocess.run(['powershell','-NoProfile','-NonInteractive','-File',str(harness)],capture_output=True,text=True)
    assert run.returncode==0,run.stderr
    result=json.loads(run.stdout.splitlines()[-1])
    # Invoke-ForbiddenScan now also hosts the EA_SYMBOL_HARDCODED and EA_LIVE_NEWS_ARCHIVE_DEPENDENCY
    # scanners (OWNER 2026-09-06); the fixture repo carries neither tool, so those report
    # *_SCANNER_MISSING. This test is about ML scoping: count only the ML findings.
    result=[x for x in result if 'EA_ML_FORBIDDEN' in x]
    assert len(result)==4,result
    assert all('EA_ML_FORBIDDEN' in x for x in result)
    assert not any('coefficients.mq5' in x or 'comment.mq5' in x for x in result)
