#import <UIKit/UIKit.h>

@class GLTriangleView;
@protocol GLTriangleViewDelegate <NSObject>

- (void)onUpdate:(GLTriangleView *)triangleView readTime:(double)readTime;

@end

@interface GLTriangleView : UIView

@property (nonatomic, weak) id<GLTriangleViewDelegate> delegate;

- (void)setPBOEnable:(BOOL)pboEnable;

@end
