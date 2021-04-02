#import "GLTriangleView.h"

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>

#include "GLHelper.hpp"
#include <memory>

@interface GLTriangleView () {
    std::shared_ptr<GLHelper> _glHelper;
    dispatch_queue_t _decodeQueue;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (assign, nonatomic) BOOL isOnScreen;
@property (strong, nonatomic) UIImageView *rbImageView;
@end

@implementation GLTriangleView

#pragma mark - Layer Class

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initLayer];
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onTick:)];
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        [self settingContext];
        
        CGFloat scale = [UIScreen mainScreen].scale;
        _glHelper = std::make_shared<GLHelper>((int)CGRectGetWidth(frame) * scale, (int)CGRectGetHeight(frame) * scale);

        [self bindDrawableObjectToRenderBuffer];
        
        _decodeQueue = dispatch_queue_create("GLTriangleView.DecodeQueue", DISPATCH_QUEUE_SERIAL);
        self.rbImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:self.rbImageView];
    }
    return self;
}

- (void)initLayer {
    CAEAGLLayer *glLayer = (CAEAGLLayer *)self.layer;
    
    glLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking : @(YES), // retained unchange
                                   kEAGLDrawablePropertyColorFormat     : kEAGLColorFormatRGBA8 // 32-bits Color
                                   };
    
    glLayer.contentsScale = [UIScreen mainScreen].scale;
    glLayer.opaque = YES;
    
}

- (void)updateViewWithPixels:(unsigned char *)pixels width:(int)width height:(int)height byteSize:(uint64_t)byteSize {
    unsigned char *copyPixels = (unsigned char *)malloc(byteSize);
    
    uint64_t bytesPerRow = byteSize / height;
    
    // flip pixels only on x-axis
    for (int i = 0, j = height - 1; i < height && j >= 0; ++i, --j) {
        uint64_t offsetDst = bytesPerRow * i;
        uint64_t offsetSrc = bytesPerRow * j;
        memcpy(copyPixels + offsetDst, pixels + offsetSrc, bytesPerRow);
    }

    // dispatch decoding task to another queue
    dispatch_async(_decodeQueue, ^{
        CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef cgBitmapCtx = CGBitmapContextCreate(copyPixels,
                                                         width,
                                                         height,
                                                         8,
                                                         byteSize / height,
                                                         colorSpaceRef,
                                                         kCGImageAlphaPremultipliedLast);
        
        CGImageRef cgImg = CGBitmapContextCreateImage(cgBitmapCtx);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *img = [UIImage imageWithCGImage:cgImg];
            self.rbImageView.image = img;
            CGImageRelease(cgImg);
        });
        if (copyPixels) {
            free(copyPixels);
        }
        CFRelease(colorSpaceRef);
        CFRelease(cgBitmapCtx);
    });
}

- (void)onTick:(id)sender {
    [self settingContext];
    
    _glHelper->DoRender();
    
    if (self.isOnScreen) {
        [self present];
    } else {
        _glHelper->GetPixels([&](int width, int height, uint64_t byteSize, GLchar *pixels) {
            [self updateViewWithPixels:(unsigned char *)pixels width:width height:height byteSize:byteSize];
        });
    }
}

#pragma mark - Context

- (void)settingContext {
    
    [EAGLContext setCurrentContext:self.context];
    
}

- (void)bindDrawableObjectToRenderBuffer {
    
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
}

- (void)present {
    
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
    
}

@end
