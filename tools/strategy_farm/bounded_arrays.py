"""Conservative local integer-interval proofs for MQL numeric-array accesses.

No EA names or source hashes occur here. Unknown expressions/effects yield no
proof. This supplements the existing structural CopyBuffer/loop checks.
"""
from __future__ import annotations
import ast
from functools import lru_cache
from dataclasses import dataclass
import re

VAR = r'[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*'
PURE = {'ArraySize','ArrayResize','ArraySort','ArraySetAsSeries','MathIsValidNumber',
        'MathAbs','MathMin','MathMax','StringFormat','Print','PrintFormat'}


def end_delimiter(text, opening, left='(', right=')'):
    depth = 0
    for pos in range(opening, len(text)):
        if text[pos] == left: depth += 1
        elif text[pos] == right:
            depth -= 1
            if depth == 0: return pos
    return None


def compact(text):
    return re.sub(r'\s+', '', text)


def unwrap(text):
    text = text.strip()
    while text.startswith('(') and end_delimiter(text, 0) == len(text)-1:
        text = text[1:-1].strip()
    return text


def split_boolean(text, token):
    text = unwrap(text)
    depth = 0; start = 0; parts = []; i = 0
    while i < len(text):
        char = text[i]
        if char == '(': depth += 1
        elif char == ')': depth -= 1
        if depth == 0 and text.startswith(token, i):
            parts.append(text[start:i]); start = i + len(token); i += len(token); continue
        i += 1
    parts.append(text[start:])
    return parts


@dataclass
class Control:
    kind: str
    start: int
    condition: str
    condition_end: int
    body_start: int
    body_end: int
    end: int


