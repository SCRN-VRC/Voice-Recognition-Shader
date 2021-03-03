Shader "VoiceRecognition/VoiceCNN"
{
    Properties
    {
        _CamIn ("Cam Input", 2D) = "black" {}
        _Buffer ("Buffer", 2D) = "black" {}
        _Weights ("Weights", 2D) = "black" {}
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
            #include "VoiceCNN.cginc"

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float> _CamIn;
            Texture2D<float> _Buffer;
            Texture2D<float> _Weights;
            float4 _Buffer_TexelSize;
            float _MaxDist;

            // float test (uint3 i)
            // {
            //     return (i.x * i.y) / 392.0;
            // }

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = float4(v.uv * 2 - 1, 0, 1);
                #ifdef UNITY_UV_STARTS_AT_TOP
                v.uv.y = 1-v.uv.y;
                #endif
                o.uv.xy = UnityStereoTransformScreenSpaceTex(v.uv);
                o.uv.z = (distance(_WorldSpaceCameraPos,
                    mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz) > _MaxDist ||
                    !unity_OrthoParams.w) ?
                    -1 : 1;
                return o;
            }

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);
                uint2 px = _Buffer_TexelSize.zw * i.uv.xy;
                float col = _Buffer.Load(uint3(px, 0)).x;

                [branch]
                if (insideArea(txL1, px))
                {
                    px -= txL1.xy;
                    uint i = px.y % 26;
                    uint j = px.x % 26;
                    uint k = (px.x / 26) + (px.y / 26) * 8;

                    uint i0 = i, i1 = i + 1, i2 = i + 2;
                    uint j0 = j, j1 = j + 1, j2 = j + 2;

                    float s =
                        getInput(_CamIn, uint2(j0, 27 - i0)) * getWL1(_Weights, uint3(0, 0, k)) +
                        getInput(_CamIn, uint2(j0, 27 - i1)) * getWL1(_Weights, uint3(0, 1, k)) +
                        getInput(_CamIn, uint2(j0, 27 - i2)) * getWL1(_Weights, uint3(0, 2, k)) +
                        getInput(_CamIn, uint2(j1, 27 - i0)) * getWL1(_Weights, uint3(1, 0, k)) +
                        getInput(_CamIn, uint2(j1, 27 - i1)) * getWL1(_Weights, uint3(1, 1, k)) +
                        getInput(_CamIn, uint2(j1, 27 - i2)) * getWL1(_Weights, uint3(1, 2, k)) +
                        getInput(_CamIn, uint2(j2, 27 - i0)) * getWL1(_Weights, uint3(2, 0, k)) +
                        getInput(_CamIn, uint2(j2, 27 - i1)) * getWL1(_Weights, uint3(2, 1, k)) +
                        getInput(_CamIn, uint2(j2, 27 - i2)) * getWL1(_Weights, uint3(2, 2, k));

                    // float s =
                    //     test(uint3(i0, j0, 0)) * getWL1(_Weights, uint3(0, 0, k)) +
                    //     test(uint3(i0, j1, 0)) * getWL1(_Weights, uint3(0, 1, k)) +
                    //     test(uint3(i0, j2, 0)) * getWL1(_Weights, uint3(0, 2, k)) +
                    //     test(uint3(i1, j0, 0)) * getWL1(_Weights, uint3(1, 0, k)) +
                    //     test(uint3(i1, j1, 0)) * getWL1(_Weights, uint3(1, 1, k)) +
                    //     test(uint3(i1, j2, 0)) * getWL1(_Weights, uint3(1, 2, k)) +
                    //     test(uint3(i2, j0, 0)) * getWL1(_Weights, uint3(2, 0, k)) +
                    //     test(uint3(i2, j1, 0)) * getWL1(_Weights, uint3(2, 1, k)) +
                    //     test(uint3(i2, j2, 0)) * getWL1(_Weights, uint3(2, 2, k));

                    s += getBias(_Weights, uint3(txBL1.xy, 1), k);
                    s = relu(s);
                    s = batchNorm(_Weights, s, k);

                    col = s;
                }
                else if (insideArea(txL2, px))
                {
                    px -= txL2.xy;
                    uint i = px.y % 24;
                    uint j = px.x % 24;
                    uint k = (px.x / 24) + (px.y / 24) * 8;

                    uint i0 = i, i1 = i + 1, i2 = i + 2;
                    uint j0 = j, j1 = j + 1, j2 = j + 2;

                    float s = 0.0;

                    for (int l = 0; l < 32; l++)
                    {
                        s +=
                            getL1(_Buffer, uint3(i0, j0, l)) * getWL2(_Weights, uint4(0, 0, l, k)) +
                            getL1(_Buffer, uint3(i0, j1, l)) * getWL2(_Weights, uint4(0, 1, l, k)) +
                            getL1(_Buffer, uint3(i0, j2, l)) * getWL2(_Weights, uint4(0, 2, l, k)) +
                            getL1(_Buffer, uint3(i1, j0, l)) * getWL2(_Weights, uint4(1, 0, l, k)) +
                            getL1(_Buffer, uint3(i1, j1, l)) * getWL2(_Weights, uint4(1, 1, l, k)) +
                            getL1(_Buffer, uint3(i1, j2, l)) * getWL2(_Weights, uint4(1, 2, l, k)) +
                            getL1(_Buffer, uint3(i2, j0, l)) * getWL2(_Weights, uint4(2, 0, l, k)) +
                            getL1(_Buffer, uint3(i2, j1, l)) * getWL2(_Weights, uint4(2, 1, l, k)) +
                            getL1(_Buffer, uint3(i2, j2, l)) * getWL2(_Weights, uint4(2, 2, l, k));
                    }

                    s += getBias(_Weights, uint3(txBL2.xy, 1), k);
                    s = relu(s);
                    col = s;
                }
                else if (insideArea(txMP1, px))
                {
                    px -= txMP1.xy;
                    uint i = px.y % 12;
                    uint j = px.x % 12;
                    uint k = (px.x / 12) + (px.y / 12) * 8;

                    uint i0 = i * 2, i1 = i0 + 1;
                    uint j0 = j * 2, j1 = j0 + 1;

                    float m = getL2(_Buffer, uint3(i0, j0, k));
                    m = max(m, getL2(_Buffer, uint3(i0, j1, k)));
                    m = max(m, getL2(_Buffer, uint3(i1, j0, k)));
                    m = max(m, getL2(_Buffer, uint3(i1, j1, k)));
                    col = m;
                }
                // Manually unrolling the 9216 loop into 288 parts
                else if (insideArea(txFC1, px))
                {
                    px -= txFC1.xy;
                    uint k = px.x;
                    uint i = px.y; // loop part index

                    float s = 0.0;
                    for (uint l = i * 32; l < ((i + 1) * 32); l++)
                    {
                        s += getMP1(_Buffer, l) * getWFC1(_Weights, uint2(l, k));
                    }

                    col = s;
                }
                else if (insideArea(txFC1Sum, px))
                {
                    px -= txFC1Sum.xy;
                    uint k = px.x;

                    float s = 0.0;
                    for (int i = 0; i < 288; i++)
                    {
                        s += _Buffer.Load(uint3(k, i, 0));
                    }

                    s += getBias(_Weights, uint3(txBFC1.xy, 0), k);
                    s = relu(s);
                    col = s;
                }
                else if (insideArea(txOut, px))
                {
                    px -= txOut.xy;
                    uint k = px.x;

                    float s = 0.0;
                    for (int l = 0; l < 100; l++)
                    {
                        s += getFC1Sum(_Buffer, l) * getWOut(_Weights, uint2(l, k));
                    }

                    s += getBias(_Weights, uint3(txBOut.xy, 1), k);
                    col = s;
                }
                else if (insideArea(txSoft, px))
                {
                    px -= txSoft.xy;
                    uint i = px.x;

                    float s = 0.0;
                    for (int j = 0; j < 10; j++)
                    {
                        s += exp(getOut(_Buffer, j));
                    }

                    col = exp(getOut(_Buffer, i)) / s;

                    // if (i == 2)
                    // {
                    //     buffer[0] = col;
                    // }
                }
                return col;
            }
            ENDCG
        }
    }
}
