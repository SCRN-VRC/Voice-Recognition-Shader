Shader "VoiceRecognition/InstructionsShader"
{
    Properties
    {
        _MainTex ("Instruction Tex", 2D) = "white" {}
        _DirTex ("Direction Tex", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _DirTex;
            float4 _MainTex_ST;
            //RWStructuredBuffer<float4> buffer : register(u1);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                clip(col.a - 0.1);
                float3 viewDir = mul((float3x3)unity_ObjectToWorld, UNITY_MATRIX_IT_MV[2].xyz);
                float ang = atan2(viewDir.x, viewDir.z) / UNITY_PI * 180.0 + 180;

                if (abs(i.uv.y - 0.207) < 0.065)
                {
                    col *= fmod(_Time.y, 0.75) <= 0.375 ? 0.0 : 1.0;
                }

                if (abs(i.uv.y - 0.76) < 0.03125 && abs(i.uv.x - 0.7266) < 0.03125)
                {
                    i.uv.y = (i.uv.y - 0.732) / 0.0625;
                    i.uv.x = (i.uv.x - 0.6953) / 0.25 + ang / 360.0;
                    float4 dirImg = tex2D(_DirTex, i.uv);
                    col.rgb = dirImg.rgb * dirImg.a;
                }

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
