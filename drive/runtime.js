"use strict";

/*
 * 迷你 Shadertoy 运行时 —— 仅为复刻与改编 "Sunset Drive Unlimited" (shadertoy wtS3W3) 实现所需子集。
 * 原作: Sunset Drive Unlimited by spolsh (Michal Klos), CC BY-NC-SA 3.0
 *
 * - WebGL2 (#version 300 es),每个通道的片元源码 = Shadertoy 头 + Common 选项卡 + 通道源码 + main 包装
 * - Buffer 通道双缓冲 ping-pong:自引用通道读到上一帧输出;按列表顺序渲染,
 *   因此排在后面的 Buffer 读到前面 Buffer 的本帧输出(与 Shadertoy 行为一致)
 * - 键盘输入 = 256x2 的 R8 纹理:第 0 行为按键按下状态,第 1 行为 toggle 状态
 * - 音频输入(iChannel3)以 512x2 静音纹理代替 —— 原 shader 实际并未采样该通道,
 *   配乐由 music.js 用 Web Audio 程序合成
 * - 改编层(文案/调色/速度/光点/碎片反馈/安详值/柔雾/三幕天空)以补丁形式按
 *   「旅程版本」启用,见 VERSION_PRESETS 与面板下拉
 */

// Shadertoy 统一注入的 uniform 头
const FRAG_HEADER = `#version 300 es
precision highp float;
precision highp int;
uniform vec3      iResolution;
uniform float     iTime;
uniform float     iTimeDelta;
uniform float     iFrameRate;
uniform int       iFrame;
uniform float     iChannelTime[4];
uniform vec3      iChannelResolution[4];
uniform vec4      iMouse;
uniform vec4      iDate;
uniform float     iSampleRate;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;
out vec4          outColor;
`;

const FRAG_WRAPPER = `
void main() { mainImage(outColor, gl_FragCoord.xy); }
`;

const VERT_SRC = `#version 300 es
void main() {
    vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}`;

// 通道连接关系(对应原作的 iChannel 绑定与采样器设置)
const PASSES = [
  {
    name: "BufferA", file: "shaders/bufferA.glsl",
    inputs: [
      { channel: 0, buffer: "BufferA", filter: "linear", wrap: "clamp" },
      { channel: 1, keyboard: true, filter: "linear", wrap: "clamp" },
    ],
  },
  {
    name: "BufferB", file: "shaders/bufferB.glsl",
    inputs: [
      { channel: 0, buffer: "BufferA", filter: "linear", wrap: "clamp" },
      { channel: 1, texture: "textures/tex_noise.png", filter: "mipmap", wrap: "repeat" },
      { channel: 2, texture: "textures/tex_font.png", filter: "mipmap", wrap: "repeat" },
    ],
  },
  {
    name: "BufferC", file: "shaders/bufferC.glsl",
    inputs: [
      { channel: 0, buffer: "BufferB", filter: "linear", wrap: "clamp" },
      { channel: 1, buffer: "BufferA", filter: "nearest", wrap: "clamp" },
      { channel: 3, texture: "textures/tex_abc.png", filter: "linear", wrap: "clamp" },
    ],
  },
  {
    name: "BufferD", file: "shaders/bufferD.glsl",
    inputs: [
      { channel: 0, buffer: "BufferC", filter: "nearest", wrap: "clamp" },
    ],
  },
  {
    name: "Image", file: "shaders/image.glsl",
    inputs: [
      { channel: 0, buffer: "BufferD", filter: "nearest", wrap: "clamp" },
      { channel: 3, audio: true, filter: "linear", wrap: "clamp" },
    ],
  },
];

const COMMON_FILE = "shaders/common.glsl";

// 诊断补丁:仅当 URL 带 ?patch=<key> 时应用(不影响正常运行)
const DEBUG_PATCHES = {
  glyphcode: {
    file: "shaders/bufferC.glsl",
    pairs: [
      { from: "float titleText( vec2 p )", to: "float g_dbgC = 0.0; float g_dbgSDF = 0.0;\nfloat titleText( vec2 p )" },
      { from: "float sdf = textSDF( p, c );\n    return ( c != 0. ) ? smoothstep( -.05, +.05, sdf ) : 1.0;\n}",
        to: "float sdf = textSDF( p, c );\n    g_dbgC = c; g_dbgSDF = sdf;\n    return ( c != 0. ) ? smoothstep( -.05, +.05, sdf ) : 1.0;\n}" },
      { from: "color.rgb = mix( vec3( 1.0 ), color.rgb, maskTitle );",
        to: "color.rgb = mix( vec3( 1.0 ), color.rgb, maskTitle ); color.rgb = vec3( 0.5 + 0.5 * g_dbgSDF, fract( g_dbgC / 16.0 ), step( 0.5, maskTitle ) );" },
    ],
  },
};

// ---- 改编层补丁:按「旅程版本」启用(面板「旅程版本」下拉,或 URL ?ver=v0..v7)----
// ---- 效果开关:切换时重编译 shader(Common 选项卡的 #define)----
const MACROS = [
  { name: "REFLECTIONS",  label: "反射(吃 GPU)", on: true },
  { name: "VOLUMETRICS",  label: "体积光(吃 GPU)", on: true },
  { name: "FXAA",         label: "FXAA 抗锯齿", on: true },
  { name: "GRADE",        label: "调色", on: true },
  { name: "NOISE",        label: "噪点纹理", on: true },
  { name: "FORCED_RATIO", label: "宽银幕黑边", on: true },
  { name: "SHOW_UI",      label: "游戏界面", on: true },
  { name: "FPS_COUNTER",  label: "FPS 计数(调试)", on: false },
  { name: "DEBUG_2D",     label: "2D 调试图(调试)", on: false },
  { name: "DEBUG_CAMERA", label: "相机调试(调试)", on: false },
  { name: "CAM_STICKED",  label: "固定相机(调试)", on: false },
];
MACROS.forEach(m => m.def = m.on); // 记录默认状态,供"恢复默认"使用

const FEAT_KEYS = ["text", "palette", "speed", "orbs", "fail", "serenity", "glow", "sky"];
const VERSION_PRESETS = [
  { name: "v7", label: "v7 完整安详版(当前)", feat: { text: 1, palette: 1, speed: 1, orbs: 1, fail: 1, serenity: 1, glow: 1, sky: 1 } },
  { name: "v6", label: "v6 柔雾与落日柔光", feat: { text: 1, palette: 1, speed: 1, orbs: 1, fail: 1, serenity: 1, glow: 1, sky: 0 } },
  { name: "v5", label: "v5 安详值系统", feat: { text: 1, palette: 1, speed: 1, orbs: 1, fail: 1, serenity: 1, glow: 0, sky: 0 } },
  { name: "v4", label: "v4 安详光点", feat: { text: 1, palette: 1, speed: 1, orbs: 1, fail: 1, serenity: 0, glow: 0, sky: 0 } },
  { name: "v3", label: "v3 速度递减", feat: { text: 1, palette: 1, speed: 1, orbs: 0, fail: 1, serenity: 0, glow: 0, sky: 0 } },
  { name: "v2", label: "v2 心情调色", feat: { text: 1, palette: 1, speed: 0, orbs: 0, fail: 1, serenity: 0, glow: 0, sky: 0 } },
  { name: "v1", label: "v1 安详文案", feat: { text: 1, palette: 0, speed: 0, orbs: 0, fail: 1, serenity: 0, glow: 0, sky: 0 } },
  { name: "v0", label: "v0 经典复刻(原作)", feat: { text: 0, palette: 0, speed: 0, orbs: 0, fail: 0, serenity: 0, glow: 0, sky: 0 } },
];
let currentVersion = "v7";

