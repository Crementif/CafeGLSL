#include "CafeGLSLCompiler.h"
#include "gx2_definitions.h"

#include <cstdint>

class CafeGLSLCompiler
{
public:
    // todo - these are no longer necessary. We can directly write to GX2VertexShader/GX2PixelShader
    typedef struct
    {
        uint32_t sq_pgm_resources_vs;
        uint32_t vgt_primitiveid_en;
        uint32_t spi_vs_out_config;
        uint32_t num_spi_vs_out_id;
        uint32_t spi_vs_out_id[10];
        uint32_t pa_cl_vs_out_cntl;
        uint32_t sq_vtx_semantic_clear;
        uint32_t num_sq_vtx_semantic;
        uint32_t sq_vtx_semantic[32];
        uint32_t vgt_strmout_buffer_en;
        uint32_t vgt_vertex_reuse_block_cntl;
        uint32_t vgt_hos_reuse_depth;
    }VSRegs;

    typedef struct
    {
      uint32_t sq_pgm_resources_ps;
      uint32_t sq_pgm_exports_ps;
      uint32_t spi_ps_in_control_0;
      uint32_t spi_ps_in_control_1;
      uint32_t num_spi_ps_input_cntl;
      uint32_t spi_ps_input_cntls[32];
      uint32_t cb_shader_mask;
      uint32_t cb_shader_control;
      uint32_t db_shader_control;
      uint32_t spi_input_z;
    }PSRegs;


    enum class SHADER_TYPE
    {
        VERTEX_SHADER,
        GEOMETRY_SHADER,
        PIXEL_SHADER,
    };

	CafeGLSLCompiler();
    ~CafeGLSLCompiler();

    bool CompileGLSL(const char *shaderSource, SHADER_TYPE shaderType, char* infoLogOut, int infoLogMaxLength);
    bool GetShaderBytecode(uint32_t *&programPtr, uint32_t &programSize);
    void PrintShaderDisassembly(); // outputs to stderr

    void GetVertexShaderRegs(VSRegs& vsRegs);
    void GetPixelShaderRegs(PSRegs& psRegs);

    void GetVertexShaderVars(GX2VertexShader *vs);
    void GetPixelShaderVars(GX2PixelShader* ps);



    void CleanupCurrentProgram();
private:
    void _InitGLContext();

    void _InitScreen();
    void _InitStateContext();

    void GetShaderIOInfo(struct CafeShaderIOInfo& shaderIOInfo);

    struct r600_pipe_shader* GetCurrentPipeShader();
	struct gl_program* GetCurrentGLProgram();

public:
	SHADER_TYPE lastCompiledShaderType{};
	// GLSL
	struct gl_context* glCtx{};
	// screen
	struct r600_screen* r600Screen{};
	// pipe context
	struct r600_context* r600Ctx{};
	struct r600_isa* r600Isa{};
	// our fake render state
	struct st_context* stContext;
	// shader
	struct gl_shader_program* shProg{};
};
