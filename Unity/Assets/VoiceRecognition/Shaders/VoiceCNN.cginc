#ifndef _VOICECNN
#define _VOICECNN

// Layers
#define txL1                    uint4(100, 0, 208, 128)          // 26x26 x 8x4
#define txL2                    uint4(100, 128, 192, 192)        // 24x24 x 8x8
#define txMP1                   uint4(308, 0, 96, 96)            // 12x12 x 8x8
#define txFC1                   uint4(0, 0, 100, 288)            // 100 x 1, 288 times
#define txFC1Sum                uint4(0, 288, 100, 1)            // 100 x 1, summation
#define txOut                   uint4(404, 0, 10, 1)             // 10 x 1
#define txSoft                  uint4(404, 1, 10, 1)             // 10 x 1

//Weights
#define txWL1                   uint4(100, 960, 32, 9)
#define txBL1                   uint4(961, 288, 1, 32)
#define txNL1                   uint4(0, 971, 32, 4)
#define txWL2                   uint4(960, 0, 64, 288)
#define txBL2                   uint4(960, 288, 1, 64)
#define txWFC1                  uint4(0, 0, 960, 960)
#define txBFC1                  uint4(0, 970, 100, 1)
#define txWOut                  uint4(0, 960, 100, 10)
#define txBOut                  uint4(962, 288, 1, 10)

inline bool insideArea(in uint4 area, uint2 px)
{
    [flatten]
    if (px.x >= area.x && px.x < (area.x + area.z) &&
        px.y >= area.y && px.y < (area.y + area.w))
    {
        return true;
    }
    return false;
}

inline float LoadValue(in Texture2D<float> tex, in uint2 re)
{
    return tex.Load(int3(re, 0));
}

inline void StoreValue(in uint2 txPos, in float value, inout float col,
    in uint2 fragPos)
{
    col = all(fragPos == txPos) ? value : col;
}

inline float relu(float x)
{
    return max(0.0, x);
}

inline float batchNorm(Texture2D<float> tex, float x, float k)
{
    float gamma = tex.Load(uint3(txNL1.xy + uint2(k, 0), 0));
    float beta = tex.Load(uint3(txNL1.xy + uint2(k, 1), 0));
    float mean = tex.Load(uint3(txNL1.xy + uint2(k, 2), 0));
    float var = tex.Load(uint3(txNL1.xy + uint2(k, 3), 0));
    return ((x - mean) / sqrt(var + 0.001f)) * gamma + beta;
}

float getInput(Texture2D<float> tex, uint2 pos)
{
    uint2 px;
    px.x = pos.x + 2;
    px.y = pos.y / 2;
    return tex.Load(uint3(px, 0));
}

float getL1(Texture2D<float> tex, uint3 pos)
{
    uint2 px;
    px.x = pos.y + (pos.z % 8) * 26;
    px.y = pos.x + (pos.z / 8) * 26;
    return tex.Load(uint3(txL1.xy + px, 0));
}

float getL2(Texture2D<float> tex, uint3 pos)
{
    uint2 px;
    px.x = pos.y + (pos.z % 8) * 24;
    px.y = pos.x + (pos.z / 8) * 24;
    return tex.Load(uint3(txL2.xy + px, 0));
}

float getMP1(Texture2D<float> tex, uint pos)
{
    uint x = pos / 768;
    uint y = (pos / 64) % 12;
    uint z = pos % 64;
    uint2 px;
    px.x = y + (z % 8) * 12;
    px.y = x + (z / 8) * 12;
    return tex.Load(uint3(txMP1.xy + px, 0));
}

float getFC1Sum(Texture2D<float> tex, uint pos)
{
    return tex.Load(uint3(txFC1Sum.xy + uint2(pos, 0), 0));
}

float getOut(Texture2D<float> tex, uint pos)
{
    return tex.Load(uint3(txOut.xy + uint2(pos, 0), 0));
}

// offs.z = vertical or horizontal
float getBias(Texture2D<float> tex, uint3 offs, uint pos)
{
    uint2 px = pos;
    px.x = pos * (1 - offs.z);
    px.y = pos * offs.z;
    return tex.Load(uint3(offs.xy + px, 0));
}

float getWL1(Texture2D<float> tex, uint3 pos)
{
    uint2 px;
    px.x = pos.z;
    px.y = pos.x + pos.y * 3;
    return tex.Load(uint3(txWL1.xy + px, 0));
}

float getWL2(Texture2D<float> tex, uint4 pos)
{
    uint2 px;
    px.x = pos.w;
    px.y = pos.z + pos.y * 32 + pos.x * 96;
    return tex.Load(uint3(txWL2.xy + px, 0));
}

float getWFC1(Texture2D<float> tex, uint2 pos)
{
    uint2 px;
    px.x = pos.y % 10 + (pos.x % 96) * 10;
    px.y = pos.y / 10 + (pos.x / 96) * 10;
    return tex.Load(uint3(txWFC1.xy + px, 0));
}

float getWOut(Texture2D<float> tex, uint2 pos)
{
    uint2 px;
    px.x = pos.y + (pos.x % 10) * 10;
    px.y = pos.x / 10;
    return tex.Load(uint3(txWOut.xy + px, 0));
}

#endif