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



AppState updateGame( AppState s, float isDemo )
{
    if ( isDemo > 0.0 )
    {
        s.timeAccumulated += 1.0 * iTimeDelta;
    	s.playerPos.y = 5.0 * s.timeAccumulated;
    }
    else
    {
        float playerCellID = floor( s.playerPos.y );
        s.paceScale = saturate( ( playerCellID - 50.0) / 500.0);
        float timeMultiplier = mix( 0.75, 2.0, pow( s.paceScale, 1.0 ) );

        s.timeAccumulated += timeMultiplier * iTimeDelta;
        s.playerPos.y = 5.0 * s.timeAccumulated;
    }    
    
    float playerCellID = floor( s.playerPos.y );

    if ( isDemo > 0.0 )
    {           
        float cellOffset = 1.0;
        float nextPlayerCellID = playerCellID + cellOffset;

        float nextCellCoinRND = hash11( nextPlayerCellID + s.seed ); // skip rnd obstacle every second cell to make room for driving
        nextCellCoinRND *= mix( 1.0, -1.0, step( mod( nextPlayerCellID, 4.0 ), 1.5 ) ); // gaps in coin placing: 2 gaps, 2 coins
        nextCellCoinRND = mix( nextCellCoinRND, -1.0, step( nextPlayerCellID, 5.0 ) ); // head start
        float nextCellCoinCol = floor( 3.0 * nextCellCoinRND );

        // OBSTACLE
        float nextCellObsRND = hash11( 100.0 * nextPlayerCellID + s.seed );
        nextCellObsRND *= mix( 1.0, -1.0, step( mod( nextPlayerCellID, 3.0 ), 1.5 ) );
        nextCellObsRND = mix( nextCellObsRND, -1.0, step( nextPlayerCellID, 7.0 ) ); // head start
        float nextCellObsCol = floor( 3.0 * nextCellObsRND );
        
        float inputObs = 0.0;                
        if ( nextCellObsCol > -0.5 )
        {
            nextCellCoinCol -= 0.5; // pos fix
        	float toObs = nextCellObsCol - s.playerPos.x;
        
            if ( nextCellObsCol == 1.0 )
                inputObs = hash11( nextPlayerCellID + s.seed );
            
            if ( nextCellObsCol < 1.0 )
                inputObs = 1.0;

            if ( nextCellObsCol > 1.0 )
                inputObs = -1.0;
        }
        
        
        float inputCoin = 0.0;
        if ( nextCellCoinCol > -0.5 )
        {               
            nextCellCoinCol -= 0.5; // pos fix
            float toCoin = nextCellCoinCol - s.playerPos.x;
            
			inputCoin = sign(toCoin) * saturate( abs( toCoin ) );
        }

        float inputDir = inputCoin + 5.0 * inputObs;
        inputDir = sign( inputDir ) * 4.0 * saturate( abs( inputDir ) );
        
        s.isPressedLeft  = step( 0.5, -inputDir );
        s.isPressedRight = step( 0.5,  inputDir );
    }

    float speed = mix( 0.1, 0.15, isDemo );
    s.playerPos.x -= speed * s.isPressedLeft; 
    s.playerPos.x += speed * s.isPressedRight; 

    s.playerPos.x = clamp( s.playerPos.x, -0.5, 1.5 );

    if ( playerCellID != s.coin0Pos ) 
    {
        s.coin3Pos 	 = s.coin2Pos;
        s.coin3Taken = s.coin2Taken;

        s.coin2Pos 	 = s.coin1Pos;
        s.coin2Taken = s.coin1Taken;

        s.coin1Pos 	 = s.coin0Pos;
        s.coin1Taken = s.coin0Taken;

        s.coin0Pos = playerCellID;
        s.coin0Taken = 0.0;
    }
 
    // COIN start
    float cellCoinRND = hash11( playerCellID + s.seed ); // skip rnd obstacle every second cell to make room for driving
    cellCoinRND *= mix( 1.0, -1.0, step( mod( playerCellID, 4.0 ), 1.5 ) ); // gaps in coin placing: 2 gaps, 2 coins
    cellCoinRND = mix( cellCoinRND, -1.0, step( playerCellID, 5.0 ) ); // head start
    float cellCoinCol = floor( 3.0 * cellCoinRND );

    vec2 coinPos = -vec2( 0.0, playerCellID )	// cell pos
        +vec2( 0.5, -0.5 )	// move to cell center
        -vec2( cellCoinCol, 0.0 ); // move to column

    if ( cellCoinRND >= 0.0 )
    {        
        float distCoinPlayer = length( coinPos + s.playerPos );

        if ( distCoinPlayer < 0.5 && s.coin0Taken < 0.5 )
        {
            if ( isDemo < 1.0 )
            	s.score++;
            
            s.coin0Taken = 1.0;
            s.timeCollected = iTime;
        }
    }
    // COIN end

    // OBSTACLE start
    float cellObsRND = hash11( 100.0 * playerCellID + s.seed );
    cellObsRND *= mix( 1.0, -1.0, step( mod( playerCellID, 3.0 ), 1.5 ) );
    cellObsRND = mix( cellObsRND, -1.0, step( playerCellID, 7.0 ) ); // head start
    float cellObsCol = floor( 3.0 * cellObsRND );

    if ( cellObsRND >= 0.0 && cellObsCol != cellCoinCol )
    {   
        vec2 obstaclePos = -vec2( 0.0, playerCellID )	// cell pos
            +vec2( 0.5, -0.25 )	// move to cell center
            -vec2(cellObsCol, 0.0 ); // move to column

        float distObstaclePlayer = length( obstaclePos + s.playerPos );

        if ( distObstaclePlayer < 0.5 && isDemo < 1.0 )
        {
            s.timeFailed = iTime;
            s.timeCollected = -1.0;
            s.highscore = max( s.highscore, s.score );
        }
    }
    // OBSTACLE end        
    return s;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = vec4(0.0);
    
    if ( fragCoord.x >= 8. || fragCoord.y >= 8. ) 
    {        
        discard;    
    }
    
    AppState s;
    loadState( iChannel0, s );
        
    s.showUI = mod( s.showUI + texelFetch( iChannel1, ivec2( ASCII_U, 1 ), 0 ).x, 2.0 );
    float isSpacePressed = texelFetch( iChannel1, ivec2( ASCII_SPACE, 1 ), 0 ).x;
   
  	// read keys that people usually press
    // https://www.shadertoy.com/view/lsXGzf
    float keyLeft = 0.0;
    for ( int i = 0; i < keysLeft.length(); ++i )
        keyLeft = max( keyLeft, texelFetch( iChannel1, ivec2( keysLeft[i], 0 ), 0 ).x );
    
	s.isPressedLeft = keyLeft;    
            
    float keyRight = 0.0;
    for ( int i = 0; i < keysRight.length(); ++i )
        keyRight = max( keyRight, texelFetch( iChannel1, ivec2( keysRight[i], 0 ), 0 ).x );
    
    s.isPressedRight = keyRight;    
       
    if ( s.stateID == GS_SPLASH ) // splash
    {                             
        if ( isSpacePressed > 0.5 || s.isPressedLeft > 0.5 || s.isPressedRight > 0.5 )
        {
            s = setStateStartGame( s, iTime );
            s.stateID = GS_GAME;            
            s.timeStarted = iTime;
            s.timeAccumulated = 0.0;
            s.seed += iTime;
        }
        else
        {
            s = updateGame( s, 1.0 );
        }        
    }
    else if ( s.stateID == GS_GAME ) // game
    {
        if ( s.timeFailed > s.timeStarted )
        {   
            if ( iTime > s.timeFailed + 1.0 
                && ( s.isPressedLeft > 0.5 || s.isPressedRight > 0.5 ) )
            {            
            	s.timeStarted = iTime;
                s.timeFailed = -1.0;
            }
                        
            if ( iTime > s.timeFailed + 5.0 )
            {                
                s = setStateStartGame( s, iTime );
                s.stateID = GS_SPLASH;
            }
            
            s.isPressedLeft = 0.0;
            s.isPressedRight = 0.0;
        }
        else
        {
            s = updateGame( s, 0.0 );
        }
    }
  
    fragColor = saveState( s, fragCoord, iFrame, iTime );
}