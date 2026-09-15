#import "DYLVCCore.h"
#import <objc/message.h>
#import <objc/runtime.h>

NSNotificationName const DYLVCThemeDidChangeNotification = @"DYLVCThemeDidChangeNotification";

UIWindow *DYLVCActiveWindow(void) {
    UIWindow *candidate = nil;
    UIApplication *application = UIApplication.sharedApplication;
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            (scene.activationState != UISceneActivationStateForegroundActive &&
             scene.activationState != UISceneActivationStateForegroundInactive)) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha < 0.01 || window.windowLevel != UIWindowLevelNormal) continue;
            if (window.isKeyWindow) return window;
            if (window.rootViewController) candidate = window;
        }
    }
    if (!candidate) {
        for (UIWindow *window in application.windows.reverseObjectEnumerator) {
            if (window.hidden || window.alpha < 0.01 || window.windowLevel != UIWindowLevelNormal) continue;
            if (window.isKeyWindow) return window;
            if (window.rootViewController) candidate = window;
        }
    }
    return candidate;
}

// 优先读取抖音宿主的主题样式，接口不可用时回退到窗口样式。
UIUserInterfaceStyle DYLVCUserInterfaceStyle(void) {
    Class manager = NSClassFromString(@"AWEUIThemeManager");
    SEL selector = NSSelectorFromString(@"isLightTheme");
    Method method = class_getClassMethod(manager, selector);
    if (method) {
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        const char type = signature.methodReturnType[0];
        if (signature.numberOfArguments == 2 && (type == 'B' || type == 'c')) {
            return ((BOOL (*)(id, SEL))objc_msgSend)(manager, selector) ?
                UIUserInterfaceStyleLight : UIUserInterfaceStyleDark;
        }
    }
    return DYLVCActiveWindow().traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ?
        UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
}

static void DYLVCNotifyThemeChange(void) {
    static BOOL scheduled;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (scheduled) return;
        scheduled = YES;
        // 等宿主完成主题切换后再读取，并合并一次切换触发的多个通知。
        dispatch_async(dispatch_get_main_queue(), ^{
            scheduled = NO;
            [NSNotificationCenter.defaultCenter postNotificationName:DYLVCThemeDidChangeNotification object:nil];
        });
    });
}

void DYLVCInstallThemeHooks(void) {
    static BOOL installed[3];
    NSArray<NSString *> *selectors = @[@"changeThemeStyleLightModeEnable:", @"setLightMode:", @"setThemeStyle:"];
    for (NSUInteger index = 0; index < selectors.count; index++) {
        if (installed[index]) continue;
        Class cls = NSClassFromString(index == 2 ? @"AWEThemeManager" : @"AWESettingThemeManager");
        if (index == 2) cls = object_getClass(cls);
        SEL selector = NSSelectorFromString(selectors[index]);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) continue;
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        if (signature.methodReturnType[0] != 'v' || signature.numberOfArguments != 3) continue;
        char argument = [signature getArgumentTypeAtIndex:2][0];
        if (index == 2 ? (argument != 'Q' && argument != 'q') : (argument != 'B' && argument != 'c')) continue;
        IMP original = method_getImplementation(method);
        IMP replacement;
        if (index == 2) {
            replacement = imp_implementationWithBlock(^(id owner, NSUInteger style) {
                ((void (*)(id, SEL, NSUInteger))original)(owner, selector, style);
                DYLVCNotifyThemeChange();
            });
        } else {
            replacement = imp_implementationWithBlock(^(id owner, BOOL light) {
                ((void (*)(id, SEL, BOOL))original)(owner, selector, light);
                DYLVCNotifyThemeChange();
            });
        }
        class_replaceMethod(cls, selector, replacement, method_getTypeEncoding(method));
        installed[index] = YES;
    }
}

@implementation DYLVCColorScheme

+ (UIColor *)badgeBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:0.0 alpha:0.65];
            } else {
                return [UIColor colorWithWhite:0.0 alpha:0.55];
            }
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.55];
}

+ (UIColor *)badgeTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor whiteColor];
            } else {
                return [UIColor whiteColor];
            }
        }];
    }
    return [UIColor whiteColor];
}

+ (UIColor *)badgeBorderColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.15];
            } else {
                return [UIColor colorWithWhite:1.0 alpha:0.2];
            }
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.2];
}

@end

static NSString *DYLVCCompactDecimal(double value, NSString *suffix) {
    NSString *number = [NSString stringWithFormat:@"%.1f", value];
    if ([number hasSuffix:@".0"]) {
        number = [number substringToIndex:number.length - 2];
    }
    return [number stringByAppendingString:suffix];
}

@implementation DYLVCFormatter

+ (NSString *)formatViewerCount:(long long)count {
    if (count < 0) {
        return @"0";
    }

    if (count < 10000) {
        return [NSString stringWithFormat:@"%lld", count];
    } else if (count < 100000000) {
        double wan = count / 10000.0;
        if (wan >= 10000) {
            return DYLVCCompactDecimal(wan / 10000.0, @"亿");
        }
        return DYLVCCompactDecimal(wan, @"万");
    } else {
        double yi = count / 100000000.0;
        return DYLVCCompactDecimal(yi, @"亿");
    }
}

+ (NSString *)preciseViewerCount:(long long)count {
    if (count < 0) {
        return @"0";
    }
    return [NSString stringWithFormat:@"%lld", count];
}

@end
