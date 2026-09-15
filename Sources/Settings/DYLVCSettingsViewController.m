#import "DYLVCSettingsViewController.h"
#import "DYLVCSettings.h"
#import "../Core/DYLVCCore.h"
#import "../UI/DYLVCModeControl.h"
#import "../UI/DYLVCRefreshIntervalView.h"

// 横向拖动交给原生控件，纵向仍可滚动整个设置页。
@interface DYLVCSettingsScrollView : UIScrollView
@end

@implementation DYLVCSettingsScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    for (UIView *candidate = view; candidate && candidate != self; candidate = candidate.superview) {
        if ([candidate isKindOfClass:UISegmentedControl.class] ||
            [candidate isKindOfClass:UISlider.class]) return NO;
    }
    return [super touchesShouldCancelInContentView:view];
}

@end

@interface DYLVCSettingsViewController ()
@property (nonatomic, strong) DYLVCModeControl *modeControl;
@property (nonatomic, strong) DYLVCRefreshIntervalView *intervalView;
@property (nonatomic, assign) BOOL navigationBarWasHidden;
@property (nonatomic, assign) BOOL hasNavigationAppearance;
@property (nonatomic, assign) UIUserInterfaceStyle previousNavigationStyle;
@property (nonatomic, strong) UIColor *previousNavigationTint;
@end

@implementation DYLVCSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"直播观众数";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.view.tintColor = UIColor.systemBlueColor;

    DYLVCSettingsScrollView *scroll = [DYLVCSettingsScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.delaysContentTouches = NO;
    [self.view addSubview:scroll];

    UIStackView *content = [UIStackView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 12.0;
    [scroll addSubview:content];

    UIView *displayCard = [UIView new];
    displayCard.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    displayCard.layer.cornerRadius = 16.0;
    displayCard.layer.cornerCurve = kCACornerCurveContinuous;
    displayCard.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(16, 16, 16, 16);
    UILabel *title = [UILabel new];
    title.text = @"显示设置";
    title.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:[UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
        maximumPointSize:24.0];
    title.adjustsFontForContentSizeCategory = YES;
    title.numberOfLines = 1;
    title.textColor = UIColor.labelColor;
    title.accessibilityTraits |= UIAccessibilityTraitHeader;

    self.modeControl = [[DYLVCModeControl alloc] initWithFrame:CGRectZero];
    [self.modeControl.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
    [self.modeControl addTarget:self action:@selector(modeChanged:)
              forControlEvents:UIControlEventValueChanged];

    UILabel *modeDescription = [UILabel new];
    modeDescription.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    modeDescription.adjustsFontForContentSizeCategory = YES;
    modeDescription.numberOfLines = 0;
    modeDescription.textColor = UIColor.secondaryLabelColor;
    // 文案固定，切换选项时卡片不会改变高度、挤动下方滑块。
    modeDescription.text = @"在推荐页直播卡片上显示在线人数\n精准：12345 人 · 模糊：1.2万 人";

    UIStackView *displayContent = [[UIStackView alloc] initWithArrangedSubviews:@[
        title, self.modeControl, modeDescription
    ]];
    displayContent.translatesAutoresizingMaskIntoConstraints = NO;
    displayContent.axis = UILayoutConstraintAxisVertical;
    displayContent.spacing = 12.0;
    [displayCard addSubview:displayContent];
    UILayoutGuide *displayMargins = displayCard.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [displayContent.topAnchor constraintEqualToAnchor:displayMargins.topAnchor],
        [displayContent.leadingAnchor constraintEqualToAnchor:displayMargins.leadingAnchor],
        [displayContent.trailingAnchor constraintEqualToAnchor:displayMargins.trailingAnchor],
        [displayContent.bottomAnchor constraintEqualToAnchor:displayMargins.bottomAnchor]
    ]];
    [content addArrangedSubview:displayCard];

    self.intervalView = [[DYLVCRefreshIntervalView alloc] initWithFrame:CGRectZero];
    [content addArrangedSubview:self.intervalView];

    UIButton *about = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = @"关于插件";
    configuration.subtitle = @"DYLiveViewerCount · 1.0-1";
    configuration.image = [UIImage systemImageNamed:@"info.circle"];
    configuration.imagePadding = 12.0;
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(14, 16, 14, 16);
    configuration.baseForegroundColor = UIColor.secondaryLabelColor;
    about.configuration = configuration;
    about.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [about addTarget:self action:@selector(showAbout) forControlEvents:UIControlEventTouchUpInside];
    [about.heightAnchor constraintGreaterThanOrEqualToConstant:60.0].active = YES;
    [content addArrangedSubview:about];

    NSLayoutConstraint *preferredWidth = [content.widthAnchor
        constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32.0];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16.0],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24.0],
        [scroll.contentLayoutGuide.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
        [content.centerXAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.centerXAnchor],
        [content.widthAnchor constraintLessThanOrEqualToConstant:560.0],
        [content.widthAnchor constraintLessThanOrEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32.0],
        preferredWidth
    ]];

    NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
    [notifications addObserver:self selector:@selector(reloadSettings) name:DYLVCSettingsDidChangeNotification object:nil];
    [notifications addObserver:self selector:@selector(updateTheme) name:DYLVCThemeDidChangeNotification object:nil];
    [notifications addObserver:self selector:@selector(applicationDidBecomeActive)
        name:UIApplicationDidBecomeActiveNotification object:nil];
    [self updateTheme];
    [self reloadSettings];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationBarWasHidden = self.navigationController.navigationBarHidden;
    self.previousNavigationStyle = self.navigationController.navigationBar.overrideUserInterfaceStyle;
    self.previousNavigationTint = self.navigationController.navigationBar.tintColor;
    self.hasNavigationAppearance = YES;
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    DYLVCInstallThemeHooks();
    [self updateTheme];
    [self reloadSettings];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.hasNavigationAppearance) {
        self.hasNavigationAppearance = NO;
        self.navigationController.navigationBar.overrideUserInterfaceStyle = self.previousNavigationStyle;
        self.navigationController.navigationBar.tintColor = self.previousNavigationTint;
    }
    if (self.navigationBarWasHidden) [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)applicationDidBecomeActive {
    DYLVCInstallThemeHooks();
    [self updateTheme];
    [self reloadSettings];
}

