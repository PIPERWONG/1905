# Serene Escape Unlimited — 本地复刻(安详版文案)

在本地浏览器中复刻并改编 Shadertoy 上的多通道 shader 游戏 **Sunset Drive Unlimited**。

- 原作:https://www.shadertoy.com/view/wtS3W3
- 作者:**spolsh(Michal Klos)**,2019
- 许可:**CC BY-NC-SA 3.0**(署名-非商业性使用-相同方式共享)

> 版权说明:本项目仅供学习研究。`shaders/` 目录下的 GLSL 源码提取自上述公开页面,
> 每个文件头部均保留了原作者的版权与许可声明。任何再分发请遵循 CC BY-NC-SA 3.0,
> 保留署名并仅用于非商业用途。原作音乐为 Lifelike - *So Electric*(SoundCloud),
> 同样仅在非商业场景下提及。

## 安详版文案改编

在原作玩法不变的前提下,文案改编为"安详"主题:

| 位置 | 原版 | 现在 |
| --- | --- | --- |
| 标题 | SUNSET DRIVE UNLIMITED | SERENE ESCAPE UNLIMITED |
| 高分行 | Highscore: | You are safe now |
| 开始提示 | Press [space] to start | begin when ready |
| 撞车 | (无文字) | You are still safe |
| 游戏内分数 | 数字 | 安详值 N(HTML 覆盖层) |
| 阶段提示 | (无) | 你不需要逃得更快 / 慢一点也没关系 |

实现:英文走 shader 内的 abc 字形纹理(编译期把字符打包常量替换为新文案的
编码,见 `runtime.js` 的 `THEME_PATCHES`);中文无法用该字形集渲染,由
runtime 每 150ms 读回游戏状态(BufferA 的 8x8 状态区)驱动 HTML 覆盖层显示,
按行进阶段轮换提示、撞车时显示安慰文案。`?zen=1` 可进入无尽禅意驾驶
(不撞障碍),用于安静地看风景和文案。

## 运行

页面需要通过 HTTP 访问(浏览器不允许 `file://` 下 fetch 本地文件),任选其一:

```bat
:: Windows —— 双击 start.bat,或手动:
cd sunset-drive
python -m http.server 8020
:: 然后浏览器打开 http://localhost:8020/
```

```bash
# 或者用 Node
npx serve .
```

## 操作

| 按键 | 作用 |
| --- | --- |
| `←` `→` 或 `A` `D` | 左右移动 |
| `空格` / 左右移动键 | 开始游戏 / 撞车后重新开始 |
| `U` | 显示/隐藏计分板 |
| 按住鼠标拖动 | 转动视角 |

玩法:吃金币、躲路障,无尽 synthwave 公路狂飙。祝你打破高分 :)

## 目录结构

```
sunset-drive/
├── index.html            页面(全屏 canvas + 操作提示)
├── runtime.js            迷你 Shadertoy 运行时(WebGL2)
├── start.bat             一键启动本地服务器
├── shaders/              原作 GLSL 源码(保留原始版权头)
│   ├── common.glsl       Common 选项卡(状态结构、哈希、按键定义、开关宏)
│   ├── bufferA.glsl      Buffer A — 游戏状态机(存于 8x8 像素区域)
│   ├── bufferB.glsl      Buffer B — 主体:raymarching 场景渲染
│   ├── bufferC.glsl      Buffer C — bloom、文字与 HUD 叠加
│   ├── bufferD.glsl      Buffer D — 色差/后期
│   └── image.glsl        Image — FXAA、噪点、胶片比例与 gamma
└── textures/             原 shader 引用的 Shadertoy 托管纹理(已本地化)
    ├── tex_noise.png     64x64 噪声(Buffer B 地形)
    ├── tex_font.png      512x512(Buffer B 网格/材质)
    └── tex_abc.png       1024x1024 "abc" 字形纹理(Buffer C 文字)
```

## 实现说明(runtime.js)

- **多通道**:按 `Common(仅参与编译)→ BufferA → BufferB → BufferC → BufferD → Image`
  顺序渲染;Common 源码前置到每个通道编译。
- **Buffer 双缓冲**:自引用(Buffer A 读自己的上一帧输出)用 ping-pong;通道按顺序渲染,
  排在后面的 Buffer 读到前面 Buffer 的本帧输出,与 Shadertoy 语义一致。
