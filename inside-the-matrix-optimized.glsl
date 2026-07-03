/*
  Optimized inside-the-matrix shader for Ghostty.

  Original by 0xhckr / @pkazmier.
  Rune code by FabriceNeyret2 (https://www.shadertoy.com/view/4ltyDM).

  Performance changes:
  - Reduced ITERATIONS from 40 to 10
  - Replaced pow() with manual multiplication in hot path
  - Simplified per-pixel camera path calculation

  Feel free to use and modify.
*/

const int ITERATIONS = 10;
const float SPEED = 0.55;

const float STRIP_CHARS_MIN = 7.0;
const float STRIP_CHARS_MAX = 40.0;
const float STRIP_CHAR_HEIGHT = 0.15;
const float STRIP_CHAR_WIDTH = 0.10;
const float ZCELL_SIZE = STRIP_CHAR_HEIGHT * STRIP_CHARS_MAX;
const float XYCELL_SIZE = 12.0 * STRIP_CHAR_WIDTH;

const int BLOCK_SIZE = 10;
const int BLOCK_GAP = 2;

const float WALK_SPEED = 0.5 * XYCELL_SIZE;
const float BLOCKS_BEFORE_TURN = 3.0;

const float PI = 3.14159265359;

// Random / hash

float hash(float v) {
    return fract(sin(v) * 43758.5453123);
}

float hash(vec2 v) {
    return hash(dot(v, vec2(5.3983, 5.4427)));
}

vec2 hash2(vec2 v) {
    v = vec2(v * mat2(127.1, 311.7, 269.5, 183.3));
    return fract(sin(v) * 43758.5453123);
}

vec4 hash4(vec2 v) {
    vec4 p = vec4(v * mat4x2(127.1, 311.7,
                             269.5, 183.3,
                             113.5, 271.9,
                             246.1, 124.6));
    return fract(sin(p) * 43758.5453123);
}

vec4 hash4(vec3 v) {
    vec4 p = vec4(v * mat4x3(127.1, 311.7, 74.7,
                             269.5, 183.3, 246.1,
                             113.5, 271.9, 124.6,
                             271.9, 269.5, 311.7));
    return fract(sin(p) * 43758.5453123);
}

// Rune symbols

float rune_line(vec2 p, vec2 a, vec2 b) {
    p -= a;
    b -= a;
    float h = clamp(dot(p, b) / dot(b, b), 0.0, 1.0);
    return length(p - b * h);
}

float rune(vec2 U, vec2 seed, float highlight) {
    float d = 1e5;
    for (int i = 0; i < 4; i++) {
        vec4 pos = hash4(seed);
        seed += 1.0;

        if (i == 0) pos.y = 0.0;
        if (i == 1) pos.x = 0.999;
        if (i == 2) pos.x = 0.0;
        if (i == 3) pos.y = 0.999;

        vec4 snaps = vec4(2.0, 3.0, 2.0, 3.0);
        pos = (floor(pos * snaps) + 0.5) / snaps;

        if (pos.xy != pos.zw)
            d = min(d, rune_line(U, pos.xy, pos.zw + 0.001));
    }
    return smoothstep(0.1, 0.0, d) + highlight * smoothstep(0.4, 0.0, d);
}

float random_char(vec2 outer, vec2 inner, float highlight) {
    vec2 seed = vec2(dot(outer, vec2(269.5, 183.3)),
                     dot(outer, vec2(113.5, 271.9)));
    return rune(inner, seed, highlight);
}

// Digital rain ray traversal

