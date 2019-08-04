#version 150

#ifdef VS_PROGRAM

in vec4 position;
in vec3 normal;
in vec4 uv0;
#ifdef NORMAL_MAP
in vec3 tangent;
out vec4 oUv0;
out vec4 oTangent;
#else
out vec2 oUv0;
#endif
out vec3 fragPos;
out vec3 oNormal;

uniform mat4 modelMat;
uniform mat4 it_worldMat;
uniform mat4 worldViewProjMat;

void main()
{
    fragPos = vec3(modelMat * position);
   
#ifdef NORMAL_MAP
    oNormal = normalize (vec3(it_worldMat * vec4(normal, 0)));	
    vec3 wTangent = normalize(vec3(it_worldMat * vec4(tangent, 0)));  //转到世界空间
    vec3 wBiTangent = cross(oNormal, wTangent);
    oUv0 = vec4(uv0.xy, wBiTangent.xy);
    oTangent = vec4(wTangent.xyz, wBiTangent.z);
#else
    oNormal = vec3(it_worldMat * vec4(normal, 1));
    oUv0 = uv0.xy;
#endif

	gl_Position = worldViewProjMat * position;
}

#else

uniform vec4 AmbientColor;    //ambient RGBA -- alpha is intensity

uniform vec4 diffuseMat;   //材质属性
uniform vec4 specularMat;  //反射光属性 RGBA --alpha表示高光强度 
uniform vec4 ambientMat;   //漫反射材质属性
uniform vec4 emissiveMat;  //伪自发光材质属性
uniform float shiness;  //高光强度

uniform int light_count;    //实际灯光数量
uniform int light_type_array[MAX_LIGHT_COUNT];  //灯光类型 LT_POINT = 0, LT_DIRECTIONAL = 1, LT_SPOTLIGHT = 2
uniform vec4 light_diffuse_array[MAX_LIGHT_COUNT];   //灯光颜色
uniform float light_power_array[MAX_LIGHT_COUNT];   //灯光强度
uniform vec3 light_direction_array[MAX_LIGHT_COUNT];  //平行光和聚光灯
uniform vec3 light_position_array[MAX_LIGHT_COUNT];
  //Attenuation = Constant + Linear * Distance + Quadratic * Distance ^ 2
  //Luminosity = 1 / Attenuation
uniform vec4 light_attenuation_array[MAX_LIGHT_COUNT]; //点光源，聚光灯衰减，平行光无效，
uniform float spotlight_params_array[MAX_LIGHT_COUNT]; //聚光灯内半角cos值
uniform int light_cast_shadow_array[MAX_LIGHT_COUNT]; //是否投射阴影


uniform sampler2D diffuseMap;
uniform float minAlpha;
#ifdef NORMAL_MAP
uniform sampler2D normalMap;
in vec4 oUv0;
in vec4 oTangent;
#else
    #ifdef NORMAL_HEIGHTMAP
    uniform sampler2D normalHeightMap;
    uniform vec4 scaleBias;
    in vec4 oUv0;
    in vec4 oTangent;
	vec2 steepPallaxMapping(in vec3 v, in vec2 t)
	{
		const float minLayers = 5;
		const float maxLayers = 15;
		float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0, 0, 1), v)));
	 
		float layerHeight = 8 / numLayers;
		float currentLayerHeight = 0;
		vec2 dtex = 0.6 * v.xy / v.z / numLayers;
		vec2 currentTextureCoords = t;

		float heightFromTexture = texture(normalHeightMap, currentTextureCoords).a;
		while(heightFromTexture > currentLayerHeight) 
		{
			currentLayerHeight += layerHeight;
			currentTextureCoords -= dtex;
			heightFromTexture = texture(normalHeightMap, currentTextureCoords).a;
		}
	   return currentTextureCoords;
	}
    #else
    in vec2 oUv0;
    #endif
#endif

#ifdef SPECULAR_MAP
uniform sampler2D specularMap;
#endif
#ifdef AO_MAP
uniform sampler2D aoMap;
#endif

uniform vec3 cameraPos;

in vec3 fragPos;
in vec3 oNormal;

vec3 expand(vec3 v)
{
	return (v - 0.5) * 2.0;
}



