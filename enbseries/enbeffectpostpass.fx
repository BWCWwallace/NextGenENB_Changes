// LICENSE

// Copyright (c) 2017-2019 Advanced Micro Devices, Inc. All rights reserved.
// -------
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// -------
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
// -------
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE

// Port of CAS.fx to ENB. Original ReShade implementation (by Marty McFly) here:
// https://gist.github.com/martymcmodding/303

//+++++++++++++++++++++++++++++
//internal parameters, modify or add new
//+++++++++++++++++++++++++++++
//example parameters with annotations for in-game editor
float ECASSharpAmount <
  string UIName="CAS Sharp: amount";        string UIWidget="spinner";  float UIMin=0.0;  float UIMax=1.0;
> = {0.0};
bool EnableClamp < string UIName = "Enable Clamping"; > = {false};
float CASSharpClamp <
  string UIName="CAS Sharp: clamp amount";        string UIWidget="spinner";  float UIMin=0.0;  float UIMax=1.0;
> = {0.07};

//+++++++++++++++++++++++++++++
//external enb parameters, do not modify
//+++++++++++++++++++++++++++++
//x = generic timer in range 0..1, period of 16777216 ms (4.6 hours), y = average fps, w = frame time elapsed (in seconds)
float4	Timer;
//x = Width, y = 1/Width, z = aspect, w = 1/aspect, aspect is Width/Height
float4	ScreenSize;
//changes in range 0..1, 0 means full quality, 1 lowest dynamic quality (0.33, 0.66 are limits for quality levels)
float	AdaptiveQuality;
//x = current weather index, y = outgoing weather index, z = weather transition, w = time of the day in 24 standart hours. Weather index is value from weather ini file, for example WEATHER002 means index==2, but index==0 means that weather not captured.
float4	Weather;
//x = dawn, y = sunrise, z = day, w = sunset. Interpolators range from 0..1
float4	TimeOfDay1;
//x = dusk, y = night. Interpolators range from 0..1
float4	TimeOfDay2;
//changes in range 0..1, 0 means that night time, 1 - day time
float	ENightDayFactor;
//changes 0 or 1. 0 means that exterior, 1 - interior
float	EInteriorFactor;

//+++++++++++++++++++++++++++++
//external enb debugging parameters for shader programmers, do not modify
//+++++++++++++++++++++++++++++
//keyboard controlled temporary variables. Press and hold key 1,2,3...8 together with PageUp or PageDown to modify. By default all set to 1.0
float4	tempF1; //0,1,2,3
float4	tempF2; //5,6,7,8
float4	tempF3; //9,0
// xy = cursor position in range 0..1 of screen;
// z = is shader editor window active;
// w = mouse buttons with values 0..7 as follows:
//    0 = none
//    1 = left
//    2 = right
//    3 = left+right
//    4 = middle
//    5 = left+middle
//    6 = right+middle
//    7 = left+right+middle (or rather cat is sitting on your mouse)
float4	tempInfo1;
// xy = cursor position of previous left mouse button click
// zw = cursor position of previous right mouse button click
float4	tempInfo2;

//+++++++++++++++++++++++++++++
//mod parameters, do not modify
//+++++++++++++++++++++++++++++
Texture2D			TextureOriginal; //color R10B10G10A2 32 bit ldr format
Texture2D			TextureColor; //color which is output of previous technique (except when drawed to temporary render target), R10B10G10A2 32 bit ldr format
Texture2D			TextureDepth; //scene depth R32F 32 bit hdr format

//temporary textures which can be set as render target for techniques via annotations like <string RenderTarget="RenderTargetRGBA32";>
Texture2D			RenderTargetRGBA32; //R8G8B8A8 32 bit ldr format
Texture2D			RenderTargetRGBA64; //R16B16G16A16 64 bit ldr format
Texture2D			RenderTargetRGBA64F; //R16B16G16A16F 64 bit hdr format
Texture2D			RenderTargetR16F; //R16F 16 bit hdr format with red channel only
Texture2D			RenderTargetR32F; //R32F 32 bit hdr format with red channel only
Texture2D			RenderTargetRGB32F; //32 bit hdr format without alpha

