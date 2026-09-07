# RepairMitra Android App

The Android app is a thin native WebView shell around the RepairMitra web application. It is designed to keep the existing Supabase-backed customer, vendor and admin flows in one installable Android app.

## Build
Open this `android-app` folder in Android Studio and build a debug APK with **Build > Build APK(s)**.

The app loads the production GitHub Pages site and supports JavaScript, DOM storage, file upload and external links. The website remains the source of truth for the RepairMitra UI and backend flow.

## Required final live step
Run `store_setup.sql` in the linked Supabase project's SQL Editor before testing Shop → Cart → Order → Stock Auto-Reduce. The SQL file contains the transactional order function and RLS policies.