function currentFeat() {
  const sel = document.getElementById("ver-select");
  const urlV = new URLSearchParams(location.search).get("ver");
  const name = (sel && sel.value) || urlV || currentVersion || "v7";
  const p = VERSION_PRESETS.find(x => x.name === name) || VERSION_PRESETS[0];
  const f = { ...p.feat };
  // 依赖钳制:后层依赖前层的变量声明
  if (f.orbs) f.speed = true;
  if (f.speed || f.orbs || f.serenity || f.glow || f.fail) f.palette = true;
  return { name: p.name, feat: f };
}

function buildThemePatches(f) {
  const P = [];
  const add = (file, from, to) => P.push({ file, from, to });

  // ---- 第 1 步:安详文案 ----
  if (f.text) {
    add("shaders/bufferC.glsl", "v = t.y == 0. ? ( t.x < 4. ? 1397642579u : ( t.x < 8. ? 1142969413u : ( t.x < 12. ? 1163282770u : ( t.x < 16. ? 1280202016u : ( t.x < 20. ? 1414090057u : 17477u ) ) ) ) ) : v;",
      "v = t.y == 0. ? ( t.x < 4. ? 1163019603u : ( t.x < 8. ? 1159742798u : ( t.x < 12. ? 1346454355u : ( t.x < 16. ? 1314201669u : ( t.x < 20. ? 1229801804u : 4474196u ) ) ) ) ) : v;");
    add("shaders/bufferC.glsl", "v = t.y == 0. ? ( t.x < 4. ? 1936028240u : ( t.x < 8. ? 1935351923u : ( t.x < 12. ? 1701011824u : ( t.x < 16. ? 1869881437u : ( t.x < 20. ? 1635021600u : 29810u ) ) ) ) ) : v;",
      "v = t.y == 0. ? ( t.x < 4. ? 1768383842u : ( t.x < 8. ? 1752637550u : ( t.x < 12. ? 1914728037u : ( t.x < 16. ? 2036621669u : 0u ) ) ) ) : v;");
    add("shaders/bufferC.glsl", "v = t.y == 0. ? ( t.x < 4. ? 1751607624u : ( t.x < 8. ? 1919902579u : 14949u ) ) : v;",
      "v = t.y == 0. ? ( t.x < 4. ? 544567129u : ( t.x < 8. ? 543519329u : ( t.x < 12. ? 1701208435u : 2003791392u ) ) ) : v;");
    add("shaders/bufferC.glsl", "v = t.x >= 0. && t.x < 12. ? v : 0u;",
      "v = t.x >= 0. && t.x < 16. ? v : 0u;");
    add("shaders/bufferC.glsl", "float sScore = printInt( pScore, s.score );",
      "float sScore = 0.0;");
  }

  // ---- 第 2 步:mood 调色(声明 mood,供后续层使用)----
  if (f.palette) {
    add("shaders/bufferA.glsl", "loadState( iChannel0, s );",
      "loadState( iChannel0, s );\n    float mood = loadValue( iChannel0, 3, 0 ).z;");
    add("shaders/bufferC.glsl", "loadState( iChannel1, s );",
      "loadState( iChannel1, s );\n    float moodC = texelFetch( iChannel1, ivec2( 3, 0 ), 0 ).z;");
    add("shaders/bufferC.glsl", "void mainImage( out vec4 fragColor, in vec2 fragCoord )",
      `vec3 sereneHueRotate( vec3 col, float a )
{
    vec3 yiq = vec3(
        dot( col, vec3( 0.299, 0.587, 0.114 ) ),
        dot( col, vec3( 0.596, -0.274, -0.322 ) ),
        dot( col, vec3( 0.211, -0.523, 0.312 ) ) );
    float h = atan( yiq.z, yiq.y ) + a;
    float chr = length( yiq.yz );
    return vec3(
        yiq.x + 0.956 * chr * cos( h ) + 0.621 * chr * sin( h ),
        yiq.x - 0.272 * chr * cos( h ) - 0.647 * chr * sin( h ),
        yiq.x - 1.106 * chr * cos( h ) + 1.703 * chr * sin( h ) );
}

vec3 applyMood( vec3 c, float mood )
{
    float p2 = smoothstep( 0.28, 0.58, mood );
    float p3 = smoothstep( 0.60, 0.94, mood );
    c = sereneHueRotate( c, p2 * -0.28 + p3 * 0.16 );
    float l = dot( c, vec3( 0.299, 0.587, 0.114 ) );
    c = mix( vec3( l ), c, 1.0 - p2 * 0.22 - p3 * 0.32 );
    c = ( c - 0.18 ) * ( 1.0 - p3 * 0.22 ) + 0.18 + p3 * 0.05;
    c += p2 * -0.030 * vec3( 1.0, 0.35, -0.35 );
    c += p3 * 0.035 * vec3( 1.0, 0.97, 0.92 );
    c += p3 * 0.020 * vec3( -0.2, 0.3, 0.6 );
    return c;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )`);
    let bc = "vec3 color = mix( beauty.rgb, blurred, blurMask );\n    color = applyMood( color, clamp( moodC, 0.0, 1.0 ) );";
    if (f.orbs) bc += "\n    color += 0.06 * exp( -2.5 * ( iTime - s.timeCollected ) ) * vec3( 0.75, 0.9, 1.0 );";
    if (f.fail) bc += "\n    color = mix( color, vec3( dot( color, vec3( 0.299, 0.587, 0.114 ) ) ), 0.75 * exp( -4.0 * ( iTime - max( s.timeFailed, -1.0 ) ) ) );";
    if (f.glow) bc += "\n    color = mix( color, mix( vec3( 0.92, 0.84, 0.97 ) * ( 0.55 + 0.45 * moodC ), vec3( 0.06, 0.06, 0.15 ), smoothstep( 0.55, 0.85, moodC ) ), moodC * 0.16 * smoothstep( 0.30, 0.95, uv.y ) );";
    add("shaders/bufferC.glsl", "vec3 color = mix( beauty.rgb, blurred, blurMask );", bc);
    add("shaders/bufferA.glsl", "fragColor = saveState( s, fragCoord, iFrame, iTime );",
      `fragColor = saveState( s, fragCoord, iFrame, iTime );
    {
        vec2 fcM = floor( fragCoord );
        float moodTarget = clamp( 0.10 + s.playerPos.y / 260.0 + s.score / 60.0, 0.0, 1.0 );
        mood = mix( mood, moodTarget, saturate( 1.2 * iTimeDelta ) );
        if ( fcM.x == 3.0 && fcM.y == 0.0 ) fragColor = vec4( s.paceScale, s.seed, mood, 1.0 );
    }`);
  }

  // ---- 第 3 步:速度随心情递减 ----
    // ---- 第 3 步:速度随心情递减(收集/碎片的呼吸因子按层叠加)----
  if (f.speed || f.orbs || f.fail) {
    add("shaders/bufferA.glsl", "AppState updateGame( AppState s, float isDemo )",
      "AppState updateGame( AppState s, float isDemo, float mood )");
    add("shaders/bufferA.glsl", "s = updateGame( s, 1.0 );", "s = updateGame( s, 1.0, mood );");
    add("shaders/bufferA.glsl", "s = updateGame( s, 0.0 );", "s = updateGame( s, 0.0, mood );");
    let fac = "mix( 1.0, 0.45, mood )";
    if (f.orbs) fac += " * ( 1.0 - 0.35 * exp( -3.0 * ( iTime - s.timeCollected ) ) )";
    if (f.fail) fac += " * ( 1.0 - 0.85 * exp( -5.0 * ( iTime - s.timeFailed ) ) )";
    add("shaders/bufferA.glsl", "s.timeAccumulated += 1.0 * u_speed * iTimeDelta;",
      `s.timeAccumulated += 1.0 * u_speed * ${fac} * iTimeDelta;`);
    add("shaders/bufferA.glsl", "s.timeAccumulated += timeMultiplier * u_speed * iTimeDelta;",
      `s.timeAccumulated += timeMultiplier * u_speed * ${fac} * iTimeDelta;`);
  }

  // ---- 柔雾与落日柔光(glow)----
  if (f.glow) {
    add("shaders/bufferB.glsl", "float gFogDensity\t\t= 0.1;",
      "float serN = texelFetch( iChannel0, ivec2( 3, 1 ), 0 ).x / 100.0;\n    float moodF = texelFetch( iChannel0, ivec2( 3, 0 ), 0 ).z;\n    float gFogDensity\t\t= 0.1 * mix( 1.0, 0.45, serN ) * mix( 0.85, 1.15, moodF );");
    add("shaders/bufferB.glsl", "vec3 fogColor = FOG_COLOR + vec3( 1.0 );",
      "vec3 fogColor = FOG_COLOR + vec3( 1.0 );\n    fogColor = mix( fogColor, vec3( 1.0, 0.84, 0.74 ) + vec3( 0.28, 0.18, 0.42 ), moodF * 0.40 );\n    color = mix( fogColor, color, fogAlpha );\n    color += fogColor * moodF * 0.07 * fogAlpha;");
    add("shaders/bufferB.glsl", "col.rgb = mix( col.rgb, FOG_COLOR, 1.0 - exp( -0.00005 * t * t * t ) );",
      "float serN2 = texelFetch( iChannel0, ivec2( 3, 1 ), 0 ).x / 100.0;\n    float moodF2 = texelFetch( iChannel0, ivec2( 3, 0 ), 0 ).z;\n    col.rgb = mix( col.rgb, mix( FOG_COLOR, vec3( 1.0, 0.84, 0.76 ), moodF2 * 0.6 ), ( 1.0 - exp( -0.00005 * t * t * t ) ) * mix( 1.0, 0.55, serN2 ) );");
    add("shaders/bufferB.glsl", "float sunGlow = smoothstep( 0.9, 1.0, dot( rd, sunDir ) );",
      "float moodSun = texelFetch( iChannel0, ivec2( 3, 0 ), 0 ).z;\n    float sunGlow = smoothstep( 0.9 - 0.22 * moodSun, 1.0, dot( rd, sunDir ) );");
    add("shaders/bufferB.glsl", "sun = smoothstep( 0.987, 0.99, dot(rd, sunDir ) );",
      "sun = smoothstep( 0.987 - 0.005 * moodSun, 0.99 + 0.004 * moodSun + 0.002 * moodSun * sin( 1.2 * iTime ), dot(rd, sunDir ) );");
    add("shaders/bufferB.glsl", "color = mix( color, sunCol, 0.25 * sunGlow );",
      "color = mix( color, sunCol, ( 0.25 + 0.4 * moodSun ) * sunGlow );");
    add("shaders/bufferB.glsl", "return bloom;",
      "float moodBl = texelFetch( iChannel0, ivec2( 3, 0 ), 0 ).z;\n    return bloom * ( 1.0 + 0.4 * moodBl );");
    add("shaders/bufferC.glsl", "scale = max( scale * u_bloom, 0.0 ) + 0.1;",
      "scale = max( scale * u_bloom * mix( 0.8, 1.25, moodC ), 0.0 ) + 0.1;");
  }

  // ---- 三幕天空与丝带尾迹(sky)----
  if (f.sky) {
    add("shaders/bufferB.glsl", "vec3 color = mix( SKY_COLOR_1 * 1.4, SKY_COLOR_2, rd.y / 9.0 );",
      `float moodK = texelFetch( iChannel0, ivec2( 3, 0 ), 0 ).z;
    float act2 = smoothstep( 0.30, 0.55, moodK );
    float act3 = smoothstep( 0.58, 0.88, moodK );
    vec3 color = mix( SKY_COLOR_1 * 1.4, SKY_COLOR_2, rd.y / 9.0 );
    vec3 nightSky = mix( vec3( 0.10, 0.06, 0.24 ), vec3( 0.03, 0.04, 0.13 ), clamp( rd.y * 1.6, 0.0, 1.0 ) );
    color = mix( color, nightSky * mix( 1.25, 0.85, act3 ), max( act2 * 0.7, act3 * 0.9 ) );`);
    add("shaders/bufferB.glsl", "stars *= step( 0.9, starRand.x );",
      "stars *= step( 0.9 - act3 * 0.38, starRand.x );");
    add("shaders/bufferB.glsl", "stars *= 5.0;", "stars *= 5.0 + 5.0 * act3;");
    add("shaders/bufferB.glsl", "float stars = saturate( 1.0 - ( ( sin( iTime * 1.0 + 50.0 * rd.y ) ) * 0.5 + 6.0 ) * length( starPos ) );",
      "float starSpd = mix( 1.0, 0.3, act3 );\n    vec2 starDrift = vec2( iTime * 0.010, iTime * 0.006 ) * act3;\n    float stars = saturate( 1.0 - ( ( sin( iTime * starSpd + 50.0 * rd.y ) ) * 0.5 + mix( 6.0, 4.2, act3 ) ) * length( starPos + starDrift ) );");
    add("shaders/bufferB.glsl", "sun = 2.0 * clamp( sun * stripes, 0.0, 1.0 );",
      "sun = 2.0 * clamp( sun * stripes, 0.0, 1.0 ) * ( 1.0 - act3 * 0.8 );");
    add("shaders/bufferB.glsl", "color += stars;",
      `if ( act3 > 0.01 )
    {
        vec2 ap = rd.xy * vec2( 3.0, 6.0 );
        float wave = sin( ap.x * 2.0 + iTime * 0.4 ) * 0.5 + sin( ap.x * 4.7 - iTime * 0.23 ) * 0.25;
        float band = rd.y - 0.10 - wave * 0.06;
        float aur = exp( -abs( band ) * 9.0 ) * ( 0.55 + 0.45 * sin( ap.x * 7.0 + iTime * 0.9 + wave * 4.0 ) );
        aur *= smoothstep( 0.02, 0.18, rd.y );
        vec3 aurCol = mix( vec3( 0.10, 0.90, 0.55 ), vec3( 0.85, 0.30, 0.80 ), 0.5 + 0.5 * sin( ap.x * 1.7 + iTime * 0.3 ) );
        color += aurCol * aur * act3 * 0.8;

        vec2 cp = rd.xz / max( rd.y, 0.06 ) * 0.35 + iTime * vec2( 0.020, 0.008 );
        vec2 cid = floor( cp ), cf = fract( cp );
        float n1 = mix( mix( hash22( cid ).x, hash22( cid + vec2( 1, 0 ) ).x, cf.x ),
                        mix( hash22( cid + vec2( 0, 1 ) ).x, hash22( cid + vec2( 1, 1 ) ).x, cf.x ), cf.y );
        float cl = smoothstep( 0.35, 0.75, n1 );
        float band2 = smoothstep( 0.03, 0.18, rd.y ) * smoothstep( 0.55, 0.25, rd.y );
        vec3 clCol = mix( vec3( 0.35, 0.28, 0.50 ), vec3( 0.98, 0.88, 0.94 ), cl );
        color = mix( color, clCol, act3 * band2 * ( 0.25 + 0.55 * cl ) );
    }
    color += stars;`);
    add("shaders/bufferB.glsl", "float bloomB = box( t + vec3( -4.4, -0.2, 0.0 ), vec3( 0.2, 0.4, 0.2 ) );",
      "float trailM = texelFetch( iChannel0, ivec2( 3, 0 ), 0 ).z;\n        float bloomB = box( t + vec3( -4.4 - 3.5 * trailM, -0.2, 0.0 ), vec3( 0.15 + 0.25 * trailM, 0.4 - 0.15 * trailM, 0.2 + 4.0 * trailM ) );");
    add("shaders/bufferB.glsl", "bloom += vec3( 1.0, 0.2, 0.0 )  * 1.0 * vec3( exp( -saturate(g_glowPlayer) * 10.0 ) );",
      "float trailMood = texelFetch( iChannel0, ivec2( 3, 0 ), 0 ).z;\n    vec3 trailCol = mix( vec3( 1.0, 0.25, 0.0 ), vec3( 0.30, 0.75, 0.90 ), smoothstep( 0.25, 0.55, trailMood ) );\n    trailCol = mix( trailCol, vec3( 1.0, 0.88, 0.75 ), smoothstep( 0.58, 0.90, trailMood ) );\n    bloom += trailCol * 1.0 * vec3( exp( -saturate(g_glowPlayer) * ( 10.0 - 5.5 * trailMood ) ) );");
    add("shaders/bufferB.glsl", "bloom += vec3( 1.0, 0.2, 0.0 )  * 0.5 * vec3( exp( -saturate(g_glowPlayerRefl) * 10.0 ) );",
      "bloom += trailCol * 0.5 * vec3( exp( -saturate(g_glowPlayerRefl) * ( 10.0 - 5.5 * trailMood ) ) );");
    add("shaders/bufferB.glsl", "color = mix( FOG_COLOR, color, 0.8 + 0.2 * fogFalloff );",
      "color = mix( FOG_COLOR, color, ( 0.8 + 0.2 * fogFalloff ) * ( 1.0 - act3 * 0.8 ) );");
  }

  return P;
}

