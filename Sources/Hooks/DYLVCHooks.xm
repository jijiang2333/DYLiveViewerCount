#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <errno.h>
#import <limits.h>
#import <math.h>
#import <stdlib.h>
#import <string.h>
#import "../Core/DYLVCCore.h"
#import "../UI/DYLVCBadgeView.h"
#import "../Settings/DYLVCSettingsViewController.h"
#import "../Settings/DYLVCSettings.h"

@interface AWESettingBaseViewModel : NSObject
@end

@interface AWESettingItemModel : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subTitle;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, copy) NSString *svgIconImageName;
@property (nonatomic, copy) NSString *iconImageName;
@property (nonatomic, assign) NSInteger cellType;
@property (nonatomic, assign) NSInteger colorStyle;
@property (nonatomic, assign) BOOL isEnable;
@property (nonatomic, assign) BOOL isSwitchOn;
@property (nonatomic, copy) void (^cellTappedBlock)(void);
- (void)refreshCell;
@end

@interface AWESettingSectionModel : NSObject
@property (nonatomic, strong) NSArray *itemArray;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, assign) CGFloat sectionHeaderHeight;
@property (nonatomic, copy) NSString *sectionHeaderTitle;
@property (nonatomic, copy) NSString *sectionFooterTitle;
@property (nonatomic, assign) BOOL useNewFooterLayout;
@end

@interface AWESettingsViewModel : AWESettingBaseViewModel
@property (nonatomic, weak) UIViewController *controllerDelegate;
@property (nonatomic, strong) NSArray *sectionDataArray;
@property (nonatomic, assign) NSInteger colorStyle;
- (void)dylvc_showSettingsPage:(UIViewController *)rootVC;
@end

@interface AWELiveNewPreStreamViewController : UIViewController
@end

@interface HTSLiveApi : NSObject
@end

@interface HTSLiveRoomAPI : HTSLiveApi
- (instancetype)initWithRoomID:(id)roomID;
- (void)fetchRoomInfoWithRoomID:(id)roomID completion:(id)completion;
@end

@interface AWELiveFeedStatusLabel : UIView
@end

static char kDYLVCPreviewStateKey;

#pragma mark - 预览数据

