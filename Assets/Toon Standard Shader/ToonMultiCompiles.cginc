// Toon Standard Shader
// Adrian Biagioli (github.com/Flafla2)
// See LICENSE.txt

#ifndef TOON_MULTI_COMPILES_DEFINED
#define TOON_MULTI_COMPILES_DEFINED

#if _USER_DIFFUSE_WRAP_ON
    #define DIFFUSE_WRAP
#elif _USER_DIFFUSE_WRAP_OFF
    #undef DIFFUSE_WRAP
#else // default
    #if GLOBAL_DIFFUSE_WRAP
    #define DIFFUSE_WRAP
    #else
    #undef DIFFUSE_WRAP
    #endif
#endif

#if _USER_ENERGY_CONSERVATION_ON
    #define ENERGY_CONSERVATION
#elif _USER_ENERGY_CONSERVATION_OFF
    #undef ENERGY_CONSERVATION
#else // default
    #if GLOBAL_ENERGY_CONSERVATION
    #define ENERGY_CONSERVATION
    #else
    #undef ENERGY_CONSERVATION
    #endif
#endif

#endif