precision mediump float;

attribute vec4 vertex_position; 
uniform   mat4 projection_matrix;

void main()
{
    gl_Position = projection_matrix * vertex_position;
} 