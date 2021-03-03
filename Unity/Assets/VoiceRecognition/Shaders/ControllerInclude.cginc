#ifndef _CONTROLLER_INC
#define _CONTROLLER_INC

#define txScoreAgregate                     uint2(0, 1)
#define txDoggoStates                       uint2(1, 1)
#define txDoggoAngleAnims                   uint2(2, 1)
#define txDoggoRootPos                      uint2(3, 1)
#define txDoggoRootRot1                     uint2(4, 1)
#define txDoggoRootRot2                     uint2(5, 1)
#define txDoggoRootRot3                     uint2(6, 1)
#define txMyPos                             uint2(7, 1)

static const float animLength[12] = {
    6, 6, 4, 4, 7, 5, 5, 36, 19, 7, 6, 7
};

#define ANIM_IDLE                           0
#define ANIM_WALK                           1
#define ANIM_TURN_LEFT                      2
#define ANIM_TURN_RIGHT                     3
#define ANIM_SIT_DOWN                       4
#define ANIM_SIT_IDLE                       5
#define ANIM_SIT_UP                         6
#define ANIM_DANCE                          7
#define ANIM_SPEAK                          8
#define ANIM_PLAYDEAD_DOWN                  9
#define ANIM_PLAYDEAD_IDLE                 10
#define ANIM_PLAYDEAD_UP                   11

#define STATE_IDLE                          0
#define STATE_LISTEN                        1
#define STATE_SIT_DOWN                      2
#define STATE_SIT_IDLE                      3
#define STATE_SIT_UP                        4
#define STATE_FOLLOW                        5
#define STATE_ANIMATION                     6
#define STATE_PLAYDEAD_DOWN                 7
#define STATE_PLAYDEAD_IDLE                 8
#define STATE_PLAYDEAD_UP                   9

#define COM_NOISE                           0
#define COM_SIL                             1
#define COM_DANCE                           2
#define COM_FOLLOW                          3
#define COM_PLAY_DEAD                       4
#define COM_SIT                             5
#define COM_SPEAK                           6
#define COM_STAY                            7
#define COM_STOP                            8
#define COM_TUPPER                          9

#define eps                                 0.001
#define DEFAULT_TIMER                       150.0
#define SPEED                               0.014
#define DOGGO_DIST                          2.0
#define PI2                                 1.570796326795

#define mod(x,y) ((x)-(y)*floor((x)/(y))) // glsl mod

bool commandIsAnimation(uint command)
{
    if (command == COM_DANCE || command == COM_SPEAK) return true;
    return false;
}

uint commandToAnimation(uint command)
{
    if (command == COM_DANCE) return ANIM_DANCE;
    if (command == COM_SPEAK) return ANIM_SPEAK;
    return ANIM_IDLE;
}

inline bool insideArea(in uint2 area, uint2 px)
{
    [flatten]
    if (all(area == px))
    {
        return true;
    }
    return false;
}

inline float4 LoadValue(in Texture2D<float4> tex, in uint2 re)
{
    return tex.Load(int3(re, 0));
}

inline void StoreValue(in uint2 txPos, in float4 value, inout float4 col,
    in uint2 fragPos)
{
    col = all(fragPos == txPos) ? value : col;
}

void channelShift(float nextFloat, inout float4 curFloats)
{
    curFloats.w = curFloats.z;
    curFloats.z = curFloats.y;
    curFloats.y = curFloats.x;
    curFloats.x = nextFloat;
}

float3x3 lookAt( in float3 ro, in float3 ta)
{
    float3 cw = normalize(ta-ro);
    float3 cp = float3(0, -1, 0);
    float3 cu = normalize( cross(cw,cp) );
    float3 cv = normalize( cross(cu,cw) );
    return transpose(float3x3( cu, cv, -cw ));
}

#endif