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



AppState g_S;

float g_glowCoin = 1e10;
float g_glowCoinRefl = 1e10;
float g_glowEnemy = 1e10;
float g_glowEnemyRefl = 1e10;
float g_glowPlayer = 1e10;
float g_glowPlayerRefl = 1e10;
float g_glowPlayerFront = 1e10;
float g_glowPlayerLights = 1e10;
float g_cameraMode = 0.0;

const float GRID_SIZE = 0.5;
const float GRID_LINE_SIZE = 1.25;

const float GRID_CAR_SIZE = 0.5;
const float GRID_CAR_LINE_SIZE = 1.5;

const vec3 GRID_COLOR_1 = vec3(0.00, 0.02, 0.20);
const vec3 GRID_COLOR_2 = vec3(26.00, 14.0, 122.0)/255.;

const vec3 SUN_DIRECTION = vec3(0.0, 0.025, 0.5);
const vec3 SKY_COLOR_1 = vec3(49., 33., 66.)/255.;
const vec3 SKY_COLOR_2 = vec3(0.00,0.02,0.20);

const vec3 SUN_COLOR_1 = vec3(1.0, 0.3, 0.1) * 0.5;
const vec3 SUN_COLOR_2 = vec3(1.0, 1.0, 0.1) * 0.5;

const vec3 CAR_COLOR_1 = vec3(1.0, 0.5, 0.1) * 0.0;
const vec3 CAR_COLOR_2 = vec3(1.0, 0.0, 0.0) * 1.5;

const vec3 CAR_PLAYER_COLOR_1 = vec3(0.1, 1.0, 0.5) * 0.1;
const vec3 CAR_PLAYER_COLOR_2 = vec3(0.1, 1.0, 0.5) * 1.5;

const vec3 FOG_COLOR = vec3(193.00, 24.0, 123.0)/255.;


struct sHit {
    float t;
    float m;
    vec3 lPos;
};
    
sHit createHit( float t, float m, vec3 lPos )
{
    sHit h;
    h.t = t;
    h.m = m;
    h.lPos = lPos;
    return h;
}

void drawCoin( inout vec3 color, vec2 p, vec2 coinPos )
{  
    float sCoin = length(
        p
        -vec2( 0.0, coinPos.y )	// cell pos
        +vec2( 0.5, -0.5 )		// move to cell center
        -vec2( coinPos.x, 0.0 ) // move to column
    ) - 0.25; 					// radius of coin

    color.rgb = mix( vec3( 1.0, 1.0, 0.0 ), color.rgb, smoothstep( 0.0, 0.1, sCoin ) );
}

void drawGameFlat( inout vec4 color, vec2 p, AppState s )
{
    // game
	vec2 p0 = p;    
    // float cameraAnim = smoothstep(-0.5, 0.5, sin(iTime) );
    float cameraAnim = 0.0;
	p0 *= mix( 5.0, 10.0, cameraAnim );		// scale field of view
    p0.x += 0.25;							// fix track centering
    p0.y += mix( 2.0, 8.0, cameraAnim );	// move camera pos
    p0.y += s.playerPos.y;
    
    float playerCellID = floor( s.playerPos.y );
    float sPlayer = length( p0 - s.playerPos ) - 0.25;
           
    vec2 p1 = p0;
    p1.y += 2.0 * s.playerPos.y;
    color.rgb = mix( vec3( 1.0 ), color.rgb, smoothstep( 1.5, 1.75, abs( p1.x - 0.5 ) ) );
    color.rgb = mix( texture( iChannel2, fract( p1 ) ).rgb, color.rgb, 0.5 );
       
	// COIN start
    float cellID = floor( p0.y );
    float cellCoinRND = hash11( cellID + g_S.seed );					// skip rnd obstacle every second cell to make room for driving    
    cellCoinRND *= mix( 1.0, -1.0, step( mod( cellID, 4.0 ), 1.5 ) );	// gaps in coin placing: 2 gaps, 2 coins
    cellCoinRND = mix( cellCoinRND, -1.0, step (cellID, 5.0 ) );		// head start
    float cellCoinCol = floor( 3.0 * cellCoinRND );
       
    if ( cellCoinRND >= 0.0 )
    {
        if ( cellID > playerCellID )
           	drawCoin( color.rgb, p0, vec2( cellCoinCol, cellID ) );
        
        if ( cellID == playerCellID && s.coin0Taken < 0.5 )
            drawCoin( color.rgb, p0, vec2( cellCoinCol, cellID ) );
        
        if ( cellID == playerCellID - 1.0 && s.coin1Taken < 0.5 )
            drawCoin( color.rgb, p0, vec2( cellCoinCol, cellID ) );
        
        if ( cellID == playerCellID - 2.0 && s.coin2Taken < 0.5 )
            drawCoin( color.rgb, p0, vec2( cellCoinCol, cellID ) );
       
        if ( cellID == playerCellID - 3.0 && s.coin3Taken < 0.5 )
            drawCoin( color.rgb, p0, vec2( cellCoinCol, cellID ) );
    }    
// COIN end

// OBSTACLE start
    float cellObsRND = hash11( 100.0 * cellID + g_S.seed );		// skip rnd obstacle every second cell to make room for driving
    cellObsRND *= mix( 1.0, -1.0, step( mod( cellID, 3.0 ), 1.5 ) );
    cellObsRND = mix( cellObsRND, -1.0, step( cellID, 7.0) );	// head start
    float cellObsCol = floor( 3.0 * cellObsRND );
    
	if ( cellObsRND >= 0.0 && cellObsCol != cellCoinCol )
    {        
    	float sObstacle = length(
            p0
            -vec2( 0.0, cellID )		// cell pos
            +vec2( 0.5, -0.5 )			// move to cell center
            -vec2( cellObsCol, 0.0 )	// move to column
        ) - 0.25;						// radius of coin
        
    	color.rgb = mix( vec3( 1.0, 0.0, 0.0 ), color.rgb, smoothstep( 0.0, 0.1, sObstacle ) );
        
        vec2 obstaclePos = -vec2( 0.0, cellID )			// cell pos
            				+vec2( 0.5, -0.5 )			// move to cell center
            				-vec2( cellObsCol, 0.0 );	// move to column

        float distObstaclePlayer = length( obstaclePos + s.playerPos );
        
        if ( distObstaclePlayer < 0.5 ) 
        {
            color.rgb += vec3( 0.5 );
        }
    }
    
    color.rgb = mix( vec3( 0.0, 1.0, 0.0 ), color.rgb, smoothstep( 0.0, 0.1, sPlayer ) );

// OBSTACLE end        

}

