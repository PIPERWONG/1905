// Copyright © 2019 Michal Klos
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Sunset Drive Unlimited
//  Endless runner with synthwave stylization
//	"Brick Driver" sequel, because it missed fluent turning and coins:
//	https://www.shadertoy.com/view/wssSD4

// #define options in Common tab
//  Some effects can be disabled on low end gpus

// Gameplay is based on Brick Game Racing,
//  https://youtu.be/EdMyKRC8qyU

// First draft created in 24h on Game Jam Square 26-28.04.2019
//	Finished after couple of spare evenings on 24.06.2019

// Based on:
// - "80's raymarching" by villedieumorgan. https://shadertoy.com/view/lsVSRt
// - "[SH16B] Speed Drive 80" by knarkowicz. https://shadertoy.com/view/4ldGz4
// Other snippets credits in comments next to the code
// Thank you guys for sharing it, hope you like it :)

// Music: Lifelike - So Electric
//  https://soundcloud.com/rombo_rama/lifelike-so-electric



// switches, enable/disable effects:
#define REFLECTIONS // needs good gpu
#define VOLUMETRICS // needs good gpu
#define FXAA
#define GRADE
#define NOISE
#define FORCED_RATIO
// debug:
#define SHOW_UI
// #define FPS_COUNTER
// #define DEBUG_2D
// #define DEBUG_CAMERA
// #define CAM_STICKED


#define ZERO (min(iFrame,0))
#define R iResolution
#define F gl_FragCoord
// fix by adx
#define texture(s,u) textureLod(s,u,0.)

const float g_forceRatio = 2.39;
const float PI = float(3.14159);

// control loop
const float keysLeft[] = float[] ( 
	 37.0,  // Arrow left
	 65.0,  // A
	 197.0  // a 
);

const float keysRight[] = float[] ( 
	 39.0, // Arrow right
	 68.0, // D
     100.0 // d
);

const int ASCII_U		= 85;
const int ASCII_SPACE	= 32;

// Game State
const float GS_SPLASH = 0.0;
const float GS_GAME   = 1.0;

// Cell State
struct AppState
{
	float stateID;
    float isPressedLeft;
    float isPressedRight;
    float timeStarted;
    
    vec2 playerPos;
    float score;
    float timeFailed;
    
    float highscore;
    float timeCollected;
    float timeAccumulated;
    float showUI;
    
    float paceScale;
    float seed;
    
    float coin0Pos;
    float coin0Taken;
    float coin1Pos;
    float coin1Taken;
    float coin2Pos;
    float coin2Taken;
    float coin3Pos;
    float coin3Taken;
};

   
// https://www.shadertoy.com/view/4djSRW
float hash11( float p )
{
	vec3 p3  = fract( vec3( p ) * .1031 );
    p3 += dot( p3, p3.yzx + 19.19 );
    return fract( ( p3.x + p3.y) * p3.z );
}

vec2 hash21( float p )
{
	vec3 p3 = fract( vec3( p ) * vec3( .1031, .1030, .0973 ) );
	p3 += dot( p3, p3.yzx + 19.19 );
    return fract( ( p3.xx + p3.yz ) * p3.zy );
}

vec2 hash22( vec2 p )
{
	vec3 p3 = fract( vec3( p.xyx ) * vec3( .1031, .1030, .0973 ) );
    p3 += dot( p3, p3.yzx + 19.19 );
    return fract( ( p3.xx + p3.yz ) * p3.zy );
}

// from Tiny Planet: Earth by morgan3d https://www.shadertoy.com/view/lt3XDM
float hash( float n ) { return fract( sin( n ) * 1e4 ); }
float noise( vec3 x ) { const vec3 step = vec3( 110, 241, 171 ); vec3 i = floor( x ); vec3 f = fract( x ); float n = dot( i, step ); vec3 u = f * f * ( 3.0 - 2.0 * f ); return mix( mix( mix( hash( n + dot( step, vec3( 0, 0, 0 ) ) ), hash( n + dot( step, vec3( 1, 0, 0 ) ) ), u.x ), mix( hash( n + dot( step, vec3( 0, 1, 0 ) ) ), hash( n + dot( step, vec3( 1, 1, 0 ) ) ), u.x ), u.y ), mix( mix( hash( n + dot( step, vec3( 0, 0, 1 ) ) ), hash( n + dot( step, vec3( 1, 0, 1 ) ) ), u.x ), mix( hash( n + dot( step, vec3( 0, 1, 1) ) ), hash( n + dot( step, vec3( 1, 1, 1 ) ) ), u.x ), u.y ), u.z ); }