static id DYLVCValueForKey(id object, NSString *key) {
    if (!object || object == [NSNull null]) {
        return nil;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        id value = [object objectForKey:key];
        return value == [NSNull null] ? nil : value;
    }
    // 私有字段在不同版本中可能缺失，读取时避免抛出异常。
    Class objectClass = [object class];
    if (![object respondsToSelector:NSSelectorFromString(key)] &&
        !class_getInstanceVariable(objectClass, key.UTF8String) &&
        !class_getInstanceVariable(objectClass, [@"_" stringByAppendingString:key].UTF8String)) {
        return nil;
    }
    @try {
        id value = [object valueForKey:key];
        return value == [NSNull null] ? nil : value;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSNumber *DYLVCOnlineCount(id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        value = [value stringValue];
    }
    if (![value isKindOfClass:[NSString class]] || [value length] == 0) {
        return nil;
    }
    const char *digits = [value UTF8String];
    if (!digits || strlen(digits) != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return nil;
    }
    for (const char *cursor = digits; *cursor; ++cursor) {
        if (*cursor < '0' || *cursor > '9') {
            return nil;
        }
    }
    errno = 0;
    char *end = NULL;
    unsigned long long count = strtoull(digits, &end, 10);
    if (errno == ERANGE || end == digits || *end || count > LLONG_MAX) {
        return nil;
    }
    return @((long long)count);
}

static id DYLVCDecodeRoomData(id object) {
    NSData *data = nil;
    if ([object isKindOfClass:[NSString class]]) {
        data = [object dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([object isKindOfClass:[NSData class]]) {
        data = object;
    } else {
        return object;
    }
    if (data.length == 0 || data.length > 1024 * 1024) {
        return nil;
    }
    id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [decoded isKindOfClass:[NSDictionary class]] ? decoded : nil;
}

static NSString *DYLVCRoomID(id room) {
    for (NSString *key in @[@"roomID", @"idStr", @"id_str", @"id"]) {
        NSNumber *number = DYLVCOnlineCount(DYLVCValueForKey(room, key));
        if (number.longLongValue > 0) {
            return number.stringValue;
        }
    }
    return nil;
}

static BOOL DYLVCIsRecommendationPreview(UIViewController *controller) {
    id viewModel = DYLVCValueForKey(controller, @"viewModel");
    if ([DYLVCValueForKey(controller, @"showInSearchResult") boolValue] ||
        [DYLVCValueForKey(viewModel, @"showInSearchResult") boolValue]) {
        return NO;
    }
    // 优先通过来源字段确认卡片是否来自推荐页。
    NSNumber *isHomepageHot = DYLVCValueForKey(viewModel, @"isFromHomepageHot");
    if (isHomepageHot) {
        return isHomepageHot.boolValue;
    }
    for (id object in @[controller, viewModel ?: [NSNull null],
                        DYLVCValueForKey(controller, @"model") ?: [NSNull null]]) {
        NSString *source = DYLVCValueForKey(object, @"referString");
        if (![source isKindOfClass:[NSString class]] || source.length == 0) {
            continue;
        }
        source = source.lowercaseString;
        return [source isEqualToString:@"homepage_hot"] ||
               [source hasPrefix:@"homepage_hot_"] ||
               [source isEqualToString:@"homepage_recommend"] ||
               [source isEqualToString:@"recommend"];
    }
    return NO;
}

static void DYLVCAppendRoom(NSMutableArray *rooms, id room) {
    if (room && room != [NSNull null] && [rooms indexOfObjectIdenticalTo:room] == NSNotFound) {
        [rooms addObject:room];
    }
}

static void DYLVCAppendAwemeRooms(NSMutableArray *rooms, id model) {
    id rawModel = DYLVCValueForKey(model, @"rawDataRoomModel");
    DYLVCAppendRoom(rooms, DYLVCValueForKey(model, @"rawHTSLiveRoomModel"));
    DYLVCAppendRoom(rooms, DYLVCValueForKey(rawModel, @"rawRoom"));
    DYLVCAppendRoom(rooms, rawModel);
    DYLVCAppendRoom(rooms, DYLVCValueForKey(model, @"roomModel"));
}

static NSArray *DYLVCPreviewRooms(UIViewController *controller, UIView *statusLabel,
                                 NSString *__autoreleasing *currentRoomID) {
    *currentRoomID = nil;
    id viewModel = DYLVCValueForKey(controller, @"viewModel");
    id model = DYLVCValueForKey(controller, @"model") ?: DYLVCValueForKey(viewModel, @"model");
    id cellRoom = DYLVCValueForKey(model, @"cellRoom");
    NSMutableArray *feedRooms = [NSMutableArray array];
    DYLVCAppendAwemeRooms(feedRooms, model);
    DYLVCAppendAwemeRooms(feedRooms, cellRoom);
    // 类型化房间模型尚未解码时，推荐流可能先提供原始房间数据。
    DYLVCAppendRoom(feedRooms, DYLVCDecodeRoomData(DYLVCValueForKey(model, @"liveRoomRawData")));
    DYLVCAppendRoom(feedRooms, DYLVCDecodeRoomData(DYLVCValueForKey(cellRoom, @"liveRoomRawData")));
    NSString *roomID = DYLVCRoomID(model);
    for (id room in feedRooms) {
        if (!roomID) {
            roomID = DYLVCRoomID(room);
        }
    }
    if (model && !roomID) {
        return @[];
    }

    id streamView = DYLVCValueForKey(controller, @"streamView");
    id statusModel = DYLVCValueForKey(statusLabel, @"viewModel");
    NSMutableArray *rooms = [NSMutableArray array];
    DYLVCAppendRoom(rooms, DYLVCValueForKey(viewModel, @"room"));
    DYLVCAppendRoom(rooms, DYLVCValueForKey(controller, @"roomService"));
    DYLVCAppendRoom(rooms, DYLVCValueForKey(streamView, @"room"));
    for (id room in feedRooms) {
        DYLVCAppendRoom(rooms, room);
    }
    DYLVCAppendRoom(rooms, DYLVCValueForKey(statusModel, @"roomModel"));
    for (id room in rooms) {
        if (!roomID) {
            roomID = DYLVCRoomID(room);
        }
    }
    if (!roomID) {
        return @[];
    }
    *currentRoomID = roomID;
    NSMutableArray *matchingRooms = [NSMutableArray array];
    for (id room in rooms) {
        // 控制器复用时可能暂时保留上一个房间，必须按房间 ID 过滤。
        if ([DYLVCRoomID(room) isEqualToString:roomID]) {
            [matchingRooms addObject:room];
        }
    }
    return matchingRooms;
}

static NSNumber *DYLVCViewerCount(NSArray *rooms) {
    NSArray<NSString *> *keys = @[
        @"onlineCountByIM", @"userCount", @"user_count"
    ];
    for (id room in rooms) {
        for (NSString *key in keys) {
            NSNumber *count = DYLVCOnlineCount(DYLVCValueForKey(room, key));
            // 预览模型可能先返回零，在线人数填充后再使用有效值。
            if (count.longLongValue > 0) {
                return count;
            }
        }
    }
    return nil;
}

static NSNumber *DYLVCNetworkViewerCount(id object, NSString *roomID, NSUInteger depth) {
    if (!object || object == [NSNull null] || depth > 5) {
        return nil;
    }
    NSString *responseRoomID = DYLVCRoomID(object);
    if (responseRoomID && ![responseRoomID isEqualToString:roomID]) {
        return nil;
    }
    NSNumber *direct = DYLVCViewerCount(@[object]);
    if (direct) {
        return direct;
    }
    NSArray<NSString *> *nestedKeys = @[
        @"data", @"room", @"roomModel", @"room_info", @"roomInfo", @"liveRoom",
        @"live_room", @"stats", @"roomViewStats", @"response", @"result", @"data_list", @"rooms"
    ];
    for (NSString *key in nestedKeys) {
        id nested = DYLVCValueForKey(object, key);
        NSNumber *count = DYLVCNetworkViewerCount(nested, roomID, depth + 1);
        if (count) {
            return count;
        }
    }
    if ([object isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)object) {
            NSNumber *count = DYLVCNetworkViewerCount(item, roomID, depth + 1);
            if (count) {
                return count;
            }
        }
    }
    return nil;
}

static DYLVCDisplayMode DYLVCCurrentDisplayMode(void) {
    return [[DYLVCSettings sharedInstance] displayMode];
}

#pragma mark - 预览徽章生命周期

static UIViewController *DYLVCPreviewControllerForView(UIView *view) {
    Class previewClass = NSClassFromString(@"AWELiveNewPreStreamViewController");
    if (!previewClass) {
        return nil;
    }
    for (UIResponder *responder = view; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:[UIViewController class]]) {
            continue;
        }
        for (UIViewController *controller = (UIViewController *)responder;
             controller; controller = controller.parentViewController) {
            if ([controller isKindOfClass:previewClass]) {
                return controller;
            }
        }
    }
    return nil;
}

