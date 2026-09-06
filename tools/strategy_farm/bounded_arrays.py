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
PURE = {'ArraySize','ArrayResize','ArraySort','ArraySetAsSeries','ArrayInitialize','MathIsValidNumber',
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


def statement_end(text, start):
    """Return the end of one MQL statement, including nested controls."""
    while start < len(text) and text[start].isspace(): start += 1
    if start >= len(text): return None
    if text[start] == '{':
        close = end_delimiter(text, start, '{', '}')
        return None if close is None else close + 1
    control = re.match(r'(if|for|while)\s*\(', text[start:])
    if control:
        opening = text.find('(', start, start + control.end())
        close = end_delimiter(text, opening)
        if close is None: return None
        finish = statement_end(text, close + 1)
        if finish is None: return None
        if control[1] == 'if':
            cursor = finish
            while cursor < len(text) and text[cursor].isspace(): cursor += 1
            if text.startswith('else', cursor) and not re.match(r'else\w', text[cursor:]):
                alternate = statement_end(text, cursor + 4)
                if alternate is None: return None
                finish = alternate
        return finish
    finish = text.find(';', start)
    return None if finish < 0 else finish + 1


def terminal_return_arm(text):
    """Accept a flat statement sequence whose final statement is return."""
    if '{' in text or '}' in text:return False
    statements=[item.strip() for item in text.split(';') if item.strip()]
    if not statements or not re.match(r'return\b',statements[-1]):return False
    return not any(
        re.search(r'\b(?:if|for|while|switch|return|break|continue)\b',item)
        for item in statements[:-1]
    )


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
    def __init__(self, body, round3_enabled=True):
        self.body = body
        self.round3_enabled = round3_enabled
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

    def directly_changed(self,name,start,end):
        """Detect scalar writes without treating indexed call arguments as escapes."""
        text=self.body[start:end]
        escaped=re.escape(name)
        return bool(re.search(
            rf'(?<![\w.]){escaped}\s*(?:=(?!=)|[+*/%-]=)|'
            rf'(?:\+\+|--)\s*{escaped}\b|\b{escaped}\s*(?:\+\+|--)',
            text,
        ))

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
                if (terminal_return_arm(arm) if self.round3_enabled else
                    re.fullmatch(r'return\b[^;]*;\s*',arm,re.S)):
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

    def assignment_expression(self,name,pos):
        assignments=list(re.finditer(
            rf'(?<![\w.]){re.escape(name)}\s*=(?!=)\s*([^;]+);',
            self.body[:pos],
        ))
        assignment=next(
            (item for item in reversed(assignments)
             if self.dominates(item.start(),item.end(),pos)),
            None,
        )
        if assignment is None or self.changed(name,assignment.end(),pos):return None
        return assignment[1],assignment.start()

    def affine(self,expression,pos,seen=()):
        """Expand a small integer affine expression into coefficients + constant."""
        expression=compact(re.sub(r'\((?:int|long|uint|short)\)', '', unwrap(expression)))
        try:node=ast.parse(expression,mode='eval').body
        except (ValueError,SyntaxError):return None
        def merge(left,right,sign=1):
            coefficients=dict(left[0])
            for key,value in right[0].items():
                coefficients[key]=coefficients.get(key,0)+sign*value
                if coefficients[key]==0:del coefficients[key]
            return coefficients,left[1]+sign*right[1]
        def walk(item,trail):
            if isinstance(item,ast.Constant) and type(item.value) is int:return {},item.value
            if isinstance(item,(ast.Name,ast.Attribute)):
                name=ast.unparse(item)
                if name not in trail:
                    assigned=self.assignment_expression(name,pos)
                    if assigned:
                        expanded=self.affine(assigned[0],assigned[1],(*trail,name))
                        if expanded is not None:return expanded
                return {name:1},0
            if isinstance(item,ast.UnaryOp) and isinstance(item.op,(ast.USub,ast.UAdd)):
                value=walk(item.operand,trail)
                if value is None:return None
                return ({key:-coefficient for key,coefficient in value[0].items()},-value[1]) if isinstance(item.op,ast.USub) else value
            if isinstance(item,ast.BinOp) and isinstance(item.op,(ast.Add,ast.Sub)):
                left,right=walk(item.left,trail),walk(item.right,trail)
                if left is None or right is None:return None
                return merge(left,right,-1 if isinstance(item.op,ast.Sub) else 1)
            if isinstance(item,ast.BinOp) and isinstance(item.op,ast.Mult):
                left,right=walk(item.left,trail),walk(item.right,trail)
                if left is None or right is None:return None
                if not left[0]:return ({key:left[1]*value for key,value in right[0].items()},left[1]*right[1])
                if not right[0]:return ({key:right[1]*value for key,value in left[0].items()},right[1]*left[1])
            return None
        return walk(node,seen)

    def scalar_lower_bound(self,name,pos):
        lower=None
        initial=self.zero_initialization(name,pos)
        if initial is not None and not self.changed(name,initial.end(),pos,ignore_steps=True):lower=0
        for condition,truth,origin in self.guards(pos):
            match=re.fullmatch(rf'\s*{re.escape(name)}\s*(==|!=|<=|>=|<|>)\s*(-?\d+)\s*',condition)
            if not match or self.changed(name,origin,pos):continue
            op,value=match[1],int(match[2])
            if not truth:op={'!=':'==','==':'!=','<':'>=','>':'<=','<=':'>','>=':'<'}[op]
            if op in ('==','>=','>'):
                candidate=value+(op=='>')
                lower=candidate if lower is None else max(lower,candidate)
        return lower

    def affine_leq(self,left,right,pos):
        """Prove ``left <= right`` from affine expansion and fail-fast lower guards."""
        lhs,rhs=self.affine(left,pos),self.affine(right,pos)
        if lhs is None or rhs is None:return False
        coefficients=dict(rhs[0])
        for name,value in lhs[0].items():coefficients[name]=coefficients.get(name,0)-value
        constant=rhs[1]-lhs[1]
        for name,coefficient in coefficients.items():
            if coefficient<0:return False
            lower=self.scalar_lower_bound(name,pos)
            if lower is None:return False
            constant+=coefficient*lower
        return constant>=0

    def guarded_strict_upper(self,name,targets,pos,seen=()):
        if name in seen:return False
        for condition,truth,origin in self.guards(pos):
            match=re.fullmatch(rf'\s*{re.escape(name)}\s*(==|!=|<=|>=|<|>)\s*(.+)',condition,re.S)
            if not match or self.changed(name,origin,pos):continue
            op,rhs=match[1],unwrap(match[2])
            if not truth:op={'!=':'==','==':'!=','<':'>=','>':'<=','<=':'>','>=':'<'}[op]
            if op not in ('<','<='):continue
            if compact(rhs) in targets and op=='<':return True
            if re.fullmatch(VAR,rhs) and self.guarded_strict_upper(rhs,targets,pos,(*seen,name)):
                return True
        return False

    def bounded_search_result(self,name,index,pos):
        """Prove a post-loop index copied from a same-buffer bounded cursor."""
        result=compact(index)
        if not re.fullmatch(VAR,result):return False
        lower=self.scalar_lower_bound(result,pos)
        if lower is None or lower<0:return False
        for loop in self.controls:
            if loop.kind!='for' or loop.end>pos or loop.condition.count(';')!=2:continue
            init,condition,step=loop.condition.split(';')
            cursor_match=re.fullmatch(rf'\s*(?:int\s+)?({VAR})\s*=\s*0\s*',init,re.S)
            if not cursor_match:continue
            cursor=cursor_match[1]
            if compact(condition)!=cursor+'<ArraySize('+name+')':continue
            if compact(step) not in ('++'+cursor,cursor+'++'):continue
            if self.directly_changed(cursor,loop.body_start,loop.body_end):continue
            assignments=list(re.finditer(
                rf'(?<![\w.]){re.escape(result)}\s*=\s*{re.escape(cursor)}\s*;',
                self.body[loop.body_start:loop.body_end],
            ))
            if len(assignments)!=1:continue
            before=self.body[:loop.start]
            sentinel=list(re.finditer(rf'(?<![\w.]){re.escape(result)}\s*=\s*-1\s*;',before))
            if not sentinel:continue
            start=sentinel[-1]
            if self.changed(result,start.end(),loop.start):continue
            if self.changed(result,loop.end,pos):continue
            if self.changed(name,loop.start,pos):continue
            return True
        return False

    def bounded(self,name,index,pos,size_expression=None):
        size=self.capacity(name,pos)
        interval=self.interval(index,pos)
        if size and interval and 0<=interval[0]<=interval[1]<size[0]:return True
        if self.round3_enabled and self.explicit_guard(name,compact(index),pos,size_expression):return True
        if self.round3_enabled and self.bounded_search_result(name,index,pos):return True
        return bool(
            size_expression and
            (self.counter_append_bounded(name,index,pos,size_expression) or
             (self.round3_enabled and
              self.paired_cursor_append_bounded(name,index,pos,size_expression)))
        )

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
        if self.round3_enabled:
            lower=lower or self.monotone_from_zero(index,pos)
            upper=upper or self.guarded_strict_upper(index,targets,pos)
        return lower and upper

    def paired_cursor_append_bounded(self,name,index,pos,size_expression):
        """Prove a paired-buffer append counter is dominated by two merge cursors."""
        counter,size=compact(index),compact(size_expression)
        if not re.fullmatch(VAR,counter) or not re.fullmatch(VAR,size):return False
        if not self.monotone_from_zero(counter,pos):return False
        assigned=self.assignment_expression(size,pos)
        if assigned is None:return False
        minimum=re.fullmatch(rf'\s*MathMin\s*\(\s*({VAR})\s*,\s*({VAR})\s*\)\s*',assigned[0])
        if not minimum:return False
        bounds={minimum[1],minimum[2]}
        for loop in self.controls:
            if loop.kind!='while' or not self.contains(loop,pos):continue
            parts={compact(part) for part in split_boolean(loop.condition,'&&')}
            cursor_bounds={}
            for part in parts:
                match=re.fullmatch(rf'({VAR})<({VAR})',part)
                if match:cursor_bounds[match[1]]=match[2]
            cursors={cursor for cursor,bound in cursor_bounds.items() if bound in bounds}
            if len(cursors)!=2 or {cursor_bounds[item] for item in cursors}!=bounds:continue
            if any(self.zero_initialization(cursor,loop.start) is None for cursor in cursors):continue
            counter_steps=list(re.finditer(
                rf'(?:\+\+\s*{re.escape(counter)}\b|\b{re.escape(counter)}\s*\+\+)',
                self.body[loop.body_start:loop.body_end],
            ))
            if len(counter_steps)!=1 or self.changed(counter,loop.body_start,loop.body_end,ignore_steps=True):continue
            counter_step=loop.body_start+counter_steps[0].start()
            branch=next((control for control in sorted(self.controls,key=lambda item:item.start,reverse=True)
                         if control.kind=='if' and self.contains(control,pos) and self.contains(control,counter_step)),None)
            if branch is None:continue
            coupled=True
            for cursor in cursors:
                if self.changed(cursor,loop.body_start,loop.body_end,ignore_steps=True):coupled=False;break
                steps=re.findall(
                    rf'(?:\+\+\s*{re.escape(cursor)}\b|\b{re.escape(cursor)}\s*\+\+)',
                    self.body[branch.body_start:branch.body_end],
                )
                if len(steps)!=1:coupled=False;break
            if not coupled:continue
            siblings=[]
            for resize in re.finditer(r'\bArrayResize\s*\(\s*([A-Za-z_]\w*)\s*,',self.body[:pos]):
                sibling=resize[1]
                if sibling==name:continue
                access=re.search(
                    rf'\b{re.escape(sibling)}\s*\[\s*{re.escape(counter)}\s*\]',
                    self.body[branch.body_start:pos],
                )
                if access and self.capacity_expression(sibling,pos) and compact(self.capacity_expression(sibling,pos))==size:
                    siblings.append(sibling)
            if siblings:return True
        return False

    def zero_initialization(self,name,pos):
        assignments=list(re.finditer(
            rf'(?<![\w.]){re.escape(name)}\s*=(?!=)\s*0\s*;',
            self.body[:pos],
        ))
        return next(
            (item for item in reversed(assignments)
             if self.dominates(item.start(),item.end(),pos)),
            None,
        )

    def monotone_from_zero(self,name,pos):
        """Prove a simple counter is non-negative at ``pos``.

        The proof deliberately accepts only a dominating zero reset followed by
        unit increments. Assignments, decrements, compound updates, and escapes
        to unknown functions invalidate it.
        """
        if not re.fullmatch(VAR,name):return False
        initial=self.zero_initialization(name,pos)
        if initial is None:return False
        tail=self.body[initial.end():pos]
        if self.changed(name,initial.end(),pos,ignore_steps=True):return False
        decrement=rf'(?:--\s*{re.escape(name)}\b|\b{re.escape(name)}\s*--)'
        return re.search(decrement,tail) is None

    def dominating_resize(self,name,pos,size_expression):
        calls=[]
        for call in re.finditer(rf'\bArrayResize\s*\(\s*{re.escape(name)}\s*,',self.body[:pos]):
            opening=self.body.find('(',call.start())
            close=end_delimiter(self.body,opening)
            if close is None or close>=pos:continue
            expression=self.body[call.end():close].split(',')[0].strip()
            calls.append((call,close,expression))
        if not calls:return None
        call,close,expression=calls[-1]
        if compact(expression)!=compact(size_expression):return None
        if not self.dominates(call.start(),close+1,pos):return None
        if self.changed(name,close+1,pos):return None
        return call,close,expression

    def counter_append_bounded(self,name,index,pos,size_expression):
        """Prove a counter-indexed append stays below its resized capacity.

        Accepted shapes are intentionally narrow: a checked resize to
        ``counter + 1``; a direct counter/cap loop guard; or at most one
        post-access counter increment per iteration of a canonical loop whose
        iteration cap is the resize cap. These are local structural proofs, not
        data-flow guesses.
        """
        counter=compact(index)
        if not re.fullmatch(VAR,counter) or not self.monotone_from_zero(counter,pos):
            return False
        # A resize to counter+1 is safe only when its return value is checked.
        approved_size=self.capacity_expression(name,pos)
        if approved_size and compact(approved_size) in {
            counter+'+1','1+'+counter,
        }:
            return True

        resize=self.dominating_resize(name,pos,size_expression)
        if resize is None:return False
        size=compact(size_expression)
        initial=self.zero_initialization(counter,pos)
        if initial is None:return False

        for loop in self.controls:
            if loop.kind not in ('for','while') or not self.contains(loop,pos):continue
            if initial.end()>loop.start:continue
            if self.changed(counter,initial.end(),loop.start):continue
            loop_body_end=loop.body_end
            old_steps=re.findall(
                rf'(?:\+\+\s*{re.escape(counter)}\b|\b{re.escape(counter)}\s*\+\+)',
                self.body[loop.body_start:loop.body_end],
            )
            # Preserve every established proof. Only widen an unbraced loop's
            # parsed statement when the old body stopped before the sole
            # counter increment and therefore could not prove anything.
            if self.round3_enabled and len(old_steps)!=1:
                statement_start=loop.condition_end+1
                while statement_start<len(self.body) and self.body[statement_start].isspace():statement_start+=1
                if statement_start<len(self.body) and self.body[statement_start]!='{':
                    full_end=statement_end(self.body,statement_start)
                    if full_end is not None:loop_body_end=full_end
            nested=any(
                inner.kind in ('for','while') and inner.start>loop.start and self.contains(inner,pos)
                for inner in self.controls
            )
            if nested:continue
            if self.changed(counter,loop.body_start,loop_body_end,ignore_steps=True):continue
            increments=list(re.finditer(
                rf'(?:\+\+\s*{re.escape(counter)}\b|\b{re.escape(counter)}\s*\+\+)',
                self.body[loop.body_start:loop_body_end],
            ))
            decrements=list(re.finditer(
                rf'(?:--\s*{re.escape(counter)}\b|\b{re.escape(counter)}\s*--)',
                self.body[loop.body_start:loop_body_end],
            ))
            if len(increments)!=1 or decrements:continue
            increment_pos=loop.body_start+increments[0].start()
            if increment_pos<pos:continue

            condition=loop.condition
            if loop.kind=='for' and condition.count(';')==2:
                init,condition,step=condition.split(';')
            else:
                init=step=''
            direct=any(
                compact(part)==counter+'<'+size
                for part in split_boolean(condition,'&&')
            )
            if direct:return True
            if loop.kind!='for':continue

            ascending=re.fullmatch(rf'\s*(?:int\s+)?({VAR})\s*=\s*0\s*',init,re.S)
            if ascending:
                cursor=ascending[1]
                if (compact(condition)==cursor+'<'+size and
                    compact(step) in ('++'+cursor,cursor+'++') and
                    not self.directly_changed(cursor,loop.body_start,loop_body_end)):
                    return True
            descending=re.fullmatch(rf'\s*(?:int\s+)?({VAR})\s*=\s*(.+)\s*',init,re.S)
            if descending:
                cursor,start=descending[1],compact(descending[2])
                canonical_descending=(start==size+'-1' and compact(condition)==cursor+'>=0')
                if self.round3_enabled:
                    canonical_descending=(canonical_descending or
                                          (start==size and compact(condition)==cursor+'>=1'))
                if (canonical_descending and
                    compact(step) in ('--'+cursor,cursor+'--') and
                    not self.directly_changed(cursor,loop.body_start,loop_body_end)):
                    return True
        return False


@lru_cache(maxsize=256)
def proof_for(body, round3_enabled=True):
    return Proof(body, round3_enabled)


def proves(body,array,index,pos):
    return proof_for(body).bounded(array,index,pos)
