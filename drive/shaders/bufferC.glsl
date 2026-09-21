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



float textSDF( vec2 p, float glyph )
{
    p = abs( p.x - .5 ) > .5 || abs( p.y - .5 ) > .5 ? vec2( 0. ) : p;
    return 2. * ( texture( iChannel3, p / 16. + fract( vec2( glyph, 15. - floor( glyph / 16. ) ) / 16. ) ).w - 127. / 255. );
}

void menuText( inout vec3 color, vec2 p, in AppState s )
{        
    vec2 scale = vec2( 4., 8. );
    vec2 t = floor( p / scale );   
    
    uint v = 0u;
	v = t.y == 2. ? ( t.x < 4. ? 1768452929u : ( t.x < 8. ? 1768777835u : ( t.x < 12. ? 5653614u : 0u ) ) ) : v;
	v = t.y == 1. ? ( t.x < 4. ? 1918986307u : ( t.x < 8. ? 1147496812u : ( t.x < 12. ? 1752383839u : ( t.x < 16. ? 1835559785u : 5664361u ) ) ) ) : v;
	v = t.y == 0. ? ( t.x < 4. ? 1918986307u : ( t.x < 8. ? 1147496812u : ( t.x < 12. ? 86u : 0u ) ) ) : v;
	v = t.x >= 0. && t.x < 20. ? v : 0u;
    
	float c = float( ( v >> uint( 8. * t.x ) ) & 255u );
    
	vec3 textColor = vec3( 1.0 );

    p = ( p - t * scale ) / scale;
    p.x = ( p.x - .5 ) * .5 + .5;
    float sdf = textSDF( p, c );
    if ( c != 0. )
    {
    	color = mix( textColor, color, smoothstep( -.05, +.05, sdf ) );
    }
}

float titleText( vec2 p )
{        
    vec2 scale = vec2( 4., 8. );
    vec2 t = floor( p / scale );   
    
    uint v = 0u;
	v = t.y == 0. ? ( t.x < 4. ? 1397642579u : ( t.x < 8. ? 1142969413u : ( t.x < 12. ? 1163282770u : ( t.x < 16. ? 1280202016u : ( t.x < 20. ? 1414090057u : 17477u ) ) ) ) ) : v;
	v = t.x >= 0. && t.x < 24. ? v : 0u;
    
	float c = float( ( v >> uint( 8. * t.x ) ) & 255u );
    
    p = ( p - t * scale ) / scale;
    p.x = ( p.x - .5 ) * .5 + .5;
    float sdf = textSDF( p, c );
    return ( c != 0. ) ? smoothstep( -.05, +.05, sdf ) : 1.0;
}

float spaceText(vec2 p)
{        
    vec2 scale = vec2( 4., 8. );
    vec2 t = floor( p / scale );   
    
    uint v = 0u;    
    v = t.y == 0. ? ( t.x < 4. ? 1936028240u : ( t.x < 8. ? 1935351923u : ( t.x < 12. ? 1701011824u : ( t.x < 16. ? 1869881437u : ( t.x < 20. ? 1635021600u : 29810u ) ) ) ) ) : v;
	v = t.x >= 0. && t.x < 24. ? v : 0u;
    
	float c = float( ( v >> uint( 8. * t.x ) ) & 255u );
    
    p = ( p - t * scale ) / scale;
    p.x = (p.x - .5 ) * .5 + .5;
    float sdf = textSDF( p, c );
    return ( c != 0. ) ? smoothstep( -.05, +.05, sdf ) : 1.0;
}

float highscoreText( vec2 p )
{        
    vec2 scale = vec2( 4., 8. );
    vec2 t = floor( p / scale );
    
    uint v = 0u;    
	v = t.y == 0. ? ( t.x < 4. ? 1751607624u : ( t.x < 8. ? 1919902579u : 14949u ) ) : v;
	v = t.x >= 0. && t.x < 12. ? v : 0u;
    
	float c = float( ( v >> uint( 8. * t.x ) ) & 255u );
    
    p = ( p - t * scale ) / scale;
    p.x = ( p.x - .5 ) * .5 + .5;
    float sdf = textSDF( p, c );
    return ( c != 0. ) ? smoothstep( -.05, +.05, sdf ) : 1.0;
}

