#import "GeneratedPluginRegistrant.h"

// firebase_messaging exposes its plugin class through a pod header (CocoaPods)
// or a Clang module (Swift Package Manager). Support both so FCM can configure
// the UNUserNotificationCenter delegate before didFinishLaunching returns.
#if __has_include(<firebase_messaging/FLTFirebaseMessagingPlugin.h>)
#import <firebase_messaging/FLTFirebaseMessagingPlugin.h>
#else
@import firebase_messaging;
#endif
