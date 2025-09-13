//
//  AppDelegate.swift
//  HarvestTimeReport
//
//  Created by Kent Moya on 9/13/25.
//  Licensed under the MIT License
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusBarController: StatusBarController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide the dock icon since this is a menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize the status bar controller
        statusBarController = StatusBarController()
        
        // Hide the main window that gets created by the storyboard
        if let mainWindow = NSApplication.shared.mainWindow {
            mainWindow.orderOut(nil)
        }
        
        // Also hide any other windows
        for window in NSApplication.shared.windows {
            window.orderOut(nil)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Prevent reopening windows when the app is activated
        return false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when last window closes - we're a menu bar app
        return false
    }
}