float circle( vec2 p, float r )
{
    return ( length( p / r ) - 1. ) * r;
}

void opRotate( inout vec2 p, float a ) 
{
    p = cos( a ) * p + sin( a ) * vec2( p.y, -p.x );
}

vec2 opU( vec2 d1, vec2 d2 )
{
	return ( d1.x < d2.x ) ? d1 : d2;
}

sHit opUS( sHit d1, sHit d2 )
{
    if ( d1.t < d2.t )
        return d1;
    else 
        return d2;
}

float sdPlane( vec3 p, vec4 n )
{
   	p = vec3( p.z, p.x, -p.y ); // Coord fix
    // n must be normalized
          
    vec3 p0 = vec3(p.x, p.y, p.z);

    float fgProf = 0.2 * smoothstep( 1.5, 2.0, abs( p0.y ) );
    float bgProf = 1.0 * smoothstep( 3.5, 4.5, abs( p0.y ) );
    float fg = 0.15 * p.y * p.y * fgProf + fgProf * clamp( texture( iChannel2, p0.xy / 10. ).r, 0.0, 1.0 );
    float bg = 0.1 * fgProf + bgProf * clamp( texture( iChannel2, p0.xy / 40.).r, 0.0, 1.0 );
    float displace = 1.5 * fg + 2.5 * bg;
    
    float sGround = dot(
        vec3( p.x, p.y, max( p.z + displace, p.z ) ),
        n.xyz )
        + n.w;
    
    sGround *= 0.5;
    
  	return sGround;
}


float sdSphere( vec3 p, float s )
{
    return length( p ) - s;
}

float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs( p ) - b;
    return min( max( d.x, max( d.y, d.z ) ), 0.0 ) + length( max( d, 0.0 ) );
}

float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot( pa, ba ) / dot( ba, ba ), 0.0, 1.0 );
	return length( pa - ba * h ) - r;
}

float opUnion( float a, float b )
{
    return min( a, b );
}

float opIntersect( float a, float b )
{
    return max( a, b );
}

float opSubstract( float a, float b )
{
    return max( a, -b );
}

float opSubstractChamfer( float a, float b, float r ) 
{
    return max( max( a, -b ), ( a + r - b ) * 0.70711 );
}

float plane( vec3 p, vec4 plane ) 
{
    return dot( p, plane.xyz ) + plane.w;
}

float box( vec3 p, vec3 b )
{
    vec3 d = abs( p ) - b;
    return min( max( d.x, max( d.y, d.z ) ), 0.0 ) + length( max( d, 0.0 ) );
}

float cylinder( vec3 p, float r, float height ) 
{
    float d = length( p.xz ) - r;
    d = max( d, abs( p.y ) - height );
    return d;
}

float sphere( vec3 p, float s )
{
    return length( p ) - s;
}

vec2 sdColumn( vec3 p, float r, float id )
{
    return vec2( ( ( abs( p.x ) + abs( p.y ) ) - r ) / sqrt( 2.0 ), id );
}

float sdCoin( vec3 p, float id )
{       
    float sCyl = cylinder( p.yzx, 0.1, 0.02 );    

    if ( id == 2.0 )
        g_glowCoin = min( g_glowCoin, sCyl );
    
    if ( id == 12.0 )
    	g_glowCoinRefl = min( g_glowCoin, sCyl );
    
    return sCyl;
}

// From "[SH16B] Speed Drive 80" by knarkowicz. https://shadertoy.com/view/4ldGz4
float car( vec3 p, float id )
{        
    p *= 5.5;
    
    p.x = -p.x;     
    p.y -= 0.3;
    
    float a = box( p, vec3( 4.2, 0.9, 1.8 ) );   
    
    vec3 t = p + vec3( -6.0, 0.0, 0.0 );
    opRotate( t.yx, 0.2 );
    float b = plane( t, vec4( 0.0, -1.0, 0.0, 0.0 ) );
    
    t = p + vec3( -5.0, 0.0, 0.0 );
    opRotate( t.yx, -0.4 );
    float c = plane( t, vec4( 0.0, 1.0, 0.0, 0.0 ) );    
    
    t = p + vec3( 2.0, -0.2, 0.0 );
    opRotate( t.yx, -0.4 );
    float d = plane( t, vec4( 0.0, -1.0, 0.0, 0.0 ) );   
    
    t = p + vec3( 2.0, -0.3, 0.0 );
    opRotate( t.yx, -0.05 );
    float e = plane( t, vec4( 0.0, -1.0, 0.0, 0.0 ) );       
    
    t = p + vec3( 2.0, 1.0, 0.0 );
    opRotate( t.yx, 0.2 );
    float f = plane( t, vec4( 0.0, 1.0, 0.0, 0.0 ) );     
        
    if ( id == 1.0 )
    {
        float bloomF = box( t + vec3( -0.5, 0.7, 0.0 ), vec3( 0.1, 0.3, 1.5 ) );
        t.z = abs( t.z );
        t.z -= 1.5;       
        float bloomB = box( t + vec3( -4.4, -0.2, 0.0 ), vec3( 0.2, 0.4, 0.2 ) );
    	g_glowPlayer = min( g_glowPlayer, 1.0 / 5.5 * min( bloomF, bloomB ) );
    }
    
    if ( id == 3.0 )
        g_glowEnemy = min( g_glowEnemy, 1.0 / 5.5 * box( t + vec3( -2.0, 0.7, 0.0 ), vec3( 3.0, 1.0, 1.0 ) ) );

    t = p + vec3( 1.0, -0.6, 0.0 );
    opRotate( t.yx, -0.4 );
    float frontWindow = box( t, vec3( 0.6, 0.05, 1.6 ) );
    
    t = p + vec3( -2.5, -0.7, 0.0 );
    opRotate( t.yx, 0.2 );
    float backWindow = box( t, vec3( 1.0, 0.05, 1.6 ) );
    
    float body = opSubstract( a, opUnion( opUnion( opUnion( b, c ), opIntersect( d, e ) ), f ) );
    
    t = p;
    t.z = -abs( t.z );
    t += vec3( 0.0, -0.8, 1.2 );
    opRotate( t.yz, -0.9 );
    float sideCutPlanes = plane( t, vec4( 0.0, -1.0, 0.0, 0.0 ) );      
    
    body = opSubstractChamfer( body, opUnion( backWindow, frontWindow ), 0.1 );
    body = opSubstractChamfer( body, sideCutPlanes, 0.05 );
    
    p.x += 0.1;
    p.xz = abs( p.xz );
    t = p.xzy - vec3( 2.4, 1.5, -0.65 );
    float wheel = cylinder( t, 0.7, 1.0 );
    body = opSubstract( body, wheel );
    t.y -= .1;
    wheel = opSubstract( cylinder( t, 0.6, 0.3 ), sphere( t + vec3( 0.0, -0.45, 0.0 ), 0.45 ) );
    
    body = opUnion( body, wheel );
    
    body /= 5.5;
    
    return body;
}

