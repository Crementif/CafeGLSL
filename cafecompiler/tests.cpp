#include "CafeGLSLCompiler.h"

#include <cstdio>
#include <cstring>

#define CHECK(condition)                                                        \
   do {                                                                         \
      if (!(condition)) {                                                       \
         fprintf(stderr, "Check failed at %s:%d: %s\n",                       \
                 __FILE__, __LINE__, #condition);                               \
         return 1;                                                              \
      }                                                                          \
   } while (false)

constexpr uint32_t kCfTex = 1;
constexpr uint32_t kCfVtx = 2;
constexpr uint32_t kCfVtxTc = 3;
constexpr uint32_t kCfAlu = 8;
constexpr uint32_t kVFetch = 0;

static int FindUniformBlock(const GX2UniformBlock *blocks, uint32_t count, const char *name)
{
   for (uint32_t i = 0; i < count; ++i) {
      if (!strcmp(blocks[i].name, name))
         return static_cast<int>(blocks[i].offset);
   }
   return -1;
}

static int FindSampler(const GX2SamplerVar *samplers, uint32_t count, const char *name)
{
   for (uint32_t i = 0; i < count; ++i) {
      if (!strcmp(samplers[i].name, name))
         return static_cast<int>(samplers[i].location);
   }
   return -1;
}

static const GX2UniformVar *FindUniform(const GX2UniformVar *uniforms,
                                       uint32_t count,
                                       const char *name)
{
   for (uint32_t i = 0; i < count; ++i) {
      if (!strcmp(uniforms[i].name, name))
         return &uniforms[i];
   }
   return nullptr;
}

static bool HasControlFlowOpcode(const void *program, uint32_t size, uint32_t opcode)
{
   const auto *words = static_cast<const uint32_t *>(program);
   const uint32_t word_count = size / sizeof(uint32_t);
   for (uint32_t i = 0; i + 1 < word_count; i += 2) {
      const uint32_t word1 = words[i + 1];
      if (((word1 >> 23) & 0x7f) == opcode)
         return true;
      if (word1 & (1u << 21))
         break;
   }
   return false;
}

static bool HasVFetchInTexClause(const void *program,
                                 uint32_t size,
                                 uint32_t resource_id)
{
   const auto *words = static_cast<const uint32_t *>(program);
   const uint32_t word_count = size / sizeof(uint32_t);
   for (uint32_t i = 0; i + 1 < word_count; i += 2) {
      const uint32_t word0 = words[i];
      const uint32_t word1 = words[i + 1];
      const uint32_t opcode = (word1 >> 23) & 0x7f;
      if (opcode == kCfTex) {
         uint32_t count = (word1 >> 10) & 0x7;
         count |= ((word1 >> 19) & 0x1) << 3;
         count++;

         const uint32_t clause_start = word0 * 2;
         for (uint32_t fetch = 0; fetch < count; ++fetch) {
            const uint32_t fetch_word = clause_start + fetch * 4;
            if (fetch_word >= word_count)
               break;
            const uint32_t vtx_word0 = words[fetch_word];
            if ((vtx_word0 & 0x1f) == kVFetch &&
                ((vtx_word0 >> 8) & 0xff) == resource_id)
               return true;
         }
      }
      if (word1 & (1u << 21))
         break;
   }
   return false;
}

static bool HasAluConstSource(const void *program,
                              uint32_t size,
                              uint32_t selector,
                              bool relative)
{
   const auto *words = static_cast<const uint32_t *>(program);
   const uint32_t word_count = size / sizeof(uint32_t);
   for (uint32_t i = 0; i + 1 < word_count; i += 2) {
      const uint32_t cf_word0 = words[i];
      const uint32_t cf_word1 = words[i + 1];
      const uint32_t alu_opcode = (cf_word1 >> 26) & 0xf;
      const bool is_alu = alu_opcode >= kCfAlu;
      if (is_alu) {
         const uint32_t count = ((cf_word1 >> 18) & 0x7f) + 1;
         const uint32_t clause_start = (cf_word0 & 0x3fffff) * 2;
         for (uint32_t instruction = 0; instruction < count; ++instruction) {
            const uint32_t alu_word = clause_start + instruction * 2;
            if (alu_word + 1 >= word_count)
               break;
            const uint32_t word0 = words[alu_word];
            const uint32_t selectors[2] = {
               word0 & 0x1ff,
               (word0 >> 13) & 0x1ff,
            };
            const bool relatives[2] = {
               ((word0 >> 9) & 1) != 0,
               ((word0 >> 22) & 1) != 0,
            };
            for (unsigned source = 0; source < 2; ++source) {
               if (selectors[source] == selector &&
                   (!relative || relatives[source]))
                  return true;
            }
         }
      }
      if (!is_alu && (cf_word1 & (1u << 21)))
         break;
   }
   return false;
}

static bool HasKcacheBank(const void *program, uint32_t size, uint32_t bank)
{
   const auto *words = static_cast<const uint32_t *>(program);
   const uint32_t word_count = size / sizeof(uint32_t);
   for (uint32_t i = 0; i + 1 < word_count; i += 2) {
      const uint32_t word0 = words[i];
      const uint32_t word1 = words[i + 1];
      const bool is_alu = ((word1 >> 26) & 0xf) >= kCfAlu;
      if (is_alu) {
         const uint32_t mode0 = (word0 >> 30) & 0x3;
         const uint32_t mode1 = word1 & 0x3;
         if ((mode0 && ((word0 >> 22) & 0xf) == bank) ||
             (mode1 && ((word0 >> 26) & 0xf) == bank))
            return true;
      }
      if (!is_alu && (word1 & (1u << 21)))
         break;
   }
   return false;
}

int main()
{
   static const char vertex_source[] = R"(
#version 450
layout(location = 0) in vec2 position;
layout(location = 5) in vec2 offset;
layout(location = 0) out vec2 uv;
layout(binding = 4, std140) uniform VertexData {
   vec4 translation;
   vec4 scale;
};
void main() {
   uv = position;
   gl_Position = vec4(position * scale.xy + offset + translation.xy, 0.0, 1.0);
}
)";

   static const char pixel_source[] = R"(
#version 450
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 color;
layout(binding = 2) uniform sampler2D sourceTexture;
layout(binding = 4) uniform sampler2D extraTextures[2];
layout(binding = 9, std140) uniform PixelData {
   vec4 bias;
   vec4 tint;
};
uniform vec4 baseColor;
uniform float exposure;
struct LooseData {
   vec4 color;
   float factor;
};
uniform LooseData looseData;
void main() {
   color = (texture(sourceTexture, uv) + texture(extraTextures[1], uv)) *
           (tint + bias) * exposure + baseColor +
           looseData.color * looseData.factor;
}
)";

   char diagnostics[4096] = {};
   DestroyGLSLCompiler();
   CHECK(!CompileVertexShader(vertex_source,
                              diagnostics,
                              sizeof(diagnostics),
                              GLSL_COMPILER_FLAG_NONE));
   CHECK(strstr(diagnostics, "not initialized"));

   CHECK(!CompileVertexShader(nullptr,
                              diagnostics,
                              sizeof(diagnostics),
                              GLSL_COMPILER_FLAG_NONE));
   InitGLSLCompiler();
   InitGLSLCompiler();

   CHECK(!CompileVertexShader(nullptr,
                              diagnostics,
                              sizeof(diagnostics),
                              GLSL_COMPILER_FLAG_NONE));
   CHECK(strstr(diagnostics, "null"));

   GX2VertexShader *vertex = CompileVertexShader(
      vertex_source, diagnostics, sizeof(diagnostics), GLSL_COMPILER_FLAG_NONE);
   if (!vertex) {
      fprintf(stderr, "Vertex compilation failed: %s\n", diagnostics);
      return 1;
   }
   CHECK(vertex->program && vertex->size);
   CHECK(vertex->mode == GX2_SHADER_MODE_UNIFORM_BLOCK);
   CHECK(vertex->attribVarCount == 2);
   CHECK(vertex->regs.pa_cl_vs_out_cntl == 0);
   CHECK(vertex->regs.num_sq_vtx_semantic == 2);
   CHECK(vertex->regs.sq_vtx_semantic[0] == 0);
   CHECK(vertex->regs.sq_vtx_semantic[1] == 5);
   CHECK((vertex->regs.spi_vs_out_id[0] & 0xff) == 0x8a);
   CHECK(FindUniformBlock(vertex->uniformBlocks,
                          vertex->uniformBlockCount,
                          "VertexData") == 4);
   const GX2UniformVar *scale = FindUniform(
      vertex->uniformVars, vertex->uniformVarCount, "scale");
   CHECK(scale && scale->offset == 16);

   GX2PixelShader *pixel = CompilePixelShader(
      pixel_source, diagnostics, sizeof(diagnostics), GLSL_COMPILER_FLAG_NONE);
   if (!pixel) {
      fprintf(stderr, "Pixel compilation failed: %s\n", diagnostics);
      return 1;
   }
   CHECK(pixel->program && pixel->size);
   CHECK(pixel->mode == GX2_SHADER_MODE_UNIFORM_REGISTER);
   CHECK((pixel->regs.spi_ps_input_cntls[0] & 0xff) == 0x8a);
   CHECK(FindUniformBlock(pixel->uniformBlocks,
                          pixel->uniformBlockCount,
                          "PixelData") == 9);
   CHECK(pixel->uniformBlockCount == 1);
   CHECK(HasAluConstSource(pixel->program, pixel->size, 257, false));
   CHECK(HasKcacheBank(pixel->program, pixel->size, 9));
   CHECK(FindSampler(pixel->samplerVars,
                     pixel->samplerVarCount,
                     "sourceTexture") == 2);
   CHECK(FindSampler(pixel->samplerVars,
                     pixel->samplerVarCount,
                     "extraTextures") == 4);
   const GX2UniformVar *tint = FindUniform(
      pixel->uniformVars, pixel->uniformVarCount, "tint");
   const GX2UniformVar *exposure = FindUniform(
      pixel->uniformVars, pixel->uniformVarCount, "exposure");
   const GX2UniformVar *loose_color = FindUniform(
      pixel->uniformVars, pixel->uniformVarCount, "looseData.color");
   const GX2UniformVar *loose_factor = FindUniform(
      pixel->uniformVars, pixel->uniformVarCount, "looseData.factor");
   CHECK(tint && tint->offset == 16);
   CHECK(tint->block == 0);
   CHECK(exposure && exposure->offset == 16);
   CHECK(exposure->block == -1);
   CHECK(loose_color && loose_factor);
   CHECK(loose_factor->offset > loose_color->offset);
   CHECK(loose_color->block == -1);
   CHECK(loose_factor->block == -1);

   GX2VertexShader *loose_vertex = CompileVertexShader(
      "#version 450\n"
      "uniform vec4 positions[4];\n"
      "void main() { gl_Position = positions[gl_VertexID & 3]; }\n",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(loose_vertex);
   CHECK(loose_vertex->mode == GX2_SHADER_MODE_UNIFORM_REGISTER);
   CHECK(loose_vertex->uniformBlockCount == 0);
   CHECK(HasAluConstSource(loose_vertex->program,
                           loose_vertex->size,
                           256,
                           true));

   GX2VertexShader *last_uniform_block = CompileVertexShader(
      "#version 450\n"
      "layout(binding = 15, std140) uniform LastBlock { vec4 position; };\n"
      "void main() { gl_Position = position; }\n",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(last_uniform_block);
   CHECK(last_uniform_block->mode == GX2_SHADER_MODE_UNIFORM_BLOCK);
   CHECK(FindUniformBlock(last_uniform_block->uniformBlocks,
                          last_uniform_block->uniformBlockCount,
                          "LastBlock") == 15);
   CHECK(HasKcacheBank(last_uniform_block->program,
                       last_uniform_block->size,
                       15));

   GX2PixelShader *sampler_aggregate = CompilePixelShader(
      "#version 450\n"
      "struct Material { sampler2D texture; };\n"
      "uniform Material material;\n"
      "layout(location = 0) out vec4 color;\n"
      "void main() { color = texture(material.texture, vec2(0.0)); }\n",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(!sampler_aggregate);
   CHECK(strstr(diagnostics, "structures"));

   GX2VertexShader *vertex_id = CompileVertexShader(
      "#version 450\n"
      "layout(binding = 3, std140) uniform VertexTable { vec4 values[4]; };\n"
      "void main() { gl_Position = values[gl_VertexID & 3]; }\n",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(vertex_id);
   CHECK(FindUniformBlock(vertex_id->uniformBlocks,
                          vertex_id->uniformBlockCount,
                          "VertexTable") == 3);
   CHECK(HasControlFlowOpcode(vertex_id->program, vertex_id->size, kCfTex));
   CHECK(!HasControlFlowOpcode(vertex_id->program, vertex_id->size, kCfVtx));
   CHECK(!HasControlFlowOpcode(vertex_id->program, vertex_id->size, kCfVtxTc));
   CHECK(HasVFetchInTexClause(vertex_id->program, vertex_id->size, 0x83));

   GX2PixelShader *environment_pass = CompilePixelShader(
      "#version 450\n"
      "layout(binding = 0) uniform uf_data { vec2 pixelSize; uint isVertical; };\n"
      "layout(location = 0) out vec2 color;\n"
      "const int Quality = 5;\n"
      "const float Weights[5] = float[](0.227027, 0.1945946, 0.1216216,\n"
      "                                  0.054054, 0.016216);\n"
      "void main() {\n"
      "   color = pixelSize * Weights[0] + vec2(float(isVertical));\n"
      "   for (int i = 1; i < Quality; ++i)\n"
      "      color += pixelSize * Weights[i];\n"
      "}\n",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(environment_pass);
   CHECK(FindUniformBlock(environment_pass->uniformBlocks,
                          environment_pass->uniformBlockCount,
                          "uf_data") == 0);

   GX2VertexShader *dynamic_block = CompileVertexShader(
      "#version 450\n"
      "layout(binding = 0, std140) uniform Block { vec4 value; } blocks[2];\n"
      "void main() { gl_Position = blocks[gl_VertexID & 1].value; }\n",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(!dynamic_block);
   CHECK(strstr(diagnostics, "UBO indexing"));

   GX2PixelShader *invalid = CompilePixelShader(
      "#version 450\nthis is invalid;",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(!invalid);
   CHECK(diagnostics[0]);

   FreeVertexShader(vertex);
   FreeVertexShader(vertex_id);
   FreeVertexShader(loose_vertex);
   FreeVertexShader(last_uniform_block);
   FreePixelShader(pixel);
   FreePixelShader(environment_pass);
   DestroyGLSLCompiler();

   GX2VertexShader *still_initialized = CompileVertexShader(
      "#version 450\nvoid main() { gl_Position = vec4(0.0); }\n",
      diagnostics,
      sizeof(diagnostics),
      GLSL_COMPILER_FLAG_NONE);
   CHECK(still_initialized);
   FreeVertexShader(still_initialized);

   DestroyGLSLCompiler();
   CHECK(!CompileVertexShader(vertex_source,
                              diagnostics,
                              sizeof(diagnostics),
                              GLSL_COMPILER_FLAG_NONE));
   return 0;
}