class Proof:
    def __init__(self, body):
        self.body = body
        self.controls = []
        for match in re.finditer(r'\b(if|for|while)\s*\(', body):
            opening = body.find('(', match.start())
            close = end_delimiter(body, opening)
            if close is None: continue
            start = close + 1
            while start < len(body) and body[start].isspace(): start += 1
            if start < len(body) and body[start] == '{':
                finish = end_delimiter(body,start,'{','}')
                if finish is None: continue
                bstart, bend, end = start+1, finish, finish+1
            else:
                finish = body.find(';',start)
                if finish < 0: continue
                bstart, bend, end = start, finish+1, finish+1
            self.controls.append(Control(match[1],match.start(),body[opening+1:close],close,bstart,bend,end))

    def contains(self, control, pos):
        return control.body_start <= pos < control.body_end

    def dominates(self, start, end, pos):
        return end <= pos and all(not self.contains(c,start) or self.contains(c,pos) for c in self.controls)

    def changed(self, name, start, end, *, ignore_steps=False):
        text = self.body[start:end]
        escaped = re.escape(name)
        patterns = [rf'(?<![\w.]){escaped}\s*(?:=(?!=)|[+*/%-]=)']
        if not ignore_steps:
            patterns += [rf'(?:\+\+|--)\s*{escaped}\b', rf'\b{escaped}\s*(?:\+\+|--)']
        if any(re.search(p,text) for p in patterns): return True
        for match in re.finditer(r'\b([A-Za-z_]\w*)\s*\(',text):
            name_of_call = match[1]
            opening = text.find('(',match.start()); close=end_delimiter(text,opening)
            if name_of_call in {'ArrayResize','ArrayFree','ArrayCopy','ZeroMemory'} and close is not None:
                first=text[opening+1:close].split(',')[0].strip()
                if first==name or (name.startswith(first+'.') and first):return True
            if name_of_call in PURE or name_of_call in {'if','while','for'}: continue
            if close is not None and re.search(rf'(?<![\w.]){escaped}(?![\w.])',text[opening+1:close]):
                return True
        return False

    def guards(self, pos):
        for c in self.controls:
            opening=self.body.find('(',c.start,c.condition_end)
            if opening < pos < c.condition_end:
                prefix=self.body[opening+1:pos]
                stack=[]
                for i,char in enumerate(prefix):
                    if char=='(':stack.append(i+1)
                    elif char==')' and stack:stack.pop()
                for start in [0,*stack]:
                    local=prefix[start:]
                    if len(split_boolean(local,'||'))==1:
                        for part in split_boolean(local,'&&')[:-1]:
                            yield unwrap(part),True,opening+1+start
            if c.kind == 'if' and self.dominates(c.start,c.end,pos):
                # A true failure arm must exit the function. An unrelated
                # nested guard or conditional break is not a dominating fact.
                arm = self.body[c.body_start:c.body_end].strip()
                if re.fullmatch(r'return\b[^;]*;\s*',arm,re.S):
                    for part in split_boolean(c.condition,'||'):
                        if len(split_boolean(part,'&&')) == 1:
                            yield unwrap(part), False, c.end
            if self.contains(c,pos):
                condition = c.condition.split(';')[1] if c.kind == 'for' and c.condition.count(';')==2 else c.condition
                for part in split_boolean(condition,'&&'):
                    if len(split_boolean(part,'||'))==1:
                        variable=re.match(rf'\s*({VAR})\s*(?:<=|>=|<|>)',unwrap(part))
                        if variable:
                            name=variable[1]
                            # The loop condition is refreshed before every
                            # iteration.  A secondary counter may therefore be
                            # used before its first write in the current body;
                            # a write before the access invalidates the fact.
                            if c.kind=='for' and self.changed(name,c.body_start,pos):continue
                            stable=True
                            for inner in self.controls:
                                if inner.kind not in ('for','while') or inner.start<=c.start or not self.contains(inner,pos):continue
                                if not self.changed(name,inner.body_start,inner.body_end):continue
                                # An outer while condition is not rechecked by
                                # an inner loop. A changed counter must exit the
                                # inner loop unconditionally before iterating.
                                writes=list(re.finditer(rf'(?:\+\+|--)\s*{re.escape(name)}\b|\b{re.escape(name)}\s*(?:\+\+|--)',self.body[pos:inner.body_end]))
                                if len(writes)!=1:stable=False;break
                                tail=self.body[pos+writes[0].end():inner.body_end]
                                if not re.fullmatch(r'\s*;(?:\s*(?:\+\+\w+|\w+\+\+|[\w.]+\s*=\s*\w+)\s*;)*\s*break\s*;\s*',tail):stable=False;break
                            if not stable:continue
                        yield unwrap(part), True, c.body_start

    def interval(self, expression, pos, seen=()):
        expression = unwrap(expression)
        if len(seen)>14: return None
        # The union of the two branches is safe without assuming its predicate.
        ternary = re.fullmatch(r'.*\?\s*([^?:]+)\s*:\s*([^?:]+)',expression,re.S)
        if ternary:
            a,b=(self.interval(ternary[i],pos,seen) for i in (1,2))
            return (min(a[0],b[0]),max(a[1],b[1])) if a and b else None
        expression = re.sub(r'\((?:int|long|uint|short)\)', '', expression)
        try: node=ast.parse(expression,mode='eval').body
        except (ValueError,SyntaxError): return None
        def walk(n):
            if isinstance(n,ast.Constant) and type(n.value) is int: return n.value,n.value
            if isinstance(n,(ast.Name,ast.Attribute)):
                name=ast.unparse(n)
                return self.variable(name,pos,seen) if name not in seen else None
            if isinstance(n,ast.UnaryOp) and isinstance(n.op,(ast.USub,ast.UAdd)):
                v=walk(n.operand)
                return (-v[1],-v[0]) if v and isinstance(n.op,ast.USub) else v
            if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='ArraySize' and len(n.args)==1:
                return self.capacity(ast.unparse(n.args[0]),pos,seen)
            if isinstance(n,ast.BinOp):
                a,b=walk(n.left),walk(n.right)
                if a is None or b is None:return None
                if isinstance(n.op,ast.Add):return a[0]+b[0],a[1]+b[1]
                if isinstance(n.op,ast.Sub):return a[0]-b[1],a[1]-b[0]
                if isinstance(n.op,ast.Mult):
                    values=[x*y for x in a for y in b];return min(values),max(values)
                if isinstance(n.op,(ast.Div,ast.FloorDiv)) and a[0]>=0 and b[0]>0:
                    return a[0]//b[1],a[1]//b[0]
            return None
        value=walk(node)
        return value if value and max(abs(x) for x in value)<2**31 else None

    def variable(self,name,pos,seen):
        seen=(*seen,name); low=None; high=None
        assignments=list(re.finditer(rf'(?<![\w.]){re.escape(name)}\s*=(?!=)\s*([^;]+);',self.body[:pos]))
        assignment=next((a for a in reversed(assignments) if self.dominates(a.start(),a.end(),pos)),None)
        if assignment:
            value=self.interval(assignment[1],assignment.start(),seen)
            if value and not self.changed(name,assignment.end(),pos):low,high=value
            elif value and not self.changed(name,assignment.end(),pos,ignore_steps=True):
                tail=self.body[assignment.end():pos]
                up=bool(re.search(rf'(?:\+\+\s*{re.escape(name)}\b|\b{re.escape(name)}\s*\+\+)',tail))
                down=bool(re.search(rf'(?:--\s*{re.escape(name)}\b|\b{re.escape(name)}\s*--)',tail))
                if not down:low=value[0]
                if not up:high=value[1]
            for c in self.controls:
                if c.kind not in ('for','while') or not self.contains(c,pos) or assignment.end()>c.start:continue
                if not self.changed(name,c.body_start,c.body_end):continue
                if self.changed(name,c.body_start,c.body_end,ignore_steps=True):
                    low=high=None;continue
                text=self.body[c.body_start:c.body_end]
                if re.search(rf'(?:\+\+\s*{re.escape(name)}\b|\b{re.escape(name)}\s*\+\+)',text):high=None
                if re.search(rf'(?:--\s*{re.escape(name)}\b|\b{re.escape(name)}\s*--)',text):low=None
        for c in self.controls:
            if c.kind=='for' and self.contains(c,pos) and c.condition.count(';')==2:
                init,condition,step=c.condition.split(';')
                m=re.fullmatch(rf'\s*(?:int\s+)?{re.escape(name)}\s*=\s*(.+)',init,re.S)
                if m and compact(step) in ('++'+name,name+'++') and not self.changed(name,c.body_start,pos):
                    value=self.interval(m[1],c.start,seen)
                    if value:low=value[0] if low is None else max(low,value[0])
            # A unit-step descending cursor cannot finish below -1 when
            # guarded by >=0. This also applies to cursor+1 after insertion.
            if c.kind=='while' and c.end<=pos and self.dominates(c.start,c.end,pos):
                cond=compact(c.condition)
                arm=self.body[c.body_start:c.body_end]
                decrement=rf'(?:--\s*{re.escape(name)}\b|\b{re.escape(name)}\s*--)'
                if cond.startswith(name+'>=0') and len(re.findall(decrement,arm))==1:
                    if not self.changed(name,c.body_start,c.body_end,ignore_steps=True) and not self.changed(name,c.end,pos):
                        low=-1 if low is None else max(low,-1)
        for condition,truth,origin in self.guards(pos):
            m=re.fullmatch(rf'\s*({VAR})\s*(==|!=|<=|>=|<|>)\s*(.+)',condition,re.S)
            if not m or m[1]!=name or self.changed(name,origin,pos):continue
            value=self.interval(m[3],origin,seen)
            if not value:continue
            op=m[2]
            if not truth:op={'!=':'==','==':'!=','<':'>=','>':'<=','<=':'>','>=':'<'}[op]
            if op in ('==','>=','>'):
                candidate=value[0]+(op=='>');low=candidate if low is None else max(low,candidate)
            if op in ('==','<=','<'):
                candidate=value[1]-(op=='<');high=candidate if high is None else min(high,candidate)
        return (low,high) if low is not None and high is not None and low<=high else None

    def capacity_expression(self,name,pos,seen=()):
        # No fact survives a later resize or an escape to an unknown function.
        calls=list(re.finditer(rf'\bArrayResize\s*\(\s*{re.escape(name)}\s*,',self.body[:pos]))
        if not calls:return None
        call=calls[-1];opening=self.body.find('(',call.start());close=end_delimiter(self.body,opening)
        if close is None:return None
        expression=self.body[call.end():close].split(',')[0].strip()
        if self.changed(name,close+1,pos):return None
        approved=False
        for condition,truth,origin in self.guards(pos):
            expected='ArrayResize('+name+','+compact(expression)+')!='+compact(expression)
            if not truth and compact(condition)==expected and call.start()<origin:
                approved=True;break
            prefix='ArrayResize('+name+','+compact(expression)+')!='
            if not truth and compact(condition).startswith(prefix) and call.start()<origin:
                requested=self.interval(expression,call.start(),seen)
                returned=self.interval(compact(condition)[len(prefix):],call.start(),seen)
                if requested and returned and requested[0]==requested[1]==returned[0]==returned[1]:
                    approved=True;break
        return expression if approved else None

    def capacity(self,name,pos,seen=()):
        expression=self.capacity_expression(name,pos,seen)
        if expression is None:return None
        call=list(re.finditer(rf'\bArrayResize\s*\(\s*{re.escape(name)}\s*,',self.body[:pos]))[-1]
        return self.interval(expression,call.start(),seen)

    def bounded(self,name,index,pos):
        size=self.capacity(name,pos)
        interval=self.interval(index,pos)
        return bool(size and interval and 0<=interval[0]<=interval[1]<size[0])

    def explicit_guard(self,name,index,pos,size_expression=None):
        lower = bool(re.fullmatch(r'\d+',compact(index)))
        upper = False
        targets = {compact('ArraySize('+name+')')}
        if size_expression: targets.add(compact(size_expression))
        for condition,truth,origin in self.guards(pos):
            if self.changed(index,origin,pos) or self.changed(name,origin,pos):continue
            text=compact(condition)
            if not truth:
                if text in {index+'<0',index+'<=-1'}:lower=True
                if any(text==index+'>='+target for target in targets):upper=True
            else:
                if text in {index+'>=0',index+'>-1'}:lower=True
                if any(text==index+'<'+target for target in targets):upper=True
        interval=self.interval(index,pos)
        lower=lower or bool(interval and interval[0]>=0)
        return lower and upper


@lru_cache(maxsize=128)
def proof_for(body):
    return Proof(body)


def proves(body,array,index,pos):
    return proof_for(body).bounded(array,index,pos)