static UIView *DYLVCFindStatusLabel(UIView *root, NSUInteger depth) {
    if (!root || depth > 20) {
        return nil;
    }
    Class labelClass = NSClassFromString(@"AWELiveFeedStatusLabel");
    if (labelClass && [root isKindOfClass:labelClass]) {
        return root;
    }
    for (UIView *subview in root.subviews) {
        UIView *label = DYLVCFindStatusLabel(subview, depth + 1);
        if (label) {
            return label;
        }
    }
    return nil;
}

static BOOL DYLVCUsableRect(CGRect rect) {
    return !CGRectIsNull(rect) && !CGRectIsInfinite(rect) && !CGRectIsEmpty(rect) &&
           isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
           isfinite(rect.size.width) && isfinite(rect.size.height);
}

// 滑动转场的回调可能早于手势最终结果。
// 结合裁剪区域和容器控制器状态确认卡片是否真正离开。
static BOOL DYLVCPreviewIsMostlyVisible(UIViewController *controller) {
    UIView *root = controller.viewIfLoaded;
    UIWindow *window = root.window;
    if (!window) {
        return NO;
    }
    for (UIViewController *child = controller; child; child = child.parentViewController) {
        UIViewController *parent = child.parentViewController;
        if ([parent isKindOfClass:UINavigationController.class] &&
            ((UINavigationController *)parent).visibleViewController != child) {
            return NO;
        }
        if ([parent isKindOfClass:UITabBarController.class] &&
            ((UITabBarController *)parent).selectedViewController != child) {
            return NO;
        }
        UIViewController *presented = child.presentedViewController;
        if (presented.viewIfLoaded.window && !presented.isBeingDismissed) {
            return NO;
        }
    }
    CGRect frame = [root convertRect:root.bounds toView:window];
    if (!DYLVCUsableRect(frame)) {
        return NO;
    }
    CGRect visible = CGRectIntersection(frame, window.bounds);
    for (UIView *view = root; view; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) {
            return NO;
        }
        if (view.clipsToBounds) {
            CGRect clip = [view convertRect:view.bounds toView:window];
            if (!DYLVCUsableRect(clip)) {
                return NO;
            }
            visible = CGRectIntersection(visible, clip);
        }
    }
    return DYLVCUsableRect(visible) &&
        visible.size.width >= frame.size.width * 0.5 &&
        visible.size.height >= frame.size.height * 0.5;
}

static BOOL DYLVCScrollIsMoving(UIScrollView *scrollView) {
    return scrollView.tracking || scrollView.dragging || scrollView.decelerating;
}

static UIScrollView *DYLVCPreviewScrollView(UIView *root) {
    UIScrollView *nearest = nil;
    for (UIView *view = root.superview; view; view = view.superview) {
        if ([view isKindOfClass:UIScrollView.class]) {
            UIScrollView *scrollView = (UIScrollView *)view;
            if (DYLVCScrollIsMoving(scrollView)) {
                return scrollView;
            }
            if (!nearest) nearest = scrollView;
        }
    }
    return nearest;
}

@interface DYLVCPreviewState : NSObject
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UIView *statusLabel;
@property (nonatomic, strong) DYLVCBadgeView *badge;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *visibilityTimer;
@property (nonatomic, strong) NSTimer *layoutRetryTimer;
@property (nonatomic, weak) UIScrollView *disappearingScrollView;
@property (nonatomic, assign) BOOL disappearancePending;
@property (nonatomic, assign) BOOL transitionInProgress;
@property (nonatomic, assign) NSUInteger disappearanceGeneration;
@property (nonatomic, assign) NSUInteger settledVisibilityPasses;
@property (nonatomic, assign) NSUInteger layoutRetriesRemaining;
@property (nonatomic, assign) CGRect lastVisibilityRect;
@property (nonatomic, assign) CGRect badgeAnchor;
@property (nonatomic, assign) CGRect badgeAnchorBounds;
@property (nonatomic, assign) UIEdgeInsets badgeAnchorInsets;
@property (nonatomic, strong) id defaultsObserver;
@property (nonatomic, strong) id backgroundObserver;
@property (nonatomic, strong) id foregroundObserver;
@property (nonatomic, strong) id roomAPI;
@property (nonatomic, strong) NSTimer *requestTimeoutTimer;
@property (nonatomic, copy) NSString *viewerRoomID;
@property (nonatomic, copy) NSString *requestRoomID;
@property (nonatomic, strong) NSNumber *lastViewerCount;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL refreshScheduled;
@property (nonatomic, assign) BOOL sampleRequested;
@property (nonatomic, assign) BOOL requestInFlight;
@property (nonatomic, assign) BOOL hasNetworkCount;
@property (nonatomic, assign) NSUInteger requestGeneration;
- (instancetype)initWithController:(UIViewController *)controller;
- (void)scheduleRefresh;
- (void)refresh;
- (void)activate;
- (void)beginDisappearance;
- (void)deactivate;
- (void)clearContent;
- (void)resetViewerCount;
@end

