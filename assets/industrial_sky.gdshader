shader_type sky;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 float h=max(EYEDIR.y,0.0);
 vec3 atmosphere=mix(vec3(.48,.59,.63),vec3(.12,.24,.34),pow(h,.45));
 vec2 uv=EYEDIR.xz/max(.18,EYEDIR.y+.23)*2.8;
 float cloud=noise(uv)*.58+noise(uv*2.1)*.27+noise(uv*4.3)*.15;
 float cover=smoothstep(.43,.72,cloud)*smoothstep(.0,.18,h);
 COLOR=mix(atmosphere,vec3(.70,.73,.71),cover*.72);
}
