//
//  StatusBarController.swift
//  HarvestTimeReport
//
//  Created by Kent Moya on 9/13/25.
//  Licensed under the MIT License
//

import Cocoa

enum TimePeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

class StatusBarController: NSObject {
    
    private var statusItem: NSStatusItem!
    private var harvestAPI: HarvestAPI!
    private var lastUpdateTime: Date?
    private var selectedTimePeriod: TimePeriod = .month
    
    override init() {
        super.init()
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "⏱ --"
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        // Load saved time period preference
        if let savedPeriod = UserDefaults.standard.string(forKey: "SelectedTimePeriod"),
           let period = TimePeriod(rawValue: savedPeriod) {
            selectedTimePeriod = period
        }
        
        // Initialize Harvest API
        harvestAPI = HarvestAPI()
        
        // Set up the menu
        setupMenu()
        
        // Load initial data if credentials are available, otherwise show config needed
        if harvestAPI.hasValidCredentials() {
            refreshBillableHours()
        } else {
            updateStatusBarTitle("⏱ Config needed")
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshBillableHours), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let clearSettingsItem = NSMenuItem(title: "Clear Settings", action: #selector(clearSettings), keyEquivalent: "")
        clearSettingsItem.target = self
        menu.addItem(clearSettingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add time period selection submenu
        let timePeriodItem = NSMenuItem(title: "Time Period", action: nil, keyEquivalent: "")
        let timePeriodSubmenu = NSMenu(title: "Time Period")
        
        for period in TimePeriod.allCases {
            let periodItem = NSMenuItem(title: period.rawValue, action: #selector(selectTimePeriod(_:)), keyEquivalent: "")
            periodItem.target = self
            periodItem.representedObject = period
            periodItem.state = (period == selectedTimePeriod) ? .on : .off
            timePeriodSubmenu.addItem(periodItem)
        }
        
        timePeriodItem.submenu = timePeriodSubmenu
        menu.addItem(timePeriodItem)
        
        // Add current period indicator
        let periodDescription = getCurrentPeriodDescription()
        let periodItem = NSMenuItem(title: "Showing: \(periodDescription)", action: nil, keyEquivalent: "")
        periodItem.isEnabled = false
        menu.addItem(periodItem)
        
        if let lastUpdate = lastUpdateTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            let updateItem = NSMenuItem(title: "Last updated: \(formatter.string(from: lastUpdate))", action: nil, keyEquivalent: "")
            updateItem.isEnabled = false
            menu.addItem(updateItem)
            menu.addItem(NSMenuItem.separator())
        } else {
            menu.addItem(NSMenuItem.separator())
        }
        
        let aboutItem = NSMenuItem(title: "About Time Report", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func getCurrentPeriodDescription() -> String {
        let formatter = DateFormatter()
        let now = Date()
        
        switch selectedTimePeriod {
        case .day:
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: now)
        case .week:
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startOfWeek)
            let endString = formatter.string(from: endOfWeek)
            return "Week of \(startString) - \(endString)"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: now)
        }
    }
    
    @objc private func selectTimePeriod(_ sender: NSMenuItem) {
        guard let period = sender.representedObject as? TimePeriod else { return }
        
        selectedTimePeriod = period
        
        // Save the selected time period
        UserDefaults.standard.set(period.rawValue, forKey: "SelectedTimePeriod")
        
        // Refresh the menu to update checkmarks and period description
        setupMenu()
        
        // Refresh data for the new time period
        if harvestAPI.hasValidCredentials() {
            refreshBillableHours()
        }
    }
    
    @objc private func statusBarButtonClicked() {
        // When clicked, refresh the data
        refreshBillableHours()
    }
    
    @objc private func refreshBillableHours() {
        guard harvestAPI.hasValidCredentials() else {
            updateStatusBarTitle("⏱ Config needed")
            openSettings()
            return
        }
        
        updateStatusBarTitle("⏱ Loading...")
        
        harvestAPI.fetchBillableHours(for: selectedTimePeriod) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let hours):
                    self?.updateStatusBarTitle("⏱ \(String(format: "%.2f", hours))h")
                    self?.lastUpdateTime = Date()
                    self?.setupMenu() // Refresh menu to show updated timestamp
                case .failure(let error):
                    self?.updateStatusBarTitle("⏱ Error")
                    self?.showError(error)
                }
            }
        }
    }
    
    private func updateStatusBarTitle(_ title: String) {
        statusItem.button?.title = title
    }
    
    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to fetch Harvest data"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func openSettings() {
        let alert = NSAlert()
        alert.messageText = "Harvest API Configuration"
        alert.informativeText = "Enter your Harvest API credentials. You can find these in your Harvest account under Settings > Integrations > Personal Access Tokens."
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        
        // Account ID field
        let accountLabel = NSTextField(labelWithString: "Account ID:")
        accountLabel.frame = NSRect(x: 0, y: 90, width: 80, height: 20)
        let accountField = NSTextField(frame: NSRect(x: 85, y: 90, width: 200, height: 20))
        accountField.stringValue = UserDefaults.standard.string(forKey: "HarvestAccountID") ?? ""
        
        // Token field
        let tokenLabel = NSTextField(labelWithString: "API Token:")
        tokenLabel.frame = NSRect(x: 0, y: 60, width: 80, height: 20)
        let tokenField = NSSecureTextField(frame: NSRect(x: 85, y: 60, width: 200, height: 20))
        tokenField.stringValue = UserDefaults.standard.string(forKey: "HarvestAPIToken") ?? ""
        
        // User Agent field
        let userAgentLabel = NSTextField(labelWithString: "User Agent:")
        userAgentLabel.frame = NSRect(x: 0, y: 30, width: 80, height: 20)
        let userAgentField = NSTextField(frame: NSRect(x: 85, y: 30, width: 200, height: 20))
        userAgentField.stringValue = UserDefaults.standard.string(forKey: "HarvestUserAgent") ?? "HarvestTimeReport (your-email@example.com)"
        
        // Info text
        let infoLabel = NSTextField(labelWithString: "User Agent should include your app name and contact email")
        infoLabel.frame = NSRect(x: 0, y: 5, width: 300, height: 20)
        infoLabel.font = NSFont.systemFont(ofSize: 10)
        infoLabel.textColor = .secondaryLabelColor
        
        accessoryView.addSubview(accountLabel)
        accessoryView.addSubview(accountField)
        accessoryView.addSubview(tokenLabel)
        accessoryView.addSubview(tokenField)
        accessoryView.addSubview(userAgentLabel)
        accessoryView.addSubview(userAgentField)
        accessoryView.addSubview(infoLabel)
        
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Save the credentials
            UserDefaults.standard.set(accountField.stringValue, forKey: "HarvestAccountID")
            UserDefaults.standard.set(tokenField.stringValue, forKey: "HarvestAPIToken")
            UserDefaults.standard.set(userAgentField.stringValue, forKey: "HarvestUserAgent")
            
            // Update the API with new credentials
            harvestAPI.updateCredentials()
            
            // Refresh data with new credentials
            refreshBillableHours()
        }
    }
    
    @objc private func clearSettings() {
        let alert = NSAlert()
        alert.messageText = "Clear All Settings"
        alert.informativeText = "This will remove all stored Harvest API credentials (Account ID, API Token, and User Agent). You will need to reconfigure the app to use it again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Remove all stored credentials
            UserDefaults.standard.removeObject(forKey: "HarvestAccountID")
            UserDefaults.standard.removeObject(forKey: "HarvestAPIToken")
            UserDefaults.standard.removeObject(forKey: "HarvestUserAgent")
            
            // Update the API to reflect cleared credentials
            harvestAPI.updateCredentials()
            
            // Update status bar to show config is needed
            updateStatusBarTitle("⏱ Config needed")
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Settings Cleared"
            confirmAlert.informativeText = "All Harvest API credentials have been removed. Use Settings to reconfigure the app."
            confirmAlert.alertStyle = .informational
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.runModal()
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Harvest Time Report"
        alert.informativeText = """
        A macOS menu bar app that displays your monthly billable hours from Harvest.
        
        Version: 1.0
        Licensed under the MIT License
        
        For more information, documentation, and source code:
        """
        
        alert.alertStyle = .informational
        
        // Set the app icon for the about dialog
        if let appIcon = NSApp.applicationIconImage {
            alert.icon = appIcon
        }
        
        alert.addButton(withTitle: "Visit GitHub")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open GitHub repository in default browser
            if let url = URL(string: "https://github.com/kmoya/harvest-billable-time-viewer?tab=readme-ov-file#readme") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