float carFront( vec3 p, float id )
{        
    // front lights
    p.z = abs( p.z );
    p.z -= 0.2;
    float front = cylinder( p.zxy + vec3( -0.06, -0.77, -0.02 ), 0.05, 0.01 );
    
    if ( id == 1.5 )
        g_glowPlayerFront = min( g_glowPlayerFront, front );
       
    return front;
}

float carLights( vec3 p, float id )
{        
    // back lights
    p.z = abs( p.z );
    p.z -= 0.2;
    float back = box( p + vec3( 0.75, -0.09, 0.0 ), vec3( 0.02, 0.02, 0.075 ) );
    
    if ( id == 1.5 )
    	g_glowPlayerLights = min( g_glowPlayerLights, back );
       
    return back;
}


float carRefl( vec3 p, float id )
{        
    float body = box( p + vec3( 0.0, -0.07, 0.0 ), vec3( 0.6, 0.02, 0.2) );
    body = min( body, box( p + vec3( 0.2, -0.1, 0.0 ), vec3( 0.4, 0.02, 0.2 ) ) );
    
    // back lights
    p.z = abs( p.z );
    p.z -= 0.2;
    float bloom = box( p + vec3( 0.75, -0.09, 0.0 ), vec3( 0.02, 0.02, 0.075 ) );    
    
    bloom = min( bloom, body );
    
    if ( id == 1.5 )
    	g_glowPlayerRefl = min( g_glowPlayerRefl, bloom );
    
    if ( id == 3.5 )
        g_glowEnemyRefl = min( g_glowEnemyRefl, bloom );
       
    return body;
}

vec2 getBent()
{
    float bentSide	= sin( g_S.timeAccumulated / PI );
    float bentUp	= ( ( cos( 0.25 * g_S.timeAccumulated / PI ) * 0.5 ) + 0.5 ) * 1.5;
    return vec2( bentSide, bentUp );
}

