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



vec2 barrelDistortion( vec2 coord, float amt, float zoom )
{ // based on gtoledo3 (XslGz8)
  // added zoomimg
	vec2 cc = coord - 0.5;
    vec2 p = cc * zoom;
    coord = p + 0.5;
	float dist = dot( cc, cc );
	return coord + cc * dist * amt;
}

vec3 tonemapACES( vec3 x )
{
    // Narkowicz 2015, "ACES Filmic Tone Mapping Curve"	        
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return ( x * ( a * x + b ) ) / ( x * ( c * x + d ) + e );
}

vec3 ca( sampler2D t, vec2 UV )
{	
	const int N = 8;	
    float scale = 1.0;
	vec2 uv = 1.0 - 2.0 * UV;
	vec3 c = vec3( 0 );
	float rf = 1.0;
	float gf = 1.0;
    float bf = 1.0;
	float f = 1.0 / float( N );
	for( int i = 0; i < N; ++i )
    {
		c.r += f * texture( t, 0.5 - 0.5 * ( ( uv ) * rf ) ).r;
		c.g += f * texture( t, 0.5 - 0.5 * ( ( uv ) * gf ) ).g;
		c.b += f * texture( t, 0.5 - 0.5 * ( ( uv ) * bf ) ).b;
		rf *= mix( 1.0, 0.9972, scale );
		gf *= mix( 1.0, 0.998,  scale );
        bf /= mix( 1.0, 0.9988, scale );
	}
	return c;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{   
    fragColor = vec4(0.0);
	
	vec2 uv = F.xy / R.xy;
    vec2 q = 1.0 - 2.0 * uv;
    q.x *= R.x / R.y;

#ifdef FORCED_RATIO        
	float bars = step( abs( q.y ) * g_forceRatio, R.x / R.y );
    if ( bars < 0.5 ) return;	
#endif

    // barrel distortion
	vec2 uvb = barrelDistortion( uv, 0.1, 0.97 );
    
    // chromatic aberration	
    vec3 color;
	color.rgb = ca( iChannel0, uv );
    // color = texture( iChannel0, uv ).rgb;
    
    // vignette
	color.rgb *= 0.7 + 0.3 * clamp( pow( 28.0 * uv.x * uv.y * ( 1.0 - uv.x ) * ( 1.0 - uv.y ), 2.0 ), 0.0, 1.0 );
	
	// grade
#ifdef GRADE
    color.rgb = smoothstep( vec3( -0.05 ), vec3( 0.8 ), color.rgb );
#endif
          
    color.rgb = tonemapACES( color.rgb );
     
	fragColor.rgb = color;
}