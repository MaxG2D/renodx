// ------------------------------------------------------------------
// UI/Particle Modulation Shader
// ------------------------------------------------------------------

sampler2D Tex0 : register(s0);

struct PS_IN
{
    float4 color : COLOR0;
    float2 texcoord : TEXCOORD0; 
};

// Main pixel shader function
float4 main(PS_IN input) : COLOR
{
    // Sample the texture (texld r0, v1, s0)
    float4 f4TextureColor = tex2D(Tex0, input.texcoord);
    
    // Multiply the texture color by the vertex color (mul oC0, r0, v0)
    float4 f4OutputColor = f4TextureColor * input.color;

    return f4OutputColor;
}