//
//  ViewController.m
//  GLReadPixelsWithPBO
//
//  Created by forrestlin on 2021/4/1.
//

#import "ViewController.h"
#import "GLTriangleView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    GLTriangleView *triangleView = [[GLTriangleView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:triangleView];
}


@end