// ?zen=1 调试模式:撞车判定置为永假 —— 无尽禅意驾驶,用于观察提示文案
const ZEN_PATCHES = [
  { file: "shaders/bufferA.glsl", from: "distObstaclePlayer < 0.5 && isDemo < 1.0",
    to: "distObstaclePlayer < -1.0 && isDemo < 1.0" },
];

// ---- 参数滑块(恒定启用;默认值 = 原版行为)----
const PARAM_PATCHES = [
  { file: "shaders/common.glsl", from: "const float g_forceRatio = 2.39;",
    to: "uniform float g_forceRatio;" },
  { file: "shaders/image.glsl", from: "0.8 + 0.2 * hash22",
    to: "1.0 - u_noise + u_noise * hash22" },
  { file: "shaders/bufferC.glsl", from: "scale += 0.1;",
    to: "scale = max( scale * u_bloom, 0.0 ) + 0.1;" },
  { file: "shaders/bufferD.glsl", from: "float scale = 1.0;",
    to: "float scale = u_chroma;" },
  { file: "shaders/bufferD.glsl", from: "barrelDistortion( uv, 0.1, 0.97 )",
    to: "barrelDistortion( uv, u_barrel, 0.97 )" },
  { file: "shaders/bufferD.glsl", from: "color.rgb *= 0.7 + 0.3 * clamp( pow( 28.0",
    to: "color.rgb *= 1.0 - u_vignette * 0.3 + u_vignette * 0.3 * clamp( pow( 28.0" },
  { file: "shaders/bufferA.glsl", from: "s.timeAccumulated += 1.0 * iTimeDelta;",
    to: "s.timeAccumulated += 1.0 * u_speed * iTimeDelta;" },
  { file: "shaders/bufferA.glsl", from: "s.timeAccumulated += timeMultiplier * iTimeDelta;",
    to: "s.timeAccumulated += timeMultiplier * u_speed * iTimeDelta;" },
];
const PARAM_UNIFORMS = "\nuniform float u_noise;\nuniform float u_bloom;\nuniform float u_chroma;\nuniform float u_barrel;\nuniform float u_vignette;\nuniform float u_speed;\n";
const PARAMS = [
  { uniform: "g_forceRatio", label: "画面比例", min: 1.33, max: 3.2, step: 0.01, def: 2.39 },
  { uniform: "u_noise", label: "噪点强度", min: 0, max: 1, step: 0.01, def: 0.2 },
  { uniform: "u_bloom", label: "泛光模糊", min: 0.2, max: 3, step: 0.05, def: 1 },
  { uniform: "u_chroma", label: "色差强度", min: 0, max: 3, step: 0.05, def: 1 },
  { uniform: "u_barrel", label: "镜头畸变", min: 0, max: 0.5, step: 0.005, def: 0.1 },
  { uniform: "u_vignette", label: "暗角强度", min: 0, max: 1, step: 0.01, def: 1 },
  { uniform: "u_speed", label: "游戏速度", min: 0.1, max: 4, step: 0.05, def: 1 },
];
const paramState = {};
PARAMS.forEach(p => paramState[p.uniform] = p.def);

