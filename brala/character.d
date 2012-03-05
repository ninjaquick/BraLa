module brala.character;

private {
    import gl3n.linalg : vec3, quat;
    
    import brala.camera : FreeCamera;
}

class Character : FreeCamera { // the one you're playing
    int entity_id;
    
    this(int entity_id) {
        this.entity_id = entity_id;
        forward = vec3(0.0f, 0.0f, 1.0f);
    }
       
    void set_rotation(float yaw, float pitch, float roll = 0) {
        quat rotation = quat.euler_rotation(yaw, pitch, 0);
        forward = vec3(rotation.to_matrix!(3, 3) * vec3(0.0f, 0.0f, 1.0f)).normalized; // z+1 = 0° yaw
    }
}