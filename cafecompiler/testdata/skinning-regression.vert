#version 440
#extension GL_ARB_separate_shader_objects : require

layout(std140, binding = 1) uniform MdlEnvView
{
   vec4 cView[3];
   vec4 cViewProj[4];
   vec3 cLightDiffPosition[8];
   vec4 cLightDiffColor[8];
   vec4 cAmbColor[2];
   vec3 cFogColor;
   float cFogStart;
   float cFogStartEndInv;
   vec4 cProj[4];
};

layout(std140, binding = 3) uniform Mat
{
   vec4 mat_color0;
   vec4 mat_color1;
   vec4 amb_color0;
   vec4 amb_color1;
   vec4 tev_color0;
   vec4 tev_color1;
   vec4 tev_color2;
   vec4 konst0;
   vec4 konst1;
   vec4 konst2;
   vec4 konst3;
   vec4 ind_texmtx0[2];
   vec4 ind_texmtx1[2];
   vec4 ind_texmtx2[2];
   vec4 texmtx0[3];
   vec4 texmtx1[3];
   vec4 texmtx2[3];
   vec4 texmtx3[3];
   vec4 texmtx4[3];
   vec4 texmtx5[3];
   vec4 texmtx6[3];
   vec4 texmtx7[3];
   vec4 indirect_mtx0a;
   vec4 indirect_mtx0b;
   vec4 indirect_mtx1a;
   vec4 indirect_mtx1b;
   vec4 indirect_mtx2a;
   vec4 indirect_mtx2b;
   vec2 texpivot0;
   vec2 texpivot1;
   vec2 texpivot2;
   vec2 texpivot3;
   vec2 texpivot4;
   vec2 texpivot5;
   vec2 texpivot6;
   vec2 texpivot7;
   vec3 edge_light_color;
   float edge_light_intensity;
   float edge_light_sharpness;
   float edge_light_rim_intensity;
   float edge_light_out_intensity;
   float edge_alpha_out_sharpness;
   float soft_edge_distance_inv;
   float soft_edge_alpha_min;
   float bloom_intensity_offset;
   float specular_intensity;
   float fresnel_coeff;
   float diffuse_intensity;
};

layout(std140, binding = 0) uniform MdlMtx
{
   vec4 cMtxPalette[192];
};

layout(std140, binding = 2) uniform LightInfo
{
   vec4 cLightMtx1[4];
   vec4 cLightMtx2[4];
   vec4 cLightMtx3[4];
   vec4 cLightMtx4[4];
   vec4 cCascadeLength;
   vec4 cCloudProjMtx[4];
   float cDepthSadowPower;
   float cCloudShadowPower;
   float cPrimShadowIntensity;
   float cTactShadowSH;
   vec4 cShadowParam;
   vec4 cTactShadowParam;
   vec4 cLightPrepassParam;
   float bloom_intensity_offset_particle;
   vec4 cCameraParam;
   vec4 cFrameBufferSize;
   vec4 cIceColorA;
   vec4 cIceColorB;
   vec4 cIceColorToon;
   vec4 cFigureParam;
   vec4 cDebugParam0;
   vec4 cDebugParam1;
   vec4 cDebugParam2;
   vec4 cDebugParam3;
   vec4 cDebugParam4;
   vec4 cDebugParam5;
   vec4 cDebugParam6;
   vec4 cDebugParam7;
   vec4 cDebugParam8;
   vec4 cDebugParam9;
};

layout(location = 0) out vec4 PARAM_0;
layout(location = 1) out vec4 PARAM_1;
layout(location = 2) out vec3 PARAM_2;
layout(location = 3) out vec2 PARAM_3;
layout(location = 4) out vec4 PARAM_4;
layout(location = 5) out vec4 PARAM_5;
layout(location = 6) out vec3 PARAM_6;
layout(location = 7) out vec2 PARAM_7;
layout(location = 8) out vec4 PARAM_8;

layout(location = 0) in ivec4 aBlendIndex;
layout(location = 1) in vec4 aBlendWeight;
layout(location = 2) in vec3 aNormal;
layout(location = 3) in vec3 aPosition;
layout(location = 4) in vec2 aTexCoord0;

