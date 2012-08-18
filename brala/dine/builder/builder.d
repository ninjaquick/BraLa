module brala.dine.builder.builder;

private {
    import brala.dine.chunk : Block;
    import brala.dine.builder.tessellator : Vertex;
    import brala.dine.builder.constants : Side;
}

public {
    import std.array : array, join;
    import std.algorithm : map;
    import std.functional : memoize;
    import std.typetuple : TypeTuple;
    
    import brala.dine.builder.biomes : BiomeData, BIOMES;
    import brala.dine.builder.vertices : BLOCK_VERTICES_LEFT, BLOCK_VERTICES_RIGHT, BLOCK_VERTICES_NEAR,
                                         BLOCK_VERTICES_FAR, BLOCK_VERTICES_TOP, BLOCK_VERTICES_BOTTOM,
                                         get_vertices, TextureSlice, SlabTextureSlice,
                                         simple_block, simple_slab;
}


template WoolPair(byte xi, byte yi) {
    enum x = xi;
    enum y = yi;
}

mixin template BlockBuilder() {
    void add_vertex(float x, float y, float z,
                    float nx, float ny, float nz,
                    ubyte u_terrain, ubyte v_terrain,
                    ubyte u_mask, ubyte v_mask,
                    float u_biome, float v_biome)
        in { assert(elements+1 <= buffer.length, "not enough allocated memory for tessellator"); }
        body {
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&x)[0..4];
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&y)[0..4];
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&z)[0..4];
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&nx)[0..4];
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&ny)[0..4];
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&nz)[0..4];
            buffer.ptr[elements..(elements+=1)] = (cast(void*)&u_terrain)[0..1];
            buffer.ptr[elements..(elements+=1)] = (cast(void*)&v_terrain)[0..1];
            buffer.ptr[elements..(elements+=1)] = (cast(void*)&u_mask)[0..1];
            buffer.ptr[elements..(elements+=1)] = (cast(void*)&v_mask)[0..1];
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&u_biome)[0..4];
            buffer.ptr[elements..(elements+=4)] = (cast(void*)&v_biome)[0..4];
        }

    void add_template_vertices(T : Vertex)(const auto ref T[] vertices,
                               float x_offset, float y_offset, float z_offset,
                               float u_biome, float v_biome)
        in { assert(elements+vertices.length <= buffer.length, "not enough allocated memory for tessellator"); }
        body {
            size_t end = elements + vertices.length*Vertex.sizeof;
            
            buffer.ptr[elements..end] = cast(void[])vertices;
            
            for(; elements < end; elements += Vertex.sizeof) {
                Vertex* vertex = cast(Vertex*)&((buffer.ptr)[elements]);
                vertex.x += x_offset;
                vertex.y += y_offset;
                vertex.z += z_offset;
                vertex.u_biome = u_biome;
                vertex.v_biome = v_biome;
            }
        }

    void add_vertices(T : Vertex)(const auto ref T[] vertices)
        in { assert(elements+vertices.length <= buffer.length, "not enough allocated memory for tesselator"); }
        body {
            buffer.ptr[elements..(elements += vertices.length*Vertex.sizeof)] = cast(void[])vertices;
        }

    // blocks
    void grass_block(Side s)(const ref Block block, const ref BiomeData biome_data,
                             float x_offset, float y_offset, float z_offset) {
        Vertex[] vertices = get_vertices!(s)(block.id);

        add_template_vertices(vertices, x_offset, y_offset, z_offset,
                              biome_data.grass_uv.field);
    }

    void plank_block(Side s)(const ref Block block, const ref BiomeData biome_data,
                             float x_offset, float y_offset, float z_offset) {       
        final switch(block.metadata & 0x3) {
            case 0: mixin(add_block_enum_vertices("4", "1")); break; // oak
            case 1: mixin(add_block_enum_vertices("6", "13")); break; // spruce
            case 2: mixin(add_block_enum_vertices("6", "14")); break; // birch
            case 3: mixin(add_block_enum_vertices("7", "13")); break; // jungle
        }
    }

    void wood_block(Side s)(const ref Block block, const ref BiomeData biome_data,
                            float x_offset, float y_offset, float z_offset) {

        if(block.metadata == 0) {
            tessellate_simple_block!(s)(block, biome_data, x_offset, y_offset, z_offset);
        }

        enum set_tex = ```
        final switch(block.metadata & 0x3) {
            case 0: tex = TextureSlice(4, 2); break; // oak
            case 1: tex = TextureSlice(4, 8); break; // spruce
            case 2: tex = TextureSlice(5, 8); break; // birch
            case 3: tex = TextureSlice(9, 10); break; // jungle
        }
        ```;
        
        TextureSlice tex;
        byte[2][4] texcoords;
        // TODO: rewrite it/think of something better, I don't like it
        static if(s == Side.NEAR || s == Side.FAR) { // south and north
            if((block.metadata & 0xc) == 0) {
                mixin(set_tex);
                texcoords = tex.texcoords;
            } else if(block.metadata & 0x4) {
                mixin(set_tex);
                texcoords = tex.texcoords_90;
            } else { // it is 0x8
                texcoords = TextureSlice(5, 2).texcoords;
            }
        } else static if(s == Side.LEFT || s == Side.RIGHT) { // west and east
            if((block.metadata & 0xc) == 0) {
                mixin(set_tex);
                texcoords = tex.texcoords;
            } else if(block.metadata & 0x8) {
                mixin(set_tex);
                texcoords = tex.texcoords_90;
            } else { // it is 0x4
                texcoords = TextureSlice(5, 2).texcoords;
            }
        } else static if(s == Side.TOP || s == Side.BOTTOM) {
            if(block.metadata & 0x4) {
                mixin(set_tex);
                texcoords = tex.texcoords_90;
            } else if(block.metadata & 0x8) {
                mixin(set_tex);
                texcoords = tex.texcoords;
            } else { // it is 0x0
                texcoords = TextureSlice(5, 2).texcoords;
            }
        } else {
            static assert(false, "use single_side string-mixin gen for wood_block.");
        }
        
        auto sb = memoize!(simple_block, 16)(s, texcoords); // memoize is faster!
        add_template_vertices(sb, x_offset, y_offset, z_offset, 0, 0);
    }
        
    void leave_block(Side s)(const ref Block block, const ref BiomeData biome_data,
                             float x_offset, float y_offset, float z_offset) {
        final switch(block.metadata & 0x03) {
            case 0: enum vertices = simple_block(s, TextureSlice(5, 4)); // oak
                    add_template_vertices(vertices, x_offset, y_offset, z_offset, biome_data.leave_uv.field); break;
            case 1: enum vertices = simple_block(s, TextureSlice(5, 9)); // spruce
                    add_template_vertices(vertices, x_offset, y_offset, z_offset, biome_data.leave_uv.field); break;
            case 2: enum vertices = simple_block(s, TextureSlice(5, 4)); // birch, uses oak texture
                    // birch trees have a different biome color?
                    add_template_vertices(vertices, x_offset, y_offset, z_offset, biome_data.leave_uv.field); break;
            case 3: enum vertices = simple_block(s, TextureSlice(5, 13)); // jungle
                    add_template_vertices(vertices, x_offset, y_offset, z_offset, biome_data.leave_uv.field); break;
        }
    }

    void sandstone_block(Side s)(const ref Block block, const ref BiomeData biome_data,
                                 float x_offset, float y_offset, float z_offset) {
        if(block.metadata == 0) {
            return tessellate_simple_block!(s)(block, biome_data, x_offset, y_offset, z_offset);
        }

        static if(s == Side.TOP || s == Side.BOTTOM) {
            enum vertices = simple_block(s, TextureSlice(0, 12).texcoords);
            add_template_vertices(vertices, x_offset, y_offset, z_offset, 0, 0);
        } else {
            if(block.metadata == 0x1) { // chiseled
                enum vertices = simple_block(s, TextureSlice(5, 15).texcoords);
                add_template_vertices(vertices, x_offset, y_offset, z_offset, 0, 0);
            } else { // smooth
                enum vertices = simple_block(s, TextureSlice(6, 15).texcoords);
                add_template_vertices(vertices, x_offset, y_offset, z_offset, 0, 0);
            }
        }
    }

    void wool_block(Side s)(const ref Block block, const ref BiomeData biome_data,
                            float x_offset, float y_offset, float z_offset) {
        static string wool_vertices() {
                    // no enum possible due to CTFE bug?
            return `auto vertices = memoize!(simple_block, 16)(s, TextureSlice(slice.x, slice.y).texcoords);
                    add_template_vertices(vertices, x_offset, y_offset, z_offset, 0, 0);`;
        }

        alias WoolPair t;
        final switch(block.metadata) {                                                     
            foreach(i, slice; TypeTuple!(t!(0, 5),  t!(2, 14), t!(2, 13), t!(2, 12), t!(2, 11), t!(2, 10), t!(2, 9), t!(2, 8),
                                         t!(1, 15), t!(1, 14), t!(1, 13), t!(1, 12), t!(1, 11), t!(1, 10), t!(1, 9), t!(1, 8))) {
                case i: mixin(wool_vertices()); break;
            }
        }
    }

    void stonebrick_block(Side s)(const ref Block block, const ref BiomeData biome_data,
                                  float x_offset, float y_offset, float z_offset) {
        final switch(block.metadata & 0x3) {
            case 0: mixin(add_block_enum_vertices("6", "4")); break; // normal
            case 1: mixin(add_block_enum_vertices("4", "7")); break; // mossy
            case 2: mixin(add_block_enum_vertices("5", "7")); break; // cracked
            case 3: mixin(add_block_enum_vertices("5", "14")); break; // chiseled
        }
    }

    void wooden_slab(Side s)(const ref Block block, const ref BiomeData biome_data,
                             float x_offset, float y_offset, float z_offset) {
        bool upside_down = (block.metadata & 0x8) != 0;
        final switch(block.metadata & 0x3) {
            case 0: mixin(add_slab_enum_vertices(s, "4", "1")); break; // oak
            case 1: mixin(add_slab_enum_vertices(s, "6", "13")); break; // spruce
            case 2: mixin(add_slab_enum_vertices(s, "6", "14")); break; // birch
            case 3: mixin(add_slab_enum_vertices(s, "7", "13")); break; // jungle
        }
    }

    void stone_slab(Side s)(const ref Block block, const ref BiomeData biome_data,
                             float x_offset, float y_offset, float z_offset) {
        bool upside_down = (block.metadata & 0x8) != 0;

        static if(s == Side.TOP) {
            bool tessellated = true;
            if(block.metadata == 0) { // stone
                mixin(add_slab_enum_vertices(s, "6", "1"));
            } else if((block.metadata & 0x7) == 1) { // sandstone
                mixin(add_slab_enum_vertices(s, "0", "12"));
            } else {
                tessellated = false;
            }
        } else static if(s == Side.BOTTOM) {
            bool tessellated = true;
            if(block.metadata == 0) { // stone
                mixin(add_slab_enum_vertices(s, "6", "1"));
            } else if((block.metadata & 0x7) == 1) { // sandstone
                mixin(add_slab_enum_vertices(s, "0", "14"));
            } else {
                tessellated = false;
            }
        } else {
            bool tessellated = false;
        }

        if(!tessellated) {
            final switch(block.metadata & 0x7) {
                case 0: mixin(add_slab_enum_vertices(s, "5", "1")); break; // stone
                case 1: mixin(add_slab_enum_vertices(s, "0", "13")); break; // sandstone
                case 2: mixin(add_slab_enum_vertices(s, "4", "1")); break; // wooden stone
                case 3: mixin(add_slab_enum_vertices(s, "0", "2")); break; // cobblestone
                case 4: mixin(add_slab_enum_vertices(s, "7", "1")); break; // brick
                case 5: mixin(add_slab_enum_vertices(s, "6", "4")); break; // stone brick
            }
        }
    }

    void dispatch(Side side)(const ref Block block, const ref BiomeData biome_data,
                             float x_offset, float y_offset, float z_offset) {
        switch(block.id) {
            case 2: mixin(single_side("grass_block")); break; // grass
            case 5: mixin(single_side("plank_block")); break; // planks
            case 17: mixin(single_side("wood_block")); break; // wood
            case 18: mixin(single_side("leave_block")); break; // leaves
            case 24: mixin(single_side("sandstone_block")); break; // sandstone
            case 35: mixin(single_side("wool_block")); break; // wool
            case 44: mixin(single_side("stone_slab")); break; // stone slabs - stone, sandstone, wooden stone, cobblestone, brick, stone brick
            case 98: mixin(single_side("stonebrick_block")); break; // stone brick
            case 126: mixin(single_side("wooden_slab")); break; // wooden slab
            default: tessellate_simple_block!(side)(block, biome_data, x_offset, y_offset, z_offset);
        }
    }

    void tessellate_simple_block(Side side)(const ref Block block, const ref BiomeData biome_data,
                                            float x_offset, float y_offset, float z_offset) {
        static if(side == Side.LEFT) {
            add_template_vertices(BLOCK_VERTICES_LEFT[block.id], x_offset, y_offset, z_offset, 0, 0);
        } else static if(side == Side.RIGHT) {
            add_template_vertices(BLOCK_VERTICES_RIGHT[block.id], x_offset, y_offset, z_offset, 0, 0);
        } else static if(side == Side.NEAR) {
            add_template_vertices(BLOCK_VERTICES_NEAR[block.id], x_offset, y_offset, z_offset, 0, 0);
        } else static if(side == Side.FAR) {
            add_template_vertices(BLOCK_VERTICES_FAR[block.id], x_offset, y_offset, z_offset, 0, 0);
        } else static if(side == Side.TOP) {
            add_template_vertices(BLOCK_VERTICES_TOP[block.id], x_offset, y_offset, z_offset, 0, 0);
        } else static if(side == Side.BOTTOM) {
            add_template_vertices(BLOCK_VERTICES_BOTTOM[block.id], x_offset, y_offset, z_offset, 0, 0);
        } else static if(side == Side.ALL) {
            tessellate_simple_block!(Side.LEFT)(block, biome_data, x_offset, y_offset, z_offset);
            tessellate_simple_block!(Side.RIGHT)(block, biome_data, x_offset, y_offset, z_offset);
            tessellate_simple_block!(Side.NEAR)(block, biome_data, x_offset, y_offset, z_offset);
            tessellate_simple_block!(Side.FAR)(block, biome_data, x_offset, y_offset, z_offset);
            tessellate_simple_block!(Side.TOP)(block, biome_data, x_offset, y_offset, z_offset);
            tessellate_simple_block!(Side.BOTTOM)(block, biome_data, x_offset, y_offset, z_offset);
        }
    }
}

