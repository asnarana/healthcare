# Filter Consistency Analysis

## Current Filter Design

### Time Range Filters:
- **Flu**: Weeks (4, 8, 12, 16, 24, 52) - Makes sense because flu data is weekly
- **Hospital**: Days (7, 14, 30, 60, 90, 180) - Makes sense because hospital data is daily
- **FDA**: Days (7, 14, 30, 60, 90, 180) - Makes sense because FDA data is daily
- **OpenAQ**: Days (7, 14, 30, 60, 90, 180) - Makes sense because air quality is hourly/daily

### Location Filters:
- **OpenAQ**: ZIP/Coordinates (automatic from initial search, no visible filter)
- **Hospital**: ZIP/Coordinates (automatic from initial search, no visible filter)
- **Flu**: Region dropdown (National, Auto, or State) - Separate filter
- **FDA**: State dropdown (Optional, All States or specific state) - Separate filter

## Issues Identified:

1. **Inconsistent Time Units**: Flu uses weeks, others use days - confusing for users
2. **Hidden Location Filters**: OpenAQ/Hospital location is set on home page but not visible/changeable on dashboard
3. **Different Filter Patterns**: Some filters are automatic, others have dropdowns
4. **Flu "Auto" Option**: Tries to detect from ZIP, but this isn't clear to users

## Recommendations:

### Option 1: Standardize Time Ranges (Recommended)
- Convert Flu weeks to days: 4 weeks = 28 days, 8 weeks = 56 days, etc.
- OR show both: "4 Weeks (28 Days)" in the dropdown
- Makes all filters use same unit (days)

### Option 2: Make Location Filters Consistent
- Add visible location filter for OpenAQ/Hospital (show current ZIP/coordinates, allow change)
- OR remove separate filters for Flu/FDA and use initial search location
- Makes all filters work the same way

### Option 3: Simplify Flu Region Filter
- Remove "Auto" option, just show "National" and state list
- Auto-detection happens automatically in background
- Less confusing for users

### Option 4: Group Related Filters
- Group location-based filters (OpenAQ, Hospital) together
- Group region-based filters (Flu, FDA) together
- Makes it clearer which filters affect which charts

