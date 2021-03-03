Shader "VoiceRecognition/RenderToHandCamera"
{
    Properties
    {
        _MainTex ("Buffer", 2D) = "black" {}
        _MaxDist ("Max Distance", Float) = 0.02
    }
    SubShader
    {
        Tags { "Queue"="Overlay+1" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        ZWrite Off
        ZTest Always
        Cull Off
        Blend SrcAlpha OneMinusSrcAlpha
        
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

            bool isVR() {
                // USING_STEREO_MATRICES
                #if UNITY_SINGLE_PASS_STEREO
                    return true;
                #else
                    return false;
                #endif
            }
            
            bool isVRHandCamera() {
                return !isVR() && abs(UNITY_MATRIX_V[0].y) > 0.0000005;
            }
            
            bool isDesktop() {
                return !isVRHandCamera();
            }
            
            bool isVRHandCameraPreview() {
                return isVRHandCamera() && _ScreenParams.y == 720;
            }
            
            bool isVRHandCameraPicture() {
                return isVRHandCamera() && _ScreenParams.y == 1080;
            }
            
            bool isOrthographic()
            {
                return UNITY_MATRIX_P[3][3] == 1;
            }

            bool IsInMirror()
            {
                return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
            }

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

            Texture2D<float4> _MainTex;
            float4 _MainTex_TexelSize;
            float _MaxDist;

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

            float4 frag(v2f i) : SV_TARGET
            {
                clip(i.uv.z);
                if (isOrthographic() || IsInMirror()) discard;

                float4 col = 0;
                #if UNITY_SINGLE_PASS_STEREO
                    i.uv.x += .25 - .5 * unity_StereoEyeIndex;
                #endif
                col.r = _MainTex.Load(int3(i.uv.xy * _MainTex_TexelSize.zw, 0)).r;
                col.a = isVRHandCamera() ? 1.0 : col.r;

                return col;
            }
            ENDCG
        }
    }
}
