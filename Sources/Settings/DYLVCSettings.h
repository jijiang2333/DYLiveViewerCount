#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const DYLVCSettingsDidChangeNotification;

// 显示模式：关闭、模糊（如 1.2万）或精准（如 12345）
typedef NS_ENUM(NSInteger, DYLVCDisplayMode) {
    DYLVCDisplayModeDisabled = 0,
    DYLVCDisplayModeFormatted = 1,
    DYLVCDisplayModePrecise = 2
};

enum {
    DYLVCMinimumRefreshInterval = 2,
    DYLVCDefaultRefreshInterval = 3,
    DYLVCMaximumRefreshInterval = 10
};

@interface DYLVCSettings : NSObject

// 获取单例
+ (instancetype)sharedInstance;

// 功能是否启用
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;

// 显示模式
- (DYLVCDisplayMode)displayMode;
- (void)setDisplayMode:(DYLVCDisplayMode)mode;

- (NSInteger)refreshInterval;
- (void)setRefreshInterval:(NSInteger)seconds;

@end

NS_ASSUME_NONNULL_END