@implementation DYLVCPreviewState

- (instancetype)initWithController:(UIViewController *)controller {
    self = [super init];
    if (self) {
        _controller = controller;
        _badgeAnchor = CGRectNull;
        _layoutRetriesRemaining = 15;
        __weak DYLVCPreviewState *weakSelf = self;
        _defaultsObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:DYLVCSettingsDidChangeNotification
                        object:nil
                         queue:nil
                    usingBlock:^(__unused NSNotification *notification) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf scheduleRefresh];
                        });
                    }];
        _backgroundObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationWillResignActiveNotification
                        object:nil
                         queue:nil
                    usingBlock:^(__unused NSNotification *notification) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf pauseForApplicationState];
                        });
                    }];
        _foregroundObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:nil
                    usingBlock:^(__unused NSNotification *notification) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf resumeForApplicationState];
                        });
                    }];
    }
    return self;
}

- (void)dealloc {
    [_timer invalidate];
    [_visibilityTimer invalidate];
    [_layoutRetryTimer invalidate];
    [_requestTimeoutTimer invalidate];
    if (_defaultsObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_defaultsObserver];
    }
    if (_backgroundObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_backgroundObserver];
    }
    if (_foregroundObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_foregroundObserver];
    }
    [_badge removeFromSuperview];
}

- (void)stopLayoutRetry {
    [self.layoutRetryTimer invalidate];
    self.layoutRetryTimer = nil;
}

- (void)removeBadge {
    [self stopLayoutRetry];
    [self.badge removeFromSuperview];
    self.badge = nil;
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)cancelDisappearance {
    [self.visibilityTimer invalidate];
    self.visibilityTimer = nil;
    self.disappearancePending = NO;
    self.transitionInProgress = NO;
    self.disappearingScrollView = nil;
    self.settledVisibilityPasses = 0;
    self.disappearanceGeneration += 1;
}

- (void)activate {
    BOOL wasActive = self.active;
    [self cancelDisappearance];
    self.active = YES;
    // 同一张卡片可能收到多次出现回调，不能因此重复发起请求。
    if (!wasActive) self.sampleRequested = YES;
    [self scheduleRefresh];
}

- (void)checkVisibilityAfterTransition {
    if (!self.active || !self.disappearancePending) {
        return;
    }
    UIView *root = self.controller.viewIfLoaded;
    UIScrollView *scrollView = DYLVCPreviewScrollView(root);
    if (self.transitionInProgress || DYLVCScrollIsMoving(scrollView) ||
        DYLVCScrollIsMoving(self.disappearingScrollView)) {
        self.settledVisibilityPasses = 0;
        return;
    }
    CGRect frame = root.window ? [root convertRect:root.bounds toView:root.window] : CGRectNull;
    self.settledVisibilityPasses = CGRectEqualToRect(frame, self.lastVisibilityRect)
        ? self.settledVisibilityPasses + 1 : 1;
    self.lastVisibilityRect = frame;
    // 等待两个稳定布局周期，给取消的拖动或转场留出回调时间。
    if (self.settledVisibilityPasses < 2) {
        return;
    }
    if (DYLVCPreviewIsMostlyVisible(self.controller)) {
        [self cancelDisappearance];
        [self scheduleRefresh];
    } else {
        [self deactivate];
    }
}

- (void)beginDisappearance {
    if (!self.active) {
        return;
    }
    if (!self.disappearancePending) {
        self.disappearancePending = YES;
        self.disappearanceGeneration += 1;
        self.settledVisibilityPasses = 0;
        self.lastVisibilityRect = CGRectNull;
    }
    self.disappearingScrollView = DYLVCPreviewScrollView(self.controller.viewIfLoaded)
        ?: self.disappearingScrollView;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    __weak DYLVCPreviewState *weakSelf = self;
    if (!self.visibilityTimer) {
        self.visibilityTimer = [NSTimer timerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *timer) {
            DYLVCPreviewState *state = weakSelf;
            if (!state) {
                [timer invalidate];
                return;
            }
            [state checkVisibilityAfterTransition];
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.visibilityTimer forMode:NSRunLoopCommonModes];
    }
    id<UIViewControllerTransitionCoordinator> coordinator = self.controller.transitionCoordinator;
    if (coordinator.isAnimated && !self.transitionInProgress) {
        self.transitionInProgress = YES;
        NSUInteger generation = self.disappearanceGeneration;
        BOOL registered = [coordinator animateAlongsideTransition:nil
            completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                DYLVCPreviewState *state = weakSelf;
                if (!state.active || state.disappearanceGeneration != generation) return;
                state.transitionInProgress = NO;
                if (context.isCancelled) {
                    [state cancelDisappearance];
                    [state scheduleRefresh];
                } else {
                    [state checkVisibilityAfterTransition];
                }
            }];
        if (!registered) self.transitionInProgress = NO;
    }
}

