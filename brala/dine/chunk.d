module brala.dine.chunk;

private {
    import glamour.gl : GLuint, GLenum;
    import glamour.vbo : Buffer;
    
    import std.bitmanip : bitfields;
    import std.string : format, capitalize;
    
    import gl3n.linalg : vec3i;
    import brala.dine.util : log2_ub;
    import brala.dine.builder.blocks : BLOCKS;
    import brala.dine.builder.biomes : DEFAULT_BIOMES, Biome;
    import brala.utils.memory : calloc, free;
}


struct Block {   
    mixin(bitfields!(uint, "id", 12,
                     ubyte, "metadata", 4,
                     ubyte, "block_light", 4,
                     ubyte, "sky_light", 4,
                     ubyte, "", 8));  // padding

    this(uint id) {
        this.id = id;
    }
                     
    this(uint id, ubyte metadata) {
        this.id = id;
        this.metadata = metadata;
    }
                     
    bool opEquals(const ref Block other) const {
        return other.id == id && other.metadata == metadata;
    }
    
    bool opEquals(const int id) const {
        return id == this.id;
    }

    string toString() const {
        return `Block(id : %s (%s), metadata : %s, block_light : %s, sky_light : %s)`
                .format(id, BLOCKS[id].name.capitalize(), metadata, block_light, sky_light);
    }
}

// NOTE to prgrammer, ctor will maybe called from a seperate thread
// => dont do opengl stuff in the ctor
class Chunk {
    // width, height, depth must be a power of two
    const int width = 16;
    const int height = 256;
    const int depth = 16;

    const int zstep = width*height;
    const int log2width = log2_ub(width);
    const int log2height = log2_ub(height);
    const int log2depth = log2_ub(depth);
    const int log2heightwidth = log2_ub(height*width);
    
    const int block_count = width*height*depth;
    const int data_size = block_count*Block.sizeof;
    
    static Block* empty_blocks;
    
    private static this() {
        empty_blocks = cast(Block*)calloc(block_count, Block.sizeof);
    }
    
    private static ~this() {
        free(empty_blocks);
    }
    
    bool dirty;
    bool tessellated = false;

    bool empty;
    Block* blocks;
    ubyte[256] biome_data;
    ushort primary_bitmask;
    ushort add_bitmask;
    
    Buffer vbo;
    size_t vbo_vcount;
    
    protected void free_chunk() {
        if(!empty) {
            free(blocks);
        }
    }
    
    this() {
        blocks = empty_blocks;
        empty = true;
        dirty = false;
    }
    
    ~this() {
        free_chunk();
    }
    
    // Make sure you allocated *blocks with malloc,
    // the chunk will free the memory when needed.
    void fill_chunk(Block* blocks) {
        free_chunk();
        
        this.blocks = blocks;
        empty = false;
        dirty = true;
    }
    
    void fill_chunk_with_nothing() {
        free_chunk();
        
        blocks = cast(Block*)calloc(block_count, Block.sizeof);
        empty = false;
        dirty = true;
    }
    
    void empty_chunk() {
        free(blocks);
        blocks = empty_blocks;
        empty = true;
        dirty = true;
    }
    
    Block get_block(vec3i position) {
        return get_block(to_flat(position));
    }
    
    Block get_block(uint x, uint y, uint z) {
        return get_block(to_flat(x, y, z));
    }
    
    Block get_block(uint flat)
        in { assert(!empty); assert(flat < block_count); }
        body {
            return blocks[flat];
        }
    
    Block get_block_safe(vec3i position) {
        return get_block_safe(position.x, position.y, position.z);
    }
    
    Block get_block_safe(int x, int y, int z) {
        if(x >= 0 && x < width && y >= 0 && y < height && z >= 0 && z < depth) {
            return get_block(to_flat(x, y, z));
        } else {
            return Block(0, 0);
        }
    }

    Biome get_biome(int column) {
        return cast(Biome)biome_data[column];
    }

    Biome get_biome_safe(int column) {
        if(column < biome_data.length && biome_data[column] < DEFAULT_BIOMES.length) {
            return cast(Biome)biome_data[column];
        } else {
            return cast(Biome)0;
        }
    }
        
    // operator overloading
    Block opIndex(size_t flat)
    in { assert(!empty); assert(flat < block_count); }
    body {
        return blocks[flat];
    }
    
    Block opIndex(vec3i position)
        in { assert(!empty); }
        body {
            return blocks[to_flat(position)];
        }
    
    void opIndexAssign(Block value, size_t flat)
        in { assert(!empty); assert(flat < block_count); }
        body {
            blocks[flat] = value;
            dirty = true;
        }
        
    void opIndexAssign(Block value, vec3i position)
        in { assert(!empty); }
        body {
            blocks[to_flat(position)] = value;
            dirty = true;
        }
    
    int opApply(int delegate(const ref Block) dg)
        in { assert(!empty); }
        body {
            int result;
            
            foreach(b; 0..block_count) {
                result = dg(blocks[b]);
                if(result) break;
            }
            
            return result;
        }
    
    int opApply(int delegate(size_t, const ref Block) dg)
        in { assert(!empty); }
        body {
            int result;
            
            foreach(b; 0..block_count) {
                result = dg(b, blocks[b]);
                if(result) break;
            }
            
            return result;
        }
         
    // static stuff
    static int to_flat(vec3i inp) {
        return to_flat(inp.x, inp.y, inp.z);
    }
    
    static int to_flat(int x, int y, int z)
        in { assert(x >= 0 && x < width && y >= 0 && y < height && z >= 0 && z < depth); }
        out (result) { assert(result < block_count); }
        body {
            return x + y*width + z*zstep;
        }
    
    static vec3i from_flat(int flat)
        in { assert(flat < block_count); }
        out (result) { assert(result.vector[0] < width && result.vector[1] < height && result.vector[2] < depth); }
        body {
            return vec3i(flat & (width-1), // x: flat % width
                        (flat >> log2width) & (height-1), // y: (flat / width) % height
                         flat >> log2heightwidth); // z: flat / (height*width)
        }
}