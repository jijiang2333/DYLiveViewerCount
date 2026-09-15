#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const DYLVCThemeDidChangeNotification;
FOUNDATION_EXPORT UIWindow * _Nullable DYLVCActiveWindow(void);
FOUNDATION_EXPORT UIUserInterfaceStyle DYLVCUserInterfaceStyle(void);
FOUNDATION_EXPORT void DYLVCInstallThemeHooks(void);

@interface DYLVCColorScheme : NSObject

// 获取当前主题的背景色（半透明）
+ (UIColor *)badgeBackgroundColor;

// 获取当前主题的文字颜色
+ (UIColor *)badgeTextColor;

// 获取当前主题的边框颜色（可选）
+ (UIColor *)badgeBorderColor;

@end

@interface DYLVCFormatter : NSObject

// 格式化人数（模糊模式：12345 -> 1.2万）
+ (NSString *)formatViewerCount:(long long)count;

// 精准模式：显示完整数字（12345 -> 12345）
+ (NSString *)preciseViewerCount:(long long)count;

@end

NS_ASSUME_NONNULL_END