void main()
{
   vec4 pos = vec4(aPosition, 1.0f);
   vec4 nrm = vec4(aNormal, 0.0f);

   vec4 position_weight = vec4(0.0f, 0.0f, 0.0f, 1.0f);
   vec4 normal_weight = vec4(0.0f, 0.0f, 0.0f, 0.0f);

   for (int i = 0; i < 2; i++) {
      int index = aBlendIndex[i] * 3;
      float weight = aBlendWeight[i];

      position_weight.x += weight * dot(pos, cMtxPalette[index + 0]);
      position_weight.y += weight * dot(pos, cMtxPalette[index + 1]);
      position_weight.z += weight * dot(pos, cMtxPalette[index + 2]);

      normal_weight.x += weight * dot(nrm, cMtxPalette[index + 0]);
      normal_weight.y += weight * dot(nrm, cMtxPalette[index + 1]);
      normal_weight.z += weight * dot(nrm, cMtxPalette[index + 2]);
   }

   normal_weight = normalize(normal_weight);

   vec3 pos_view;
   pos_view.x = dot(position_weight, cView[0]);
   pos_view.y = dot(position_weight, cView[1]);
   pos_view.z = dot(position_weight, cView[2]);

   PARAM_0.x = pos_view.x;
   PARAM_0.y = pos_view.y;
   PARAM_0.z = pos_view.z;
   PARAM_0.w = cCameraParam.z * ((-pos_view.z) + (-cCameraParam.y));

   gl_Position.x = dot(vec4(pos_view.xyz, 1.0f), cProj[0]);
   gl_Position.y = dot(vec4(pos_view.xyz, 1.0f), cProj[1]);
   gl_Position.z = dot(vec4(pos_view.xyz, 1.0f), cProj[2]);
   gl_Position.w = dot(vec4(pos_view.xyz, 1.0f), cProj[3]);

   PARAM_1.x = gl_Position.w * ((gl_Position.x / gl_Position.w) * 0.5f) + 0.5f;
   PARAM_1.y = gl_Position.w * (-(gl_Position.y / gl_Position.w) * 0.5f) + 0.5f;
   PARAM_1.z = gl_Position.w;
   PARAM_1.w = (cCameraParam.x * 50.0f) * cLightPrepassParam.z;

   PARAM_2.x = dot(vec4(position_weight.xyz, 1.0f), cCloudProjMtx[0]);
   PARAM_2.y = dot(vec4(position_weight.xyz, 1.0f), cCloudProjMtx[1]);
   PARAM_2.z = dot(vec4(position_weight.xyz, 1.0f), cCloudProjMtx[2]);

   PARAM_3 = aTexCoord0.xy;

   PARAM_6 = mix(cAmbColor[0].rgb, cAmbColor[1].rgb,
                 (normal_weight.y * 0.5f) + 0.5f);
   PARAM_4 = vec4(edge_light_intensity *
                  (pos_view.xyz * edge_light_color.xyz),
                  edge_light_sharpness * 10.0f);

   float fog = clamp(((-cFogStart) + length(pos_view)) *
                     cFogStartEndInv, 0.0, 1.0);
   PARAM_5 = vec4(cFogColor.xyz, fog * fog);

   vec3 light_dir = normalize(pos_view - cLightDiffPosition[0]);

   PARAM_8.x = dot(vec4(normal_weight.xyz, 0.0f), cView[0]);
   PARAM_8.y = dot(vec4(normal_weight.xyz, 0.0f), cView[1]);
   PARAM_8.z = dot(vec4(normal_weight.xyz, 0.0f), cView[2]);
   PARAM_8.w = ((clamp(-dot(light_dir, normalize(pos_view)),
                       0.0f, 1.0f) - 1.0f) *
                edge_light_rim_intensity) + 1.0f;

   float temp = clamp(-dot(PARAM_8.xyz, light_dir), 0.0f, 1.0f);
   PARAM_7.xy = max(clamp((temp * cLightDiffColor[0].xy) +
                          exp(log(amb_color0.xy) * 0.45454544f),
                          0.0, 1.0),
                    0.0f) *
                exp(log(mat_color0.xy) * 0.45454544f);
}