SamplerState		Sampler0
{
	Filter = MIN_MAG_MIP_POINT;//MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};
SamplerState		Sampler1
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

//+++++++++++++++++++++++++++++
//
//+++++++++++++++++++++++++++++
struct VS_INPUT_POST
{
	float3 pos		: POSITION;
	float2 txcoord	: TEXCOORD0;
};
struct VS_OUTPUT_POST
{
	float4 pos		: SV_POSITION;
	float2 txcoord0	: TEXCOORD0;
};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
float4 casSharpen(float4 inColor, float2 inCoord)
{    
	float2 pixeloffset = ScreenSize.y;
    pixeloffset.y     *= ScreenSize.z;
    float2 offsets[9] =
    {
      float2(-1.0,-1.0),
      float2( 0.0,-1.0),
      float2( 1.0,-1.0),
      float2(-1.0, 0.0),
	    float2( 0.0, 0.0),
	    float2( 1.0, 0.0),
	    float2(-1.0, 1.0),
	    float2( 0.0, 1.0),
	    float2( 1.0, 1.0),
    };	
	
	float2 aCoord = offsets[0].xy * pixeloffset.xy + inCoord.xy;
  float2 bCoord = offsets[1].xy * pixeloffset.xy + inCoord.xy;
  float2 cCoord = offsets[2].xy * pixeloffset.xy + inCoord.xy;
  float2 dCoord = offsets[3].xy * pixeloffset.xy + inCoord.xy;
  float2 eCoord = offsets[4].xy * pixeloffset.xy + inCoord.xy;
  float2 fCoord = offsets[5].xy * pixeloffset.xy + inCoord.xy;
  float2 gCoord = offsets[6].xy * pixeloffset.xy + inCoord.xy;
  float2 hCoord = offsets[7].xy * pixeloffset.xy + inCoord.xy;
  float2 iCoord = offsets[8].xy * pixeloffset.xy + inCoord.xy;
	
	// fetch a 3x3 neighborhood around the pixel 'e',
    //  a b c
    //  d(e)f
    //  g h i
	float4 a = TextureColor.Sample(Sampler0, aCoord.xy);
	float4 b = TextureColor.Sample(Sampler0, bCoord.xy);
	float4 c = TextureColor.Sample(Sampler0, cCoord.xy);
	float4 d = TextureColor.Sample(Sampler0, dCoord.xy);
	float4 e = TextureColor.Sample(Sampler0, eCoord.xy);
	float4 f = TextureColor.Sample(Sampler0, fCoord.xy);
	float4 g = TextureColor.Sample(Sampler0, gCoord.xy);
	float4 h = TextureColor.Sample(Sampler0, hCoord.xy);
	float4 i = TextureColor.Sample(Sampler0, iCoord.xy);
  
	// Soft min and max.
	//  a b c             b
	//  d e f * 0.5  +  d e f * 0.5
	//  g h i             h
  // These are 2.0x bigger (factored out the extra multiply).
  float3 mnRGB = min(min(min(d, e), min(f, b)), h);
  float3 mnRGB2 = min(mnRGB, min(min(a, c), min(g, i)));
  mnRGB += mnRGB2;

  float3 mxRGB = max(max(max(d, e), max(f, b)), h);
  float3 mxRGB2 = max(mxRGB, max(max(a, c), max(g, i)));
  mxRGB += mxRGB2;

  // Smooth minimum distance to signal limit divided by smooth max.
  float3 rcpMRGB = rcp(mxRGB);
  float3 ampRGB = saturate(min(mnRGB, 2.0 - mxRGB) * rcpMRGB);    
    
  // Shaping amount of sharpening.
  ampRGB = rsqrt(ampRGB);

  float peak = 8.0 - 3.0 * ECASSharpAmount;
  float3 wRGB = -rcp(ampRGB * peak);

  float3 rcpWeightRGB = rcp(1.0 + 4.0 * wRGB);

  //                          0 w 0
  //  Filter shape:           w 1 w
  //                          0 w 0  
  float3 window = (b + d) + (f + h);
  float3 outColor = saturate((window * wRGB + e) * rcpWeightRGB);

  // Clamping, based on a suggestion from u/Parpinator
  if (EnableClamp) {
    outColor = clamp(outColor, saturate(e - CASSharpClamp), saturate(e + CASSharpClamp));
  }

  return float4(outColor, 1.0);
}

VS_OUTPUT_POST	VS_PostProcess(VS_INPUT_POST IN)
{
	VS_OUTPUT_POST	OUT;
	float4	pos;
	pos.xyz=IN.pos.xyz;
	pos.w=1.0;
	OUT.pos=pos;
	OUT.txcoord0.xy=IN.txcoord.xy;
	return OUT;
}

float4 PS_CAS_Sharp(VS_OUTPUT_POST IN, float4 v0 : SV_Position0) : SV_Target
{
  float4 res;
  res = casSharpen(res, IN.txcoord0.xy);
  res.w = 1.0;
  return res;
}

// TECHNIQUES
///+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++///
/// Techniques are drawn one after another and they use the result of   ///
/// the previous technique as input color to the next one.  The number  ///
/// of techniques is limited to 255.  If UIName is specified, then it   ///
/// is a base technique which may have extra techniques with indexing   ///
///+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++///
technique11 CASSharp <string UIName="CAS_Sharpen";>
{
  pass p0
  {
    SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
    SetPixelShader(CompileShader(ps_5_0, PS_CAS_Sharp()));
  }
}