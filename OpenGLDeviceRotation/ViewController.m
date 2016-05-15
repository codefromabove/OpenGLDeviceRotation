//
//  ViewController.m
//  OpenGLDeviceRotation
//
//  Created by Philip Schneider on 12/6/15.
//  Copyright © 2015 Philip Schneider. All rights reserved.
//

#import "ViewController.h"
#import "GLView.h"
#import <OpenGLES/ES2/gl.h>
#import <GLKit/GLKEffects.h>

@interface ViewController ()
@property (nonatomic)                          GLuint       vertexPositionLocation;
@property (nonatomic)                          GLuint       projectionLocation;
@property (strong, nonatomic)                  EAGLContext *context;
@property (nonatomic)                          GLuint       renderBuffer;
@property (nonatomic)                          GLuint       frameBuffer;
@property (nonatomic, getter=isTransitioning)  BOOL         transitioning;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Create a context
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [self setContext:context];
    [EAGLContext setCurrentContext:context];

    [self createBuffers];
    [self compileShaders];
    [self setupDisplayLink];
}

- (void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    printf("\n");
    printf("viewWillLayoutSubviews()\n");
    printf("  Before:\n");
    [self printGLInfo];

    GLuint renderbuffer = [self renderBuffer];
    glDeleteRenderbuffers(1, &renderbuffer);

    glGenRenderbuffers(1, &renderbuffer);
    [self setRenderBuffer:renderbuffer];
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    [[self context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)[self view].layer];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);

    printf("  After:\n");
    [self printGLInfo];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [self setTransitioning:YES];

    printf("\n");
    printf("viewWillTransitionToSize()\n");
    printf("     size                   : [%.2f, %.2f]\n",     size.width, size.height);
    [self printGLInfo];

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
         UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
     } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
         printf("viewWillTransitionToSize completion\n");
         [self printGLInfo];
         [self setTransitioning:NO];
     }];

    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)createBuffers
{
    GLuint renderbuffer;
    glGenRenderbuffers(1, &renderbuffer);
    [self setRenderBuffer:renderbuffer];
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    [[self context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)[self view].layer];

    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    [self setFrameBuffer:framebuffer];
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);
}

- (void)compileShaders
{
    // Read vertex shader source
    NSString *vertexShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VertexShader" ofType:@"vsh"]
                                                             encoding:NSUTF8StringEncoding
                                                                error:nil];
    const char *vertexShaderSourceCString = [vertexShaderSource cStringUsingEncoding:NSUTF8StringEncoding];

    // Create and compile vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSourceCString, NULL);
    glCompileShader(vertexShader);

    // Read fragment shader source
    NSString *fragmentShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"FragmentShader" ofType:@"fsh"]
                                                               encoding:NSUTF8StringEncoding
                                                                  error:nil];
    const char *fragmentShaderSourceCString = [fragmentShaderSource cStringUsingEncoding:NSUTF8StringEncoding];

    // Create and compile fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSourceCString, NULL);
    glCompileShader(fragmentShader);

    // Create and link program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);

    // Use program
    glUseProgram(program);

    // Shader locations
    GLuint vertexPositionLocation = glGetAttribLocation(program, "vertex_position");
    [self setVertexPositionLocation:vertexPositionLocation];
    glEnableVertexAttribArray([self vertexPositionLocation]);

    GLuint projectionLocation = glGetUniformLocation(program, "projection_matrix");
    [self setProjectionLocation:projectionLocation];
}

- (void)setupDisplayLink
{
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self
                                                             selector:@selector(render:)];

//    [displayLink setFrameInterval:60];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                      forMode:NSDefaultRunLoopMode];
}


