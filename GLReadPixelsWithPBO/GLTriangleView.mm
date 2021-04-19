#import "GLTriangleView.h"

#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>

#include "GLHelper.hpp"
#include <memory>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#define USE_CVPB 0

@interface GLTriangleView () {
    std::shared_ptr<GLHelper> _glHelper;
    dispatch_queue_t _decodeQueue;
    CVPixelBufferRef _renderTarget;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) CADisplayLink *displayLink;
@property (assign, nonatomic) BOOL isOnScreen;
@property (strong, nonatomic) UIImageView *rbImageView;
@end

bool transformRGBA8ToBGRA8(void *rgbaData, CGSize size, size_t bytePerRow) {
    const uint8_t permuteMap[4] = { 2, 1, 0, 3 };
    vImage_Buffer rgba8;
    vImage_Error error = kvImageNoError;
    rgba8.width = size.width;
    rgba8.height = size.height;
    rgba8.rowBytes = bytePerRow;
    rgba8.data = rgbaData;

    error = vImagePermuteChannels_ARGB8888(&rgba8, &rgba8, permuteMap, kvImageNoFlags);
    return (error == kvImageNoError);
}

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
        GLuint shareTextureID = 0;
#if USE_CVPB
        if ([GLTriangleView supportsFastTextureUpload])
        {
            CVOpenGLESTextureCacheRef coreVideoTextureCache;
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &coreVideoTextureCache);
            if (err) {
                NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate");
            }

            int width = CGRectGetWidth(frame), height = CGRectGetHeight(frame);
            
            CFDictionaryRef empty; // empty value for attr value.
            CFMutableDictionaryRef attrs;
            empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); // our empty IOSurface properties dictionary
            attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
            
            err = CVPixelBufferCreate(kCFAllocatorDefault, width * scale, height * scale, kCVPixelFormatType_32BGRA, attrs, &_renderTarget);
            
            if (err) {
                NSAssert(NO, @"Error at create pixel buffer");
            }

            int pbwidth = (int)CVPixelBufferGetWidth(_renderTarget);
            int pbheight = (int)CVPixelBufferGetHeight(_renderTarget);
            CVOpenGLESTextureRef renderTexture;
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreVideoTextureCache, _renderTarget,
                                                          NULL, // texture attributes
                                                          GL_TEXTURE_2D,
                                                          GL_RGBA, // opengl format
                                                          pbwidth,
                                                          pbheight,
                                                          GL_RGBA, // native iOS format
                                                          GL_UNSIGNED_BYTE,
                                                          0,
                                                          &renderTexture);
            if (err) {
                NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate");
            }

            shareTextureID = CVOpenGLESTextureGetName(renderTexture);
            CFRelease(attrs);
            CFRelease(empty);
        }
#endif
        _glHelper = std::make_shared<GLHelper>((int)CGRectGetWidth(frame) * scale, (int)CGRectGetHeight(frame) * scale, shareTextureID);

        [self bindDrawableObjectToRenderBuffer];
        
        _decodeQueue = dispatch_queue_create("GLTriangleView.DecodeQueue", DISPATCH_QUEUE_SERIAL);
        self.rbImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:self.rbImageView];
    }
    return self;
}

- (void)setPBOEnable:(BOOL)pboEnable {
    _glHelper->SetPBOEnable(pboEnable);
}

#pragma mark -
#pragma mark Manage fast texture upload
+ (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}

- (void)initLayer {
    CAEAGLLayer *glLayer = (CAEAGLLayer *)self.layer;
    
    glLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking : @(YES), // retained unchange
                                   kEAGLDrawablePropertyColorFormat     : kEAGLColorFormatRGBA8 // 32-bits Color
                                   };
    
    glLayer.contentsScale = [UIScreen mainScreen].scale;
    glLayer.opaque = YES;
    
}

- (void)updateViewWithPixels:(unsigned char *)pixels width:(int)width height:(int)height byteSize:(uint64_t)byteSize bytesPerRow:(size_t)bytesPerRow {
    unsigned char *copyPixels = (unsigned char *)malloc(byteSize);
    
//    uint64_t bytesPerRow = byteSize / height;
    
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
                                                         bytesPerRow,
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
#if USE_CVPB
        CGFloat beginTime = CFAbsoluteTimeGetCurrent();
        if (kCVReturnSuccess == CVPixelBufferLockBaseAddress(_renderTarget, kCVPixelBufferLock_ReadOnly)) {
            uint8_t *pixels = (uint8_t *)CVPixelBufferGetBaseAddress(_renderTarget);
            CGFloat scale = [UIScreen mainScreen].scale;
            int width = CVPixelBufferGetWidth(_renderTarget), height = CVPixelBufferGetHeight(_renderTarget);
            size_t bytesPerRow = CVPixelBufferGetBytesPerRow(_renderTarget);
            size_t byteSize = CVPixelBufferGetDataSize(_renderTarget);
            [self updateViewWithPixels:(unsigned char *)pixels width:width height:height byteSize:byteSize bytesPerRow:bytesPerRow];
            CVPixelBufferUnlockBaseAddress(_renderTarget, kCVPixelBufferLock_ReadOnly);
            
            CGFloat readTime = (CFAbsoluteTimeGetCurrent() - beginTime) * 100;
            if ([self.delegate respondsToSelector:@selector(onUpdate:readTime:)]) {
                [self.delegate onUpdate:self readTime:readTime];
            }
            
        }
#else
        _glHelper->GetPixels([&](int width, int height, uint64_t byteSize, GLchar *pixels, double readTime) {
            [self updateViewWithPixels:(unsigned char *)pixels width:width height:height byteSize:byteSize bytesPerRow:byteSize / height];
            if ([self.delegate respondsToSelector:@selector(onUpdate:readTime:)]) {
                [self.delegate onUpdate:self readTime:readTime];
            }
        });
#endif
        
    }
}

#pragma mark - Context

- (void)settingContext {
    
    [EAGLContext setCurrentContext:self.context];
    
}

- (void)bindDrawableObjectToRenderBuffer {
    
//    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
}

- (void)present {
    
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
    
}

@end
