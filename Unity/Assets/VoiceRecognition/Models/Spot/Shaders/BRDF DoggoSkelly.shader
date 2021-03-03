// d4rk's BRDF_PBS_Macro modified

Shader "VoiceRecognition/BRDF DoggoSkelly"
{
	Properties
	{
		[Enum(Off, 0, Front, 1, Back, 2)] _Culling ("Culling Mode", Int) = 2
		_Cutoff("Cutout", Range(0,1)) = .5
		_MainTex("Texture", 2D) = "white" {}
		[hdr] _Color("Albedo", Color) = (1,1,1,1)
		_Metallic("Metallic", 2D) = "white" {}
		_NormalMap("Normal Map", 2D) = "white" {}
		_EmissionMap("Emissive Map", 2D) = "black" {}
		[HDR] _EmissionColor ("Emission Color", Color) = (0,0,0)
		_Smoothness("Smoothness", Range(0, 1)) = 0
        _BakedAnims ("Baked Animations", 2D) = "black" {}
        _ControllerTex ("Controller Texture", 2D) = "black" {}
        _WingsTex ("Wings Texture", 2D) = "black" {}
        _SpeechTex ("Speech Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
			"Queue"="Geometry"
		}

		Cull [_Culling]

		CGINCLUDE
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityPBSLighting.cginc"
            #include "../../../Shaders/ControllerInclude.cginc"

			float4 _Color;
			float4 _EmissionColor;
			sampler2D _Metallic;
			sampler2D _NormalMap;
			sampler2D _EmissionMap;
			sampler2D _SpeechTex;
			float _Smoothness;
            sampler2D _MainTex;
            sampler2D _WingsTex;
            float4 _MainTex_ST;
            Texture2D<float3> _BakedAnims;
            Texture2D<float4> _ControllerTex;
			float _Cutoff;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float2 uv4 : TEXCOORD4;
            };

			struct v2f
			{
				#ifndef UNITY_PASS_SHADOWCASTER
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 wPos : TEXCOORD0;
				float3 T : TEXCOORD5;
				float3 B : TEXCOORD6;
				SHADOW_COORDS(3)
				#else
				V2F_SHADOW_CASTER;
				#endif
				float2 uv : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float2 uv4 : TEXCOORD4;
			};

            float3 rotMat(float3 angles, float3 vec)
            {
                float xc, xs;
                float yc, ys;
                float zc, zs;
                sincos(angles.x, xs, xc);
                sincos(angles.y, ys, yc);
                sincos(angles.z, zs, zc);

                float3x3 mat = {
                    yc*zc, -xc*zs + xs*ys*zc,  xs*zs + xc*ys*zc,
                    yc*zs,  xc*zc + xs*ys*zs, -xs*zc + xc*ys*zs,
                   -ys,     xs*yc,             xc*yc
                };

                return mul(mat, vec);
            }

            float speechBubbleCurve (float x)
            {
            	return saturate(min(x * 10.0, -(x - 1.0) * 10.0));
            }

			v2f vert(appdata v)
			{
				v2f o;

                float2 uvIndex = floor(v.uv2 / 0.0625);

                uint anim = _ControllerTex[txDoggoAngleAnims].y;
                float animTime = _ControllerTex[txDoggoAngleAnims].w;
                
                uint frame1 = floor(mod(animTime, animLength[anim]));
                uint frame2 = floor(mod(animTime + 1.0, animLength[anim]));
                float lerpAmount = frac(animTime);

                uint2 bakedUV1 = uint2(mod(anim, 3.0), floor(anim / 3.0)) * 40;
                uint2 bakedUV2 = bakedUV1;
                
                bakedUV1.x += frame1;
                bakedUV2.x += frame2;

                uint offset = 8.0 * (uvIndex.y - 1.0);

                float3 rot1, rot2;
                float3 pos1, pos2;

                // Actuator
                if (uvIndex.x > 3.0)
                {
                    rot1 = _BakedAnims[bakedUV1 + uint2(0, offset + 8)].xyz;
                    pos1 = _BakedAnims[bakedUV1 + uint2(0, offset + 9)].xyz;
                    rot2 = _BakedAnims[bakedUV2 + uint2(0, offset + 8)].xyz;
                    pos2 = _BakedAnims[bakedUV2 + uint2(0, offset + 9)].xyz;

                    rot1 = lerp(rot1, rot2, lerpAmount);
                    pos1 = lerp(pos1, pos2, lerpAmount);

                    //rot1.y = mod(uvIndex.y - 1.0, 2.0) < 1.0 ? -rot1.y : rot1.y;

                    v.vertex.xyz = rotMat(rot1, v.vertex.xyz);
                    v.vertex.xyz += pos1;
                }

                // Lower leg
                if (uvIndex.x > 2.0)
                {
                    rot1 = _BakedAnims[bakedUV1 + uint2(0, offset + 6)].xyz;
                    pos1 = _BakedAnims[bakedUV1 + uint2(0, offset + 7)].xyz;
                    rot2 = _BakedAnims[bakedUV2 + uint2(0, offset + 6)].xyz;
                    pos2 = _BakedAnims[bakedUV2 + uint2(0, offset + 7)].xyz;

                    rot1 = lerp(rot1, rot2, lerpAmount);
                    pos1 = lerp(pos1, pos2, lerpAmount);

                    //rot1.y = mod(uvIndex.y - 1.0, 2.0) < 1.0 ? -rot1.y : rot1.y;

                    v.vertex.xyz = rotMat(rot1, v.vertex.xyz);
                    v.vertex.xyz += pos1;
                }

                // Upper leg
                if (uvIndex.x > 1.0)
                {
                    rot1 = _BakedAnims[bakedUV1 + uint2(0, offset + 4)].yxz;
                    pos1 = _BakedAnims[bakedUV1 + uint2(0, offset + 5)].xyz;
                    rot2 = _BakedAnims[bakedUV2 + uint2(0, offset + 4)].yxz;
                    pos2 = _BakedAnims[bakedUV2 + uint2(0, offset + 5)].xyz;

                    rot1 = lerp(rot1, rot2, lerpAmount);
                    pos1 = lerp(pos1, pos2, lerpAmount);

                    rot1.x = mod(uvIndex.y - 1.0, 2.0) < 1.0 ? -rot1.x : rot1.x;

                    v.vertex.xyz = rotMat(rot1, v.vertex.xyz);
                    v.vertex.xyz += pos1;
                }

                // Shoulder
                if (uvIndex.x > 0.0)
                {
                    rot1 = _BakedAnims[bakedUV1 + uint2(0, offset + 2)].yxz;
                    pos1 = _BakedAnims[bakedUV1 + uint2(0, offset + 3)].xyz;
                    rot2 = _BakedAnims[bakedUV2 + uint2(0, offset + 2)].yxz;
                    pos2 = _BakedAnims[bakedUV2 + uint2(0, offset + 3)].xyz;

                    rot1 = lerp(rot1, rot2, lerpAmount);
                    pos1 = lerp(pos1, pos2, lerpAmount);

                    rot1.x = mod(uvIndex.y - 1.0, 2.0) < 1.0 ? -rot1.x : rot1.x;

                    v.vertex.xyz = rotMat(rot1, v.vertex.xyz);
                    v.vertex.xyz += pos1;
                }

                // Text box
                if (all(v.uv2 < 0.004))
                {
                	float scaledTime = saturate(animTime / (animLength[ANIM_SPEAK] - 1.0));
                	v.vertex.xz *= anim == ANIM_SPEAK ? speechBubbleCurve(scaledTime) : 0.0;
                }

                // Body
                rot1 = _BakedAnims[bakedUV1].xyz;
                pos1 = _BakedAnims[bakedUV1 + uint2(0, 1)].xyz;
                rot2 = _BakedAnims[bakedUV2].xyz;
                pos2 = _BakedAnims[bakedUV2 + uint2(0, 1)].xyz;

                rot1 = lerp(rot1, rot2, lerpAmount);
                pos1 = lerp(pos1, pos2, lerpAmount);
                
                rot1.x += UNITY_PI;

                // Fucking Euler angles are stupid

                rot1.x = -rot1.x;
                pos1.yz = -pos1.yz;

                v.vertex.xyz = rotMat(rot1, v.vertex.xyz);
                v.vertex.xyz += pos1;

                // Root
                float3 rootRot1 = _ControllerTex[txDoggoRootRot1];
                float3 rootRot2 = _ControllerTex[txDoggoRootRot2];
                float3 rootRot3 = _ControllerTex[txDoggoRootRot3];
                float3x3 lookMat = {rootRot1, rootRot2, rootRot3};
                v.vertex.xyz = mul(lookMat, v.vertex.xyz);

                float3 rootPos = _ControllerTex[txDoggoRootPos];
                rootPos = mul(unity_WorldToObject, float4(rootPos, 1)).xyz;
                v.vertex.xyz += rootPos;

				#ifdef UNITY_PASS_SHADOWCASTER
				TRANSFER_SHADOW_CASTER_NOPOS(o, o.pos);
				#else
				o.wPos = mul(unity_ObjectToWorld, v.vertex);
				o.pos = UnityWorldToClipPos(o.wPos);
				o.normal = normalize(UnityObjectToWorldNormal(v.normal));
				// calc Normal, Binormal, Tangent vector in world space
				float3 worldTangent = UnityObjectToWorldNormal(v.tangent);
				
				float3 binormal = cross(v.normal, v.tangent.xyz); // *v.tangent.w;
				float3 worldBinormal = UnityObjectToWorldNormal(binormal);

				// and, set them
				o.T = normalize(worldTangent);
				o.B = normalize(worldBinormal);

				TRANSFER_SHADOW(o);
				#endif
				o.uv = TRANSFORM_TEX(v.uv.xy, _MainTex);
                o.uv2 = v.uv2;
                o.uv4 = v.uv4;
				return o;
			}

			#ifndef UNITY_PASS_SHADOWCASTER
			float4 frag(v2f i) : SV_TARGET
			{
				// obtain a normal vector on tangent space
				float3 tangentNormal = UnpackNormal (tex2D (_NormalMap, i.uv));

				// 'TBN' transforms the world space into a tangent space
				// we need its inverse matrix
				// Tip : An inverse matrix of orthogonal matrix is its transpose matrix
				float3x3 TBN = float3x3((i.T), (i.B), (i.normal));
				TBN = transpose(TBN);

				// finally we got a normal vector from the normal map
				float3 worldNormal = mul(TBN, tangentNormal);

				float3 normal = BlendNormals(i.normal, worldNormal);
				float4 texCol = tex2D(_MainTex, i.uv) * _Color;

                bool isSpeechBubble = all(i.uv2 < 0.004);
                float4 speechBubble = tex2D(_SpeechTex, i.uv4);

                if (i.uv2.y < 0.05 && i.uv2.x > 0.02)
                {
                    texCol = tex2D(_WingsTex, i.uv4);
                }
                else if (isSpeechBubble)
                {
                	texCol = speechBubble;
                }

				clip(texCol.a - _Cutoff);

				float2 uv = i.uv;

				UNITY_LIGHT_ATTENUATION(attenuation, i, i.wPos.xyz);

				float3 specularTint;
				float oneMinusReflectivity;
				float smoothness = _Smoothness;
				float3 albedo = DiffuseAndSpecularFromMetallic(
					texCol, tex2D(_Metallic, i.uv).r, specularTint, oneMinusReflectivity
				);

				float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
				UnityLight light;
				light.color = attenuation * _LightColor0.rgb;
				light.dir = normalize(UnityWorldSpaceLightDir(i.wPos));
				UnityIndirect indirectLight;
				#ifdef UNITY_PASS_FORWARDADD
				indirectLight.diffuse = indirectLight.specular = 0;
				#else
				indirectLight.diffuse = max(0, ShadeSH9(float4(normal, 1)));
				float3 reflectionDir = reflect(-viewDir, normal);
				Unity_GlossyEnvironmentData envData;
				envData.roughness = 1 - smoothness;
				envData.reflUVW = reflectionDir;
				indirectLight.specular = Unity_GlossyEnvironment(
					UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
				);
				#endif

				float3 col = UNITY_BRDF_PBS(
					albedo, specularTint,
					oneMinusReflectivity, smoothness,
					normal, viewDir,
					light, indirectLight
				);
				col += tex2D(_EmissionMap, i.uv) * _EmissionColor;
                col = isSpeechBubble ? speechBubble : col;

				#ifdef UNITY_PASS_FORWARDADD
				return float4(col, 0);
				#else
				return float4(col, 1);
				#endif
			}
			#else
			float4 frag(v2f i) : SV_Target
			{
				float alpha = _Color.a;
				if (_Cutoff > 0)
					alpha *= tex2D(_MainTex, i.uv).a;
				clip(alpha - _Cutoff);
				SHADOW_CASTER_FRAGMENT(i)
			}
			#endif
		ENDCG

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase_fullshadows
			#pragma multi_compile UNITY_PASS_FORWARDBASE
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ForwardAdd" }
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile UNITY_PASS_FORWARDADD
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			ENDCG
		}
	}
}