let gl, canvas;
let floatLinearOK = true;
let buffers = {};          // name -> { desc, program, uni, tex[2], fbo[2], cur }
let imagePass = null;
let keyboardTex, keyboardData, audioTex;
let pngTextures = {};      // file -> { tex, w, h }
let W = 1, H = 1;

const runState = {
  frame: 0,
  time: 0,
  lastNow: 0,
  fpsSmooth: 60,
  frameDelta: 0.016,
  mouse: { x: 0, y: 0, ox: 0, oy: 0, down: false },
  keyboardDirty: false,
};

// ---------------------------------------------------------------- 工具

function showError(msg) {
  const el = document.getElementById("error");
  el.hidden = false;
  el.textContent = msg;
  console.error(msg);
}

function glErrorName(e) {
  const names = { 1280: "INVALID_ENUM", 1281: "INVALID_VALUE", 1282: "INVALID_OPERATION", 1283: "STACK_OVERFLOW", 1284: "STACK_UNDERFLOW", 1285: "OUT_OF_MEMORY", 1286: "INVALID_FRAMEBUFFER_OPERATION", 1287: "CONTEXT_LOST" };
  return names[e] || String(e);
}

let glErrorReported = 0;
function checkGLError(where) {
  const e = gl.getError();
  if (e !== gl.NO_ERROR && glErrorReported < 40) {
    glErrorReported++;
    console.warn(`[GL] ${where}: ${glErrorName(e)}`);
    (window.__glErrors = window.__glErrors || []).push(`${where}: ${glErrorName(e)}`);
  }
}