- (void)updateTheme {
    UIUserInterfaceStyle style = DYLVCUserInterfaceStyle();
    if (self.overrideUserInterfaceStyle != style) self.overrideUserInterfaceStyle = style;
    UITraitCollection *theme = [UITraitCollection traitCollectionWithUserInterfaceStyle:style];
    // 宿主导航栏不是本页子视图，需要单独同步；离开本页时恢复之前的样式。
    if (self.hasNavigationAppearance) {
        UINavigationBar *bar = self.navigationController.navigationBar;
        if (bar.overrideUserInterfaceStyle != style) bar.overrideUserInterfaceStyle = style;
        bar.tintColor = [UIColor.labelColor resolvedColorWithTraitCollection:theme];
    }
    if (self.navigationController.viewControllers.firstObject == self &&
        self.navigationController.overrideUserInterfaceStyle != style) {
        self.navigationController.overrideUserInterfaceStyle = style;
    }
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithDefaultBackground];
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor.labelColor resolvedColorWithTraitCollection:theme]
    };
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    self.presentedViewController.overrideUserInterfaceStyle = style;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.isViewLoaded) [self updateTheme];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return DYLVCUserInterfaceStyle() == UIUserInterfaceStyleDark ?
        UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent;
}

- (void)reloadSettings {
    self.modeControl.displayMode = [DYLVCSettings sharedInstance].displayMode;
    [self.intervalView reloadSettings];
}

- (void)modeChanged:(DYLVCModeControl *)control {
    DYLVCSettings *settings = [DYLVCSettings sharedInstance];
    if (settings.displayMode != control.displayMode) settings.displayMode = control.displayMode;
    [self.intervalView reloadSettings];
}

- (void)showAbout {
    if (self.presentedViewController) return;
    NSString *repository = @"https://github.com/jijiang2333/DYLiveViewerCount";
    NSString *message = [NSString stringWithFormat:
        @"版本：1.0-1\n作者：jijiang2333\n\n在推荐页直播卡片外显示实时在线人数\n\n%@", repository];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"关于 DYLiveViewerCount"
        message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = DYLVCUserInterfaceStyle();
    [alert addAction:[UIAlertAction actionWithTitle:@"打开 GitHub 仓库" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *action) {
            [UIApplication.sharedApplication openURL:[NSURL URLWithString:repository] options:@{} completionHandler:nil];
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