- **通道绑定**:`iChannel` 的纹理、filter(mipmap/linear/nearest)与 wrap(clamp/repeat)
  与原作通道设置一致(通过 WebGL2 sampler 对象实现,因为同一 Buffer 纹理在不同通道
  使用不同采样参数)。注意 sampler uniform 必须显式 `gl.uniform1i` 指向对应纹理单元,
  否则所有通道都会读到 unit 0。
- **纹理翻转**:原通道 `vflip: true`。此环境下 `UNPACK_FLIP_Y_WEBGL` 对
  `createImageBitmap` 上传路径不生效,须在解码阶段用
  `createImageBitmap(blob, { imageOrientation: "flipY" })` 翻转,否则文字会上下颠倒。
- **键盘输入**:实现为 256x2 的 R8 纹理 —— 第 0 行是按键按下状态,第 1 行是 toggle 状态,
  对应 Shadertoy 的 keyboard 通道。
- **音频通道**:原作 Image 通道的 iChannel3 绑定了 SoundCloud 音乐流,但 shader 代码
  并未采样该通道(音乐只是页面氛围)。本地复刻中以 512x2 静音纹理代替,画面不受影响;
  想要音乐氛围可自行播放 *So Electric*。
- **Uniforms**:提供 `iResolution / iTime / iTimeDelta / iFrameRate / iFrame / iMouse /
  iDate / iChannelTime / iChannelResolution / iSampleRate`,数值语义与 Shadertoy 一致。

## 程序合成配乐(心率系统)

Web Audio 实时合成的 synthwave 配乐(Am-F-C-G 进行:锯齿波贝斯琶音、
三角波 Pad、正弦底鼓与噪声镲片),无任何音频素材,零版权负担:

- **心率 = BPM**:初始 105,每收集一枚安详光点 **BPM -1**(下限 72)——
  「心率 -1」不只是文案,配乐真的会越收越慢、越来越静。
- **mood 适配**:mood 越高,BPM 越低(105→75)、低通滤波越柔(约 4700Hz→900Hz)、
  镲片越轻——高 mood 时整首歌变得舒缓朦胧。
- **撞击反馈**:撞到障碍车时低通瞬闭 + 音量下压(闷响),约 1.2 秒恢复。
- 面板可开关配乐、调节音量,并实时显示当前心率(BPM)。
- 浏览器策略要求首次交互后才能出声——按任意键即自动开始。

## 安详值系统(serenity)

全局变量 `serenity`(0 ~ 100,初始 20)存于 BufferA 状态区(像素 (3,1).x),
是整个"安详旅程"的核心驱动力:

- **吃安详光点 +2**,撞到障碍车 **-5**(同一次碰撞只计一次)。
- **数值变化反馈**:数值平滑滚动过渡,变化时飘出浮动数字(+2 青绿上浮 / -5 红色下沉),
  状态词与进度条同步过渡。
- **撞到障碍车的流程**:画面短暂变灰、大幅减速后停下,中央渐显
  *You are still safe* —— 没有自动复活,按 **←/→** 继续旅程。- **驱动 mood**:`mood 目标 = 0.06 + 里程/900 + serenity/105` —— 光点把心情推亮,
  碎片让画面回到冷色;里程保留少量自然增长。
- **影响雾浓度**:体积雾与距离雾的强度随 serenity 递减(×1.0 → ×0.45/0.55),
  越安详视野越通透清亮。
- **影响速度**:通过 mood 的速度因子(`mix(1.0, 0.45, mood)`)间接让节奏放缓。
- **影响 UI 文案**:安详值旁的状态词随数值切换——
  `还在逃离`(0-25)→ `渐渐平静`(25-50)→ `心安之处`(50-75)→ `安详自在`(75-100),
  配有一条渐变进度条。
- **音乐**:原作 shader 未采样音频,不支持;可用任意本地播放器自配。

屏幕左上以「安详值 N + 状态词 + 进度条」替代原版 Score 显示。

## 撞车行为(全版本恒定)

撞到障碍车**永远不会失败**:没有 Game Over、没有生命值、不会回到待机——
中央渐显 *You are still safe*,安详值 -5,然后继续前行。该行为在所有
「旅程版本」(含 v0 经典复刻)下恒定生效。

