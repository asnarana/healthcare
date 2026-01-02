# Dashboard Screen Layout - What Each Job Shows

## Dashboard URL: `/dashboard/12345` (replace 12345 with your ZIP code)

```
┌─────────────────────────────────────────────────────────────────┐
│  Health Radar                                                    │
│  Health Dashboard for ZIP Code: 12345              [← Back]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ TIME RANGE SELECTORS                                      │   │
│  │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐      │   │
│  │ │ Flu: 12 Wks │ │ Hospital:30d │ │ FDA: 30 Days │      │   │
│  │ └──────────────┘ └──────────────┘ └──────────────┘      │   │
│  │ ┌──────────────┐                                         │   │
│  │ │ Air: 30 Days │                                         │   │
│  │ └──────────────┘                                         │   │
│  │                                                           │   │
│  │ REGION/STATE FILTERS                                      │   │
│  │ ┌────────────────────┐ ┌────────────────────┐            │   │
│  │ │ Flu Region: [nat▼]│ │ FDA State: [All▼] │            │   │
│  │ └────────────────────┘ └────────────────────┘            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────┐ ┌─────────────────────────────┐ │
│  │ JOB 1: OpenAQ Ingestion     │ │ JOB 2: Hospital Ingestion   │ │
│  │ (runs hourly)               │ │ (runs daily at 3am)         │ │
│  │                             │ │                             │ │
│  │ Air Quality (Last 30 Days)  │ │ Hospital Capacity (30 Days) │ │
│  │ [Line Chart]                │ │ [Bar Chart]                │ │
│  │ PM2.5 and O3 levels         │ │ Total beds vs Occupied      │ │
│  │                             │ │                             │ │
│  │ Data from: OpenAQ API       │ │ Data from: Delphi Hospital  │ │
│  │ Filtered by: ZIP 12345      │ │ Filtered by: ZIP 12345      │ │
│  └─────────────────────────────┘ └─────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────┐ ┌─────────────────────────────┐ │
│  │ JOB 3: FluView Ingestion    │ │ JOB 4: FDA Ingestion         │ │
│  │ (runs weekly, Monday 2am)   │ │ (runs daily at 4am)         │ │
│  │                             │ │                             │ │
│  │ Influenza Activity (12 Wks) │ │ FDA Recalls (30 Days)       │ │
│  │ Region: National            │ │ State: All States           │ │
│  │ [Line Chart]                │ │ [Bar Chart]                  │ │
│  │ Weighted ILI percentage     │ │ Recalls per day             │ │
│  │                             │ │                             │ │
│  │ Data from: Delphi FluView   │ │ Data from: openFDA API      │ │
│  │ Filtered by: Region (nat)   │ │ Filtered by: State (optional)│ │
│  └─────────────────────────────┘ └─────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Health Facilities Map                                       │ │
│  │ [MapLibre Map showing hospitals in ZIP 12345]               │ │
│  │ Shows: Hospital locations from Hospital Ingestion Job       │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Ask Questions About Health Data                             │ │
│  │ [Chat interface]                                             │ │
│  │ Uses: FastAPI LLM service (LangChain + Ollama)              │ │
│  │ Queries: All 4 data sources via Oracle database            │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## What Each Job Shows on Screen

### JOB 1: OpenAQ Ingestion (Hourly)
**Chart Location:** Top Left
- **Chart Type:** Line chart (2 lines: PM2.5 and O3)
- **Title:** "Air Quality (Last X Days)" - X changes based on dropdown
- **Data Shown:** Air pollution measurements for the ZIP code
- **Updates:** Every hour when job runs
- **Filter:** Automatically filtered by ZIP code you entered

### JOB 2: Delphi Hospital Ingestion (Daily at 3am)
**Chart Location:** Top Right
- **Chart Type:** Bar chart (2 bars: Total Beds vs Occupied Beds)
- **Title:** "Hospital Capacity (Last X Days)" - X changes based on dropdown
- **Data Shown:** Hospital bed availability in your ZIP code
- **Updates:** Once per day
- **Filter:** Automatically filtered by ZIP code you entered

### JOB 3: Delphi FluView Ingestion (Weekly, Monday 2am)
**Chart Location:** Bottom Left
- **Chart Type:** Line chart (1 line: Weighted ILI %)
- **Title:** "Influenza Activity (Last X Weeks) - Region: Y" 
- **Data Shown:** Flu activity level (national or state-level)
- **Updates:** Once per week
- **Filter:** You can select National, Auto-detect, or any state from dropdown

### JOB 4: FDA Enforcement Ingestion (Daily at 4am)
**Chart Location:** Bottom Right
- **Chart Type:** Bar chart (bars showing recalls per day)
- **Title:** "FDA Recalls (Last X Days) - State: Y" or "All States"
- **Data Shown:** Drug recalls and enforcement actions
- **Updates:** Once per day
- **Filter:** Optional - you can filter by state or see all states

## Map Section
- Shows hospitals from **Job 2 (Hospital Ingestion)**
- Markers show hospital locations in your ZIP code
- Map center is based on air quality station location from **Job 1 (OpenAQ)**

## Chat Section
- Uses **FastAPI LLM Service** (not a job, but a service)
- Can answer questions about data from all 4 jobs
- Queries Oracle database using LangChain tools
- Uses Ollama (local AI) to generate answers

## Summary Table

| Job Name | Schedule | Chart Position | What It Shows | Filtered By |
|----------|----------|----------------|---------------|-------------|
| OpenAQ | Hourly | Top Left | Air Quality (PM2.5, O3) | ZIP Code |
| Hospital | Daily 3am | Top Right | Hospital Beds | ZIP Code |
| FluView | Weekly Mon 2am | Bottom Left | Flu Activity | Region/State (selectable) |
| FDA | Daily 4am | Bottom Right | Drug Recalls | State (optional) |

