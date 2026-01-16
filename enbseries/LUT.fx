Texture2D textureLutInterior
<
	string ResourceName="lut_interior.png";
>;

Texture2D textureLutDay
<
	string ResourceName="lut_day.png";
>;

Texture2D textureLutNight
<
	string ResourceName="lut_night.png";
>;

SamplerState	samplerLutInterior
{
	Filter=MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

SamplerState	samplerLutDay
{
	Filter=MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

SamplerState samplerLutNight
{
	Filter=MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};


void	ApplyLUT(inout float3 color, float NightDayFactor, float InteriorFactor)
{
	float3 ColorLutDay;  // CLuT for Days
	float3 ColorLutDayRow;

	float3 ColorLutNight;  // CLuT for Nights
	float3 ColorLutNightRow;

	float3 ColorLutInterior;  // CLuT for Interiors
	float3 ColorLutInteriorRow;

	float3 ColorLutBlend;  // CLuT Averages
	float3 ColorLutBlendRow;


	//float2 f2LutResolution = float2(0.00390625, 0.0625);  // 1 / float2(256, 16);
	float2 f2LutResolution = float2(0.000244140625, 0.015625);
	color.rgb = saturate(color.rgb);
	color.b *= 63;
	float4 CLut_UV  = 0;

	CLut_UV.w = floor(color.b);
	CLut_UV.xy = color.rg * 63 * f2LutResolution + 0.5 * f2LutResolution;
	CLut_UV.x += CLut_UV.w * f2LutResolution.y;

	ColorLutDay.rgb = textureLutDay.SampleLevel(samplerLutDay, CLut_UV.xyzz, 0.0).rgb;
	ColorLutDayRow.rgb = textureLutDay.SampleLevel(samplerLutDay, CLut_UV.xyzz + float4(f2LutResolution.y, 0, 0, 0), 0.0).rgb;

	ColorLutNight.rgb = textureLutNight.SampleLevel(samplerLutNight, CLut_UV.xyzz, 0.0).rgb;
	ColorLutNightRow.rgb = textureLutNight.SampleLevel(samplerLutNight, CLut_UV.xyzz + float4(f2LutResolution.y, 0, 0, 0), 0.0).rgb;

	ColorLutInterior.rgb = textureLutInterior.SampleLevel(samplerLutInterior, CLut_UV.xyzz, 0.0).rgb;
	ColorLutInteriorRow.rgb = textureLutInterior.SampleLevel(samplerLutInterior, CLut_UV.xyzz + float4(f2LutResolution.y, 0, 0, 0), 0.0).rgb;

	ColorLutBlend.rgb = lerp( lerp(ColorLutNight.rgb, ColorLutDay.rgb, NightDayFactor), ColorLutInterior.rgb, InteriorFactor);
	ColorLutBlendRow.rgb = lerp( lerp(ColorLutNightRow.rgb, ColorLutDayRow.rgb, NightDayFactor), ColorLutInteriorRow.rgb, InteriorFactor);

	color.rgb = lerp(ColorLutBlend.rgb, ColorLutBlendRow.rgb, color.b - CLut_UV.w);
}