function compileShader(type, src, label) {
  const sh = gl.createShader(type);
  gl.shaderSource(sh, src);
  gl.compileShader(sh);
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(sh);
    if (type === gl.FRAGMENT_SHADER) { window.__lastFragSrc = src; window.__lastFragLabel = label; }
    showError(`着色器编译失败 [${label}]:\n${log}`);
    throw new Error(log);
  }
  return sh;
}

function linkProgram(fragSrc, label) {
  const vs = compileShader(gl.VERTEX_SHADER, VERT_SRC, label + " vertex");
  const fs = compileShader(gl.FRAGMENT_SHADER, fragSrc, label);
  const prog = gl.createProgram();
  gl.attachShader(prog, vs);
  gl.attachShader(prog, fs);
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
    window.__lastFragSrc = fragSrc;
    window.__lastFragLabel = label;
    const log = gl.getProgramInfoLog(prog);
    showError(`着色器链接失败 [${label}]:\n${log}`);
    throw new Error(log);
  }
  return prog;
}

function createColorTexture(w, h, mipmap) {
  const tex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, tex);
  // 32 位浮点:状态量(timeAccumulated / serenity / mood 等)随时间无限增长,
  // 半精度会在大数值区间把每帧小增量舍入吞掉
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, w, h, 0, gl.RGBA, gl.FLOAT, null);
  const f = floatLinearOK ? gl.LINEAR : gl.NEAREST;
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, mipmap && floatLinearOK ? gl.LINEAR_MIPMAP_LINEAR : f);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, f);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  return tex;
}

// 采样器对象:同一 buffer 纹理在不同通道以不同 filter 被引用,靠 sampler 对象区分
function makeSampler(filter, wrap) {
  const s = gl.createSampler();
  if (!floatLinearOK) filter = "nearest";
  const mag = filter === "nearest" ? gl.NEAREST : gl.LINEAR;
  const min = filter === "nearest" ? gl.NEAREST
    : filter === "mipmap" ? gl.LINEAR_MIPMAP_LINEAR
    : gl.LINEAR;
  const w = wrap === "repeat" ? gl.REPEAT : gl.CLAMP_TO_EDGE;
  gl.samplerParameteri(s, gl.TEXTURE_MIN_FILTER, min);
  gl.samplerParameteri(s, gl.TEXTURE_MAG_FILTER, mag);
  gl.samplerParameteri(s, gl.TEXTURE_WRAP_S, w);
  gl.samplerParameteri(s, gl.TEXTURE_WRAP_T, w);
  return s;
}

async function loadImage(file) {
  const resp = await fetch(file);
  if (!resp.ok) throw new Error(`纹理加载失败: ${file} (HTTP ${resp.status})`);
  const blob = await resp.blob();
  // 此环境下 UNPACK_FLIP_Y_WEBGL 对 ImageBitmap 上传不生效,须在解码阶段翻转(原通道 vflip: true)
  const bmp = await createImageBitmap(blob, { imageOrientation: "flipY" });
  return bmp;
}

// ---------------------------------------------------------------- 初始化

function initGL() {
  canvas = document.getElementById("canvas");
  gl = canvas.getContext("webgl2", {
    antialias: false,
    alpha: false,
    depth: false,
    stencil: false,
    powerPreference: "high-performance",
  });
  if (!gl) {
    showError("此浏览器不支持 WebGL 2,无法运行。");
    throw new Error("no webgl2");
  }
  gl.bindVertexArray(gl.createVertexArray());
  // 原作启用了 float buffer(flags 位 64)。32 位浮点:状态量随时间无限增长,
  // 8bit 会钳制在 [0,1]、半精度会把大数值区间的小增量舍入吞掉
  if (!gl.getExtension("EXT_color_buffer_float")) {
    showError("缺少 EXT_color_buffer_float 扩展,无法渲染浮点缓冲。");
  }
  floatLinearOK = !!gl.getExtension("OES_texture_float_linear");
}

function applyMacroSwitches(src) {
  for (const m of MACROS) {
    src = src.replace(new RegExp("^(\\/\\/\\s*)?#define\\s+" + m.name + "\\b", "m"),
      () => m.on ? "#define " + m.name : "// #define " + m.name);
  }
  return src;
}

function applyParamPatches(file, src, themePatches) {
  const zen = new URLSearchParams(location.search).has("zen");
  for (const p of PARAM_PATCHES) {
    if (p.file !== file) continue;
    if (!src.includes(p.from)) throw new Error("参数补丁未命中: " + p.from.slice(0, 48));
    src = src.replace(p.from, p.to);
  }
  for (const p of themePatches) {
    if (p.file !== file) continue;
    if (!src.includes(p.from)) throw new Error("主题补丁未命中: " + p.from.slice(0, 48));
    src = src.replace(p.from, p.to);
  }
  if (zen) {
    for (const p of ZEN_PATCHES) {
      if (p.file !== file) continue;
      if (!src.includes(p.from)) throw new Error("zen 补丁未命中: " + p.from.slice(0, 48));
      src = src.replace(p.from, p.to);
    }
  }
  return src;
}

const rawSources = { common: "", passes: {} };

// 编译全部通道并原子替换(全部成功才替换,失败保留当前画面)
function buildAll() {
  const themePatches = buildThemePatches(currentFeat().feat);
  const commonSrc = applyParamPatches(COMMON_FILE, applyMacroSwitches(rawSources.common), themePatches);
  const built = [];
  for (const desc of PASSES) {
    let passSrc = applyParamPatches(desc.file, rawSources.passes[desc.name], themePatches);
    const patchKey = new URLSearchParams(location.search).get("patch");
    const patch = patchKey ? DEBUG_PATCHES[patchKey] : null;
    if (patch && desc.file === patch.file) {
      for (const p of patch.pairs) {
        if (!passSrc.includes(p.from)) throw new Error(`诊断补丁 ${patchKey} 未命中目标文本: ${p.from.slice(0, 40)}`);
        passSrc = passSrc.replace(p.from, p.to);
      }
    }
    const frag = FRAG_HEADER + PARAM_UNIFORMS + commonSrc + "\n" + passSrc + "\n" + FRAG_WRAPPER;
    const program = linkProgram(frag, desc.name);
    const uniformCache = {};
    const uni = (n) => {
      if (!(n in uniformCache)) uniformCache[n] = gl.getUniformLocation(program, n);
      return uniformCache[n];
    };
    built.push({ desc, program, uni });
  }
  // 全部编译成功,替换旧 program
  for (const b of built) {
    let entry = b.desc.name === "Image" ? imagePass : buffers[b.desc.name];
    if (!entry) {
      entry = { desc: b.desc, tex: [null, null], fbo: [null, null], cur: 1 };
      for (const inp of entry.desc.inputs) inp.sampler = makeSampler(inp.filter, inp.wrap);
      if (b.desc.name === "Image") imagePass = entry;
      else buffers[b.desc.name] = entry;
    } else {
      gl.deleteProgram(entry.program);
    }
    entry.desc = b.desc;
    entry.program = b.program;
    entry.uni = b.uni;
  }
}

function rebuildShaders() {
  try {
    buildAll();
    const el = document.getElementById("error");
    if (el) { el.hidden = true; el.textContent = ""; }
    const note = document.getElementById("rebuild-note");
    if (note) { note.textContent = "已重新编译 ✓"; setTimeout(() => { note.textContent = ""; }, 1500); }
  } catch (e) {
    showError("重编译失败,已保留原画面:\n" + (e && e.message || e));
  }
}

