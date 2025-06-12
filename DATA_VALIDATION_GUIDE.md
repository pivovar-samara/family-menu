# Data Validation & Population System Guide

## Overview
This system ensures that the app's static data (units, meal types, dish categories, and preloaded products/dishes) stays consistent across app versions and localization changes.

## How It Works

### 1. Version Tracking
- Each preload data schema has a version number (`currentPreloadDataVersion` in `PersistenceController`)
- The system stores the last loaded version in `UserDefaults`
- When versions don't match, the system triggers re-population

### 2. Data Validation
The system validates:
- **Units**: Correct names and sort orders
- **MealTypes**: Correct names and sort orders  
- **DishCategories**: Correct names and sort orders
- **Counts**: Expected number of entities

### 3. Smart Re-population
When outdated data is detected:
- Only static reference data is cleared (preserves user dishes, menus, etc.)
- New data is loaded from the appropriate localized `preloadData.json`
- Version is updated to mark data as current

## Usage

### For Development

#### Debug Tab (DEBUG builds only)
The app includes a debug tab with tools to:
- Check data version and validity status
- Force schema updates
- Clear all data
- Regenerate initial data
- Manage static data cache

#### Manual Testing