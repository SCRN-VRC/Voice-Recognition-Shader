Shader "VoiceRecognition/InputToBuffer"
{
    Properties
    {
        _InputTex ("Input", 2D) = "black" {}
        _MainTex ("Buffer", 2D) = "black" {}
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

            Texture2D<float> _InputTex;
            Texture2D<float> _MainTex;
            float4 _MainTex_TexelSize;
            float _MaxDist;
            //RWStructuredBuffer<float4> buffer : register(u1);

            static const uint2 VisemeFloatMap[14] =
            {
                3, 1,   // ou
                1, 1,   // oh
                1, 0,   // ih
                2, 0,   // E
                0, 0,   // aa
                1, 3,   // RR
                2, 3,   // nn
                0, 3,   // SS
                3, 2,   // CH
                0, 1,   // kk
                2, 2,   // DD
                0, 2,   // TH
                1, 2,   // FF
                3, 3,   // PP
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
                    mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz) > _MaxDist) ?
                    -1 : 1;
                return o;
            }

            float frag (v2f i) : SV_Target
            {
                clip(i.uv.z);

                uint2 px = i.uv.xy * _MainTex_TexelSize.zw;
                float col = 0;
                float count = _MainTex.Load(uint3(0, 0, 0));

                if (px.x == 1)
                {
                    col = _InputTex.Load(uint3(VisemeFloatMap[px.y], 0));
                }
                else if (px.x >= 2)
                {
                    if (count >= 0.0333) px.x -= 1;
                    col = _MainTex.Load(uint3(px, 0));
                }
                else if (px.x == 0)
                {
                    count = count < 0.0333 ? count : (count - 0.0333);
                    count += unity_DeltaTime.x;
                    col = clamp(count, 0, 0.0666);
                }

                return col;
            }
            ENDCG
        }
    }
}