sHit map( in vec3 pos )
{
    sHit sRes = createHit( 1e10, 0.0, pos );

	// player, in place in fact
    vec2 bent = getBent();
    
    // game
    vec3 p0 = pos;    
    // bending    
    p0.x -= 1.5 * sin( 0.05 * p0.z * PI ) * bent.x;
    p0.y += 1.5 * sin( 0.05 * p0.z * PI ) * bent.y;
   
    vec3 pPlayer = pos -vec3( g_S.playerPos.x, 0.25, 0.0 );
    
    pPlayer.xz *= rot(  0.2 * bent.x );
    pPlayer.yz *= rot( -0.2 * bent.y );
    // sRes = opUS( sRes, CreateHit( sdBox( pPlayer, vec3(0.5, 0.2, 0.5) ) - 0.01, 1.0, pPlayer) ); // debug collider
    
	float rotY = -.2 * g_S.isPressedLeft + .2 * g_S.isPressedRight;
    float rotX = -.1 * g_S.isPressedLeft + .1 * g_S.isPressedRight;    
    pPlayer.xz *= rot( -0.01 * PI * bent.y + rotY -0.5 * PI );
    pPlayer.yz *= rot( -0.01 * PI * bent.x + rotX );
    // pPlayer.yz *= rot( -10.0*iTime ); // mothman
    pPlayer.y += 0.05;    
    sRes = opUS( sRes, createHit( car( pPlayer, 1.0 ), 1.0, pPlayer ) );
	sRes = opUS( sRes, createHit( carLights( pPlayer, 1.5 ), 1.5, pPlayer ) );
    sRes = opUS( sRes, createHit( carFront( pPlayer, 1.6 ), 1.6, pPlayer ) );
    
    vec3 pEnv = p0;
    pEnv.z += 2.0 * g_S.playerPos.y;
    pEnv.x -= 0.5;
    sRes = opUS( sRes, createHit( sdPlane( pEnv, vec4( 0, 0, -1, 0 ) ), 0.0, vec3( pEnv.x, 0.0, pEnv.z ) ) );
    
    p0.z *= 0.5;
    p0.z += g_S.playerPos.y;
    
    vec3 p0Mod = p0;
    p0Mod.z = mod( p0.z + 0.5, 1.0 ) - 0.5;
                
    float playerCellID = floor( g_S.playerPos.y );
   
    // COIN start
    float cellID = floor( p0.z + 0.5 );
    
    float cellCoinRND = hash11( cellID + g_S.seed ); // skip rnd obstacle every second cell to make room for driving    
    cellCoinRND *= mix( 1.0, -1.0, step( mod( cellID, 4.0 ), 1.5 ) ); // gaps in coin placing: 2 gaps, 2 coins
    cellCoinRND = mix( cellCoinRND, -1.0, step( cellID, 5.0 ) ); // head start
    float cellCoinCol = floor( 3.0 * cellCoinRND );
    
    if (cellCoinRND >= 0.0)
    {
        vec3 pCoin = p0Mod; 
        float bounce = 0.3 * abs( sin( 5.0 * iTime + cellID ) );
        vec3 coinOffset = vec3( -0.5  + cellCoinCol, 0.4 + bounce, 0.0 );
        pCoin -= coinOffset;
        pCoin.z *= 2.0;
        pCoin.xz *= rot( 10.0 * iTime );
                
        if ( cellID > playerCellID )
            sRes = opUS( sRes, createHit( sdCoin( pCoin, 2.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID && g_S.coin0Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 2.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID - 1.0 && g_S.coin1Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 2.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID - 2.0 && g_S.coin2Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 2.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID - 3.0 && g_S.coin3Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 2.0 ) - 0.01, 2.0, pCoin ) );
    }    
       
    float cellObsRND = hash11( 100.0 * cellID + g_S.seed ); // skip rnd obstacle every second cell to make room for driving
    cellObsRND *= mix( 1.0, -1.0, step( mod( cellID, 3.0 ), 1.5 ) );
    cellObsRND = mix( cellObsRND, -1.0, step( cellID, 7.0 ) ); // head start
    float cellObsCol = floor( 3.0 * cellObsRND );

    if ( cellObsRND >= 0.0 && cellObsCol != cellCoinCol )
    {            
        vec3 obstacleOffset = vec3(
            -0.5 + cellObsCol,  
             0.2,
             0.0
        );

        // sRes = opUS( sRes, CreateHit( sdBox( p0Mod -obstacleOffset, vec3(0.5, 0.1, 0.5) ) - 0.01, 3.0, p0Mod ) ); // debug colider
        p0Mod -= obstacleOffset;
        p0Mod.z *= 2.0;
        p0Mod.xz *= rot( -0.5 * PI );
        sRes = opUS( sRes, createHit( car( p0Mod, 3.0 ), 3.0, p0Mod ) );
        sRes = opUS( sRes, createHit( carLights( p0Mod, 3.5 ), 3.5, p0Mod ) );
        sRes = opUS( sRes, createHit( carFront( p0Mod, 3.6 ), 3.6, p0Mod) );
    }

    return sRes;
}

sHit mapRefl( in vec3 pos )
{
    sHit sRes = createHit( 1e10, -1.0, pos );

    vec2 bent = getBent();
    vec3 p0 = pos;    
    p0.x -= 1.5 * sin( 0.05 * p0.z * PI) * bent.x;
    p0.y += 1.5 * sin( 0.05 * p0.z * PI) * bent.y;
   
    float rotY = -.2 * g_S.isPressedLeft + .2 * g_S.isPressedRight;
    float rotX = -.1 * g_S.isPressedLeft + .1 * g_S.isPressedRight;    
    vec3 pPlayer = pos - vec3( g_S.playerPos.x, 0.25, 0.0 );
    pPlayer.xz *= rot(  0.2 * bent.x );
    pPlayer.yz *= rot( -0.2 * bent.y );
    pPlayer.xz *= rot( -0.01 * PI * bent.y + rotY -0.5 * PI);
    pPlayer.yz *= rot( -0.01 * PI * bent.x + rotX);
    pPlayer.y += 0.05;
	sRes = opUS( sRes, createHit( carRefl( pPlayer, 1.5 ), 1.5, pPlayer) );

    p0.z *= 0.5;
    p0.z += g_S.playerPos.y;      
    
    vec3 p0Mod = p0;
    p0Mod.z = mod( p0.z + 0.5, 1.0 ) -0.5;
                
    float playerCellID = floor( g_S.playerPos.y );
   
    // COIN start
    float cellID = floor( p0.z + 0.5 );
    
    float cellCoinRND = hash11( cellID + g_S.seed ); // skip rnd obstacle every second cell to make room for driving    
    cellCoinRND *= mix( 1.0, -1.0, step( mod( cellID, 4.0 ), 1.5 ) ); // gaps in coin placing: 2 gaps, 2 coins
    cellCoinRND = mix( cellCoinRND, -1.0, step( cellID, 5.0 ) ); // head start
    float cellCoinCol = floor( 3.0 * cellCoinRND );
    
    if ( cellCoinRND >= 0.0 )
    {
        vec3 pCoin = p0Mod; 
        float bounce = 0.3 * abs( sin( 5.0 * iTime + cellID ) );
        vec3 coinOffset = vec3( -0.5 + cellCoinCol, 0.4 + bounce, 0.0 );
        pCoin -= coinOffset;
        pCoin.z *= 2.0;
        pCoin.xz *= rot( 10.0 * iTime );
                
        if ( cellID > playerCellID )
            sRes = opUS( sRes, createHit( sdCoin( pCoin, 12.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID && g_S.coin0Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 12.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID - 1.0 && g_S.coin1Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 12.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID - 2.0 && g_S.coin2Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 12.0 ) - 0.01, 2.0, pCoin ) );
        
        if ( cellID == playerCellID - 3.0 && g_S.coin3Taken < 0.5 )
        	sRes = opUS( sRes, createHit( sdCoin( pCoin, 12.0 ) - 0.01, 2.0, pCoin ) );
    }    
       
    float cellObsRND = hash11( 100.0 * cellID + g_S.seed ); // skip rnd obstacle every second cell to make room for driving
    cellObsRND *= mix( 1.0, -1.0, step( mod( cellID, 3.0 ), 1.5 ) );
    cellObsRND = mix( cellObsRND, -1.0, step( cellID, 7.0 ) ); // head start
    float cellObsCol = floor( 3.0 * cellObsRND );

    if ( cellObsRND >= 0.0 && cellObsCol != cellCoinCol )
    {            
        vec3 obstacleOffset = vec3(
            -0.5 + cellObsCol,  
             0.2,
             0.0
        );

        p0Mod -= obstacleOffset;
        p0Mod.z *= 2.0;
        p0Mod.xz *= rot( -0.5 * PI );
        sRes = opUS( sRes, createHit( carRefl( p0Mod, 3.5), 3.5, p0Mod ) );
    }

    return sRes;
}


