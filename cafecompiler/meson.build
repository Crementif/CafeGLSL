cafecompiler_sources = files(
  'api.cpp',
  'cafe_compiler.cpp',
)

libcafeglsl = static_library(
  'cafeglsl',
  cafecompiler_sources,
  include_directories : [
    inc_src,
    inc_include,
    inc_mesa,
    inc_compiler,
    inc_gallium,
    inc_gallium_aux,
    inc_gallium_drivers,
    inc_amd_common,
  ],
  link_whole : [libglsl_standalone, libr600, libgallium, _libgalliumvl_stub],
  dependencies : [idep_nir, idep_nir_headers, idep_mesautil],
  override_options : ['cpp_std=c++17'],
  gnu_symbol_visibility : 'hidden',
  install : true,
)

install_headers('CafeGLSLCompiler.h', 'cafe_gx2.h', subdir : 'cafeglsl')

if host_machine.system() != 'cafeos'
  cafeglsl_smoke = executable(
    'cafeglsl-smoke',
    'tests.cpp',
    include_directories : include_directories('.'),
    link_with : libcafeglsl,
    dependencies : [idep_mesautil],
    link_args : ld_args_gc_sections,
    override_options : ['cpp_std=c++17'],
  )

  test('cafeglsl-smoke', cafeglsl_smoke)

  cafeglsl_cli = executable(
    'glslcompiler.elf',
    ['main.cpp', 'gfd_write.cpp'],
    include_directories : include_directories('.'),
    link_with : libcafeglsl,
    dependencies : [idep_mesautil],
    link_args : ld_args_gc_sections,
    override_options : ['cpp_std=c++17'],
    install : true,
  )

  test(
    'cafeglsl-skinning-regression',
    cafeglsl_cli,
    args : ['-vs'] + files('testdata/skinning-regression.vert'),
  )
endif