// http://stackoverflow.com/questions/18690950/how-to-avoid-momentary-stretching-on-autorotation-of-ios-opengl-es-apps
- (void)render:(CADisplayLink*)displayLink
{
    GLView *glView = (GLView *)self.view;

    if ([self isTransitioning]) {
        printf("\nrender:\n");

        [self printGLInfo];

        CALayer *presentationLayer      = [self.view.layer presentationLayer];
        CGSize   presentationLayerSize  = presentationLayer.bounds.size;
        GLfloat  presentationLayerRatio = presentationLayerSize.width / presentationLayerSize.height;
        printf("     presentationLayerSize  : [%.2f, %.2f]\n",     presentationLayerSize.width, presentationLayerSize.height);
        printf("     presentationLayerRatio : %.2f\n", presentationLayerRatio);

        // Set the viewport
        glViewport(0, 0, glView.frame.size.width, glView.frame.size.height);

        GLfloat widthRatio  = presentationLayerSize.width/glView.frame.size.width;
        GLfloat heightRatio = presentationLayerSize.height/glView.frame.size.height;

        // Set projection matrix (ortho)
        GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1, 1, 0, 100);

#if 1
        GLfloat ratio = glView.frame.size.width/glView.frame.size.height;

        if (ratio <= 1) {
            projectionMatrix = GLKMatrix4MakeOrtho(-1*widthRatio, 1*widthRatio,
                                                   -1/ratio * heightRatio, 1/ratio * heightRatio, 0, 100);
        }
        else {
            projectionMatrix = GLKMatrix4MakeOrtho(-1*ratio* widthRatio, 1*ratio * widthRatio,
                                                   -1*heightRatio, 1*heightRatio, 0, 100);
        }
#endif

#if 0
        GLfloat ratio = glView.frame.size.width/glView.frame.size.height;

        GLfloat ratioRatio = ratio/presentationLayerRatio;
        if (ratio <= 1) {
            projectionMatrix = GLKMatrix4MakeOrtho(-1*ratioRatio, 1*ratioRatio,
                                                   -1/ratio * ratioRatio, 1/ratio * ratioRatio, 0, 100);
        }
        else {
            projectionMatrix = GLKMatrix4MakeOrtho(-1*ratio/ ratioRatio, 1*ratio / ratioRatio,
                                                   -1/ratioRatio, 1/ratioRatio, 0, 100);
        }
#endif

#if 0
        GLfloat ratio = presentationLayerRatio;
        if (ratio <= 1) {
            projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1/ratio, 1/ratio, 0, 100);
        }
        else {
            projectionMatrix = GLKMatrix4MakeOrtho(-1*ratio, 1*ratio, -1, 1, 0, 100);
        }

#endif


        glUniformMatrix4fv([self projectionLocation], 1, 0, (const float *)&projectionMatrix);

        // Clear
        glClearColor(0.5, 0.5, 0.5, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        // Define geometry
        GLfloat square[] = {
            -0.5, -0.5,
            0.5, -0.5,
            -0.5,  0.5,
            0.5,  0.5
        };

        // Draw
        glVertexAttribPointer([self vertexPositionLocation], 2, GL_FLOAT, GL_FALSE, 0, square);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        // Present renderbuffer
        [[self context] presentRenderbuffer:GL_RENDERBUFFER];

    }
    else {
        // Set the viewport
        glViewport(0, 0, glView.frame.size.width, glView.frame.size.height);

        // Set projection matrix (ortho)
        GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1, 1, 0, 100);

        GLfloat ratio = glView.frame.size.width/glView.frame.size.height;
        if (ratio <= 1) {
            projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1/ratio, 1/ratio, 0, 100);
        }
        else {
            projectionMatrix = GLKMatrix4MakeOrtho(-1*ratio, 1*ratio, -1, 1, 0, 100);
        }
        glUniformMatrix4fv([self projectionLocation], 1, 0, (const float *)&projectionMatrix);

        // Clear
        glClearColor(0.5, 0.5, 0.5, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        // Define geometry
        GLfloat square[] = {
            -0.5, -0.5,
            0.5, -0.5,
            -0.5,  0.5,
            0.5,  0.5
        };

        // Draw
        glVertexAttribPointer([self vertexPositionLocation], 2, GL_FLOAT, GL_FALSE, 0, square);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        // Present renderbuffer
        [[self context] presentRenderbuffer:GL_RENDERBUFFER];

    }

}

- (void)printGLInfo
{
    CGSize viewBoundsSize;
    CGSize viewFrameSize;
    CGSize layerBoundsSize;
    CGSize layerFrameSize;
    GLint  backingWidth;
    GLint  backingHeight;
    GLint  viewport[4];

    viewBoundsSize  = self.view.bounds.size;
    viewFrameSize   = self.view.frame.size;
    layerBoundsSize = self.view.layer.bounds.size;
    layerFrameSize  = self.view.layer.frame.size;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH,  &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    glGetIntegerv(GL_VIEWPORT, viewport);

    printf("     viewBoundsSize         : [%.2f, %.2f]\n",     viewBoundsSize.width,  viewBoundsSize.height);
    printf("     viewFrameSize          : [%.2f, %.2f]\n",     viewFrameSize.width,   viewFrameSize.height);
    printf("     layerBoundsSize        : [%.2f, %.2f]\n",     layerBoundsSize.width, layerBoundsSize.height);
    printf("     layerFrameSize         : [%.2f, %.2f]\n",     layerFrameSize.width,   layerFrameSize.height);
    printf("     viewport               : [%d, %d, %d, %d]\n", viewport[0], viewport[1], viewport[2], viewport[3]);
    printf("     backingWidth & height  : %d %d\n",            backingWidth, backingHeight);
}

@end
