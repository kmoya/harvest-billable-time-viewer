# Harvest Time Report - macOS Menu Bar App

A native macOS menu bar application that displays your daily billable hours from Harvest Time Reports API directly in the menu bar.

## Features

- 🏗️ Native macOS menu bar integration
- ⏱️ Displays today's billable hours in the menu bar
- 🔄 Updates on-demand when you click the menu bar icon
- ⚙️ Simple configuration dialog for API credentials
- 🔐 Secure storage of API credentials in UserDefaults
- 📊 Shows last update timestamp
- 🚫 Runs as a background app (no dock icon)

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

- **Click the menu bar icon**: Refreshes your billable hours data
- **Menu options**:
  - **Refresh**: Manually refresh the data
  - **Settings...**: Update your API credentials
  - **Last updated**: Shows when data was last fetched
  - **Quit**: Exit the application

## How it works

The app calls the Harvest Time Reports API endpoint:
```
GET https://api.harvestapp.com/v2/reports/time/projects?from=YYYY-MM-DD&to=YYYY-MM-DD
```

It retrieves today's time entries, sums up all the `billable_hours` values from the `results` array, and displays the total in the menu bar with a timer icon (⏱️).

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

The app sums all `billable_hours` values to show your total for the day.

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

## Development

The app consists of three main Swift files:

- **AppDelegate.swift**: Main application entry point
- **StatusBarController.swift**: Manages the menu bar interface and user interactions
- **HarvestAPI.swift**: Handles all API communication with Harvest

## Building for Distribution

1. Set your development team in Xcode
2. Archive the project (Product → Archive)
3. Export as a Mac app
4. Distribute the .app bundle

## License

This project is provided as-is for personal use. Modify as needed for your requirements.

## Contributing

Feel free to submit issues or pull requests to improve the app.
