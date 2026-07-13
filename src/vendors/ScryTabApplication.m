@import Cocoa;
#import <objc/message.h>
#import "ScryTabApplication.h"

@implementation ScryTabApplication

- (void)reportException:(NSException *)exception {
    Class bridge = NSClassFromString(@"SentryCrashReporterBridge");
    SEL selector = NSSelectorFromString(@"captureException:");
    if ([bridge respondsToSelector:selector]) {
        ((void (*)(id, SEL, NSException *))objc_msgSend)(bridge, selector, exception);
    }
    [super reportException:exception];
}

- (void)sendEvent:(NSEvent *)event {
    @try {
        [super sendEvent:event];
    } @catch (NSException *exception) {
        [self reportException:exception];
    }
}

@end