static string add_block_enum_vertices(string x, string y) {
    return `enum vertices = simple_block(s, TextureSlice(` ~ x ~ `, ` ~ y ~ `).texcoords);
            add_template_vertices(vertices, x_offset, y_offset, z_offset, 0, 0);`;
}

static string add_slab_enum_vertices(Side s, string x, string y) {
    string v;
    if(s == Side.TOP || s == Side.BOTTOM) {
        v = `enum vertices = simple_slab(s, false, TextureSlice(` ~ x ~ `, ` ~ y ~ `).texcoords);
             enum vertices_usd = simple_slab(s, true, TextureSlice(` ~ x ~ `, ` ~ y ~ `).texcoords);`;
    } else {
        v = `enum vertices = simple_slab(s, false, SlabTextureSlice(` ~ x ~ `, ` ~ y ~ `).texcoords);
             enum vertices_usd = simple_slab(s, true, SlabTextureSlice(` ~ x ~ `, ` ~ y ~ `).texcoords);`;
    }
    
    return  v ~ `
            if(upside_down) {
                add_template_vertices(vertices_usd, x_offset, y_offset, z_offset, 0, 0);
            } else {
                add_template_vertices(vertices, x_offset, y_offset, z_offset, 0, 0);
            }`;
}

string single_side(string cmd) {
    return 
    `static if(side == Side.ALL) {` ~
        cmd ~ `!(Side.LEFT)(block, biome_data, x_offset, y_offset, z_offset);` ~
        cmd ~ `!(Side.RIGHT)(block, biome_data, x_offset, y_offset, z_offset);` ~
        cmd ~ `!(Side.NEAR)(block, biome_data, x_offset, y_offset, z_offset);` ~
        cmd ~ `!(Side.FAR)(block, biome_data, x_offset, y_offset, z_offset);` ~
        cmd ~ `!(Side.TOP)(block, biome_data, x_offset, y_offset, z_offset);` ~
        cmd ~ `!(Side.BOTTOM)(block, biome_data, x_offset, y_offset, z_offset);` ~
    `} else {` ~
        cmd ~ `!(side)(block, biome_data, x_offset, y_offset, z_offset);` ~
    `}`;
}