void drawUI(inout vec3 color, vec2 p, AppState s)
{
    p *= R.y / R.x; // ratio and resolution indepenent scaling
    p *= 1.75;
    
    // splash screen   
    if ( s.stateID == GS_SPLASH )
    {
        color.rgb *= 0.1 + 0.9 * smoothstep( 0.75, 0.0, p.y ); // dark text bg
		vec2 p2 = p;
		p2 *= 50.;
		p2 -= vec2( -45, 27. );
        // color.rgb = mix(color.rgb, vec3(0.0), 1.0-smoothstep(0.0, 0.5, abs(p2.y)) ); // horiz guide
        
        float maskTitle = titleText( p2 ); // Sunset Drive Unlimited
        color.rgb = mix( vec3( 1.0 ), color.rgb, maskTitle );
        
		vec2 p1 = p;
		p1 *= 60. + 5. * abs( sin( 2.0 * iTime ) );
		p1 -= vec2( -47., -42. );
        float maskSpace = spaceText( p1 ); // press [space] to start
        color.rgb = mix( vec3( 1.0 ), color.rgb, maskSpace );

		vec2 p3 = p;
		p3 *= 60.;
		p3 -= vec2( -30, 25. );
        float maskHs = highscoreText( p3 ); // Highscore
        color.rgb = mix( vec3( 1.0 ), color.rgb, maskHs );

		vec2 pScore = p;
        pScore *= 12.0;
        pScore -= vec2( 1.3, 5.3 );
        float sScore = printInt( pScore, s.highscore );
        color.rgb = mix( color.rgb, vec3( 1.0 ), sScore );
    }
    else
    {
        vec2 pScore = p;
        pScore *= 6.0;
        pScore -= vec2( -0.9, 3.4 );
        float maxDigits = ceil( log2( s.score ) / log2( 10.0 ) );
        pScore.x += 0.5 * maxDigits;
        float sScore = printInt( pScore, s.score );
        color.rgb = mix( color.rgb, vec3( 1.0 ), sScore );
    }

	// color.rgb = mix(color.rgb, vec3(0.0), 1.0-smoothstep(0.0, 0.01, abs(p.x)) ); // center guide
    // color.rgb = mix(color.rgb, vec3(0.0), 1.0-smoothstep(0.0, 0.01, abs(p.y)) ); // horiz guide
}

const float gaussianWeights[6] = float[] (
	0.12801,
	0.12299,
	0.10908,
	0.08931,
	0.06750,
	0.04709 
);

vec3 rbg( sampler2D t, vec2 UV, vec2 dir )
{
	vec3 c = vec3( 0 );
	vec2 uv = 1.0 - 2.0 * UV;	
    vec2 rRcp = 1.0 / vec2( 1920.0, 1080.0 );
	for( int i = -5; i < 6; ++i )
    {
		c += gaussianWeights[abs( i )] * textureLod( t, 0.5 - 0.5 * ( uv + rRcp * dir * float( i ) ), 0.0 ).rgb;
	}
	return c;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = vec4(0.0);
    
 	vec2 uv = F.xy / R.xy;
    vec2 p = -1. + 2. * uv;
	p.x *= R.x / R.y;

#ifdef FORCED_RATIO
	float bars = step( abs( p.y ) * g_forceRatio, R.x / R.y );
    if ( bars < 0.5 ) return;	
#endif
    
    AppState s;
    loadState( iChannel1, s );
    
    float scale = 5.0 * s.paceScale;
    
    if ( s.timeFailed > 0.0 )
    {
        scale = 1.0;
    }
    
    if ( s.stateID == GS_SPLASH )
    {
        scale = 4.0;
    }
    
    scale += 0.1;

	vec4 beauty = texture( iChannel0, uv );
    vec2 dir = normalize( vec2( dFdx( beauty.a ), dFdy( beauty.a ) ) );
    vec3 blurred = rbg( iChannel0, uv, dir * scale );    
    float blurMask = 0.1 + smoothstep( 0.0, 0.2, beauty.a ); // 0.1 bias to blur a bit dithered volumetrics at center
    vec3 color = mix( beauty.rgb, blurred, blurMask ); 

#ifdef SHOW_UI
        drawUI( color, p, s );
#endif
        
    fragColor = vec4( color, 1.0 );
}