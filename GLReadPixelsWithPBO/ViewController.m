//
//  ViewController.m
//  GLReadPixelsWithPBO
//
//  Created by forrestlin on 2021/4/1.
//

#import "ViewController.h"
#import "GLTriangleView.h"
#import <mach/mach.h>

@interface ViewController () <GLTriangleViewDelegate>

@property (weak, nonatomic) IBOutlet UILabel *cpuUsage;
@property (weak, nonatomic) IBOutlet UILabel *memoryUsage;
@property (weak, nonatomic) IBOutlet UILabel *timeCostUsage;
@property (weak, nonatomic) IBOutlet UIButton *PBOEnableButton;
@property (nonatomic, assign) BOOL enablePBO;
@property (nonatomic, strong) GLTriangleView *triangleView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.triangleView = [[GLTriangleView alloc] initWithFrame:self.view.bounds];
    self.triangleView.delegate = self;
    [self.view insertSubview:self.triangleView atIndex:0];
    self.enablePBO = NO;
    [self setPBOButtonTitle];
}

- (IBAction)changePBOMode:(id)sender {
    _enablePBO = !_enablePBO;
    [self setPBOButtonTitle];
}

- (void)setPBOButtonTitle {
    [_PBOEnableButton setTitle:_enablePBO ? @"With PBO": @"Without PBO" forState:UIControlStateNormal];
    [self.triangleView setPBOEnable:_enablePBO];
}

#pragma mark - GLTriangleViewDelegate
- (void)onUpdate:(GLTriangleView *)triangleView readTime:(double)readTime {
    float currentCPUUsage = tt_cpu_usage();
    self.cpuUsage.text = [NSString stringWithFormat:@"CPU:%.1f%%", currentCPUUsage];
    
    float memoryUsage = tt_memory_usage_phy();
    self.memoryUsage.text = [NSString stringWithFormat:@"Memory:%.1fMB", memoryUsage];
    
    self.timeCostUsage.text = [NSString stringWithFormat:@"ReadTime:%.1fms", readTime];
}

float tt_cpu_usage()
{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;
    
    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;
    
    for (j = 0; j < thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
        
    } // for each thread
    
    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    if (kr != KERN_SUCCESS) {
        NSLog(@"Failed to get CPU usage, kr = %d", kr);
    }
    
    return tot_cpu;
}

double tt_memory_usage()
{
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount = sizeof(task_basic_info_data_t);
    kern_return_t kernReturn = task_info(mach_task_self(),
                                         TASK_BASIC_INFO, (task_info_t)&taskInfo, &infoCount);
    if (kernReturn != KERN_SUCCESS) {
        return -1;
    }
    double resident_size = taskInfo.resident_size / 1024.0 / 1024.0;
    return resident_size;
}

double tt_memory_usage_phy() {
    double memoryUsageInByte = -1;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kernelReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if(kernelReturn == KERN_SUCCESS) {
        memoryUsageInByte = vmInfo.phys_footprint / 1024.0 / 1024.0;
    }
    return memoryUsageInByte;
}


@end
