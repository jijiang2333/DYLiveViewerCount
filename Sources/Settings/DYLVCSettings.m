#import "DYLVCSettings.h"
#import <math.h>

NSNotificationName const DYLVCSettingsDidChangeNotification = @"DYLVCSettingsDidChangeNotification";

static void DYLVCPostSettingsChanged(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DYLVCSettingsDidChangeNotification object:nil];
    });
}

static NSString *const kDYLVCEnabledKey = @"DYLVCEnabled";
static NSString *const kDYLVCDisplayModeKey = @"DYLVCDisplayMode";
static NSString *const kDYLVCDisplayModeVersionKey = @"DYLVCDisplayModeVersion";
static NSString *const kDYLVCRefreshIntervalKey = @"DYLVCRefreshInterval";

@implementation DYLVCSettings

+ (instancetype)sharedInstance {
    static DYLVCSettings *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (BOOL)isEnabled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kDYLVCDisplayModeKey] != nil) {
        NSInteger mode = [defaults integerForKey:kDYLVCDisplayModeKey];
        return mode == DYLVCDisplayModeFormatted || mode == DYLVCDisplayModePrecise;
    }
    return [defaults boolForKey:kDYLVCEnabledKey];
}

- (void)setEnabled:(BOOL)enabled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:kDYLVCEnabledKey];
    if ([defaults objectForKey:kDYLVCDisplayModeKey] != nil) {
        [defaults setInteger:(enabled ? DYLVCDisplayModeFormatted : DYLVCDisplayModeDisabled)
                      forKey:kDYLVCDisplayModeKey];
    }
    DYLVCPostSettingsChanged();
}

- (DYLVCDisplayMode)displayMode {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kDYLVCDisplayModeKey] == nil) {
        return [defaults boolForKey:kDYLVCEnabledKey] ? DYLVCDisplayModeFormatted : DYLVCDisplayModeDisabled;
    }
    NSInteger storedMode = [defaults integerForKey:kDYLVCDisplayModeKey];
    if (![defaults boolForKey:kDYLVCDisplayModeVersionKey]) {
        // 早期版本使用 0=模糊、1=精准；首次读取时迁移到新三档值。
        if (storedMode == 1) {
            storedMode = DYLVCDisplayModePrecise;
        } else if (storedMode == 0 && [defaults boolForKey:kDYLVCEnabledKey]) {
            storedMode = DYLVCDisplayModeFormatted;
        }
        [defaults setBool:YES forKey:kDYLVCDisplayModeVersionKey];
        [defaults setInteger:storedMode forKey:kDYLVCDisplayModeKey];
    }
    if (storedMode < DYLVCDisplayModeDisabled || storedMode > DYLVCDisplayModePrecise) {
        return DYLVCDisplayModeFormatted;
    }
    return (DYLVCDisplayMode)storedMode;
}

- (void)setDisplayMode:(DYLVCDisplayMode)mode {
    if (mode < DYLVCDisplayModeDisabled || mode > DYLVCDisplayModePrecise) {
        mode = DYLVCDisplayModeFormatted;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:mode forKey:kDYLVCDisplayModeKey];
    [defaults setBool:YES forKey:kDYLVCDisplayModeVersionKey];
    [defaults setBool:(mode != DYLVCDisplayModeDisabled) forKey:kDYLVCEnabledKey];
    DYLVCPostSettingsChanged();
}

- (NSInteger)refreshInterval {
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:kDYLVCRefreshIntervalKey];
    if (![storedValue isKindOfClass:[NSNumber class]]) {
        return DYLVCDefaultRefreshInterval;
    }
    double seconds = [storedValue doubleValue];
    if (!isfinite(seconds)) {
        return DYLVCDefaultRefreshInterval;
    }
    return (NSInteger)lround(MAX(DYLVCMinimumRefreshInterval, MIN(DYLVCMaximumRefreshInterval, seconds)));
}

- (void)setRefreshInterval:(NSInteger)seconds {
    seconds = MAX(DYLVCMinimumRefreshInterval, MIN(DYLVCMaximumRefreshInterval, seconds));
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kDYLVCRefreshIntervalKey] &&
        [defaults integerForKey:kDYLVCRefreshIntervalKey] == seconds) {
        return;
    }
    [defaults setInteger:seconds forKey:kDYLVCRefreshIntervalKey];
    DYLVCPostSettingsChanged();
}

@end