vec3 rain(vec3 ro3, vec3 rd3, float time) {
    vec4 result = vec4(0.0);

    vec2 ro2 = vec2(ro3);
    vec2 rd2 = normalize(vec2(rd3));

    bool prefer_dx = abs(rd2.x) > abs(rd2.y);
    float t3_to_t2 = prefer_dx ? rd3.x / rd2.x : rd3.y / rd2.y;

    ivec3 cell_side = ivec3(step(0.0, rd3));
    ivec3 cell_shift = ivec3(sign(rd3));

    float t2 = 0.0;
    ivec2 next_cell = ivec2(floor(ro2 / XYCELL_SIZE));

    for (int i = 0; i < ITERATIONS; i++) {
        ivec2 cell = next_cell;
        float t2s = t2;

        vec2 side = vec2(next_cell + cell_side.xy) * XYCELL_SIZE;
        vec2 t2_side = (side - ro2) / rd2;

        if (t2_side.x < t2_side.y) {
            t2 = t2_side.x;
            next_cell.x += cell_shift.x;
        } else {
            t2 = t2_side.y;
            next_cell.y += cell_shift.y;
        }

        vec2 cell_in_block = fract(vec2(cell) / float(BLOCK_SIZE));
        float gap = float(BLOCK_GAP) / float(BLOCK_SIZE);
        if (cell_in_block.x < gap || cell_in_block.y < gap ||
            (cell_in_block.x < (gap + 0.1) && cell_in_block.y < (gap + 0.1))) {
            continue;
        }

        float t3s = t2s / t3_to_t2;
        float pos_z = ro3.z + rd3.z * t3s;

        float xycell_hash = hash(vec2(cell));

        // Replaced pow(x, 16.0) with manual multiplication for performance
        float h2 = xycell_hash * xycell_hash;
        float h4 = h2 * h2;
        float h8 = h4 * h4;
        float h16 = h8 * h8;

        float z_shift = xycell_hash * 11.0
                      - time * (0.5 + xycell_hash + h2 + h16 * 3.0);

        float char_z_shift = floor(z_shift / STRIP_CHAR_HEIGHT);
        z_shift = char_z_shift * STRIP_CHAR_HEIGHT;

        int zcell = int(floor((pos_z - z_shift) / ZCELL_SIZE));

        for (int j = 0; j < 2; j++) {
            vec4 cell_hash = hash4(vec3(ivec3(cell, zcell)));
            vec4 cell_hash2 = fract(cell_hash * vec4(127.1, 311.7, 271.9, 124.6));

            float chars_count = cell_hash.w * (STRIP_CHARS_MAX - STRIP_CHARS_MIN) + STRIP_CHARS_MIN;
            float target_length = chars_count * STRIP_CHAR_HEIGHT;
            float target_rad = STRIP_CHAR_WIDTH * 0.5;
            float target_z = float(zcell) * ZCELL_SIZE + z_shift
                           + cell_hash.z * (ZCELL_SIZE - target_length);

            vec2 target = vec2(cell) * XYCELL_SIZE + target_rad
                        + cell_hash.xy * (XYCELL_SIZE - target_rad * 2.0);

            vec2 s = target - ro2;
            float tmin = dot(s, rd2);

            if (tmin >= t2s && tmin <= t2) {
                float u = s.x * rd2.y - s.y * rd2.x;
                if (abs(u) < target_rad) {
                    u = (u / target_rad + 1.0) * 0.5;
                    float z = ro3.z + rd3.z * (tmin / t3_to_t2);
                    float v = (z - target_z) / target_length;

                    if (v >= 0.0 && v < 1.0) {
                        float c = floor(v * chars_count);
                        float q = fract(v * chars_count);
                        vec2 char_hash = hash2(vec2(c + char_z_shift, cell_hash2.x));

                        if (char_hash.x >= 0.1 || c == 0.0) {
                            // Replaced pow(char_hash.y, 4.0) with manual multiplication
                            float chy2 = char_hash.y * char_hash.y;
                            float chy4 = chy2 * chy2;

                            float time_factor = floor(
                                c == 0.0 ? time :
                                time * (1.0 * cell_hash2.z + cell_hash2.w * cell_hash2.w * 4.0 * chy4)
                            );

                            float a = random_char(vec2(char_hash.x, time_factor), vec2(u, q),
                                                  max(1.0, 3.0 - c / 2.0) * 0.2);
                            a *= clamp((chars_count - 0.5 - c) / 2.0, 0.0, 1.0);

                            if (a > 0.0) {
                                float att = 0.06 * tmin / t3_to_t2;
                                float attenuation = 1.0 + att * att;

                                vec3 col = (c == 0.0
                                    ? vec3(0.67, 1.0, 0.82)
                                    : vec3(0.25, 0.80, 0.40)) / attenuation;

                                float a1 = result.a;
                                result.a = a1 + (1.0 - a1) * a;
                                result.xyz = (result.xyz * a1 + col * (1.0 - a1) * a) / result.a;

                                if (result.a > 0.98)
                                    return result.xyz;
                            }
                        }
                    }
                }
            }
            zcell += cell_shift.z;
        }
    }
    return result.xyz * result.a;
}

// Camera helpers

vec3 rotateX(vec3 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return mat3(1.0, 0.0, 0.0,
                0.0, c,   -s,
                0.0, s,    c) * v;
}

vec3 rotateY(vec3 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return mat3(c,   0.0, -s,
                0.0, 1.0,  0.0,
                s,   0.0,  c) * v;
}

vec3 rotateZ(vec3 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return mat3(c,  -s,  0.0,
                s,   c,  0.0,
                0.0, 0.0, 1.0) * v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    if (STRIP_CHAR_WIDTH > XYCELL_SIZE ||
        STRIP_CHAR_HEIGHT * STRIP_CHARS_MAX > ZCELL_SIZE) {
        fragColor = vec4(1.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 uv = fragCoord.xy / iResolution.xy;
    float time = mod(iTime, 300.0) * SPEED;

    // Simplified smooth flying camera path
    float pathTime = time * 1.1;

    float swayX     = sin(pathTime * 0.35) * 2.2 + sin(pathTime * 0.11) * 1.0;
    float swayY     = cos(pathTime * 0.28) * 1.8;
    float heightBob = sin(pathTime * 0.9) * 0.35 + sin(pathTime * 1.7) * 0.15;

    float lookYaw   = sin(pathTime * 0.25) * 0.35;
    float lookPitch = -0.25 + sin(pathTime * 0.6) * 0.18;
    float roll      = sin(pathTime * 0.8) * 0.08;

    float level1 = float(BLOCK_SIZE) * BLOCKS_BEFORE_TURN * XYCELL_SIZE;
    vec2 mapOffset = vec2(swayX, pathTime * 0.9 + swayY);
    vec3 ro = vec3(level1 * 0.1 + mapOffset.x,
                   level1 * 0.1 + mapOffset.y,
                   heightBob);

    vec3 rd = normalize(vec3(
        (uv.x - 0.5) * 2.15,
        1.65,
        (uv.y - 0.5) * 1.85 - 0.35
    ));

    rd = rotateY(rd, lookYaw);
    rd = rotateX(rd, lookPitch);
    rd = rotateZ(rd, roll);

    ro += rd * 0.15;

    vec3 col = rain(ro, rd, time) * 0.28;

    vec4 terminalColor = texture(iChannel0, uv);
    float mask = 1.2 - step(0.5, dot(terminalColor.rgb, vec3(1.0)));
    vec3 blendedColor = mix(terminalColor.rgb * 1.15, col, mask);

    fragColor = vec4(blendedColor, terminalColor.a);
}