out vec4 FragColor;
void main()
{

	#ifndef NORMAL_HEIGHTMAP
		vec4 diffuseColor = texture(diffuseMap, oUv0.xy);
		if(diffuseColor.a < minAlpha) {discard;}
	#endif

    vec3 viewDir = normalize(fragPos - cameraPos);
	vec3 normal;
	#ifdef NORMAL_MAP
		vec3 tnormal = expand(texture(normalMap, oUv0.xy).rgb);
		normal.x = dot(vec3(oTangent.x, oUv0.z, oNormal.x), tnormal);
		normal.y = dot(vec3(oTangent.y, oUv0.w, oNormal.y), tnormal);
		normal.z = dot(vec3(oTangent.z, oTangent.w, oNormal.z), tnormal);
        normal = normalize(normal);	
	#else
        #ifdef NORMAL_HEIGHTMAP
           // float height = texture2D(normalHeightMap, oUv0.xy).a;
            //float displacement = (height * scaleBias.x) + scaleBias.y;
            //vec3 uv2 = vec3(oUv0.xy, 1.0);
          //  uv2.xy = ((viewDir * displacement) + uv2).xy;
		  vec2 uv2 = steepPallaxMapping(viewDir, oUv0.xy);
		  
            vec3 tnormal = expand(texture2D(normalHeightMap, uv2.xy).xyz);
	        normal.x = dot(vec3(oTangent.x, oUv0.z, oNormal.x), tnormal);
	    	normal.y = dot(vec3(oTangent.y, oUv0.w, oNormal.y), tnormal);
		    normal.z = dot(vec3(oTangent.z, oTangent.w, oNormal.z), tnormal);
            normal = normalize(normal);	
        #else
		    normal = normalize(oNormal);
        #endif
	#endif
	
	#ifdef NORMAL_HEIGHTMAP
		vec4 diffuseColor = texture(diffuseMap, uv2.xy);
		if(diffuseColor.a < minAlpha) {discard;}
		#ifdef AO_MAP
			vec4 aoColor = texture(aoMap, uv2.xy);
		#endif
	#else
		#ifdef AO_MAP
			vec4 aoColor = texture(aoMap, oUv0.xy);
		#endif
	#endif
		
    vec3 result = vec3(0.0);
    for(int i=0 ; i<light_count; i++)
    {
        if(light_type_array[i] == 1) //平行光
        {
            #ifdef AO_MAP
				vec3 ambient = AmbientColor.rgb * ambientMat.rgb * diffuseColor.rgb * aoColor.rgb;
            #else
				vec3 ambient = AmbientColor.rgb * ambientMat.rgb * diffuseColor.rgb;
            #endif
            vec3 diffuse =  light_diffuse_array[i].rgb * diffuseMat.rgb * max(dot(normalize(-light_direction_array[i]), normal), 0) * diffuseColor.rgb;
            #ifdef LAMBERT
                 result = result + ambient + diffuse;
            #else
                vec3 specular;
                #ifdef BLINN_PHONE
                    #ifdef SPECULAR_MAP
						#ifdef NORMAL_HEIGHTMAP
							specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), shiness) * vec3(texture(specularMap, uv2.xy));
						#else
							specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), shiness) * vec3(texture(specularMap, oUv0.xy));
						#endif      
                    #else
                        specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), shiness);
                    #endif
                #else
                    #ifdef SPECULAR_MAP
						#ifdef NORMAL_HEIGHTMAP
							specular = specularMat.rgb * pow(max(dot(normalize(reflect(-light_direction_array[i], normal)), viewDir), 0),shiness) * vec3(texture(specularMap, uv2.xy));
						#else
							specular = specularMat.rgb * pow(max(dot(normalize(reflect(-light_direction_array[i], normal)), viewDir), 0),shiness) * vec3(texture(specularMap, oUv0.xy));
						#endif                     
                    #else
                        specular = specularMat.rgb * pow(max(dot(normalize(reflect(-light_direction_array[i], normal)), viewDir), 0), shiness);
                    #endif
                #endif
                // result = result + ambient + diffuse + specular;
                  //  result = result + diffuse + specular;
		             result = result +ambient + diffuse+ specular;
            #endif
        }
        else if(light_type_array[i] == 0) //点光源
        {  
            vec3 light_dir = fragPos - light_position_array[i];
			float dis = length(light_dir);
            float attenuation = 1/(light_attenuation_array[i].r +light_attenuation_array[i].g * dis + light_attenuation_array[i].b * dis * dis); 
            vec3 ambient = AmbientColor.rgb * ambientMat.rgb * diffuseColor.rgb;
            vec3 diffuse = light_diffuse_array[i].rgb * diffuseMat.rgb * max(dot(normalize(light_dir), normal), 0) * diffuseColor.rgb;
            #ifdef LAMBERT
                 result = result + attenuation * (ambient + diffuse);
            #else
                vec3 specular;
                #ifdef BLINN_PHONE
                    #ifdef SPECULAR_MAP
						#ifdef NORMAL_HEIGHTMAP
							specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), shiness) * vec3(texture(specularMap, uv2.xy));
						#else
							specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), shiness) * vec3(texture(specularMap, oUv0.xy));
						#endif    
                    #else
                        specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_dir) + normalize(viewDir)), normal), 0), specularMat.a);
                    #endif
                #else
                    #ifdef SPECULAR_MAP
						#ifdef NORMAL_HEIGHTMAP
							specular = specularMat.rgb * pow(max(dot(normalize(reflect(normalize(light_dir), normal)), viewDir), 0), specularMat.a) * vec3(texture(specularMap, uv2	.xy));
						#else
							specular = specularMat.rgb * pow(max(dot(normalize(reflect(normalize(light_dir), normal)), viewDir), 0), specularMat.a) * vec3(texture(specularMap, oUv0.xy));
						#endif 
                    #else
                        specular = specularMat.rgb * pow(max(dot(normalize(reflect(normalize(light_dir), normal)), viewDir), 0), specularMat.a);
                    #endif
                #endif
                result = result + attenuation * (ambient + diffuse + specular);
            #endif
        }
        else if(light_type_array[i] == 2) //聚光灯
        {
            vec3 light_dir = fragPos - light_position_array[i];
			float dis = length(light_dir);
            float attenuation = 1/(light_attenuation_array[i].r +light_attenuation_array[i].g * dis + light_attenuation_array[i].b * dis * dis); 
            float theta = dot(normalize(light_dir), normalize(light_direction_array[i]));
            if(theta > spotlight_params_array[i])
            {
                vec3 ambient = AmbientColor.rgb * ambientMat.rgb * diffuseColor.rgb;
                vec3 diffuse = light_diffuse_array[i].rgb * diffuseMat.rgb * max(dot(normalize(-light_dir), normal), 0) * diffuseColor.rgb;
                #ifdef LAMBERT
                     result = result + attenuation * (ambient + diffuse);
                #else
                    vec3 specular;
                    #ifdef BLINN_PHONE
                        #ifdef SPECULAR_MAP
                            #ifdef NORMAL_HEIGHTMAP
								specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), shiness) * vec3(texture(specularMap, uv2.xy));
							#else
								specular = specularMat.rgb * pow(max(dot(normalize(normalize(-light_direction_array[i]) + viewDir), normal), 0), shiness) * vec3(texture(specularMap, oUv0.xy));
							#endif    
						#else
                            specular= specularMat.rgb * pow(max(dot(normalize(normalize(-light_dir) + normalize(viewDir)), normal), 0), specularMat.a);
                        #endif
                    #else
                        #ifdef SPECULAR_MAP
							#ifdef NORMAL_HEIGHTMAP
								specular= specularMat.rgb * pow(max(dot(normalize(reflect(normalize(light_dir), normal)), viewDir), 0), specularMat.a) * vec3(texture(specularMap, uv2.xy));
							#else
								specular= specularMat.rgb * pow(max(dot(normalize(reflect(normalize(light_dir), normal)), viewDir), 0), specularMat.a) * vec3(texture(specularMap, oUv0.xy));
							#endif    
                        #else
                            specular= specularMat.rgb * pow(max(dot(normalize(reflect(normalize(light_dir), normal)), viewDir), 0), specularMat.a);
                        #endif
                    #endif
                    result = result + attenuation * (ambient + diffuse + specular);
                #endif
            }
        }
     }
	//FragColor = vec4(1.0,0.0,0.0, 1.0);
	FragColor = vec4(result, diffuseColor.a);
    if (light_count == 0) { FragColor = emissiveMat * diffuseColor; }
}
 


#endif