// https://iquilezles.org/articles/boxfunctions
vec2 iBox( in vec3 ro, in vec3 rd, in vec3 rad ) 
{
    vec3 m = 1.0 / rd;
    vec3 n = m * ro;
    vec3 k = abs( m ) * rad;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
	return vec2( max( max( t1.x, t1.y ), t1.z ),
	             min( min( t2.x, t2.y ), t2.z ) );
}

sHit castRay( in vec3 ro, in vec3 rd, float tmin, float tmax )
{
    sHit sRes = createHit( -1.0, -1.0, rd );

    // raymarch primitives   
    vec2 tb = iBox( ro - vec3( 0.0, 0.0, 15.0 ), rd, vec3( 7.0, 4.0, 45.0 ) );
    
    if( tb.x < tb.y && tb.y > 0.0 && tb.x < tmax )
    {
        tmin = max( tb.x, tmin );
        tmax = min( tb.y, tmax );       

        float t = tmin;
        for( int i = ZERO; i < 128 && t < tmax; i++ )
        {
            sHit h = map( ro + rd * t );
            if( abs( h.t ) < ( 0.001 * t ) )
            { 
                // res = vec2(t,h.y); 
                sRes = createHit( t, h.m, h.lPos ); 
                break;
            }
            t += h.t;
        }
    }
    
    return sRes;
}

sHit castRayRefl( in vec3 ro, in vec3 rd, float tmin, float tmax )
{
    sHit sRes = createHit( -1.0, -1.0, rd );

    // raymarch primitives   
    vec2 tb = iBox( ro - vec3( 0.0, 0.0, 5.0 ), rd, vec3( 4.0, 4.0, 25.0 ) );
    
    if( tb.x < tb.y && tb.y > 0.0 && tb.x < tmax )
    {
        tmin = max( tb.x, tmin );
        tmax = min( tb.y, tmax );       

        float t = tmin;
        for( int i = ZERO; i < 32 && t < tmax; i++ )
        {
            sHit h = mapRefl( ro + rd * t );
            if( abs( h.t ) < ( 0.001 * t ) )
            { 
                sRes = createHit( t, h.m, h.lPos ); 
                break;
            }
            t += h.t;
        }
    }

    return sRes;
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos )
{
#if 1
    // vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    vec2 e = vec2( 1.0, -1.0 ) * 0.5773 * 0.01;
    return normalize( e.xyy*map( pos + e.xyy ).t + 
					  e.yyx*map( pos + e.yyx ).t + 
					  e.yxy*map( pos + e.yxy ).t + 
					  e.xxx*map( pos + e.xxx ).t );
#else
    // inspired by tdhooper and klems - a way to prevent the compiler from inlining map() 4 times
    vec3 n = vec3( 0.0 );
    for( int i = ZERO; i < 4; i++ )
    {
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e * map( pos + 0.0005 * e ).x;
    }
    return normalize( n );
#endif    
}

float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
    float sca = 1.0;
    for( int i = ZERO; i < 5; i++ )
    {
        float hr = 0.01 + 0.12 * float( i ) / 4.0;
        vec3 aopos =  nor * hr + pos;
        float dd = map( aopos ).t;
        occ += -( dd - hr ) * sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 3.0 * occ, 0.0, 1.0 ) * (0.5 + 0.5 * nor.y );
}

vec3 getSkyColor( vec3 rd )
{
    vec3 color = mix( SKY_COLOR_1 * 1.4, SKY_COLOR_2, rd.y / 9.0 );
	
    float fogFalloff = clamp( 8.0 * rd.y, 0.0, 1.0 );
    color = mix( FOG_COLOR, color, fogFalloff );
    color = mix( color, GRID_COLOR_1, smoothstep( -0.1, -0.2, rd.y ) );

    vec3 sunDir = normalize( SUN_DIRECTION );
    float sunGlow = smoothstep( 0.9, 1.0, dot( rd, sunDir ) );
        
    rd = mix( rd, sunDir, -1.0 ); // easier to bend vectors than fiddle with falloff :P
    float sun = smoothstep( 0.987, 0.99, dot(rd, sunDir ) );
    sun -= smoothstep( 0.1, 0.9, 0.5 );			        
    
    float stripes = mod( 50.0 * ( pow( rd.y + 0.15, 1.5 ) ) + 0.5, 1.0 ) -0.5;
    stripes = smoothstep( 0.2, 0.21, abs( stripes ) );
        
    
    // based on https://www.shadertoy.com/view/tssSz7
    vec2 starTile   = floor( rd.xy * 40.0 );
    vec2 starPos    = fract( rd.xy * 40.0 ) * 2.0 - 1.0;
    vec2 starRand = hash22( starTile );
    starPos += starRand * 2.0 - 1.0;
    float stars = saturate( 1.0 - ( ( sin( iTime * 1.0 + 50.0 * rd.y ) ) * 0.5 + 6.0 ) * length( starPos ) );
    stars *= step( 0.0, -sun );
    stars *= step( 0.9, starRand.x );
    stars *= 5.0;
           
    sun = 2.0 * clamp( sun * stripes, 0.0, 1.0 );
    
    vec3 sunCol = 4.0 * mix( SUN_COLOR_1, SUN_COLOR_2, -( rd.y - 0.1 ) / 0.3 );
    color = mix( color, sunCol, sun );

	color = mix( FOG_COLOR, color, 0.8 + 0.2 * fogFalloff );
    color = mix( color, sunCol, 0.25 * sunGlow );
    
    color += stars;

    // return vec3(stripes);
    // return vec3(sun);
    // return vec3(sunGlow);
    return color;
}

