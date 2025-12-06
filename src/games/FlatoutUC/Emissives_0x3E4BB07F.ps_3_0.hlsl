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

	/*
	float3 lumaWeights = float3(0.2126f, 0.7152f, 0.0722f);
	float EmissiveLuma = pow(dot(max(r0.xyz, 0.0f), lumaWeights), 1.5);
	float3 EmissiveChroma = r0.xyz + (r0.xyz - EmissiveLuma);
	float3 EmissiveChromaDir = EmissiveChroma / max(length(EmissiveChroma), 1e-6) * 2;
	r1.xyz = r0.xyz * g_PS_nonLitIntensity.xyz;
	r1.xyz *= lerp(pow(max(EmissiveLuma, 0.0f), 3) * 250, EmissiveChromaDir, saturate(0.5 * 0.5));
	*/
	if (RENODX_TONE_MAP_TYPE > 0.f) {
		r1.xyz = ApplyFakeHDRGain(r0.xyz, pow(Custom_Particles_Glow * 1.5, 10), pow(Custom_Particles_Glow_Contrast, 15), 0.0f);
	}
	//r1.xyz = pow(r0.xyz, 3) * g_PS_nonLitIntensity.xyz * 1000;
	//r1.xyz = r0.xyz * g_PS_nonLitIntensity.xyz;

	r2.xyz = g_PS_nonLitIntensity.xyz;
	r0.xyz = r0.xyz * -r2.xyz + g_PS_fogColor.xyz;
	o.w = r0.w;
	o.xyz = i.texcoord1.x * r0.xyz + r1.xyz;

	return o;
}
