Shader "VoiceRecognition/VisemesToFloat"
{
    Properties
    {
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+1" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        Cull Off

        Pass
        {
            Lighting Off
            SeparateSpecular Off
            Fog { Mode Off }

            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 5.0
            #include "UnityCG.cginc"

            //RWStructuredBuffer<float4> buffer : register(u1);
            float _MaxDist;

            struct appdata
            {
                float4 vertex : POSITION;
            };
 
            struct v2g
            {
                float4 vertex : SV_POSITION;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float distClip : TEXCOORD1;
            };
 
            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                return o;
            }

            g2f createVertex(float4 clipPos, float3 color)
            {
                g2f o;
                o.vertex = clipPos;
                o.color = float4(color, 1.0);
                o.distClip = (distance(_WorldSpaceCameraPos,
                    mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz) > _MaxDist) ?
                    -1 : 1;
                o.distClip = unity_OrthoParams.w ? o.distClip : -1;
                return o;
            }

            [maxvertexcount(36)]
            void geom(triangle v2g i[3], inout TriangleStream<g2f> triStream, uint id : SV_PrimitiveId)
            {
                const float cellWidth = 4.0;
                const float cellHeight = 4.0;
                const float cwOff = 1.0 / cellWidth;
                const float chOff = 1.0 / cellHeight;

                for (uint j = 0; j < 3; j++)
                {
                    for (uint k = 0; k < 3; k++)
                    {
                        uint newID = id * 9 + j * 3 + k;
                        float4 topRow = float4(1, 1, 0, 1);
                        float4 botRow = float4(1, 0, 0, 0);

                        topRow.yw /= cellHeight;
                        topRow.xz /= cellWidth;
                        botRow.yw /= cellHeight;
                        botRow.xz /= cellWidth;
                    
                        topRow.xz += cwOff * floor(fmod(newID, cellWidth));
                        botRow.xz += cwOff * floor(fmod(newID, cellWidth));
                        topRow.yw += chOff * floor(newID / cellHeight);
                        botRow.yw += chOff * floor(newID / cellHeight);

                        topRow = topRow * 2.0 - 1.0;
                        botRow = botRow * 2.0 - 1.0;

                        // Subtract origin
                        float3 col = abs(i[j].vertex.xyz - float3(-0.002, 1.145, 0.041));

                        triStream.Append(createVertex(float4(topRow.xy, 0.99, 1), col[k]));
                        triStream.Append(createVertex(float4(topRow.zw, 0.99, 1), col[k]));
                        triStream.Append(createVertex(float4(botRow.xy, 0.99, 1), col[k]));
                        triStream.Append(createVertex(float4(botRow.zw, 0.99, 1), col[k]));
                        triStream.RestartStrip();
                        //if (newID == 10) buffer[0] = col.xyzz;
                    }
                }
            }

            fixed4 frag (g2f i) : SV_Target
            {
                clip(i.distClip);
                fixed4 col = i.color;
                return col;
            }
            ENDCG
        }
    }
}