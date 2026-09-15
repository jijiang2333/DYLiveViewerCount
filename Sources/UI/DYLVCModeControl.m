#import "DYLVCModeControl.h"

@implementation DYLVCModeControl

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSArray<NSString *> *titles = @[@"关闭", @"精准", @"模糊"];
        for (NSUInteger index = 0; index < titles.count; index++) {
            [self insertSegmentWithTitle:titles[index] atIndex:index animated:NO];
        }
        self.selectedSegmentIndex = 0;
        self.apportionsSegmentWidthsByContent = NO;
        self.accessibilityLabel = @"显示模式";
        [self dylvc_updateFont];
        // 保留系统控件的选中背景和触摸处理，让系统负责滑动效果。
    }
    return self;
}

- (void)dylvc_updateFont {
    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
        maximumPointSize:22.0];
    [self setTitleTextAttributes:@{NSFontAttributeName: font} forState:UIControlStateNormal];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (![previousTraitCollection.preferredContentSizeCategory
            isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        [self dylvc_updateFont];
    }
}

- (void)setDisplayMode:(DYLVCDisplayMode)mode {
    // 存储顺序是关闭、模糊、精准；界面顺序是关闭、精准、模糊。
    NSInteger index = mode == DYLVCDisplayModePrecise ? 1 :
        (mode == DYLVCDisplayModeFormatted ? 2 : 0);
    if (self.selectedSegmentIndex != index) self.selectedSegmentIndex = index;
}

- (DYLVCDisplayMode)displayMode {
    switch (self.selectedSegmentIndex) {
        case 1: return DYLVCDisplayModePrecise;
        case 2: return DYLVCDisplayModeFormatted;
        default: return DYLVCDisplayModeDisabled;
    }
}

@end
