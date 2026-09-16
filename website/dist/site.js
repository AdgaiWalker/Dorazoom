(() => {
  const en = document.documentElement.lang === 'en';
  const explicit = new URL(location.href).searchParams.get('lang');
  if (explicit === 'zh' || explicit === 'en') {
    document.querySelectorAll('a[href]').forEach(link => {
      if (link.origin === location.origin && !link.hasAttribute('data-language') && !link.getAttribute('href').startsWith('#')) {
        const target = new URL(link.href); target.searchParams.set('lang', explicit); link.href = target.href;
      }
    });
  }
  document.querySelectorAll('[data-language]').forEach(link => link.addEventListener('click', () => {
    try { localStorage.setItem('dorazoom-language', link.dataset.language); } catch {}
    // Query preference also works when browser storage is unavailable.
    const target = new URL(link.href); target.searchParams.set('lang',link.dataset.language); link.href=target.href;
  }));
  const dialog = document.querySelector('#video-dialog');
  if (dialog) {
    const video=dialog.querySelector('video'); let opener;
    document.querySelectorAll('[data-video]').forEach(button=>button.addEventListener('click',()=>{opener=button;dialog.showModal();video.play().catch(()=>{});}));
    document.querySelector('#close-video').addEventListener('click',()=>dialog.close());
    dialog.addEventListener('click',event=>{if(event.target===dialog){const r=dialog.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close();}});
    dialog.addEventListener('close',()=>{video.pause();opener?.focus();});
  }
  const canvas=document.querySelector('canvas'); if(!canvas)return;
  const ctx=canvas.getContext('2d'); const marks=[];let draft=null, tool='circle', color='#e95142',pointer=null,timer;
  function toast(msg){const el=document.querySelector('#toast');el.textContent=msg;clearTimeout(timer);timer=setTimeout(()=>el.textContent='',3500);}
  function text(t,x,y,size=25,fill='#626975'){ctx.font=`${size}px -apple-system, BlinkMacSystemFont, sans-serif`;ctx.fillStyle=fill;ctx.fillText(t,x,y);}
  function render(){
    ctx.fillStyle='#fff';ctx.fillRect(0,0,1200,600);ctx.fillStyle='#f4f6fa';ctx.fillRect(45,45,1110,510);
    text(en?'YOUR NEXT PRESENTATION':'你的下一场演示',100,115,18);text(en?'A clearer idea starts here.':'让重点，一眼就能看见。',100,185,42,'#24262b');
    text(en?'Circle a detail. Point the way. Share the context.':'圈出一个细节，指明一个方向，把上下文一起分享。',100,239,24);
    ctx.fillStyle='#fff';ctx.fillRect(100,290,620,190);text(en?'One small change.':'一个小小的改变。',130,340,26,'#24262b');text(en?'A much clearer explanation.':'一次更清楚的表达。',130,391,24);
    ctx.fillStyle='#303b54';ctx.beginPath();ctx.roundRect(790,345,290,68,12);ctx.fill();text(en?'Start here':'从这里开始',830,390,27,'#fff');
    text(en?'Illustrative canvas • annotations stay on this device':'示例画布 · 标注仅保存在你的设备上',100,525,18);
    [...marks,...(draft?[draft]:[])].forEach(m=>{const a=m.points[0],b=m.points.at(-1);ctx.strokeStyle=m.color;ctx.lineWidth=5;ctx.lineCap='round';ctx.lineJoin='round';ctx.beginPath();if(m.tool==='circle'){ctx.ellipse((a.x+b.x)/2,(a.y+b.y)/2,Math.max(1,Math.abs(a.x-b.x)/2),Math.max(1,Math.abs(a.y-b.y)/2),0,0,Math.PI*2);}else{ctx.moveTo(a.x,a.y);if(m.tool==='pen')m.points.slice(1).forEach(p=>ctx.lineTo(p.x,p.y));else{ctx.lineTo(b.x,b.y);const angle=Math.atan2(b.y-a.y,b.x-a.x);ctx.moveTo(b.x-22*Math.cos(angle-.5),b.y-22*Math.sin(angle-.5));ctx.lineTo(b.x,b.y);ctx.lineTo(b.x-22*Math.cos(angle+.5),b.y-22*Math.sin(angle+.5));}}ctx.stroke();});
    document.querySelector('#mark-count').textContent=en?`${marks.length} annotation${marks.length===1?'':'s'}`:`${marks.length} 处标注`;
    document.querySelector('#undo').disabled=document.querySelector('#clear').disabled=!marks.length;
  }
  const point=e=>{const r=canvas.getBoundingClientRect();return{x:Math.max(0,Math.min(1200,(e.clientX-r.left)/r.width*1200)),y:Math.max(0,Math.min(600,(e.clientY-r.top)/r.height*600))};};
  canvas.addEventListener('pointerdown',e=>{if(pointer!==null||e.button!==0)return;pointer=e.pointerId;canvas.setPointerCapture(pointer);draft={tool,color,points:[point(e)]};render();});
  canvas.addEventListener('pointermove',e=>{if(e.pointerId!==pointer||!draft)return;draft.points.push(point(e));render();});
  canvas.addEventListener('pointerup',e=>{if(e.pointerId!==pointer||!draft)return;draft.points.push(point(e));marks.push(draft);draft=null;pointer=null;render();});
  for(const event of ['pointercancel','lostpointercapture'])canvas.addEventListener(event,()=>{draft=null;pointer=null;render();});
  canvas.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();marks.push({tool:'circle',color,points:[{x:765,y:320},{x:1105,y:438}]});render();}else if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='z'){e.preventDefault();marks.pop();render();}});
  document.querySelectorAll('[data-tool]').forEach(button=>button.addEventListener('click',()=>{tool=button.dataset.tool;document.querySelectorAll('[data-tool]').forEach(b=>b.setAttribute('aria-pressed',b===button));}));
  document.querySelectorAll('[data-color]').forEach(button=>button.addEventListener('click',()=>{color=button.dataset.color;document.querySelectorAll('[data-color]').forEach(b=>b.setAttribute('aria-pressed',b===button));}));
  document.querySelector('#undo').addEventListener('click',()=>{marks.pop();render();});
  document.querySelector('#clear').addEventListener('click',()=>{marks.length=0;render();});
  // This small fixed-size canvas exports synchronously within the user gesture.
  document.querySelector('#save').addEventListener('click',()=>{try{const a=document.createElement('a');a.href=canvas.toDataURL('image/png');a.download='DoraZoom-annotation.png';document.body.append(a);a.click();a.remove();toast(en?'Your annotated image is ready.':'标注图片已生成。');}catch{toast(en?'Could not export. Please try again.':'导出失败，请重试。');}});
  render();
})();
