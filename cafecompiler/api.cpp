#include "cafe_compiler.h"

#include "util/u_memory.h"

#include <algorithm>
#include <cstring>
#include <memory>
#include <mutex>

static std::mutex compiler_mutex;
static std::unique_ptr<CafeCompiler> compiler;
static unsigned compiler_references;

static void CopyDiagnostics(const std::string &diagnostics, char *output, int output_size)
{
   if (!output || output_size <= 0)
      return;

   const size_t length = std::min(diagnostics.size(), static_cast<size_t>(output_size - 1));
   memcpy(output, diagnostics.data(), length);
   output[length] = '\0';
}

template <typename Shader>
static void FreeShaderCommon(Shader *shader)
{
   if (!shader)
      return;

   if (shader->uniformBlocks) {
      for (uint32_t i = 0; i < shader->uniformBlockCount; ++i)
         free(const_cast<char *>(shader->uniformBlocks[i].name));
   }
   free(shader->uniformBlocks);

   if (shader->uniformVars) {
      for (uint32_t i = 0; i < shader->uniformVarCount; ++i)
         free(const_cast<char *>(shader->uniformVars[i].name));
   }
   free(shader->uniformVars);

   if (shader->samplerVars) {
      for (uint32_t i = 0; i < shader->samplerVarCount; ++i)
         free(const_cast<char *>(shader->samplerVars[i].name));
   }
   free(shader->samplerVars);

   free(shader->initialValues);
   free(shader->loopVars);
   align_free(shader->program);
}

extern "C" {

void InitGLSLCompiler(void)
{
   std::lock_guard<std::mutex> lock(compiler_mutex);
   if (!compiler_references)
      compiler = std::make_unique<CafeCompiler>();
   ++compiler_references;
}

void DestroyGLSLCompiler(void)
{
   std::lock_guard<std::mutex> lock(compiler_mutex);
   if (!compiler_references)
      return;

   if (--compiler_references == 0)
      compiler.reset();
}

const char *GetGLSLCompilerVersion(void)
{
   return "v0.3.0";
}

GX2VertexShader *CompileVertexShader(const char *source,
                                    char *info_log,
                                    int info_log_size,
                                    GLSL_COMPILER_FLAG flags)
{
   std::lock_guard<std::mutex> lock(compiler_mutex);
   std::string diagnostics;
   GX2VertexShader *shader = nullptr;

   if (!compiler)
      diagnostics = "CafeGLSL is not initialized";
   else if (!compiler->valid())
      diagnostics = compiler->initialization_error();
   else
      shader = compiler->CompileVertexShader(source, diagnostics, flags);

   CopyDiagnostics(diagnostics, info_log, info_log_size);
   return shader;
}

GX2PixelShader *CompilePixelShader(const char *source,
                                  char *info_log,
                                  int info_log_size,
                                  GLSL_COMPILER_FLAG flags)
{
   std::lock_guard<std::mutex> lock(compiler_mutex);
   std::string diagnostics;
   GX2PixelShader *shader = nullptr;

   if (!compiler)
      diagnostics = "CafeGLSL is not initialized";
   else if (!compiler->valid())
      diagnostics = compiler->initialization_error();
   else
      shader = compiler->CompilePixelShader(source, diagnostics, flags);

   CopyDiagnostics(diagnostics, info_log, info_log_size);
   return shader;
}

void FreeVertexShader(GX2VertexShader *shader)
{
   if (!shader)
      return;
   FreeShaderCommon(shader);
   if (shader->attribVars) {
      for (uint32_t i = 0; i < shader->attribVarCount; ++i)
         free(const_cast<char *>(shader->attribVars[i].name));
   }
   free(shader->attribVars);
   free(shader);
}

void FreePixelShader(GX2PixelShader *shader)
{
   if (!shader)
      return;
   FreeShaderCommon(shader);
   free(shader);
}

} // extern "C"