async function loadAndCompile() {
  rawSources.common = await (await fetch(COMMON_FILE)).text();
  for (const desc of PASSES) {
    rawSources.passes[desc.name] = await (await fetch(desc.file)).text();
  }
  buildAll();
}

function initStaticTextures() {
  // 键盘纹理:256 x 2,行 0 = 按下,行 1 = toggle
  keyboardData = new Uint8Array(256 * 2);
  keyboardTex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, keyboardTex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, 256, 2, 0, gl.RED, gl.UNSIGNED_BYTE, keyboardData);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

  // 音频纹理:512 x 2 全零(原 shader 未采样 iChannel3)
  audioTex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, audioTex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, 512, 2, 0, gl.RED, gl.UNSIGNED_BYTE, new Uint8Array(512 * 2));
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
}

async function loadPngTextures() {
  const files = new Set();
  for (const desc of PASSES) for (const inp of desc.inputs) if (inp.texture) files.add(inp.texture);
  for (const file of files) {
    const bmp = await loadImage(file);
    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, bmp);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    const needsMip = PASSES.some((p) => p.inputs.some((i) => i.texture === file && i.filter === "mipmap"));
    if (needsMip) {
      gl.generateMipmap(gl.TEXTURE_2D);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    }
    pngTextures[file] = { tex, w: bmp.width, h: bmp.height };
    bmp.close && bmp.close();
  }
}

// ---------------------------------------------------------------- 输入

function updateKeyboardTexture() {
  gl.bindTexture(gl.TEXTURE_2D, keyboardTex);
  gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, 256, 2, gl.RED, gl.UNSIGNED_BYTE, keyboardData);
}

function bindInputEvents() {
  window.addEventListener("keydown", (e) => {
    // 焦点在调节面板控件上时,按键归面板(方向键调 slider、空格切开关),不影响游戏
    if (e.target && e.target.closest && e.target.closest("#panel")) return;
    if (window.SunsetMusic) window.SunsetMusic.start(); // 首次交互启动配乐(浏览器自动播放策略)
    if ([32, 37, 38, 39, 40].includes(e.keyCode)) e.preventDefault();
    const k = e.keyCode & 0xff;
    if (!e.repeat) {
      keyboardData[k] = 255;                      // 行 0:按下
      keyboardData[256 + k] = keyboardData[256 + k] ? 0 : 255; // 行 1:toggle
      runState.keyboardDirty = true;
    }
  });
  window.addEventListener("keyup", (e) => {
    const k = e.keyCode & 0xff;
    if (keyboardData[k]) {
      keyboardData[k] = 0;
      runState.keyboardDirty = true;
    }
  });

  const toLocal = (e) => {
    const r = canvas.getBoundingClientRect();
    const s = W / r.width;
    return [Math.round((e.clientX - r.left) * s), Math.round(H - (e.clientY - r.top) * s)];
  };
  canvas.addEventListener("mousedown", (e) => {
    const [x, y] = toLocal(e);
    runState.mouse.down = true;
    runState.mouse.x = runState.mouse.ox = x;
    runState.mouse.y = runState.mouse.oy = y;
  });
  window.addEventListener("mousemove", (e) => {
    if (!runState.mouse.down) return;
    const [x, y] = toLocal(e);
    runState.mouse.x = x;
    runState.mouse.y = y;
  });
  window.addEventListener("mouseup", () => {
    runState.mouse.down = false;
    runState.mouse.ox = runState.mouse.oy = 0;
  });
}

// ---------------------------------------------------------------- 渲染

function setUniforms(entry, w, h) {
  const u = entry.uni;
  gl.uniform3f(u("iResolution"), w, h, 1.0);
  gl.uniform1f(u("iTime"), runState.time);
  gl.uniform1f(u("iTimeDelta"), runState.frameDelta);
  gl.uniform1f(u("iFrameRate"), runState.fpsSmooth);
  gl.uniform1i(u("iFrame"), runState.frame);
  gl.uniform4f(u("iMouse"),
    runState.mouse.x, runState.mouse.y, runState.mouse.ox, runState.mouse.oy);

  const d = new Date();
  gl.uniform4f(u("iDate"),
    d.getFullYear(), d.getMonth() + 1, d.getDate(),
    d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds() + d.getMilliseconds() / 1000);
  gl.uniform1f(u("iSampleRate"), 44100.0);
  gl.uniform1fv(u("iChannelTime"), [0, 0, 0, 0]);

  const res = new Float32Array(12).fill(0);
  const setRes = (c, tw, th) => { res[c * 3] = tw; res[c * 3 + 1] = th; res[c * 3 + 2] = 1; };
  for (const inp of entry.desc.inputs) {
    if (inp.buffer) setRes(inp.channel, W, H);
    else if (inp.keyboard) setRes(inp.channel, 256, 2);
    else if (inp.audio) setRes(inp.channel, 512, 2);
    else if (inp.texture) { const t = pngTextures[inp.texture]; setRes(inp.channel, t.w, t.h); }
  }
  gl.uniform3fv(u("iChannelResolution"), res);

  // 可调参数(未使用的 uniform 会被编译器剔除,location 为 null 时调用无效但不报错)
  for (const p of PARAMS) gl.uniform1f(u(p.uniform), paramState[p.uniform]);
}

function bindInputs(entry) {
  for (const inp of entry.desc.inputs) {
    // 关键:sampler uniform 默认指向 unit 0,必须显式把 iChannelN 指向 unit N
    gl.uniform1i(entry.uni("iChannel" + inp.channel), inp.channel);
    gl.activeTexture(gl.TEXTURE0 + inp.channel);
    let tex = null;
    if (inp.buffer) {
      const bp = buffers[inp.buffer];
      tex = bp.tex[bp.cur];
    } else if (inp.keyboard) tex = keyboardTex;
    else if (inp.audio) tex = audioTex;
    else if (inp.texture) tex = pngTextures[inp.texture].tex;
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.bindSampler(inp.channel, inp.sampler);
  }
}

function renderPass(entry, targetFbo, w, h) {
  gl.bindFramebuffer(gl.FRAMEBUFFER, targetFbo);
  gl.viewport(0, 0, w, h);
  gl.useProgram(entry.program);
  setUniforms(entry, w, h);
  bindInputs(entry);
  if (new URLSearchParams(location.search).get("probe") && runState.frame < 2) {
    const nameOf = (t) => {
      if (!t) return null;
      if (t === keyboardTex) return "keyboard";
      if (t === audioTex) return "audio";
      for (const [f, o] of Object.entries(pngTextures)) if (o.tex === t) return f;
      for (const [n, b] of Object.entries(buffers)) if (b.tex.includes(t)) return n;
      return "unknown";
    };
    const bindings = [];
    for (let c = 0; c < 4; c++) {
      gl.activeTexture(gl.TEXTURE0 + c);
      bindings.push({
        tex: nameOf(gl.getParameter(gl.TEXTURE_BINDING_2D)),
        sampler: gl.getParameter(gl.SAMPLER_BINDING) ? "obj" : null,
      });
    }
    (window.__probe = window.__probe || []).push({ pass: entry.desc.name, frame: runState.frame, bindings });
  }
  checkGLError(`pre-draw ${entry.desc.name} frame ${runState.frame}`);
  gl.drawArrays(gl.TRIANGLES, 0, 3);
  checkGLError(`post-draw ${entry.desc.name} frame ${runState.frame}`);
  for (let c = 0; c < 4; c++) gl.bindSampler(c, null);
}

