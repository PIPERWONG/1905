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


vec3 fxaa( vec3 color )
{
	// FXAA implementation by mudlord (I think?)
    vec3 luma = vec3(0.299, 0.587, 0.114);
	vec2 pp = 1.0 / R.xy;
    float lumaNW = dot(texture(iChannel0, (F.xy + vec2(-1.0, -1.0)) * pp).xyz, luma);
    float lumaNE = dot(texture(iChannel0, (F.xy + vec2(1.0, -1.0)) * pp).xyz, luma);
    float lumaSW = dot(texture(iChannel0, (F.xy + vec2(-1.0, 1.0)) * pp).xyz, luma);
    float lumaSE = dot(texture(iChannel0, (F.xy + vec2(1.0, 1.0)) * pp).xyz, luma);
    float lumaM  = dot(color.xyz,  luma);
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

    vec2 dir = vec2(-((lumaNW + lumaNE) - (lumaSW + lumaSE)), ((lumaNW + lumaSW) - (lumaNE + lumaSE)));

    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
                          (0.25 * (1.0/8.0)), (1.0/128.0));

    float rcpDirMin = 2.5 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(vec2(8.0, 8.0),
              max(vec2(-8.0, -8.0),
              dir * rcpDirMin)) * pp;

    vec3 rgbA = 0.5 * (
        texture(iChannel0, F.xy * pp + dir * (1.0 / 3.0 - 0.5)).xyz +
        texture(iChannel0, F.xy * pp + dir * (2.0 / 3.0 - 0.5)).xyz);
    vec3 rgbB = rgbA * 0.5 + 0.25 * (
        texture(iChannel0, F.xy * pp + dir * -0.5).xyz +
        texture(iChannel0, F.xy * pp + dir * 0.5).xyz);

    float lumaB = dot(rgbB, luma);
    if ((lumaB < lumaMin) || (lumaB > lumaMax)){
        return rgbA;
    } else {
        return rgbB;
    }
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = vec4( 0.0 );
	
	vec2 uv = F.xy / R.xy;
    vec2 q = 1.0 - 2.0 * uv;
    q.x *= R.x / R.y;

#ifdef FORCED_RATIO
    float bars = step( abs( q.y ) * g_forceRatio, R.x / R.y );
    if ( bars < 0.5 ) return;	
#endif // FORCED_RATIO
       
    fragColor = texture( iChannel0, vec2( uv ) );

#ifdef FXAA	
	fragColor.rgb = fxaa( fragColor.rgb );
#endif

#ifdef NOISE
    fragColor.rgb *= 0.8 + 0.2 * hash22( 1000.0 * ( F.xy / R.xy + fract( iTime ) ) ).x;
#endif

#ifdef FPS_COUNTER    
    vec2 h = F.xy / R.xy;
    h.x *= R.x / R.y;
    fragColor.rgb += printInt( ( h -vec2( 0.0, 0.21 ) ) * 30.0, iFrameRate );
#endif 

    // gamma
	fragColor.rgb = pow( fragColor.rgb, vec3( 0.4545 ) );
}