## 安详光点(原金币)

金币被重制为**安详光点**:路面上漂浮的柔光球,带水母式的呼吸浮沉与萤火般的
亮度轻颤,光晕为青蓝色且随 mood 增大变得更弥散、更绵长(尾迹感)。

- **数量**:生成周期随 mood 从每 4 格收敛到 2.5 格——旅程越往后,光点越密
  (BufferA 收集判定 / BufferB 渲染 / demo AI 三处同步)。
- **收集反馈**:mood 立刻 +0.015、速度短暂呼吸式放慢(约 35%,2 秒内回升)、
  全屏一闪青白柔光、画面上方浮现随机短语(「又收下一点安宁」「轻轻收好了」
  「心里亮了一下」「安详 +1」「它一直都在」)。
- **音乐**:原作的音乐是页面外挂的 SoundCloud 流,shader 并未采样,故"音乐变缓"
  以光点出现后画面节奏整体放慢代替;想听音乐可自行播放 *So Electric*。

`?zen=1` 依旧可用:不撞障碍、只收集光点,适合当纯氛围屏保。

## 三幕天空(mood 驱动)

天空随 mood 经历三幕过渡(全部 smoothstep 渐变,无硬切):

| 幕 | mood | 天空 |
| --- | --- | --- |
| 第一幕 · 落日 | 0 ~ 0.3 | 原版:粉紫渐变 + 条纹落日 + 稀疏星光 |
| 第二幕 · 渐夜 | 0.3 ~ 0.6 | 天空渐入深蓝紫,落日仍在,星星渐密渐亮 |
| 第三幕 · 安详 | 0.6 ~ 1.0 | 深蓝星空满布(星星变慢、变柔、缓缓飘移)+ 极光波动光带(青绿→粉)+ 地平线云海慢速漂移;条纹落日渐渐隐去 |

**车辆尾迹**:mood 越高尾迹越长(几何延伸)、越柔、越扁——像一条丝带;
颜色同步演变:亮橙(mood 低)→ 青粉 → 暖白(mood 高),辉光衰减也随之变慢。

**粒子(星星)**:mood 越高闪烁越慢、边缘越柔,并整体缓缓飘移。

说明:zen 贴墙视角下相机略有俯角,极光带主要出现在画面顶部边缘;
正面视角(如待机画面转向)时天空层次最完整。

## 柔雾与落日柔光

mood 越高,世界越"柔":

- **体积雾**:雾色随 mood 从粉红转向暖白粉紫,并叠加加法柔光;遮挡雾的密度
  仍受 serenity 反向调节(焦虑时雾浊,安详时雾化作发光的薄霭)。
- **落日**:日晕半径随 mood 扩大、边缘呼吸软化为柔边,日晕更亮更弥散;
  落日方向光的照明随之变柔。
- **Bloom**:全场景辉光强度随 mood 增强至 1.9 倍,BufferC 的柔光模糊半径
  同步增大(×0.8 → ×1.25)。
- **远景虚化(廉价 DOF)**:mood 高时画面上方(远方)渐渐被粉白柔雾罩住,
  越远越虚。

## 心情速度递减

行进速度由 mood 驱动:`speed 因子 = mix(1.0, 0.45, mood)`——心情越安详,
速度感越慢(mood=1 时降到原速的 45%),但永远不为 0,画面始终在前进。
BufferA 的 updateGame 同时接收 mood(演示模式与游戏模式都受影响);
原作"越跑越快"的里程加速逻辑保留,两者相乘形成先快后慢的整体节奏。

实测:mood 0.13 时约 3.3 格/秒,mood 0.80 时约 2.8 格/秒(与理论值一致)。

## 三阶段心情调色板(mood)

游戏内置随旅程演变的全局心情变量 `mood`(0.0 → 1.0),存在 BufferA 状态区
(像素 (3,0).z),随行进里程缓慢滋养、每吃一枚金币加速,并以约 1 秒时间常数
平滑逼近目标值;撞车回待机后里程清零,mood 也会缓缓回落。