#define DEFINE_FBM(name, OCTAVES) float name( vec3 x ) { float v = 0.0; float a = 0.5; vec3 shift = vec3( 100 ); for ( int i = 0; i < OCTAVES; ++i ) { v += a * noise( x ); x = x * 2.0 + shift; a *= 0.5; } return v; }
DEFINE_FBM(fbm3, 3)


vec4 loadValue( sampler2D tex, int x, int y )
{
    return texelFetch( tex, ivec2( x, y ), 0 );
}

void loadState( sampler2D tex, out AppState s )
{
    vec4 data;

	data = loadValue( tex, 0, 0 );
    s.isPressedLeft		= data.x;
    s.isPressedRight	= data.y;
    s.stateID      		= data.z;
	s.timeStarted 		= data.w;    
    
    data = loadValue( tex, 1, 0 );
    s.playerPos			= data.xy;
    s.score				= data.z;
    s.timeFailed 		= data.w;
    
    data = loadValue( tex, 2, 0 );
    s.highscore 		= data.x;
    s.timeCollected		= data.y;
    s.timeAccumulated	= data.z;
    s.showUI			= data.w;
    
    data = loadValue( tex, 3, 0 );
    s.paceScale			= data.x;
    s.seed				= data.y;
   
    data = loadValue( tex, 0, 1 );
    s.coin0Pos = data.x;
    s.coin0Taken = data.y;
    s.coin1Pos = data.z;
    s.coin1Taken = data.w;
    data = loadValue( tex, 1, 1 );
    s.coin2Pos = data.x;
    s.coin2Taken = data.y;
    s.coin3Pos = data.z;
    s.coin3Taken = data.w;
}

void storeValue( vec2 re, vec4 va, inout vec4 fragColor, vec2 fragCoord )
{
    fragCoord = floor( fragCoord );
    fragColor = ( fragCoord.x == re.x && fragCoord.y == re.y ) ? va : fragColor;
}

AppState setStateStartGame( in AppState s, float iTime )
{    
    s.stateID 			=  GS_SPLASH;
    s.timeStarted		=  iTime;
    s.playerPos			=  vec2( 0.5, 0.0 );
    s.score				=  0.0;
    s.timeFailed		= -1.0;
    s.timeCollected		= -1.0;
    s.timeAccumulated	=  0.0;
    s.showUI			=  1.0;

    s.coin0Pos		= 0.0;
    s.coin0Taken	= 0.0;
    s.coin1Pos		= 0.0;        
    s.coin1Taken	= 0.0;
    s.coin2Pos		= 0.0;        
    s.coin2Taken	= 0.0;
    s.coin3Pos		= 0.0;        
    s.coin3Taken	= 0.0;    
    
    return s;
}

vec4 saveState( in AppState s, in vec2 fragCoord, int iFrame, float iTime )
{
    if (iFrame <= 0)
    {
        s.seed = fbm3( iDate.yzw );
 		s = setStateStartGame( s, iTime );
	}
    
    vec4 ret = vec4( 0.);
	storeValue( vec2( 0., 0. ), vec4( s.isPressedLeft,		s.isPressedRight,	s.stateID,			s.timeStarted),	ret, fragCoord );    
	storeValue( vec2( 1., 0. ), vec4( s.playerPos,								s.score,			s.timeFailed),	ret, fragCoord );
	storeValue( vec2( 2., 0. ), vec4( s.highscore,			s.timeCollected,	s.timeAccumulated,	s.showUI),		ret, fragCoord );
    storeValue( vec2( 3., 0. ), vec4( s.paceScale,			s.seed,				0.0,				0.0),			ret, fragCoord );
    
    storeValue( vec2( 0., 1. ), vec4( s.coin0Pos, s.coin0Taken, s.coin1Pos, s.coin1Taken ), ret, fragCoord );
    storeValue( vec2( 1., 1. ), vec4( s.coin2Pos, s.coin2Taken, s.coin3Pos, s.coin3Taken ), ret, fragCoord );
    return ret;
}