function renderFrame() {
  if (runState.keyboardDirty) {
    updateKeyboardTexture();
    runState.keyboardDirty = false;
  }
  // ?pass=BufferA..D 调试:把该通道输出直接显示到屏幕
  const debugPassName = new URLSearchParams(location.search).get("pass");
  for (const name of Object.keys(buffers)) {
    const b = buffers[name];
    const write = 1 - b.cur;
    renderPass(b, b.fbo[write], W, H);
    b.cur = write;
    if (debugPassName === name) {
      gl.bindFramebuffer(gl.READ_FRAMEBUFFER, b.fbo[b.cur]);
      gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, null);
      gl.blitFramebuffer(0, 0, W, H, 0, 0, W, H, gl.COLOR_BUFFER_BIT, gl.NEAREST);
      return;
    }
  }
  renderPass(imagePass, null, W, H);
}

// ---------------------------------------------------------------- 安详值覆盖层(HTML)
// 中文文案无法用 abc 字形纹理(仅 ASCII)渲染,由 runtime 读回游戏状态后用 DOM 显示
let sereneFbo = null;
let sereneAcc = 1;
let sereneLastScore = -1;
let sereneLastFail = -1;
let sereneGainTimer = null;
let sereneDeltaTimer = null;
let sereneDisplay = 20;   // 数值缓动显示
let sereneShown = 20;     // 上次触发浮动的整数
const SERENE_TIPS = ["你不需要逃得更快", "慢一点也没关系"];
const SERENE_GAINS = ["安详 +1", "心率 -1", "状态:安全"];

// 安详值变化浮动数字(+绿上浮 / -红下沉)
function showPeaceDelta(delta) {
  const el = document.getElementById("peace-delta");
  if (!el) return;
  el.textContent = (delta > 0 ? "+" : "") + delta;
  el.style.color = delta > 0 ? "#8effc1" : "#ff9a9a";
  el.style.textShadow = delta > 0
    ? "0 0 12px rgba(142, 255, 193, 0.7)"
    : "0 0 12px rgba(255, 154, 154, 0.7)";
  el.classList.remove("pop");
  void el.offsetWidth; // 重置动画
  el.classList.add("pop");
}

function updateSereneOverlay(dt) {
  const feat = currentFeat().feat;
  if (!feat.serenity && !feat.orbs && !feat.fragments) return;
  sereneAcc += dt;
  if (sereneAcc < 0.15) return;
  sereneAcc = 0;
  const b = buffers.BufferA;
  const scoreEl = document.getElementById("peace-score");
  const tipEl = document.getElementById("peace-tip");
  const safeEl = document.getElementById("peace-safe");
  if (!b || !b.tex[b.cur] || !scoreEl || !tipEl || !safeEl) return;
  if (!sereneFbo) sereneFbo = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, sereneFbo);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, b.tex[b.cur], 0);
  const px = new Float32Array(8 * 8 * 4);
  gl.readPixels(0, 0, 8, 8, gl.RGBA, gl.FLOAT, px);
  gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  const cell = (x, y) => { const i = (y * 8 + x) * 4; return [px[i], px[i + 1], px[i + 2], px[i + 3]]; };
  const [, , stateID, timeStarted] = cell(0, 0);
  const [, , score, timeFailed] = cell(1, 0);
  const inGame = stateID > 0.5;
  // 音乐联动:同步 mood
  const moodNow = px[(0 * 8 + 3) * 4 + 2];
  if (window.SunsetMusic) window.SunsetMusic.setMood(moodNow);
  // 撞车态:持续显示 You are still safe,按 ←/→ 继续后才淡出
  const crashed = inGame && timeFailed > Math.max(timeStarted, 0.0) && timeFailed > 0;
  if (crashed && timeFailed > sereneLastFail + 0.5 && window.SunsetMusic) window.SunsetMusic.onCrash();
  if (crashed) sereneLastFail = Math.max(sereneLastFail, timeFailed);
  safeEl.classList.toggle("on", crashed);
  if (crashed) tipEl.classList.remove("on");
  const numEl = document.getElementById("peace-num");
  const gainEl = document.getElementById("peace-gain");
  const stateEl = document.getElementById("peace-state");
  const barEl = document.getElementById("peace-bar-fill");
  const bpmEl = document.getElementById("music-bpm");
  const serenity = Math.max(0, Math.min(100, px[(1 * 8 + 3) * 4]));
  if (bpmEl && window.SunsetMusic) bpmEl.textContent = window.SunsetMusic.getBpm();
  // 安详值变化:数值平滑滚动 + 变化幅度浮动提示
  if (Math.abs(serenity - sereneShown) >= 1) {
    showPeaceDelta(Math.round(serenity - sereneShown));
    sereneShown = serenity;
  }
  sereneDisplay += (serenity - sereneDisplay) * 0.3;
  if (Math.abs(serenity - sereneDisplay) < 0.5) sereneDisplay = serenity;
  if (inGame) {
    numEl.textContent = Math.round(sereneDisplay);
    if (stateEl) {
      stateEl.textContent = serenity < 25 ? "还在逃离"
        : serenity < 50 ? "渐渐平静"
        : serenity < 75 ? "心安之处"
        : "安详自在";
    }
    if (barEl) barEl.style.width = sereneDisplay + "%";
    scoreEl.classList.add("on");
    // 收集到光点:轻声提示一下
    if (gainEl && sereneLastScore >= 0 && score > sereneLastScore) {
      gainEl.textContent = SERENE_GAINS[Math.floor(Math.random() * SERENE_GAINS.length)];
      gainEl.classList.add("on");
      clearTimeout(sereneGainTimer);
      sereneGainTimer = setTimeout(() => gainEl.classList.remove("on"), 2000);
      if (window.SunsetMusic) window.SunsetMusic.onCollect();
    }
    sereneLastScore = score;
  } else {
    scoreEl.classList.remove("on");
    sereneLastScore = score;
  }
  // 行进阶段提示:每 45 格点亮一次,两条文案轮换(撞车态不显示)
  if (!crashed) {
    const cellID = Math.floor(5 * cell(2, 0)[2]);
    const showTip = inGame && cellID > 12 && (cellID % 45) < 11;
    const tip = SERENE_TIPS[Math.floor(cellID / 45) % SERENE_TIPS.length];
    if (tipEl.textContent !== tip) tipEl.textContent = tip;
    tipEl.classList.toggle("on", showTip);
  }
}

function tick(now) {
  requestAnimationFrame(tick);
  const dt = Math.min(Math.max((now - runState.lastNow) / 1000, 0.0001), 0.25);
  runState.lastNow = now;
  runState.frameDelta = dt;
  runState.fpsSmooth += (1 / dt - runState.fpsSmooth) * 0.05;
  runState.time += dt;
  renderFrame();
  updateSereneOverlay(dt);
  runState.frame++;
}

// ---------------------------------------------------------------- 尺寸与启动

function allocBufferTargets() {
  for (const name of Object.keys(buffers)) {
    const b = buffers[name];
    for (let i = 0; i < 2; i++) {
      if (b.tex[i]) gl.deleteTexture(b.tex[i]);
      if (b.fbo[i]) gl.deleteFramebuffer(b.fbo[i]);
      const tex = createColorTexture(W, H, false);
      const fbo = gl.createFramebuffer();
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
      b.tex[i] = tex;
      b.fbo[i] = fbo;
    }
    b.cur = 1; // 下一次写入索引 0,自引用读取索引 1(黑初始化)
  }
}

