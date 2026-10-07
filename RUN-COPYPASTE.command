#!/bin/bash
# Part V copy-paste test: ShaderToy's default "New shader" mainImage, plus a white band where
# ShaderToy's uv.y > 0.9 (the TOP of the screen in ShaderToy). Restores mytoy.frag and the
# submitted toy frames afterwards.
set -u
cd "$(dirname "$0")"
OUT=report; B=build
mkdir -p $OUT/.bak-cp
cp shaders/mytoy.frag $OUT/.bak-cp/mytoy.frag
cp $OUT/toy_0.png $OUT/toy_1.png $OUT/toy_2.png $OUT/.bak-cp/
trap 'cp $OUT/.bak-cp/mytoy.frag shaders/mytoy.frag; cp $OUT/.bak-cp/toy_?.png $OUT/; cmake --build $B --target toy > /dev/null 2>&1; cmp -s shaders/mytoy.frag $OUT/.bak-cp/mytoy.frag && echo "restored mytoy.frag and toy frames"' EXIT
cat > shaders/mytoy.frag <<'GLSL'
#version 450
#extension GL_GOOGLE_include_directive : require

#include <shadertoy.glsl>
#include <noise.glsl>

// pasted from shadertoy.com's default new shader, unchanged except for the marked line
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;

    // Time varying pixel color
    vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));

    if (uv.y > 0.9) col = vec3(1.0);   // orientation probe: ShaderToy's top band

    // Output to screen
    fragColor = vec4(col,1.0);
}
GLSL
cmake --build $B --target toy > /dev/null || { echo "build failed"; exit 1; }
./$B/toy --headless --save $OUT/copypaste_test.png 2>&1 | tee $OUT/out-copypaste.txt
echo "done"
