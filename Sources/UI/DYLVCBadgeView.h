#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYLVCBadgeView : UIView

// 设置观众数（已格式化的字符串）
- (void)setViewerCountString:(NSString *)countString;

// 更新主题适配（主题环境变化时调用）
- (void)updateTheme;

@end

NS_ASSUME_NONNULL_END
