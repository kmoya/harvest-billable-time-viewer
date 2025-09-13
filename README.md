# Harvest Time Report - macOS Menu Bar App

A native macOS menu bar application that displays your monthly billable hours from Harvest Time Reports API directly in the menu bar.

## Features

- 🏗️ Native macOS menu bar integration
- 📅 Displays current month's total billable hours in the menu bar
- 🔄 Manual refresh available through the menu
- ⚙️ Simple configuration dialog for API credentials
- 🔐 Secure storage of API credentials in UserDefaults
- 📊 Shows last update timestamp and current month indicator
- 🚫 Runs as a background app (no dock icon or desktop windows)
- 🗓️ Automatically switches to new month when calendar month changes

## Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- A Harvest account with API access

## Setup

### 1. Get your Harvest API credentials

1. Log in to your Harvest account
2. Go to Settings → Integrations → Personal Access Tokens
3. Create a new personal access token
4. Note down:
   - Your **Account ID** (found in the URL or account settings)
   - Your **API Token** (the token you just created)

### 2. Build the app

1. Open `HarvestTimeReport.xcodeproj` in Xcode
2. Select your development team in the project settings (if you want to run it)
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
  - **Refresh**: Manually refresh the monthly billable hours data
  - **Settings...**: Update your API credentials
  - **Showing: [Month Year]**: Displays which month's data is being shown
  - **Last updated**: Shows when data was last fetched
  - **Quit**: Exit the application

## How it works

The app calls the Harvest Time Reports API endpoint:
```
GET https://api.harvestapp.com/v2/reports/time/projects?from=YYYY-MM-01&to=YYYY-MM-31
```

It retrieves the current month's time entries, sums up all the `billable_hours` values from the `results` array, and displays the monthly total in the menu bar with a timer icon (⏱️). The date range automatically covers the entire current month (e.g., September 1st through September 30th).

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

The app sums all `billable_hours` values to show your total for the current month.

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

## Monthly Tracking

The app automatically tracks your billable hours for the current calendar month:

- **September 2025**: Shows total hours from September 1-30, 2025
- **October 2025**: Automatically switches to October 1-31, 2025 when the month changes
- **Historical data**: Only shows current month data (not past months)

This gives you a running total of your monthly progress toward billing goals.

## Development

The app consists of three main Swift files:

- **AppDelegate.swift**: Main application entry point, handles window management
- **StatusBarController.swift**: Manages the menu bar interface, monthly display, and user interactions
- **HarvestAPI.swift**: Handles all API communication with Harvest, calculates month date ranges

## Building for Distribution

1. Set your development team in Xcode
2. Archive the project (Product → Archive)
3. Export as a Mac app
4. Distribute the .app bundle

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Feel free to submit issues or pull requests to improve the app.
