/* Local review enhancement: supplied public counters and decorative candle field. */
(() => {
  'use strict';
  document.addEventListener('qm:funnel-data',({detail:d})=>{
    document.querySelectorAll('[data-funnel-stat]').forEach(n=>{const v=d[n.dataset.funnelStat];if(Number.isFinite(v))n.textContent=v.toLocaleString('en-US');});
    const stamp=document.querySelector('[data-funnel-stamp]');if(stamp)stamp.textContent='Snapshot '+d.snapshot_utc.slice(0,10)+'. Distinct strategies, completed backtests and qualified pairs count different things. The current pair target is '+d.qualified_pairs_target+'.';
  });
  const canvas=document.getElementById('hero-bg');if(!canvas)return;
  const ctx=canvas.getContext('2d'),media=matchMedia('(prefers-reduced-motion: reduce)');let w=0,h=0,last=0,t=0,raf=0,visible=true;
  function draw(){ctx.clearRect(0,0,w,h);const dx=22;for(let i=-2;i<Math.ceil(w/dx)+3;i++){const x=i*dx-(t*5)%dx,base=h*.56+Math.sin(i*.21)*h*.13+Math.sin(i*.63)*h*.04,delta=Math.sin(i*2.87)*21;ctx.strokeStyle=delta>0?'#4b6c91':'#9a6e65';ctx.fillStyle=ctx.strokeStyle;ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(x,base-30);ctx.lineTo(x,base+30);ctx.stroke();ctx.fillRect(x-4,base-Math.abs(delta)/2,8,Math.max(3,Math.abs(delta)));}}
  function resize(){const r=canvas.getBoundingClientRect(),d=Math.min(devicePixelRatio||1,2);w=r.width;h=r.height;canvas.width=w*d;canvas.height=h*d;ctx.setTransform(d,0,0,d,0,0);draw();}
  function tick(now){raf=0;if(media.matches||document.hidden||!visible){last=0;return;}if(last)t+=Math.min((now-last)/1000,.05);last=now;draw();raf=requestAnimationFrame(tick);}
  function sync(){cancelAnimationFrame(raf);last=0;draw();if(!media.matches&&visible&&!document.hidden)raf=requestAnimationFrame(tick);}
  new ResizeObserver(resize).observe(canvas);new IntersectionObserver(e=>{visible=e[0].isIntersecting;sync();}).observe(canvas);media.addEventListener('change',sync);document.addEventListener('visibilitychange',sync);resize();sync();
})();
