#import "DYLVCRefreshIntervalView.h"
#import "../Settings/DYLVCSettings.h"
#import <math.h>

// 只补充按秒调整的无障碍操作，滑块外观和手势交给系统处理。
@interface DYLVCIntervalSlider : UISlider
@end

@implementation DYLVCIntervalSlider

- (void)adjustAccessibilityInterval:(NSInteger)delta {
    if (!self.enabled) return;
    float value = MAX(self.minimumValue, MIN(self.maximumValue, lroundf(self.value) + delta));
    if (value == self.value) return;
    [self setValue:value animated:NO];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)accessibilityIncrement {
    [self adjustAccessibilityInterval:1];
}

- (void)accessibilityDecrement {
    [self adjustAccessibilityInterval:-1];
}

@end

@interface DYLVCRefreshIntervalView ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *minimumLabel;
@property (nonatomic, strong) UILabel *maximumLabel;
@property (nonatomic, strong) DYLVCIntervalSlider *slider;
@property (nonatomic, strong) UISelectionFeedbackGenerator *feedback;
@property (nonatomic, assign) NSInteger previewInterval;
@end

@implementation DYLVCRefreshIntervalView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.layer.cornerRadius = 16.0;
        self.layer.cornerCurve = kCACornerCurveContinuous;
        self.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 16, 14, 16);
        self.feedback = [UISelectionFeedbackGenerator new];

        self.titleLabel = [UILabel new];
        self.titleLabel.text = @"刷新间隔";
        self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
            scaledFontForFont:[UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
            maximumPointSize:24.0];
        self.titleLabel.adjustsFontForContentSizeCategory = YES;
        self.titleLabel.numberOfLines = 1;
        self.titleLabel.textColor = UIColor.labelColor;
        self.titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
        [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                       forAxis:UILayoutConstraintAxisHorizontal];

        self.valueLabel = [UILabel new];
        self.valueLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
            scaledFontForFont:[UIFont monospacedDigitSystemFontOfSize:17.0 weight:UIFontWeightMedium]
            maximumPointSize:24.0];
        self.valueLabel.adjustsFontForContentSizeCategory = YES;
        self.valueLabel.textAlignment = NSTextAlignmentRight;
        [self.valueLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                       forAxis:UILayoutConstraintAxisHorizontal];

        UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.valueLabel]];
        heading.alignment = UIStackViewAlignmentFirstBaseline;
        heading.spacing = 12.0;

        self.slider = [[DYLVCIntervalSlider alloc] initWithFrame:CGRectZero];
        self.slider.minimumValue = DYLVCMinimumRefreshInterval;
        self.slider.maximumValue = DYLVCMaximumRefreshInterval;
        self.slider.continuous = YES;
        self.slider.accessibilityLabel = @"刷新间隔";
        [self.slider.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
        [self.slider addTarget:self action:@selector(intervalBegan:)
             forControlEvents:UIControlEventTouchDown];
        [self.slider addTarget:self action:@selector(intervalChanged:)
             forControlEvents:UIControlEventValueChanged];
        [self.slider addTarget:self action:@selector(intervalCommitted:)
             forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.slider addTarget:self action:@selector(intervalCancelled:)
             forControlEvents:UIControlEventTouchCancel];

        self.minimumLabel = [UILabel new];
        self.minimumLabel.text = [NSString stringWithFormat:@"%d 秒", DYLVCMinimumRefreshInterval];
        self.maximumLabel = [UILabel new];
        self.maximumLabel.text = [NSString stringWithFormat:@"%d 秒", DYLVCMaximumRefreshInterval];
        self.maximumLabel.textAlignment = NSTextAlignmentRight;
        for (UILabel *label in @[self.minimumLabel, self.maximumLabel]) {
            label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
            label.adjustsFontForContentSizeCategory = YES;
            label.textColor = UIColor.secondaryLabelColor;
        }
        UIStackView *range = [[UIStackView alloc] initWithArrangedSubviews:@[self.minimumLabel, self.maximumLabel]];
        range.distribution = UIStackViewDistributionFillEqually;

        UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[heading, self.slider, range]];
        content.axis = UILayoutConstraintAxisVertical;
        content.spacing = 6.0;
        content.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:content];
        UILayoutGuide *margins = self.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [content.topAnchor constraintEqualToAnchor:margins.topAnchor],
            [content.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
            [content.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
            [content.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor]
        ]];
        self.accessibilityElements = @[self.titleLabel, self.slider];
        [self reloadSettings];
    }
    return self;
}

- (NSInteger)roundedInterval {
    return MAX(DYLVCMinimumRefreshInterval, MIN(DYLVCMaximumRefreshInterval, (NSInteger)lroundf(self.slider.value)));
}

- (void)updateValueLabel {
    NSString *value = [NSString stringWithFormat:@"%ld 秒", (long)self.previewInterval];
    self.valueLabel.text = value;
    self.slider.accessibilityValue = value;
}

- (void)reloadSettings {
    DYLVCSettings *settings = [DYLVCSettings sharedInstance];
    BOOL enabled = settings.displayMode != DYLVCDisplayModeDisabled;
    if (!enabled && self.slider.isTracking) [self.slider cancelTrackingWithEvent:nil];
    self.slider.enabled = enabled;
    if (!enabled || !self.slider.isTracking) {
        self.previewInterval = settings.refreshInterval;
        if (self.slider.value != (float)self.previewInterval) {
            [self.slider setValue:(float)self.previewInterval animated:NO];
        }
        [self updateValueLabel];
    }
    self.valueLabel.textColor = enabled ? UIColor.labelColor : UIColor.tertiaryLabelColor;
    self.minimumLabel.textColor = enabled ? UIColor.secondaryLabelColor : UIColor.tertiaryLabelColor;
    self.maximumLabel.textColor = self.minimumLabel.textColor;
    self.slider.accessibilityHint = enabled ? @"每次调整一秒" : @"选择精准或模糊模式后可调整";
}

- (void)intervalBegan:(UISlider *)slider {
    [self.feedback prepare];
}

- (void)intervalChanged:(UISlider *)slider {
    if (!slider.enabled) return;
    NSInteger interval = [self roundedInterval];
    if (interval != self.previewInterval && slider.isTracking) {
        [self.feedback selectionChanged];
        [self.feedback prepare];
    }
    self.previewInterval = interval;
    [self updateValueLabel];
    // 拖动时只更新读数，避免设置通知或吸附动画打断系统滑块；无障碍调整立即保存。
    if (!slider.isTracking) [self intervalCommitted:slider];
}

- (void)intervalCommitted:(UISlider *)slider {
    DYLVCSettings *settings = [DYLVCSettings sharedInstance];
    if (!slider.enabled || settings.displayMode == DYLVCDisplayModeDisabled) {
        [self reloadSettings];
        return;
    }
    self.previewInterval = [self roundedInterval];
    [self updateValueLabel];
    [slider setValue:(float)self.previewInterval animated:!UIAccessibilityIsReduceMotionEnabled()];
    if (settings.refreshInterval != self.previewInterval) settings.refreshInterval = self.previewInterval;
}

- (void)intervalCancelled:(UISlider *)slider {
    self.previewInterval = [DYLVCSettings sharedInstance].refreshInterval;
    [slider setValue:(float)self.previewInterval animated:NO];
    [self updateValueLabel];
}

@end
