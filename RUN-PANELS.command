#!/bin/bash
# Lab 07: records every panel, the debug views, and the experiments the write-ups ask for
# into report/. Experiments edit a shader for one run only; every edited shader is restored
# from report/.bak and rebuilt afterwards, even if the script is stopped with Ctrl-C.
set -u
cd "$(dirname "$0")"
OUT=report
B=build
mkdir -p "$OUT/.bak"
EDITED="noise.glsl sdf.frag heightmap.vert mytoy.frag"

cmake -S . -B $B -DCMAKE_BUILD_TYPE=Release > /dev/null && cmake --build $B > /dev/null || { echo "build failed"; exit 1; }
for f in $EDITED; do cp "shaders/$f" "$OUT/.bak/$f"; done

restore() {
  for f in $EDITED; do cp "$OUT/.bak/$f" "shaders/$f"; done
  cmake --build $B > /dev/null 2>&1
}
trap 'restore; for f in $EDITED; do cmp -s "shaders/$f" "$OUT/.bak/$f" && echo "restored $f" || echo "!! $f NOT restored, copy it back from $OUT/.bak"; done' EXIT

run() { local name=$1; shift; echo "\$ $*" > "$OUT/out-$name.txt"; "$@" 2>&1 | tee -a "$OUT/out-$name.txt"; }
quiet() { "$@" > /dev/null 2>&1; }
build() { cmake --build $B --target "$1" > /dev/null || { echo "build of $1 failed"; exit 1; }; }

echo "== 1. panels, as submitted"
run info      ./$B/info
run circle    ./$B/circle    --headless
run terrain   ./$B/terrain   --headless
run sdf       ./$B/sdf       --headless
run heightmap ./$B/heightmap --headless

echo "== 2. debug views at t = 1"
for m in 0 1 2 3; do
  quiet ./$B/circle    --headless --mode $m --save $OUT/circle_mode$m.png
  quiet ./$B/terrain   --headless --mode $m --save $OUT/terrain_mode$m.png
  quiet ./$B/sdf       --headless --mode $m --save $OUT/sdf_mode$m.png
  quiet ./$B/heightmap --headless --mode $m --save $OUT/heightmap_mode$m.png
  quiet ./$B/toy       --headless --mode $m --save $OUT/toy_mode$m.png
done
for o in 1 2 4 8; do quiet ./$B/terrain --headless --mode 1 --octaves $o --save $OUT/terrain_oct$o.png; done

echo "== 3. write-up 4.4: the grid below the noise frequency"
for n in 16 32; do
  run heightmap-N$n ./$B/heightmap --headless --grid $n --save $OUT/heightmap_N$n.png
  quiet ./$B/heightmap --headless --grid $n --mode 2 --save $OUT/heightmap_N${n}_mode2.png
done

echo "== 4. write-up 2.5: Hermite replaced by plain f"
perl -pi -e 's/vec2 w = f \* f \* \(3\.0 - 2\.0 \* f\);/vec2 w = f;/' shaders/noise.glsl
build terrain
run exp-linear ./$B/terrain --headless --mode 2 --save $OUT/exp_linear_mode2.png
restore

echo "== 5. write-up 3.2: two values of k"
for k in 0.05 0.40; do
  perl -pi -e "s/op_smooth_union\(body, ball, 0\.20\)/op_smooth_union(body, ball, $k)/" shaders/sdf.frag
  build sdf
  run exp-k$k ./$B/sdf --headless --save $OUT/exp_k${k}_mode0.png
  quiet ./$B/sdf --headless --mode 1 --save $OUT/exp_k${k}_mode1.png
  restore
done

echo "== 6. write-up 4.2-4.3: forward differences, 3 height() calls per vertex instead of 5"
perl -0pi -e 's/vec3 n = normalize\(vec3\(height.*?\)\)\)\);/vec3 n = normalize(vec3(pos.y - height(xz + vec2(e, 0.0)), e, pos.y - height(xz + vec2(0.0, e))));/s' shaders/heightmap.vert
grep -q "pos.y - height" shaders/heightmap.vert || { echo "forward-difference edit did not apply"; exit 1; }
build heightmap
run exp-forward ./$B/heightmap --headless
restore

echo "== 7. write-up 5.2-5.3: Part V without its most expensive term, and at 3 octaves"
perl -pi -e 's/for \(int i = 0; i < 3; \+\+i\)/for (int i = 0; i < 0; ++i)/' shaders/mytoy.frag
build toy
run exp-toy-nomountains ./$B/toy --headless
restore
run exp-toy-oct3 ./$B/toy --headless --octaves 3 --save $OUT/exp_toy_oct3.png

echo "== 8. Part V as submitted (writes toy_0/1/2.png last)"
run toy ./$B/toy --headless

echo
echo "done: panels in $OUT/out-*.txt, images in $OUT/*.png"
