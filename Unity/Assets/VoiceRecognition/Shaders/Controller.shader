Shader "VoiceRecognition/Controller"
{
    Properties
    {
        _VoiceCNN ("VoiceCNN Input", 2D) = "black" {}
        _Buffer ("Buffer", 2D) = "black" {}
        _Reset ("Reset", Int) = 0
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+1" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        ZWrite Off
        ZTest Always
        Cull Off
        
        Pass
        {
            Lighting Off
            SeparateSpecular Off
            Fog { Mode Off }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "ControllerInclude.cginc"
            #include "VoiceCNN.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 centerPos : TEXCOORD1;
            };

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float> _VoiceCNN;
            Texture2D<float4> _Buffer;
            float4 _Buffer_TexelSize;
            float _MaxDist;
            int _Reset;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = float4(v.uv * 2 - 1, 0, 1);
                #ifdef UNITY_UV_STARTS_AT_TOP
                v.uv.y = 1-v.uv.y;
                #endif
                o.uv.xy = UnityStereoTransformScreenSpaceTex(v.uv);
                o.centerPos = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;
                o.uv.z = (distance(_WorldSpaceCameraPos, o.centerPos) > _MaxDist) ?
                    -1 : 1;
                //o.centerPos.y = 0; // Don't move in the Y axis
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                clip(i.uv.z);
                uint2 px = _Buffer_TexelSize.zw * i.uv.xy;

                float count = _Buffer.Load(uint3(0, 0, 0)).z;
                float4 col = _Buffer.Load(uint3(px, 0));

                if (px.y == 0)
                {
                    // Find the highest score
                    if (px.x == 0)
                    {
                        uint topIndex = 0;
                        float topScore = -1.0;
                        for (uint x = 0; x < 10; x++)
                        {
                            float curScore = _VoiceCNN.Load(uint3(txSoft.xy + uint2(x, 0), 0)).x;
                            topIndex = curScore > topScore ? x : topIndex;
                            topScore = curScore > topScore ? curScore : topScore;
                        }
                        col.w = topIndex;
                        col.y = topScore;

                        // 30 fps
                        count = count < 0.0333 ? count : (count - 0.0333);
                        count += unity_DeltaTime.x;
                        col.z = clamp(count, 0, 0.0666);
                    }
                    // Buffer the highest score
                    else
                    {
                        // 30 fps
                        if (count >= 0.0333) {
                            px.x -= 1;
                            float prevChannel = _Buffer.Load(uint3(px, 0)).w;
                            channelShift(prevChannel, col);
                        }
                    }
                }
                else
                {
                    float4 score = _Buffer[txScoreAgregate];
                    float4 doggoState = _Buffer[txDoggoStates];
                    float4 doggoPos = _Buffer[txDoggoRootPos];
                    float4 doggoAngleAnims = _Buffer[txDoggoAngleAnims];
                    float3 rootRot1 = _Buffer[txDoggoRootRot1];
                    float3 rootRot2 = _Buffer[txDoggoRootRot2];
                    float3 rootRot3 = _Buffer[txDoggoRootRot3];
                    float3x3 lookMat = {rootRot1, rootRot2, rootRot3};

                    // Reset at the beginning
                    doggoPos.xyz = _Reset > 0 ? i.centerPos : doggoPos.xyz;

                    // majority rule polling

                    uint predicts[10] = 
                    {
                        0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                    };

                    uint x;
                    for (x = 1; x < 5; x++)
                    {
                        uint4 val = floor(_Buffer.Load(uint3(x, 0, 0)));
                        [unroll]
                        for (uint y = 0; y < 4; y++) predicts[val[y]] += 1;
                    }

                    uint topIndex = 0;
                    uint topScore = 0;
                    for (x = 0; x < 10; x++)
                    {
                        topIndex = predicts[x] > topScore ? x : topIndex;
                        topScore = predicts[x] > topScore ? predicts[x] : topScore;
                    }

                    score.x = topIndex;
                    score.w = topScore;

                    if (doggoState.x == STATE_IDLE)
                    {
                        doggoState.x = (topIndex == COM_TUPPER) ? STATE_LISTEN : STATE_IDLE;
                        doggoState.y = (topIndex == COM_TUPPER) ? COM_TUPPER : COM_SIL;
                        // Timer to reset back to default state
                        doggoState.z = DEFAULT_TIMER;
                        // Transition to animation play
                        doggoState.w = 0.0;

                        // Animations
                        lookMat = lookAt(doggoPos.xyz, i.centerPos);
                        float ang = atan(lookMat[0].x / lookMat[0].z);
                        doggoAngleAnims.y = (doggoAngleAnims.x - ang) < -eps ? ANIM_TURN_LEFT :
                            (doggoAngleAnims.x - ang) > eps ? ANIM_TURN_RIGHT : ANIM_IDLE;
                        doggoAngleAnims.x = ang;
                        doggoAngleAnims.w = mod(doggoAngleAnims.w + unity_DeltaTime.x * 8.0, animLength[ANIM_TURN_LEFT]);
                        
                        // doggoState.x = STATE_ANIMATION;
                        // doggoState.y = ANIM_SPEAK;
                    }
                    else if (doggoState.x == STATE_LISTEN)
                    {
                        doggoState.x = commandIsAnimation(topIndex) ? STATE_ANIMATION : doggoState.x;
                        doggoState.x = topIndex == COM_SIT ? STATE_SIT_DOWN : doggoState.x;
                        doggoState.x = topIndex == COM_FOLLOW ? STATE_FOLLOW : doggoState.x;
                        doggoState.x = topIndex == COM_PLAY_DEAD ? STATE_PLAYDEAD_DOWN : doggoState.x;
                        // No input before timer, reset to default state
                        doggoState.x = doggoState.z < 1.0 ? STATE_IDLE : doggoState.x;
                        doggoState.y = doggoState.x == STATE_ANIMATION ? commandToAnimation(topIndex) : doggoState.y;
                        doggoState.y = doggoState.x == STATE_SIT_DOWN ? COM_SIT : doggoState.y;
                        doggoState.y = doggoState.x == STATE_FOLLOW ? COM_FOLLOW : doggoState.y;
                        doggoState.z = max(0.0, count >= 0.0333 ? doggoState.z - 1.0 : doggoState.z);
                        // Reset if tupper called again
                        doggoState.z = topIndex == COM_TUPPER ? DEFAULT_TIMER : doggoState.z;
                        doggoState.w = 0.0;
                        
                        // Animations
                        lookMat = lookAt(doggoPos.xyz, i.centerPos);
                        float ang = atan(lookMat[0].x / lookMat[0].z);
                        doggoAngleAnims.y = (doggoAngleAnims.x - ang) < -eps ? ANIM_TURN_LEFT :
                            (doggoAngleAnims.x - ang) > eps ? ANIM_TURN_RIGHT : ANIM_IDLE;
                        doggoAngleAnims.x = ang;
                    }
                    else if (doggoState.x == STATE_SIT_DOWN)
                    {
                        // Animation counter
                        doggoAngleAnims.w = doggoState.w < 1.0 ? 0.0 : doggoAngleAnims.w + unity_DeltaTime.x;
                        doggoAngleAnims.y = ANIM_SIT_DOWN;
                        // Transition to idle after animation finish
                        doggoState.x = doggoAngleAnims.w > (animLength[ANIM_SIT_DOWN] - 1.0) ?
                            STATE_SIT_IDLE : STATE_SIT_DOWN;
                        doggoState.w = 1.0;
                    }
                    else if (doggoState.x == STATE_SIT_IDLE)
                    {
                        // Animation counter
                        doggoAngleAnims.w = doggoState.w < 2.0 ? 0.0 :
                            mod(doggoAngleAnims.w + unity_DeltaTime.x, animLength[ANIM_SIT_IDLE]);
                        doggoAngleAnims.y = ANIM_SIT_IDLE;
                        doggoState.x = (topIndex == COM_TUPPER || topIndex == COM_STOP) ? STATE_SIT_UP : STATE_SIT_IDLE;
                        doggoState.y = (topIndex == COM_TUPPER) ? COM_TUPPER : doggoState.y;
                        doggoState.w = 2.0;
                    }
                    else if (doggoState.x == STATE_SIT_UP)
                    {
                        doggoAngleAnims.w = doggoState.w < 3.0 ? 0.0 : doggoAngleAnims.w + unity_DeltaTime.x;
                        doggoAngleAnims.y = ANIM_SIT_UP;
                        // Transition to idle after animation finish
                        doggoState.x = doggoAngleAnims.w > (animLength[ANIM_SIT_UP] - 1.0) ? STATE_LISTEN : STATE_SIT_UP;
                        doggoState.w = 3.0;
                    }
                    else if (doggoState.x == STATE_PLAYDEAD_DOWN)
                    {
                        // Animation counter
                        doggoAngleAnims.w = doggoState.w < 1.0 ? 0.0 : doggoAngleAnims.w + unity_DeltaTime.x * 2.0;
                        doggoAngleAnims.y = ANIM_PLAYDEAD_DOWN;
                        // Transition to idle after animation finish
                        doggoState.x = doggoAngleAnims.w > (animLength[ANIM_PLAYDEAD_DOWN] - 1.0) ?
                            STATE_PLAYDEAD_IDLE : STATE_PLAYDEAD_DOWN;
                        doggoState.w = 1.0;
                    }
                    else if (doggoState.x == STATE_PLAYDEAD_IDLE)
                    {
                        // Animation counter
                        doggoAngleAnims.w = doggoState.w < 2.0 ? 0.0 :
                            mod(doggoAngleAnims.w + unity_DeltaTime.x, animLength[ANIM_PLAYDEAD_IDLE]);
                        doggoAngleAnims.y = ANIM_PLAYDEAD_IDLE;
                        doggoState.x = (topIndex == COM_TUPPER || topIndex == COM_STOP) ? STATE_PLAYDEAD_UP : STATE_PLAYDEAD_IDLE;
                        doggoState.y = (topIndex == COM_TUPPER) ? COM_TUPPER : doggoState.y;
                        doggoState.w = 2.0;
                    }
                    else if (doggoState.x == STATE_PLAYDEAD_UP)
                    {
                        doggoAngleAnims.w = doggoState.w < 3.0 ? 0.0 : doggoAngleAnims.w + unity_DeltaTime.x * 2.0;
                        doggoAngleAnims.y = ANIM_PLAYDEAD_UP;
                        // Transition to idle after animation finish
                        doggoState.x = doggoAngleAnims.w > (animLength[ANIM_PLAYDEAD_UP] - 1.0) ? STATE_LISTEN : STATE_PLAYDEAD_UP;
                        doggoState.w = 3.0;
                    }
                    else if (doggoState.x == STATE_FOLLOW)
                    {
                        doggoState.x = (topIndex == COM_STOP) ? STATE_IDLE : STATE_FOLLOW;
                        doggoState.x = (topIndex == COM_STAY) ? STATE_IDLE : doggoState.x;

                        // Animations
                        float3 distToTarget = i.centerPos - doggoPos.xyz;

                        float3 vel = clamp(distToTarget / 40.0, -SPEED, SPEED) * unity_DeltaTime.z * SPEED_MULTIPLIER;

                        lookMat = lookAt(doggoPos.xyz, i.centerPos);
                        float ang = atan(lookMat[0].x / lookMat[0].z);

                        //if not walking, do turning animations
                        if (length(distToTarget) <= DOGGO_DIST)
                        {
                            doggoAngleAnims.y = (doggoAngleAnims.x - ang) < -eps ? ANIM_TURN_LEFT :
                                (doggoAngleAnims.x - ang) > eps ? ANIM_TURN_RIGHT : ANIM_IDLE;
                            doggoAngleAnims.x = ang;
                            doggoAngleAnims.w = mod(doggoAngleAnims.w + unity_DeltaTime.x * 8.0, animLength[ANIM_TURN_LEFT]);
                        }
                        else
                        {
                            doggoPos.xyz += length(distToTarget) > DOGGO_DIST ? vel : 0.0;
                            doggoAngleAnims.y = ANIM_WALK;
                            doggoAngleAnims.w = mod(doggoAngleAnims.w + unity_DeltaTime.x * 6.0, animLength[ANIM_WALK]);
                        }
                    }
                    else if (doggoState.x == STATE_ANIMATION)
                    {
                        doggoState.x = doggoAngleAnims.w > animLength[uint(doggoState.y)] - 1.0 ?
                            STATE_IDLE : STATE_ANIMATION;
                        doggoState.x = (topIndex == COM_STOP) ? STATE_IDLE : doggoState.x;
                        doggoAngleAnims.y = uint(doggoState.y);
                        doggoAngleAnims.w = doggoState.w < 1.0 ? 0.0 : doggoAngleAnims.w + unity_DeltaTime.x * 4.0;
                        doggoState.w = 1.0;
                    }

                    //buffer[0] = doggoAngleAnims;
                    StoreValue(txScoreAgregate, score, col, px);
                    StoreValue(txDoggoStates, doggoState, col, px);
                    StoreValue(txDoggoAngleAnims, doggoAngleAnims, col, px);
                    StoreValue(txDoggoRootPos, doggoPos, col, px);
                    StoreValue(txDoggoRootRot1, float4(lookMat[0], 1), col, px);
                    StoreValue(txDoggoRootRot2, float4(lookMat[1], 1), col, px);
                    StoreValue(txDoggoRootRot3, float4(lookMat[2], 1), col, px);
                    StoreValue(txMyPos, float4(i.centerPos, 1), col, px);
                }
                return col;
            }
            ENDCG
        }
    }
}
