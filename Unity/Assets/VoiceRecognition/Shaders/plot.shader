Shader "VoiceRecognition/Plot"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CNNTex ("VoiceCNN Output", 2D) = "black" {}
        _StateTex ("Controller Texture", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "VoiceCNN.cginc"
            #include "ControllerInclude.cginc"

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
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            Texture2D<float> _CNNTex;
            Texture2D<float4> _StateTex;

            float DigitBin( const int x )
            {
                return x==0?480599.0:x==1?139810.0:x==2?476951.0:x==3?476999.0:x==4?350020.0:x==5?464711.0:x==6?464727.0:x==7?476228.0:x==8?481111.0:x==9?481095.0:0.0;
            }

            float PrintValue( float2 vStringCoords, float fValue, float fMaxDigits, float fDecimalPlaces )
            {       
                if ((vStringCoords.y < 0.0) || (vStringCoords.y >= 1.0)) return 0.0;
                
                bool bNeg = ( fValue < 0.0 );
                fValue = abs(fValue);
                
                float fLog10Value = log2(abs(fValue)) / log2(10.0);
                float fBiggestIndex = max(floor(fLog10Value), 0.0);
                float fDigitIndex = fMaxDigits - floor(vStringCoords.x);
                float fCharBin = 0.0;
                if(fDigitIndex > (-fDecimalPlaces - 1.01)) {
                    if(fDigitIndex > fBiggestIndex) {
                        if((bNeg) && (fDigitIndex < (fBiggestIndex+1.5))) fCharBin = 1792.0;
                    } else {        
                        if(fDigitIndex == -1.0) {
                            if(fDecimalPlaces > 0.0) fCharBin = 2.0;
                        } else {
                            float fReducedRangeValue = fValue;
                            if(fDigitIndex < 0.0) { fReducedRangeValue = frac( fValue ); fDigitIndex += 1.0; }
                            float fDigitValue = (abs(fReducedRangeValue / (pow(10.0, fDigitIndex))));
                            fCharBin = DigitBin(int(floor(mod(fDigitValue, 10.0))));
                        }
                    }
                }
                return floor(mod((fCharBin / pow(2.0, floor(frac(vStringCoords.x) * 4.0) + (floor(vStringCoords.y * 5.0) * 4.0))), 2.0));
            }

            float PrintValue(const in float2 fragCoord, const in float2 vPixelCoords, const in float2 vFontSize, const in float fValue, const in float fMaxDigits, const in float fDecimalPlaces)
            {
                float2 vStringCharCoords = (fragCoord.xy - vPixelCoords) / vFontSize;
                
                return PrintValue( vStringCharCoords, fValue, fMaxDigits, fDecimalPlaces );
            }

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

                if (i.uv.x > 0.105 && i.uv.x < 0.95 &&
                    i.uv.y > 0.069 && i.uv.y < 0.913)
                {
                    i.uv -= float2(0.105, 0.069);
                    i.uv /= float2(0.845, 0.844);

                    uint2 id = uint2(floor(i.uv.x / 0.1), 0);
                    float val = _CNNTex.Load(uint3(txSoft.xy + id, 0));

                    bool border = abs(fmod(i.uv.x, 0.1) / 0.1 - 0.5) < 0.35;
                    col.xyz = (i.uv.y < val && border) ?
                        fixed3(0.1216, 0.4667, 0.7059) : 1;
                }

                uint4 state = floor(_StateTex.Load(uint3(txDoggoStates, 0)));
                if (state.x == STATE_IDLE)
                {
                    col.g -= 0.35;
                }
                else if (state.x == STATE_LISTEN)
                {
                    col.r -= 0.35;
                }
                else
                {
                    col.b -= 0.35;
                }

                float3 myPos = _StateTex[txMyPos];
                float3 doggoPos = _StateTex[txDoggoRootPos];
                float2 vFontSize = float2(16.0, 30.0);
                col.xyz = lerp( col.xyz, float3(1.0, 0.0, 0.0), PrintValue( ((i.uv - float2(0.6, 0.85)) * _MainTex_TexelSize.zw) / vFontSize, myPos.x, 3.0, 3.0));
                col.xyz = lerp( col.xyz, float3(1.0, 0.0, 0.0), PrintValue( ((i.uv - float2(0.7, 0.85)) * _MainTex_TexelSize.zw) / vFontSize, myPos.y, 3.0, 3.0));
                col.xyz = lerp( col.xyz, float3(1.0, 0.0, 0.0), PrintValue( ((i.uv - float2(0.8, 0.85)) * _MainTex_TexelSize.zw) / vFontSize, myPos.z, 3.0, 3.0));

                col.xyz = lerp( col.xyz, float3(0.0, 0.0, 1.0), PrintValue( ((i.uv - float2(0.6, 0.8)) * _MainTex_TexelSize.zw) / vFontSize, doggoPos.x, 3.0, 3.0));
                col.xyz = lerp( col.xyz, float3(0.0, 0.0, 1.0), PrintValue( ((i.uv - float2(0.7, 0.8)) * _MainTex_TexelSize.zw) / vFontSize, doggoPos.y, 3.0, 3.0));
                col.xyz = lerp( col.xyz, float3(0.0, 0.0, 1.0), PrintValue( ((i.uv - float2(0.8, 0.8)) * _MainTex_TexelSize.zw) / vFontSize, doggoPos.z, 3.0, 3.0));

                col.xyz = pow(col.xyz, 2);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
