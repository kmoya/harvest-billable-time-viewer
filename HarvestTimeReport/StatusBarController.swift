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

enum AutoRefreshInterval: Int, CaseIterable {
    case off = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        }
    }
}

class StatusBarController: NSObject, NSMenuDelegate {
    
    private var statusItem: NSStatusItem!
    private var harvestAPI: HarvestAPI!
    private var lastUpdateTime: Date?
    private var selectedTimePeriod: TimePeriod = .month
    private var autoRefreshInterval: AutoRefreshInterval = .off
    private var autoRefreshTimer: Timer?
    private var clearCredentialsMenuItem: NSMenuItem?
    
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
        
        // Load saved auto-refresh preference
        let savedRefreshInterval = UserDefaults.standard.integer(forKey: "AutoRefreshInterval")
        if let interval = AutoRefreshInterval(rawValue: savedRefreshInterval) {
            autoRefreshInterval = interval
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
        
        // Set up auto-refresh timer
        setupAutoRefreshTimer()
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
        
        clearCredentialsMenuItem = NSMenuItem(title: "Clear API Credentials", action: #selector(clearSettings), keyEquivalent: "")
        clearCredentialsMenuItem?.target = self
        clearCredentialsMenuItem?.isEnabled = harvestAPI.hasValidCredentials()
        menu.addItem(clearCredentialsMenuItem!)
        
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
        
        // Add auto-refresh interval submenu
        let autoRefreshItem = NSMenuItem(title: "Auto-Refresh", action: nil, keyEquivalent: "")
        let autoRefreshSubmenu = NSMenu(title: "Auto-Refresh")
        
        for interval in AutoRefreshInterval.allCases {
            let intervalItem = NSMenuItem(title: interval.displayName, action: #selector(selectAutoRefreshInterval(_:)), keyEquivalent: "")
            intervalItem.target = self
            intervalItem.representedObject = interval
            intervalItem.state = (interval == autoRefreshInterval) ? .on : .off
            autoRefreshSubmenu.addItem(intervalItem)
        }
        
        autoRefreshItem.submenu = autoRefreshSubmenu
        menu.addItem(autoRefreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add current period indicator
        let periodDescription = getCurrentPeriodDescription()
        let periodItem = NSMenuItem(title: "Showing: \(periodDescription)", action: nil, keyEquivalent: "")
        periodItem.isEnabled = false
        menu.addItem(periodItem)
        
        if let lastUpdate = lastUpdateTime {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
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
        
        menu.delegate = self
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
    
    @objc private func selectAutoRefreshInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? AutoRefreshInterval else { return }
        
        autoRefreshInterval = interval
        
        // Save the selected auto-refresh interval
        UserDefaults.standard.set(interval.rawValue, forKey: "AutoRefreshInterval")
        
        // Update the timer
        setupAutoRefreshTimer()
        
        // Refresh the menu to update checkmarks
        setupMenu()
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
    
    private func setupAutoRefreshTimer() {
        // Invalidate any existing timer
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        
        // Set up new timer if interval is not off
        if autoRefreshInterval != .off {
            autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoRefreshInterval.rawValue), repeats: true) { [weak self] _ in
                self?.refreshBillableHours()
            }
        }
    }
    
    @objc private func autoRefreshTimerFired() {
        refreshBillableHours()
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
        userAgentField.stringValue = UserDefaults.standard.string(forKey: "HarvestUserAgent") ?? ""
        userAgentField.placeholderString = "HarvestTimeReport (your-email@example.com)"
        
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
        
        // Loop until all fields are filled or user cancels
        repeat {
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                // Validate that all fields are filled
                let accountID = accountField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let apiToken = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let userAgent = userAgentField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if accountID.isEmpty || apiToken.isEmpty || userAgent.isEmpty {
                    // Show validation error
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Incomplete Credentials"
                    errorAlert.informativeText = "All three fields are required: Account ID, API Token, and User Agent. Please fill in all fields before saving."
                    errorAlert.alertStyle = .warning
                    errorAlert.addButton(withTitle: "OK")
                    errorAlert.runModal()
                    // Continue the loop to show the settings dialog again
                    continue
                }
                
                // All fields are valid, save the credentials
                UserDefaults.standard.set(accountID, forKey: "HarvestAccountID")
                UserDefaults.standard.set(apiToken, forKey: "HarvestAPIToken")
                UserDefaults.standard.set(userAgent, forKey: "HarvestUserAgent")
                
                // Update the API with new credentials
                harvestAPI.updateCredentials()
                
                // Refresh data with new credentials
                refreshBillableHours()
                
                // Break out of the loop
                break
            } else {
                // User clicked Cancel, break out of the loop
                break
            }
        } while true
    }
    
    @objc private func clearSettings() {
        let alert = NSAlert()
        alert.messageText = "Clear API Credentials"
        alert.informativeText = "This will remove all stored Harvest API credentials (Account ID, API Token, and User Agent). Your preferences for time period and auto-refresh will be preserved. You will need to reconfigure the API credentials to use the app again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear Credentials")
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
            
            // Update the Clear API Credentials button state
            updateClearCredentialsMenuState()
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Credentials Cleared"
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
        A macOS menu bar app that displays your billable hours from Harvest with flexible time period tracking (Day, Week, Month).
        
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
    
    private func updateClearCredentialsMenuState() {
        let hasCredentials = harvestAPI.hasValidCredentials()
        clearCredentialsMenuItem?.isEnabled = hasCredentials
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Update the Clear API Credentials menu item visibility based on credentials
        let hasCredentials = harvestAPI.hasValidCredentials()
        
        // Remove the old menu item if it exists
        if let oldItem = clearCredentialsMenuItem, let index = menu.items.firstIndex(of: oldItem) {
            menu.removeItem(at: index)
            
            // Only add the menu item back if there are credentials to clear
            if hasCredentials {
                let newItem = NSMenuItem(title: "Clear API Credentials", 
                                       action: #selector(clearSettings), 
                                       keyEquivalent: "")
                newItem.target = self
                newItem.isEnabled = true  // Always enabled when visible
                
                // Insert at the same position
                menu.insertItem(newItem, at: index)
                clearCredentialsMenuItem = newItem
            } else {
                clearCredentialsMenuItem = nil
            }
        }
    }
    
    deinit {
        autoRefreshTimer?.invalidate()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