vec4 shade( vec3 wPos, vec3 lPos, vec3 nor, vec3 rd, float m )
{       
    vec2 bent = getBent();
    // repeat car rotation with fixes
    float rotY = -.2 * g_S.isPressedLeft + .2 * g_S.isPressedRight;
    float rotX = -.1 * g_S.isPressedLeft + .1 * g_S.isPressedRight;

    vec3 albedo = vec3( 0.5 );
    float met = 1.0;
    vec4 color = vec4( albedo, met );
    vec3 emissive = vec3( 0.0 );
        
    if ( m == 0.0 )
    {
        vec2 p0 = lPos.xz;
        p0.x -= 1.5 * sin( 0.05 * p0.y * PI ) * smoothstep( -0.5, 0.5, sin( iTime ) );
        vec2 uv = abs( mod( lPos.xz + GRID_SIZE / 2.0, GRID_SIZE ) - GRID_SIZE / 2.0 );
        uv /= fwidth( lPos.xz );
        float gln = min( min( uv.x, uv.y ), 1.) / GRID_SIZE;
        
    	albedo = mix( GRID_COLOR_1, GRID_COLOR_2, 0.7 - smoothstep( 0.0, GRID_LINE_SIZE / GRID_SIZE, gln ) );
        
        float pSideLine = lPos.x;
		pSideLine = abs( pSideLine );
        pSideLine -= 1.45;
        pSideLine = abs( pSideLine );
        float sideLine = 1.0 - smoothstep( 0.03, 0.04, pSideLine );
        
        float pCenterLine = lPos.x;
		pCenterLine = abs( pCenterLine );
        pCenterLine -= 0.55;
        pCenterLine = abs( pCenterLine );
        float centerLine = 1.0 - smoothstep( 0.03, 0.04, pCenterLine );
        
        float pCenterLineBreak = mod( lPos.z + 0.5, 1.0) - 0.5;
        float centerLineBreak = smoothstep( 0.15, 0.16, abs( pCenterLineBreak ) );
        float damage = pow( texture( iChannel1, 0.03 * lPos.xz ).r, 1.5 );
        albedo = mix( albedo, vec3( 1.0, 1.0, 0.5 ), ( sideLine + centerLine * centerLineBreak ) * damage );
               
        vec2 pTrail = vec2( lPos.x - g_S.playerPos.x + 0.5, lPos.z - 2.0 * g_S.playerPos.y );
        pTrail.x += 4.0 * rotY; // move the cos
        pTrail.x -= 4.0 * rotY * ( cos( 0.75 * pTrail.y - 0.1 * PI ) * 0.5 + 0.5 ); // fake car turns
        pTrail.x = abs( pTrail.x );
        pTrail.x -= 0.28;
        pTrail.x = abs( pTrail.x );
               
        float trailMask = exp( -30.0 * pTrail.x );
        trailMask += 0.2 * saturate( exp( -4.0 * pTrail.x ) );
        trailMask *= saturate( -pTrail.y + 0.5 );		// clamp on Y
        trailMask *= saturate(  pTrail.y * 0.5 + 1.5 );	// clamp on Y
        emissive += vec3( 1.5, 0.2, 0.0 ) * trailMask;       
    }
    
    if ( m == 1.0 )
    {
        vec2 p0 = 2.6 * lPos.xz;
        p0.x -= 1.5 * sin( 0.05 * p0.y * PI ) * smoothstep( -0.5, 0.5, sin( iTime ) );
        vec2 uv = abs( mod( 3.0 * lPos.xz + GRID_SIZE / 2.0, GRID_SIZE ) - GRID_SIZE / 2.0 );
        uv /= fwidth( lPos.xz );
        float gln = min( min( uv.x, uv.y ), 1. ) / GRID_SIZE;
        vec3 carCol = mix( CAR_PLAYER_COLOR_1, CAR_PLAYER_COLOR_2, 0.7 - smoothstep( 0.0, GRID_CAR_LINE_SIZE / GRID_CAR_SIZE, gln ) );
        
        float coinImp = step( 0.0, g_S.timeCollected ) * impulse( 2.0, max( 0.0, iTime - g_S.timeCollected ) * 6.0 );
        albedo = mix( carCol, vec3( 1.0, 1.0, 0.5 ), sin( 100.0 * iTime ) * coinImp );
        
        float obsImp = step( 0.0, g_S.timeFailed ) * max( 0.0, iTime - g_S.timeFailed );
        albedo = mix( albedo, vec3( 1.0, 0.0, 0.0) , sin( 100.0 * iTime ) * obsImp );
    }
    
    if ( m == 1.5 )
    {
        emissive = albedo = vec3( 1.5, 0.5, 0.5 );
    }
    
    if ( m == 1.6 )
    {
        emissive = albedo = vec3( 0.5, 0.5, 1.5 );
    }
    
    if ( m == 2.0 )
    {
        albedo = vec3( 1.0, 1.0, 0.5 );
        emissive = 10.0 * albedo;
    }
    
    if ( m == 3.0 )
    {
       vec2 p0 = 2.6 * lPos.xz;
        p0.x -= 1.5 * sin( 0.05 * p0.y * PI) * smoothstep( -0.5, 0.5, sin( iTime ) );
        vec2 uv = abs( mod( 3.0 * lPos.xz + GRID_SIZE / 2.0, GRID_SIZE ) - GRID_SIZE / 2.0 );         
        uv /= fwidth( lPos.xz );
        float gln = min( min( uv.x, uv.y ), 1. ) / GRID_SIZE;
        
        albedo = mix( CAR_COLOR_1, CAR_COLOR_2, 0.7 - smoothstep( 0.0, GRID_CAR_LINE_SIZE / GRID_CAR_SIZE, gln ) );
    }
    
    if ( m == 3.5 )
    {
        emissive = albedo = vec3( 1.0, 0.5, 0.5 );
    }
    
    if ( m == 3.6 )
    {
        emissive = albedo = vec3( 0.5, 0.5, 1.0 );
    }

    if ( m == 4.0 )
    {
        albedo = 0.2 * vec3( 1.0, 0.0, 1.0 );
    }
            
	// spotlight, paramteres-
    vec3 perSpotOffset = vec3( 0.0, 0.05, 0.8 );
    vec3 pSpot = vec3( wPos.x - g_S.playerPos.x, 0.0, wPos.z );
    pSpot -= perSpotOffset;
    vec3 spotDir = normalize( vec3( 0.0, -0.1, 1.0 ) );
    vec3 spotColor  = 100.0 * vec3( 1.0 );
    
    pSpot.yz *= rot( -0.2  * bent.y );
    pSpot.xz *= rot( -0.01 * bent.y * PI + rotY );
    pSpot.yz *= rot( -0.01 * bent.x * PI + rotX );
    spotDir.yz *= rot( 0.2 * bent.y );
    spotDir.xz *= rot(-0.2 * rotY );
    spotDir.yz *= rot(-0.2 * rotX );
    
    // spotlight, color
    float maskDist = fract( ( length( pSpot ) - 1.0 ) );
    float spotAtt = 1.0 / pow( 1.0 * length( pSpot ), 2.0 );
    spotAtt *= smoothstep( 0.1, 1.1, dot( normalize( pSpot ), spotDir ) );
    spotAtt *= saturate( dot( -nor, spotDir ) );
    emissive += albedo * spotColor * spotAtt;    
        
    float fre = pow( 0.5 * ( 1.0 + dot( nor, rd ) ), 2.0 );
    float amb = clamp( 0.5 + 0.5 * nor.y, 0.0, 1.0 );
    float occ = calcAO( wPos, nor );    
    vec3  lig = normalize( SUN_DIRECTION + vec3( 0.0, 0.2, 0.0 ) );
    float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
	vec3  hal = normalize( lig - rd );
    float spe = pow( clamp( dot( nor, hal ), 0.0, 1.0 ), 64.0 )
        * dif
        * ( 0.04 + 0.96 * pow( clamp( 1.0 + dot( hal, rd ), 0.0, 1.0 ), 5.0 ) );
   
    color.rgb = albedo * ( 0.5 + 0.5 * occ ) * ( 0.7 + 0.3 * dif ) + spe * vec3( 1.0, 0.5, 0.1 );
	color.rgb += emissive;
	color.a = fre;
    
    return color;
    // return vec4(vec3(0.4) * m, 0.5); // debug material ID
    // return vec4(vec3(fre), 0.0);
}