| 阶段 | mood | 色调 |
| --- | --- | --- |
| 想逃 | 0 ~ 0.3 | 原版:橙紫、红橙、高对比 synthwave |
| 逃 | 0.3 ~ 0.6 | 蓝紫、青粉、饱和度渐降 |
| 安详地逃 | 0.6 ~ 1.0 | 暖白、青、粉、低对比、柔光提亮 |

调色在 BufferC 中实现(bloom 之后、HUD 文字之前),全部使用
`smoothstep` 阶段权重 + `mix`/色相旋转(YIQ)渐变,无硬切;文字保持白色
不受染色。全屏变化可用调节面板的「游戏速度」加快 mood 演化来观察。

## 版本管理

两种方式回到之前的版本:

**① 面板「旅程版本」下拉(即时切换)**

调节面板顶部的版本下拉可在各阶段间任意切换,即时重编译、游戏进度不丢失:

`v0 经典复刻(原作)` → `v1 安详文案` → `v2 心情调色` → `v3 速度递减` →
`v4 安详光点` → `v5 安详值系统` → `v6 柔雾与落日柔光` →
`v7 完整安详版`。低版本会自动带上它依赖的层(如光点依赖速度系统)。
也可用 URL 参数 `?ver=v0` 直接打开指定版本。

**② 文件快照(versions\ 目录)**

```powershell
powershell -ExecutionPolicy Bypass -File versions.ps1 save "改动说明"   # 保存快照
powershell -ExecutionPolicy Bypass -File versions.ps1 list              # 列出快照
powershell -ExecutionPolicy Bypass -File versions.ps1 restore "快照名"  # 恢复(当前状态自动备份)
```

恢复前会自动把当前状态备份为 `*-auto-backup-*` 快照,不会丢档。

## 效果调节面板

页面右上角有「⚙ 效果调节」面板,点击标题可折叠:

**效果开关**(切换后自动重编译 shader,约 1 秒,游戏进度不丢失):

反射、体积光、FXAA 抗锯齿、调色、噪点纹理、宽银幕黑边、游戏界面,以及调试用的
FPS 计数 / 2D 调试图 / 相机调试 / 固定相机。对应原作 Common 选项卡顶部的
`#define` 开关。

**参数滑块**(拖动即时生效,默认值 = 原版行为):

| 参数 | 范围 | 说明 |
| --- | --- | --- |
| 画面比例 | 1.33 ~ 3.2 | 宽银幕黑边高度(原作 2.39) |
| 噪点强度 | 0 ~ 1 | 胶片噪点(原作 0.2) |
| 泛光模糊 | 0.2 ~ 3 | bloom 模糊半径倍率 |
| 色差强度 | 0 ~ 3 | RGB 色散(原作 1,0 关闭) |
| 镜头畸变 | 0 ~ 0.5 | 桶形畸变(原作 0.1) |
| 暗角强度 | 0 ~ 1 | 四角压暗(原作 1) |
| 游戏速度 | 0.1 ~ 4 | 前进速度倍率 |

「恢复默认」一键还原全部开关与滑块。也可在控制台用
`SunsetFX.setParam("u_chroma", 2)` / `SunsetFX.setMacro("VOLUMETRICS", false)` 脚本化控制。

实现方式:`shaders/*.glsl` 保持原作源码不动,runtime 在编译时做源码级替换——
宏开关通过注释/恢复 `#define` 行后重编译;连续参数把常量替换为注入的
`uniform`(如 `const float g_forceRatio = 2.39` → `uniform float g_forceRatio`),
每帧传入当前值。

## 调试参数(学习用)

runtime.js 内置了几个只读调试开关,均通过 URL 参数激活,不影响正常运行:

| 参数 | 作用 |
| --- | --- |
| `?pass=BufferA..D` | 把某个中间 Buffer 的输出直接显示到屏幕 |
| `?probe=1` | 在控制台/`window.__probe` 输出各通道前两帧的纹理单元绑定 |
| `?patch=...` | 对 BufferC 源码注入调试插桩(排查文字/采样问题用) |

## 与原版的已知差异

1. 背景音乐未本地化(如上所述,shader 未采样音频,无画面差异)。
2. 分辨率取 `window 尺寸 × devicePixelRatio`;窗口大小改变时缓冲会重建,
   游戏从 splash 重新开始(Shadertoy 上改变窗口也有类似表现)。