- (void)deactivate {
    self.active = NO;
    [self cancelDisappearance];
    [self stopTimer];
    [self clearContent];
    [self resetViewerCount];
}

- (void)resetViewerCount {
    [self.requestTimeoutTimer invalidate];
    self.requestTimeoutTimer = nil;
    self.viewerRoomID = nil;
    self.requestRoomID = nil;
    self.lastViewerCount = nil;
    self.requestInFlight = NO;
    self.hasNetworkCount = NO;
    self.requestGeneration += 1;
    self.roomAPI = nil;
    self.sampleRequested = YES;
}

- (void)clearContent {
    [self removeBadge];
    self.statusLabel = nil;
    self.badgeAnchor = CGRectNull;
    self.badgeAnchorBounds = CGRectZero;
    self.badgeAnchorInsets = UIEdgeInsetsZero;
    self.layoutRetriesRemaining = 15;
    self.sampleRequested = YES;
}

- (void)scheduleRefresh {
    if (!self.active || self.refreshScheduled) {
        return;
    }
    self.refreshScheduled = YES;
    __weak DYLVCPreviewState *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        DYLVCPreviewState *state = weakSelf;
        state.refreshScheduled = NO;
        if (state.active) {
            [state refresh];
        }
    });
}

- (void)startTimer {
    NSTimeInterval interval = [[DYLVCSettings sharedInstance] refreshInterval];
    if (self.timer.isValid && fabs(self.timer.timeInterval - interval) < 0.01) {
        return;
    }
    [self stopTimer];
    self.sampleRequested = YES;
    __weak DYLVCPreviewState *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        DYLVCPreviewState *state = weakSelf;
        if (!state) {
            [timer invalidate];
            return;
        }
        state.sampleRequested = YES;
        [state scheduleRefresh];
    }];
    self.timer.tolerance = 0.25;
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)pauseForApplicationState {
    [self stopTimer];
    [self.visibilityTimer invalidate];
    self.visibilityTimer = nil;
    self.transitionInProgress = NO;
    self.disappearanceGeneration += 1;
    [self.requestTimeoutTimer invalidate];
    self.requestTimeoutTimer = nil;
    self.requestInFlight = NO;
    self.requestGeneration += 1;
    self.requestRoomID = nil;
    self.roomAPI = nil;
    [self removeBadge];
}

- (void)resumeForApplicationState {
    if (self.active) {
        if (self.disappearancePending) [self beginDisappearance];
        self.sampleRequested = YES;
        [self scheduleRefresh];
    }
}

- (void)requestViewerCountForRoomID:(NSString *)roomID {
    if (!self.active || self.requestInFlight || roomID.length == 0) {
        return;
    }
    NSNumber *roomNumber = DYLVCOnlineCount(roomID);
    if (roomNumber.longLongValue <= 0) {
        return;
    }
    Class apiClass = NSClassFromString(@"HTSLiveRoomAPI");
    SEL initSelector = NSSelectorFromString(@"initWithRoomID:");
    SEL fetchSelector = NSSelectorFromString(@"fetchRoomInfoWithRoomID:completion:");
    if (!apiClass || ![apiClass instancesRespondToSelector:initSelector] ||
        ![apiClass instancesRespondToSelector:fetchSelector]) {
        return;
    }
    HTSLiveRoomAPI *api = [[apiClass alloc] initWithRoomID:roomNumber];
    if (!api) {
        return;
    }
    self.roomAPI = api;
    self.requestRoomID = roomID;
    self.requestInFlight = YES;
    self.requestGeneration += 1;
    NSUInteger generation = self.requestGeneration;
    NSTimeInterval timeout = MAX(5.0, [[DYLVCSettings sharedInstance] refreshInterval] * 1.5);
    __weak DYLVCPreviewState *timeoutState = self;
    self.requestTimeoutTimer = [NSTimer timerWithTimeInterval:timeout repeats:NO block:^(__unused NSTimer *timer) {
        DYLVCPreviewState *state = timeoutState;
        if (!state || !state.requestInFlight || state.requestGeneration != generation ||
            ![state.requestRoomID isEqualToString:roomID]) {
            return;
        }
        state.requestInFlight = NO;
        state.requestRoomID = nil;
        state.roomAPI = nil;
        state.requestGeneration += 1;
        state.sampleRequested = YES;
        [state scheduleRefresh];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.requestTimeoutTimer forMode:NSRunLoopCommonModes];
    __weak DYLVCPreviewState *weakSelf = self;
    void (^completion)(id, id) = ^(id first, id second) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DYLVCPreviewState *state = weakSelf;
            if (!state) {
                return;
            }
            BOOL sameRequest = state.requestInFlight && state.requestGeneration == generation &&
                [state.requestRoomID isEqualToString:roomID];
            if (sameRequest) {
                NSNumber *count = DYLVCNetworkViewerCount(first, roomID, 0) ?: DYLVCNetworkViewerCount(second, roomID, 0);
                [state.requestTimeoutTimer invalidate];
                state.requestTimeoutTimer = nil;
                state.requestInFlight = NO;
                state.requestRoomID = nil;
                state.roomAPI = nil;
                if (count && state.active && [state.viewerRoomID isEqualToString:roomID]) {
                    state.lastViewerCount = count;
                    state.hasNetworkCount = YES;
                    [state scheduleRefresh];
                }
            }
        });
    };
    [api fetchRoomInfoWithRoomID:roomNumber completion:completion];
}