float densityNoise( vec3 pos )
{
    vec2 bent = getBent();
    
    float noise = 1.0;
    float noiseDetail = textureLod( iChannel1, vec2( 1.0, 1.0 ) * pos.xz / 64.0, 0.0 ).x;        
    pos.x -= pos.y;
    vec2 uv1 = vec2( 0.2, 1.5 ) * pos.xz / 64.0 + iTime * vec2( 0.01, 0.1 );
    float noiseBase = textureLod( iChannel1, uv1, 0.0 ).y;
    noise = step( 0.6, noiseBase );
    noise *= noiseDetail * 0.5 + 0.5;
    noise *= smoothstep( 1.5, 0.0, pos.y ); // height falloff    
    noise *= ( 1.0 - bent.y ); // disable on hills    
	return noise;
}

void volumetricFog( inout vec3 color, vec3 rayOrigin, vec3 rayDir, float sceneT )
{ // From "[SH16B] Speed Drive 80" by knarkowicz. https://shadertoy.com/view/4ldGz4
    float gFogDensity		= 0.1;
    rayOrigin.z += 2.0 * g_S.playerPos.y;
    
    sceneT = sceneT <= 0.0 ? 100.0 : sceneT;
    
    vec3 seed = vec3( 0.06711056, 0.00583715, 52.9829189 );
    float dither = fract( seed.z * fract( dot( gl_FragCoord.xy, seed.xy ) ) );
    
    float fogAlpha = 0.0;
    for ( int i = ZERO; i < 32; ++i )
    {
        float t = ( float( i ) + 0.5 + dither ) * 5.0;
        if ( t <= sceneT )
        {
        	vec3 p = rayOrigin + t * rayDir;
            float s = densityNoise( p );
            fogAlpha += gFogDensity * t * exp( -gFogDensity * t ) * s;
        }
    }
    fogAlpha = 1.0 - saturate( fogAlpha );
    vec3 fogColor = FOG_COLOR + vec3( 1.0 );
    color = mix( fogColor, color, fogAlpha );
    // color = vec3(0.01)*sceneT;
}

vec3 Bloom()
{
    vec3 bloom = vec3( 0.0 );
    bloom += vec3( 1.0, 0.2, 0.1 )  * 0.5 * vec3( exp( -g_glowCoin * 10.0 ) );
    bloom += vec3( 1.0, 0.2, 0.1 )  * 0.3 * vec3( exp( -g_glowCoinRefl * 10.0 ) );
    bloom += vec3( 1.0, 0.2, 0.0 )  * 1.0 * vec3( exp( -saturate(g_glowPlayer) * 10.0 ) );
    bloom += vec3( 1.0, 0.2, 0.0 )  * 0.5 * vec3( exp( -saturate(g_glowPlayerRefl) * 10.0 ) );
    bloom += vec3( 1.0, 0.05, 0.0 ) * 0.3 * vec3( exp( -saturate(g_glowPlayerLights) * 15.0 ) );
    bloom += vec3( 0.0, 0.05, 1.0 ) * 0.3 * vec3( exp( -saturate(g_glowPlayerFront) * 15.0 ) );
    bloom += vec3( 1.0, 0.2, 0.0 )  * 0.5 * vec3( exp( -saturate(g_glowEnemy) * 5.0 ) );
    bloom += vec3( 1.0, 0.2, 0.0 )  * 0.0 * vec3( exp( -saturate(g_glowEnemyRefl) * 5.0 ) );
    return bloom;
}