// math

float saturate( float x ) { return clamp( x, 0., 1. ); }

vec3 saturate( vec3 x ) { return clamp( x, vec3( 0. ), vec3( 1. ) ); }

mat2 rot( float a ) { float s = sin( a ); float c = cos( a ); return mat2( c, -s, s, c ); }

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize( ta - ro );
	vec3 cp = vec3( sin( cr ), cos( cr ), 0.0 );
	vec3 cu = normalize( cross( cw, cp ) );
	vec3 cv =          ( cross( cu, cw ) );
    return mat3( cu, cv, cw );
}

float impulse( float k, float x ) {
    float h = k * x;
    return h * exp( 1.0 - h );
}

//-----------------------------------------------------------------
// Digit drawing function by P_Malin (https://www.shadertoy.com/view/4sf3RN)

float sampleDigit( const in float n, const in vec2 vUV )
{		
	if ( vUV.x  < 0.0 ) return 0.0;
	if ( vUV.y  < 0.0 ) return 0.0;
	if ( vUV.x >= 1.0 ) return 0.0;
	if ( vUV.y >= 1.0 ) return 0.0;
	
	float data = 0.0;
	
	     if( n < 0.5 ) data = 7.0 + 5.0 * 16.0 + 5.0 * 256.0 + 5.0 * 4096.0 + 7.0 * 65536.0;
	else if( n < 1.5 ) data = 2.0 + 2.0 * 16.0 + 2.0 * 256.0 + 2.0 * 4096.0 + 2.0 * 65536.0;
	else if( n < 2.5 ) data = 7.0 + 1.0 * 16.0 + 7.0 * 256.0 + 4.0 * 4096.0 + 7.0 * 65536.0;
	else if( n < 3.5 ) data = 7.0 + 4.0 * 16.0 + 7.0 * 256.0 + 4.0 * 4096.0 + 7.0 * 65536.0;
	else if( n < 4.5 ) data = 4.0 + 7.0 * 16.0 + 5.0 * 256.0 + 1.0 * 4096.0 + 1.0 * 65536.0;
	else if( n < 5.5 ) data = 7.0 + 4.0 * 16.0 + 7.0 * 256.0 + 1.0 * 4096.0 + 7.0 * 65536.0;
	else if( n < 6.5 ) data = 7.0 + 5.0 * 16.0 + 7.0 * 256.0 + 1.0 * 4096.0 + 7.0 * 65536.0;
	else if( n < 7.5 ) data = 4.0 + 4.0 * 16.0 + 4.0 * 256.0 + 4.0 * 4096.0 + 7.0 * 65536.0;
	else if( n < 8.5 ) data = 7.0 + 5.0 * 16.0 + 7.0 * 256.0 + 5.0 * 4096.0 + 7.0 * 65536.0;
	else if( n < 9.5 ) data = 7.0 + 4.0 * 16.0 + 7.0 * 256.0 + 5.0 * 4096.0 + 7.0 * 65536.0;
	
	vec2 vPixel = floor( vUV * vec2( 4.0, 5.0 ) );
	float fIndex = vPixel.x + ( vPixel.y * 4.0 );
	
	return mod( floor( data / pow( 2.0, fIndex ) ), 2.0 );
}

float printInt( const in vec2 uv, const in float value )
{
	float res = 0.0;
	float maxDigits = 1.0 + ceil( log2( value ) / log2( 10.0 ) );
	float digitID = floor( uv.x );
	if( digitID > 0.0 && digitID < maxDigits )
	{
        float digitVa = mod( floor( value / pow( 10.0, maxDigits - 1.0 - digitID ) ), 10.0 );
        res = sampleDigit( digitVa, vec2( fract( uv.x ), uv.y ) );
	}

	return res;	
}