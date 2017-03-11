uniform float Amplitude;

float eval(vec3 p, float a, float time) {
    float py = p.y;
    p.y = 0.;
    return length(p) + 0.25 * a*sin(0.5 * py + time * 5.0);
}

vec3 computeNormal(vec3 p, vec3 n, float a, float time) {
    vec3 e = vec3(0.1, 0, 0);
    return normalize(n - a * vec3(	eval(p + e.xyy, a, time) - eval(p - e.xyy, a, time),
                                          eval(p + e.yxy, a, time) - eval(p - e.yxy, a, time),
                                          eval(p + e.yyx, a, time) - eval(p - e.yyx, a, time)) );
}

#pragma body

vec3 p = _geometry.position.xyz;

float disp = eval(p, Amplitude, u_time);
vec2 nrm = normalize(_geometry.normal.xz);

_geometry.position.xz = nrm * disp;
_geometry.normal.xyz = computeNormal(p, _geometry.normal, Amplitude, u_time);