vec4 render( in vec3 ro, in vec3 rd )
{ 
    vec3 sky = getSkyColor( rd );
    vec4 col = vec4( sky, 1.0 );
    sHit sRes = castRay( ro, rd, 1.0, 40.0 );
    float t = sRes.t;
	float m = sRes.m;
    if( m > -0.5 )
    {
        vec3 pos = ro + t*rd;
        vec3 nor = calcNormal( pos );
        vec3 ref = reflect( rd, nor );
		
        col = shade( pos, sRes.lPos, nor, rd, m );

#ifdef REFLECTIONS
        vec3 seed = vec3( 0.06711056, 0.00583715, 52.9829189 );
	    float dither = fract( seed.z * fract( dot( gl_FragCoord.yx + fract( iTime ), seed.xy ) ) );

        vec4 bounceCol = vec4( getSkyColor( ref ), 0.0 );
        ref = normalize( mix( ref, vec3(0.0, 1.0, 0.0 ), dither * 0.1 ) );
        sHit bounceRes = castRayRefl( pos, ref, 0.1, 20.0 ); // only trace for bloom, do not shade
        float bounceT = bounceRes.t;
        if ( bounceRes.m < 0.0 )
        	bounceCol = vec4( getSkyColor( ref ), 0.0 );

        col = vec4( mix( col.xyz, bounceCol.xyz, col.w ), 0.0 );
            
#endif // REFLECTIONS
        
        col.rgb += Bloom();
        col.rgb *= 1.5;        
    }
        
    col.rgb = mix( col.rgb, FOG_COLOR, 1.0 - exp( -0.00005 * t * t * t ) );

#ifdef VOLUMETRICS
    volumetricFog( col.rgb, ro, rd, t );
#endif // VOLUMETRICS
    
    // blur mask
    col.a = 1.0 - ( dot( rd, normalize( SUN_DIRECTION + vec3( 0.0, 0.05, 0.0 ) ) ) * 0.5 + 0.5 );
    
	return col;
}

void drawGame3D( inout vec4 color, vec2 uv, AppState s )
{   
    vec2 mo = iMouse.xy / iResolution.xy;
   
    vec2 bent = getBent();

    float fbm = fbm3( vec3( 1000.0 * iTime ) );
    float crash = step( 0.0, g_S.timeFailed ) * impulse( 2.0, max( 0.0, iTime - g_S.timeFailed ) * 6.0 );
    // camera	    
    float roll = -0.1 * bent.x;
    float arm = 3.5 + 0.2 * s.paceScale;
    float angleH = -0.5 * PI + 0.1 * bent.x;
    float height = 1.2 + bent.y + crash * fbm + 0.05 * g_S.paceScale * fbm;
    float fov = 2.0 - 0.5 * s.paceScale;
    
    vec3 ro = vec3( 0.0 );
    
    if ( s.timeFailed > 0.0 )
    {
        roll = mix( roll, 0.0, saturate( iTime - s.timeFailed ) );
        arm = mix( arm, 3.5, saturate( iTime - s.timeFailed ) );
        angleH += iTime - s.timeFailed;
    }
    
    if ( s.stateID == GS_SPLASH )
    {
        arm += 0.5 * sin( iTime ) * 0.5 + 0.5;
        roll = -0.1 * ( mo.x - 0.5 );
        angleH += 0.5 * ( mo.x - 0.5 );
        height += 0.5 * (mo.y - 0.5 );                
    }
    
    ro = vec3( arm * cos( angleH ), height, arm * sin( angleH ) );
    
#ifdef DEBUG_CAMERA    
    roll = 0.0;
    ro = vec3( 0.5 + 3.5 * cos( 12.0 * mo.x ), 0.5 + 4.0 * mo.y, -0.5 + 3.5 * sin( 12.0 * mo.x ) );
#endif        
    
    vec3 ta = vec3(
        0.0, 
        mix( 1.0, 0.5, step( 0.0, s.timeFailed ) * saturate( iTime - s.timeFailed ) ),
        0.0
    );

#ifdef CAM_STICKED    
    ro.x += s.playerPos.x;
    ta.x += s.playerPos.x;
#endif    
    
    // camera-to-world transformation
    mat3 ca = setCamera( ro, ta, roll );
   
    // ray direction
    vec3 rd = ca * normalize( vec3( uv.xy, fov ) );
    
    // render	
    vec4 col = render( ro, rd );
       
    color = col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	fragColor = vec4(0.0);
    
	vec2 q = F.xy / R.xy;
    vec2 p = -1. + 2. * q;
	p.x *= R.x / R.y;

#ifdef FORCED_RATIO
	float bars = step( abs( p.y ) * g_forceRatio, R.x / R.y );
    if ( bars < 0.5 ) return;
#endif // FORCED_RATIO    
    
    AppState s;
    loadState( iChannel0, s );
    g_S = s;

    vec4 color = vec4( 0.0, 0.0, 0.0, 1.0 );
       
    vec2 pGame = p;
    pGame.x *= -1.0; // flip axis to match Flat version
    drawGame3D( color, pGame, s );
   
#ifdef DEBUG_2D
    vec2 p0 = p;    
    p0 *= 2.0;
    p0 -= vec2( -3.0, 0.0 );
    if ( p0.x < 0.7 && p0.y > -1.0 )
    {
        // drawGameFlat( color, p0, s );
    	// drawUI(color, p0, s);
    }
#endif    
    
	fragColor = color;
}