#include "./shared.h"
#include "./FakeHDRGain.h"

sampler2D Tex0 : register( s0 );
float4 g_PS_fogColor : register( c44 );
float4 g_PS_nonLitIntensity : register( c40 );

struct PS_IN
{
	float2 texcoord : TEXCOORD;
	float texcoord1 : TEXCOORD1;
};

float4 main(PS_IN i) : COLOR
{
	float4 o;

	float4 r0;
	float3 r1;
	float3 r2;
	r0 = tex2D(Tex0, i.texcoord);
	r1 = r0.xyz * g_PS_nonLitIntensity.xyz;
	if (RENODX_TONE_MAP_TYPE > 0.f) {
        r1.xyz = ApplyFakeHDRGain(r1.xyz, pow(Custom_Emissives_Glow, 15), pow(Custom_Emissives_Glow_Contrast, 15), 0.0f);
	}
	r2.xyz = g_PS_nonLitIntensity.xyz;
	r0.xyz = g_PS_fogColor.xyz - (r0.xyz * r2);
	o.w = r0.w;
	o.xyz = i.texcoord1.x * r0.xyz + r1.xyz;

	return o;
}