- (void)retryInitialLayout {
    if (self.layoutRetryTimer || self.layoutRetriesRemaining == 0) {
        return;
    }
    __weak DYLVCPreviewState *weakSelf = self;
    // 初始位置缺失时短暂重试，后续由正常布局回调更新。
    self.layoutRetryTimer = [NSTimer timerWithTimeInterval:1.0 / 30.0 repeats:YES block:^(NSTimer *timer) {
        DYLVCPreviewState *state = weakSelf;
        if (!state) {
            [timer invalidate];
            return;
        }
        if (!state.active || !state.controller.viewIfLoaded.window ||
            [UIApplication sharedApplication].applicationState != UIApplicationStateActive ||
            state.layoutRetriesRemaining == 0) {
            [state stopLayoutRetry];
            return;
        }
        state.layoutRetriesRemaining -= 1;
        [state scheduleRefresh];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.layoutRetryTimer forMode:NSRunLoopCommonModes];
}

- (void)layoutBadgeInView:(UIView *)root {
    CGRect available = UIEdgeInsetsInsetRect(root.bounds, root.safeAreaInsets);
    available = CGRectInset(available, 12.0, 8.0);
    CGSize size = self.badge.intrinsicContentSize;
    if (!DYLVCUsableRect(available) || available.size.width < 52.0 ||
        available.size.height < size.height) {
        self.badge.hidden = YES;
        [self retryInitialLayout];
        return;
    }
    if (!CGRectEqualToRect(root.bounds, self.badgeAnchorBounds) ||
        !UIEdgeInsetsEqualToEdgeInsets(root.safeAreaInsets, self.badgeAnchorInsets)) {
        self.badgeAnchor = CGRectNull;
        self.badgeAnchorBounds = root.bounds;
        self.badgeAnchorInsets = root.safeAreaInsets;
        self.layoutRetriesRemaining = 15;
    }
    CGRect anchor = CGRectNull;
    UIView *label = self.statusLabel;
    if (label && [label isDescendantOfView:root]) {
        // 等待稳定布局使用的入口容器，避免使用刚挂载时可能位于屏幕底部的临时标签位置。
        UIView *entryContainer = label.superview.superview;
        if (entryContainer && entryContainer != root && [entryContainer isDescendantOfView:root]) {
            CGRect entryFrame = [entryContainer convertRect:entryContainer.bounds toView:root];
            if (DYLVCUsableRect(entryFrame) && entryFrame.size.height <= 100.0) {
                anchor = entryFrame;
            }
        }
    }
    if (DYLVCUsableRect(anchor) && CGRectIntersectsRect(anchor, available)) {
        if (!self.disappearancePending || !DYLVCUsableRect(self.badgeAnchor)) {
            self.badgeAnchor = anchor;
        }
        anchor = self.badgeAnchor;
    } else {
        // 取消滑动时入口视图可能暂时脱离，保留当前卡片已确定的位置；首次布局完成前不使用屏幕底部的兜底位置。
        anchor = self.badgeAnchor;
    }
    if (!DYLVCUsableRect(anchor) || !CGRectIntersectsRect(anchor, available)) {
        self.badge.hidden = YES;
        [self retryInitialLayout];
        return;
    }
    [self stopLayoutRetry];
    size.width = MIN(size.width, available.size.width);
    CGFloat x = CGRectGetMidX(anchor) - size.width * 0.5;
    CGFloat y = CGRectGetMinY(anchor) - size.height - 8.0;
    if (y < CGRectGetMinY(available)) {
        y = CGRectGetMaxY(anchor) + 8.0;
    }
    x = MAX(CGRectGetMinX(available), MIN(x, CGRectGetMaxX(available) - size.width));
    y = MAX(CGRectGetMinY(available), MIN(y, CGRectGetMaxY(available) - size.height));
    CGRect frame = CGRectMake(round(x), round(y), ceil(size.width), size.height);
    [UIView performWithoutAnimation:^{
        if (!CGRectEqualToRect(self.badge.frame, frame)) {
            self.badge.frame = frame;
        }
        [self.badge layoutIfNeeded];
        self.badge.hidden = NO;
    }];
    if (root.subviews.lastObject != self.badge) {
        [root bringSubviewToFront:self.badge];
    }
}

- (void)refresh {
    UIViewController *controller = self.controller;
    UIView *root = controller.viewIfLoaded;
    if (!self.active || !root.window || [UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        [self stopTimer];
        [self removeBadge];
        return;
    }
    DYLVCDisplayMode mode = DYLVCCurrentDisplayMode();
    if (mode == DYLVCDisplayModeDisabled) {
        [self stopTimer];
        [self removeBadge];
        [self resetViewerCount];
        return;
    }
    if ([DYLVCValueForKey(controller, @"roomEntered") boolValue] ||
        [DYLVCValueForKey(controller, @"willEnterLiveRoom") boolValue]) {
        [self stopTimer];
        [self removeBadge];
        return;
    }

    [self startTimer];
    id viewModel = DYLVCValueForKey(controller, @"viewModel");
    if (!DYLVCIsRecommendationPreview(controller) ||
        [DYLVCValueForKey(viewModel, @"didEndedLive") boolValue]) {
        [self removeBadge];
        [self resetViewerCount];
        return;
    }
    for (UIView *view = root; view; view = view.superview) {
        if (view.hidden || view.alpha <= 0.01) {
            [self removeBadge];
            return;
        }
    }
    CGRect windowRect = [root convertRect:root.bounds toView:root.window];
    if (!DYLVCUsableRect(windowRect) || !CGRectIntersectsRect(windowRect, root.window.bounds)) {
        [self removeBadge];
        return;
    }

    // 先完成宿主的待处理约束，再读取入口容器坐标。
    [root layoutIfNeeded];
    if (!self.statusLabel || ![self.statusLabel isDescendantOfView:root]) {
        id tipView = DYLVCValueForKey(controller, @"getLiveStatusTipView");
        UIView *label = [tipView isKindOfClass:[UIView class]] ? DYLVCFindStatusLabel(tipView, 0) : nil;
        self.statusLabel = label && [label isDescendantOfView:root] ? label : DYLVCFindStatusLabel(root, 0);
    }
    NSString *roomID = nil;
    NSArray *rooms = DYLVCPreviewRooms(controller, self.statusLabel, &roomID);
    if (!roomID || ![self.viewerRoomID isEqualToString:roomID]) {
        [self resetViewerCount];
        self.viewerRoomID = roomID;
    }
    if (self.sampleRequested || !self.lastViewerCount) {
        NSNumber *sample = self.hasNetworkCount ? nil : DYLVCViewerCount(rooms);
        if (sample) {
            self.lastViewerCount = sample;
        }
        self.sampleRequested = NO;
        [self requestViewerCountForRoomID:roomID];
    }
    // 局部或零值样本不能覆盖当前房间最后一次有效人数。
    NSNumber *count = self.lastViewerCount;
    if (!count) {
        // 房间数据可能在首次布局后到达，仍需在可见期间重试。
        [self removeBadge];
        return;
    }

    if (!self.badge) {
        self.badge = [[DYLVCBadgeView alloc] initWithFrame:CGRectZero];
        self.badge.hidden = YES;
    }
    // 将徽章放在直播状态区域旁，确保隐藏入口按钮后仍可见。
    if (self.badge.superview != root) {
        [root addSubview:self.badge];
    }
    NSString *text = mode == DYLVCDisplayModePrecise
        ? [DYLVCFormatter preciseViewerCount:count.longLongValue]
        : [DYLVCFormatter formatViewerCount:count.longLongValue];
    [self.badge setViewerCountString:text];
    [self layoutBadgeInView:root];
}

@end

static DYLVCPreviewState *DYLVCStateForController(UIViewController *controller, BOOL create) {
    if (!controller) {
        return nil;
    }
    DYLVCPreviewState *state = objc_getAssociatedObject(controller, &kDYLVCPreviewStateKey);
    if (!state && create) {
        state = [[DYLVCPreviewState alloc] initWithController:controller];
        objc_setAssociatedObject(controller, &kDYLVCPreviewStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

static void DYLVCStatusLabelDidChange(UIView *label) {
    UIViewController *controller = DYLVCPreviewControllerForView(label);
    DYLVCPreviewState *state = DYLVCStateForController(controller, YES);
    state.statusLabel = label;
    [state scheduleRefresh];
}

static void DYLVCActivatePreview(UIViewController *controller) {
    DYLVCPreviewState *state = DYLVCStateForController(controller, YES);
    [state activate];
}

#pragma mark - 推荐页直播预览钩子

%hook AWELiveNewPreStreamViewController

- (void)configureWithModel:(id)model {
    [DYLVCStateForController(self, NO) clearContent];
    %orig;
    [DYLVCStateForController(self, NO) scheduleRefresh];
}

- (void)setModel:(id)model {
    [DYLVCStateForController(self, NO) clearContent];
    %orig;
    [DYLVCStateForController(self, NO) scheduleRefresh];
}

- (void)setViewModel:(id)viewModel {
    [DYLVCStateForController(self, NO) clearContent];
    %orig;
    [DYLVCStateForController(self, NO) scheduleRefresh];
}

- (void)setRoomEntered:(BOOL)roomEntered {
    %orig;
    [DYLVCStateForController(self, NO) scheduleRefresh];
}

- (void)setWillEnterLiveRoom:(BOOL)willEnterLiveRoom {
    %orig;
    [DYLVCStateForController(self, NO) scheduleRefresh];
}

- (void)prepareForDisplay {
    %orig;
    DYLVCActivatePreview(self);
}

- (void)pageWillAppear:(BOOL)animated {
    %orig;
    DYLVCActivatePreview(self);
}

- (void)pageDidAppear:(BOOL)animated {
    %orig;
    DYLVCActivatePreview(self);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    DYLVCActivatePreview(self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    DYLVCActivatePreview(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    [DYLVCStateForController(self, NO) scheduleRefresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    [DYLVCStateForController(self, NO) beginDisappearance];
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [DYLVCStateForController(self, NO) beginDisappearance];
}

- (void)pageWillDisappear:(BOOL)animated {
    %orig;
    [DYLVCStateForController(self, NO) beginDisappearance];
}

- (void)pageDidDisappear:(BOOL)animated {
    %orig;
    [DYLVCStateForController(self, NO) beginDisappearance];
}

- (void)didEndDisplaying {
    %orig;
    [DYLVCStateForController(self, NO) beginDisappearance];
}

- (void)prepareForReuse {
    [DYLVCStateForController(self, NO) deactivate];
    %orig;
}

- (void)reset {
    [DYLVCStateForController(self, NO) deactivate];
    %orig;
}

%end

%hook AWELiveFeedStatusLabel

- (void)setViewModel:(id)viewModel {
    %orig;
    DYLVCStatusLabelDidChange(self);
}

- (void)layoutSubviews {
    %orig;
    DYLVCStatusLabelDidChange(self);
}

- (void)didMoveToWindow {
    %orig;
    DYLVCStatusLabelDidChange(self);
}

- (void)didMoveToSuperview {
    %orig;
    DYLVCStatusLabelDidChange(self);
}

%end

#pragma mark - 设置页面

static UIViewController *DYLVCVisibleViewController(UIViewController *controller) {
    if (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
        return DYLVCVisibleViewController(controller.presentedViewController);
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        return DYLVCVisibleViewController(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return DYLVCVisibleViewController(((UITabBarController *)controller).selectedViewController);
    }
    return controller;
}

static UIViewController *DYLVCFrontmostViewController(void) {
    return DYLVCVisibleViewController(DYLVCActiveWindow().rootViewController);
}

%hook AWESettingsViewModel

- (NSArray *)sectionDataArray {
    NSArray *originalSections = %orig;
    if (![originalSections isKindOfClass:[NSArray class]]) {
        originalSections = @[];
    }

    BOOL isMainSettingsPage = NO;
    BOOL sectionExists = NO;
    for (AWESettingSectionModel *section in originalSections) {
        NSString *header = section.sectionHeaderTitle;
        if ([header isEqualToString:@"DYLiveViewerCount"]) {
            sectionExists = YES;
        }
        if ([header isEqualToString:@"账号"] || [header containsString:@"账号"]) {
            isMainSettingsPage = YES;
        }
        for (AWESettingItemModel *item in section.itemArray) {
            if ([item.identifier isEqualToString:@"DYLiveViewerCount"]) {
                sectionExists = YES;
            }
        }
    }
    if (!isMainSettingsPage || sectionExists) {
        return originalSections;
    }

    AWESettingItemModel *entry = [[%c(AWESettingItemModel) alloc] init];
    entry.identifier = @"DYLiveViewerCount";
    entry.title = @"直播观众数";
    entry.detail = @"1.0-1";
    entry.type = 0;
    entry.cellType = 26;
    entry.iconImageName = @"ic_video_outlined_20";
    entry.svgIconImageName = @"ic_video_outlined_20";
    entry.colorStyle = 2;
    entry.isEnable = YES;
    __weak AWESettingsViewModel *weakSelf = self;
    entry.cellTappedBlock = ^{
        AWESettingsViewModel *strongSelf = weakSelf;
        UIViewController *root = DYLVCVisibleViewController(strongSelf.controllerDelegate) ?: DYLVCFrontmostViewController();
        [strongSelf dylvc_showSettingsPage:root];
    };

    AWESettingSectionModel *section = [[%c(AWESettingSectionModel) alloc] init];
    section.sectionHeaderTitle = @"DYLiveViewerCount";
    section.sectionHeaderHeight = 40.0;
    section.type = 0;
    section.itemArray = @[entry];
    NSMutableArray *sections = [NSMutableArray arrayWithArray:originalSections];
    [sections insertObject:section atIndex:0];
    return sections;
}

%new
- (void)dylvc_showSettingsPage:(UIViewController *)rootVC {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = DYLVCVisibleViewController(rootVC) ?: DYLVCFrontmostViewController();
        if (!presenter || [presenter isKindOfClass:DYLVCSettingsViewController.class]) return;

        DYLVCSettingsViewController *settings = [DYLVCSettingsViewController new];
        settings.overrideUserInterfaceStyle = DYLVCUserInterfaceStyle();
        if (presenter.navigationController) {
            [presenter.navigationController pushViewController:settings animated:YES];
        } else {
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
            navigation.overrideUserInterfaceStyle = DYLVCUserInterfaceStyle();
            settings.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:settings action:@selector(closeSettings)];
            [presenter presentViewController:navigation animated:YES completion:nil];
        }
    });
}

%end

%ctor {
    @autoreleasepool {
        DYLVCInstallThemeHooks();
        NSLog(@"[DYLiveViewerCount] loaded; external live viewer badge enabled");
    }
}
