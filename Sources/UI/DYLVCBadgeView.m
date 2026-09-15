#import "DYLVCBadgeView.h"
#import <math.h>
#import "../Core/DYLVCCore.h"

@interface DYLVCBadgeView ()
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIImageView *iconView;
@end

@implementation DYLVCBadgeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = YES;
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = YES;
        self.layer.cornerRadius = 14.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 0.5;
        [self setupUI];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateTheme)
            name:DYLVCThemeDidChangeNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateTheme)
            name:UIApplicationDidBecomeActiveNotification object:nil];
        [self updateTheme];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [DYLVCColorScheme badgeBackgroundColor];
    self.layer.borderColor = [DYLVCColorScheme badgeBorderColor].CGColor;

    self.iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.tintColor = [DYLVCColorScheme badgeTextColor];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
        self.iconView.image = [[UIImage systemImageNamed:@"person.2.fill"] imageWithConfiguration:configuration];
    }
    [self addSubview:self.iconView];

    self.countLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.countLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.countLabel.textColor = [DYLVCColorScheme badgeTextColor];
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    self.countLabel.text = @"";
    self.countLabel.adjustsFontSizeToFitWidth = YES;
    self.countLabel.minimumScaleFactor = 0.8;
    [self addSubview:self.countLabel];
}

- (CGSize)intrinsicContentSize {
    CGFloat textWidth = [self.countLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20.0)].width;
    return CGSizeMake(8.0 + 12.0 + 4.0 + MAX(18.0, ceil(textWidth)) + 10.0, 28.0);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat height = CGRectGetHeight(self.bounds);
    self.layer.cornerRadius = height * 0.5;
    self.iconView.frame = CGRectMake(8.0, (height - 12.0) * 0.5, 12.0, 12.0);
    self.countLabel.frame = CGRectMake(CGRectGetMaxX(self.iconView.frame) + 4.0,
                                       1.0,
                                       MAX(18.0, CGRectGetWidth(self.bounds) - 34.0),
                                       MAX(20.0, height - 2.0));
}

- (void)setViewerCountString:(NSString *)countString {
    NSString *text = countString.length > 0 ? countString : @"0";
    if ([self.countLabel.text isEqualToString:text]) {
        return;
    }
    self.countLabel.text = text;
    self.accessibilityLabel = [NSString stringWithFormat:@"在线人数 %@", text];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)updateTheme {
    UIUserInterfaceStyle style = DYLVCUserInterfaceStyle();
    if (self.overrideUserInterfaceStyle != style) self.overrideUserInterfaceStyle = style;
    self.backgroundColor = [DYLVCColorScheme badgeBackgroundColor];
    self.layer.borderColor = [[DYLVCColorScheme badgeBorderColor]
        resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.countLabel.textColor = [DYLVCColorScheme badgeTextColor];
    self.iconView.tintColor = [DYLVCColorScheme badgeTextColor];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self updateTheme];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateTheme];
        }
    }
}

@end
