/* 展示页内嵌桥：
   - 劫持 requestAnimationFrame，父页面 postMessage {__showcase:true,type:'pause'/'resume'}
     即可冻结/恢复本作品的主循环（各作品的 rAF 循环都会经过这里）
   - 暂停时顺带把音乐一起停住：mario 暴露 __audioState.ctx，drive 暴露 SunsetMusic.setMuted
   - 加载完成后向父页面报告 ready，用于隐藏加载遮罩 */
(function () {
  var paused = false;
  var pending = [];
  var orig = window.requestAnimationFrame.bind(window);

  window.requestAnimationFrame = function (cb) {
    if (paused) { pending.push(cb); return 0; }
    return orig(function (t) {
      if (paused) { pending.push(cb); return; }
      cb(t);
    });
  };

  function pauseInner() {
    paused = true;
    try { if (window.SunsetMusic) window.SunsetMusic.setMuted(true); } catch (e) {}
    try { if (window.__audioState && window.__audioState.ctx) window.__audioState.ctx.suspend(); } catch (e) {}
  }
  function resumeInner() {
    paused = false;
    var q = pending; pending = [];
    for (var i = 0; i < q.length; i++) orig(q[i]);
    try { if (window.SunsetMusic) window.SunsetMusic.setMuted(false); } catch (e) {}
    try { if (window.__audioState && window.__audioState.ctx) window.__audioState.ctx.resume(); } catch (e) {}
  }

  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || d.__showcase !== true) return;
    if (d.type === 'pause' && !paused) pauseInner();
    if (d.type === 'resume' && paused) resumeInner();
  });

  function reportReady() {
    try {
      parent.postMessage({ __showcase: true, type: 'ready', title: document.title }, '*');
    } catch (e) {}
  }
  if (document.readyState === 'complete') setTimeout(reportReady, 400);
  else window.addEventListener('load', function () { setTimeout(reportReady, 400); });
})();
