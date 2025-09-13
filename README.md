<div align="center">
  <img src="HarvestTimeReport/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Harvest Time Report App Icon" width="128" height="128">
</div>

# Harvest Time Report - macOS Menu Bar App

A native macOS menu bar application that displays your billable hours from Harvest Time Reports API directly in the menu bar. Choose between daily, weekly, or monthly views to track your time at the granularity you prefer.

> **Disclaimer**: This application uses the Harvest API but is in no way affiliated with, endorsed by, or supported by Harvest. It is an independent third-party application developed for personal use.

## Features

- 🏗️ Native macOS menu bar integration
- 📅 **Flexible time periods**: View billable hours for the current day, week, or month
- 🔄 Manual refresh available through the menu
- ⚙️ Simple configuration dialog for API credentials
- 🔐 Secure storage of API credentials in UserDefaults
- 📊 Shows last update timestamp and current period indicator
- 🚫 Runs as a background app (no dock icon or desktop windows)
- 🗓️ Automatically updates when time periods change (new day/week/month)
- 🧹 Clear settings option to reset all stored credentials
- 💾 Remembers your preferred time period setting

## Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- A Harvest account with API access

## Setup

### 1. Get your Harvest API credentials

1. Log in to your Harvest account
2. Go to https://id.getharvest.com/developers
3. Create a new personal access token
4. Note down:
   - Your **Account ID** (found in the URL or account settings)
   - Your **API Token** (the token you just created)

### 2. Build the app

1. Open `HarvestTimeReport.xcodeproj` in Xcode
2. (Optional) Select your development team in the project settings - only needed if you want to distribute the app or if Xcode requires code signing
3. Build and run the project (⌘+R)

### 3. Configure the app

1. When the app first runs, it will show "Config needed" in the menu bar
2. Click on the menu bar item and select "Settings..."
3. Enter your credentials:
   - **Account ID**: Your Harvest account ID
   - **API Token**: Your personal access token
   - **User Agent**: Something like "HarvestTimeReport (your-email@example.com)"
4. Click "Save"

## Usage

- **Click the menu bar icon**: Opens the dropdown menu
- **Menu options**:
  - **Refresh**: Manually refresh the billable hours data for the selected time period
  - **Settings...**: Update your API credentials
  - **Clear Settings**: Remove all stored credentials and reset the app
  - **Time Period**: Choose between Day, Week, or Month views
    - **Day**: Shows today's billable hours
    - **Week**: Shows current week's billable hours
    - **Month**: Shows current month's billable hours
  - **Showing: [Period Description]**: Displays which time period's data is being shown
  - **Last updated**: Shows when data was last fetched
  - **About Time Report**: Information about the app with link to GitHub
  - **Quit**: Exit the application

## How it works

The app calls the Harvest Time Reports API endpoint with dynamic date ranges based on your selected time period:

```
GET https://api.harvestapp.com/v2/reports/time/projects?from=YYYY-MM-DD&to=YYYY-MM-DD
```

**Time Period Examples:**
- **Day**: `from=2025-09-13&to=2025-09-13` (today only)
- **Week**: `from=2025-09-09&to=2025-09-15` (current week)
- **Month**: `from=2025-09-01&to=2025-09-30` (current month)

It retrieves time entries for the selected period, sums up all the `billable_hours` values from the `results` array, and displays the total in the menu bar with a timer icon (⏱️). The date ranges automatically adjust based on the current date and your selected time period.

## API Response Format

The app expects this JSON structure from the Harvest API:

```json
{
  "results": [
    {
      "billable_hours": 2.5,
      "client_name": "Example Client",
      "project_name": "Example Project"
    },
    {
      "billable_hours": 1.75,
      "client_name": "Another Client", 
      "project_name": "Another Project"
    }
  ]
}
```

The app sums all `billable_hours` values to show your total for the selected time period.

## Security

- API credentials are stored in macOS UserDefaults
- The app uses App Sandbox for security
- Network access is limited to the Harvest API domain
- All API requests use HTTPS with proper authentication headers

## Troubleshooting

### "Config needed" in menu bar
- You need to configure your API credentials through Settings

### "Error" in menu bar
- Check your internet connection
- Verify your API credentials are correct
- Ensure your Harvest account has API access enabled
- Check that your API token hasn't expired

### HTTP error codes
- **401**: Invalid API token or Account ID
- **403**: API access denied (check permissions)
- **429**: Rate limit exceeded (wait and try again)

## Time Period Tracking

The app automatically tracks your billable hours for your selected time period:

### **Day View**
- **Today**: Shows total hours for the current day
- **Updates**: Automatically resets at midnight for the new day

### **Week View** 
- **Current Week**: Shows total hours from Monday to Sunday of the current week
- **Updates**: Automatically switches to the new week on Monday

### **Month View**
- **Current Month**: Shows total hours from the 1st to the last day of the current month
- **Updates**: Automatically switches to the new month (e.g., September → October)

### **Time Period Selection**
- **Persistent**: Your selected time period is remembered across app restarts
- **Flexible**: Switch between day/week/month views anytime through the menu
- **Current data only**: Shows current period data (not historical periods)

This gives you flexible tracking granularity - whether you prefer detailed daily monitoring, weekly summaries, or monthly progress toward billing goals.

## Development

The app consists of three main Swift files:

- **AppDelegate.swift**: Main application entry point, handles window management
- **StatusBarController.swift**: Manages the menu bar interface, time period selection, user interactions, and settings management
- **HarvestAPI.swift**: Handles all API communication with Harvest, calculates date ranges for different time periods (day/week/month)

## Building for Distribution

1. Set your development team in Xcode
2. Archive the project (Product → Archive)
3. Export as a Mac app
4. Distribute the .app bundle

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Feel free to submit issues or pull requests to improve the app.