let resizeTimer = null;
function onResize() {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => {
    const dpr = window.devicePixelRatio || 1;
    const w = Math.max(1, Math.round(canvas.clientWidth * dpr));
    const h = Math.max(1, Math.round(canvas.clientHeight * dpr));
    if (w === W && h === H) return;
    W = w; H = h;
    canvas.width = W; canvas.height = H;
    allocBufferTargets();           // 重建缓冲(内容清空)
    runState.frame = 0;             // 重新触发游戏状态初始化
  }, 150);
}

function applyFeatsToUI(f) {
  const show = (id, on) => { const el = document.getElementById(id); if (el) el.style.display = on ? "" : "none"; };
  const sereneOn = f.serenity || f.orbs || f.fragments;
  const sereneBox = document.getElementById("serene");
  if (sereneBox) sereneBox.style.display = sereneOn ? "" : "none";
  show("peace-score", f.serenity);
  show("peace-tip", f.serenity);
  show("peace-safe", f.fragments);
  show("peace-gain", f.orbs);
  const h1 = document.querySelector("#hud h1");
  const keys = document.querySelector("#hud .keys");
  if (h1 && keys) {
    if (f.text) {
      h1.textContent = "SERENE ESCAPE UNLIMITED";
      keys.textContent = "← → 呼吸 · A/D 也可以 · 空格 启程 · U 安静一下 · 按住鼠标 慢慢看风景 · 不要急";
      document.title = "Serene Escape Unlimited — 本地复刻";
    } else {
      h1.textContent = "SUNSET DRIVE UNLIMITED";
      keys.textContent = "←/→ 或 A/D 移动 · 空格 开始 · U 切换界面 · 按住鼠标拖动视角";
      document.title = "Sunset Drive Unlimited — 本地复刻";
    }
  }
}

function buildPanel() {
  const panel = document.createElement("div");
  panel.id = "panel";
  let html = `<div id="panel-head"><span>⚙ 效果调节</span><span id="panel-toggle">▾</span></div><div id="panel-body">`;
  html += `<div class="group-title">旅程版本(回到之前的阶段)</div>`;
  html += `<select id="ver-select">` +
    VERSION_PRESETS.map(p => `<option value="${p.name}"${p.name === currentFeat().name ? " selected" : ""}>${p.label}</option>`).join("") +
    `</select>`;
  html += `<div class="group-title">配乐(程序合成 · 心率即 BPM)</div>`;
  html += `<label class="row"><input type="checkbox" id="music-on" checked><span>♪ 背景配乐 · 心率 <b id="music-bpm">105</b> BPM</span></label>`;
  html += `<div class="row col"><label class="plabel"><span>音量</span></label><input type="range" id="music-vol" min="0" max="1" step="0.05" value="0.55"></div>`;
  html += `<div class="group-title">效果开关(切换后重编译约 1 秒)</div>`;
  for (const m of MACROS) {
    html += `<label class="row"><input type="checkbox" data-macro="${m.name}"${m.on ? " checked" : ""}><span>${m.label}</span></label>`;
  }
  html += `<div class="group-title">参数</div>`;
  for (const p of PARAMS) {
    html += `<div class="row col"><label class="plabel"><span>${p.label}</span><b id="val_${p.uniform}">${p.def}</b></label>` +
      `<input type="range" data-param="${p.uniform}" min="${p.min}" max="${p.max}" step="${p.step}" value="${p.def}"></div>`;
  }
  html += `<div class="row"><button id="fx-reset">恢复默认</button><span id="rebuild-note"></span></div></div>`;
  panel.innerHTML = html;
  document.body.appendChild(panel);

  panel.querySelector("#panel-head").addEventListener("click", () => {
    panel.classList.toggle("collapsed");
    panel.querySelector("#panel-toggle").textContent = panel.classList.contains("collapsed") ? "▸" : "▾";
  });
  panel.querySelector("#ver-select").addEventListener("change", (e) => {
    currentVersion = e.target.value;
    const p = VERSION_PRESETS.find(x => x.name === currentVersion);
    applyFeatsToUI(p.feat);
    rebuildShaders();
  });
  panel.querySelector("#music-on").addEventListener("change", (e) => {
    if (window.SunsetMusic) window.SunsetMusic.setMuted(!e.target.checked);
  });
  panel.querySelector("#music-vol").addEventListener("input", (e) => {
    if (window.SunsetMusic) window.SunsetMusic.setVolume(parseFloat(e.target.value));
  });
  panel.querySelectorAll("input[data-macro]").forEach(cb => {
    cb.addEventListener("change", () => {
      const m = MACROS.find(x => x.name === cb.dataset.macro);
      m.on = cb.checked;
      rebuildShaders();
    });
  });
  panel.querySelectorAll("input[data-param]").forEach(r => {
    r.addEventListener("input", () => {
      const p = PARAMS.find(x => x.uniform === r.dataset.param);
      paramState[p.uniform] = parseFloat(r.value);
      document.getElementById("val_" + p.uniform).textContent = r.value;
    });
  });
  panel.querySelector("#fx-reset").addEventListener("click", () => {
    for (const p of PARAMS) {
      paramState[p.uniform] = p.def;
      const r = panel.querySelector(`input[data-param="${p.uniform}"]`);
      r.value = p.def;
      document.getElementById("val_" + p.uniform).textContent = p.def;
    }
    let needRebuild = false;
    for (const m of MACROS) {
      const cb = panel.querySelector(`input[data-macro="${m.name}"]`);
      if (cb.checked !== m.def) { cb.checked = m.def; needRebuild = true; }
      m.on = m.def;
    }
    if (needRebuild) rebuildShaders();
  });
}

async function main() {
  initGL();
  bindInputEvents();
  await loadAndCompile();
  initStaticTextures();
  await loadPngTextures();

  const dpr = window.devicePixelRatio || 1;
  W = Math.max(1, Math.round(canvas.clientWidth * dpr));
  H = Math.max(1, Math.round(canvas.clientHeight * dpr));
  canvas.width = W; canvas.height = H;
  allocBufferTargets();

  window.addEventListener("resize", onResize);
  buildPanel();
  applyFeatsToUI(currentFeat().feat);
  window.SunsetFX = {
    setParam(name, v) {
      const p = PARAMS.find(x => x.uniform === name);
      if (!p) throw new Error("未知参数: " + name);
      v = Math.min(p.max, Math.max(p.min, Number(v)));
      paramState[name] = v;
      const r = document.querySelector(`#panel input[data-param="${name}"]`);
      if (r) { r.value = v; document.getElementById("val_" + name).textContent = v; }
      return v;
    },
    setMacro(name, on) {
      const m = MACROS.find(x => x.name === name);
      if (!m) throw new Error("未知开关: " + name);
      m.on = !!on;
      const cb = document.querySelector(`#panel input[data-macro="${name}"]`);
      if (cb) cb.checked = !!on;
      rebuildShaders();
    },
    getParams: () => ({ ...paramState }),
  };
  window.__sd = { gl, buffers, imagePass, pngTextures, keyboardTex, audioTex, get runState() { return runState; } };
  requestAnimationFrame((t) => { runState.lastNow = t; requestAnimationFrame(tick); });
}

main().catch((e) => showError(String(e && e.message || e)));