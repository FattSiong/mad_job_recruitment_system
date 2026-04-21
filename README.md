# mad_job_recruitment_system

# Project Folder Structure Guide

To keep our codebase clean and prevent merge conflicts, we are using a Feature-First (Modular) architecture. All our code lives inside the `lib/` directory. Below is a breakdown of what each folder is for.

## 📂 `lib/core/`
This folder contains global settings and configurations that are shared across the entire app, regardless of the module.
* **`constants/`**: Store static values here, such as Supabase table names, API keys (if applicable), and predefined layout spacing.
* **`theme/`**: All color palettes, text styles, and light/dark mode configurations.
* **`utils/`**: Helper functions used everywhere, like date formatters, input validators (e.g., checking if an email is valid), or error handlers.

## 📂 `lib/models/`
This folder contains our Dart data classes. Every table in our Supabase ERD should have a corresponding model here. 
* **Purpose**: To convert the raw JSON data we get from Supabase into Dart objects that are easy to work with in the UI. 
* *Examples*: `job_model.dart`, `user_model.dart`, `applicant_model.dart`.

## 📂 `lib/services/`
This folder handles all external communication, specifically our Supabase database queries and authentication.
* **`supabase_service.dart`**: The main initialization for the Supabase client.
* **`auth_service.dart`**: Logic for logging in, signing up, and handling user sessions.
* **Module Services**: Specific files like `employer_service.dart` or `job_seeker_service.dart` for handling the `SELECT`, `INSERT`, `UPDATE`, and `DELETE` queries relevant to those modules.

## 📂 `lib/modules/`
This is where the actual app screens and specific logic live. Every team member has their own dedicated workspace here to avoid stepping on each other's code. Inside each of these folders, you can create subfolders for `screens/`, `widgets/`, and `controllers/`.

* [cite_start]**`employer/`**: Managed by Tiong Fatt Siong[cite: 1]. [cite_start]This workspace contains the UI and logic for direct employers and recruitment agencies to manage job postings, view the Applicant Tracking System (ATS), and build pre-screening questions[cite: 1, 2, 5, 9].
* **`job_seeker/`**: Managed by Goh Kar Hang[cite: 17]. [cite_start]This workspace contains the job discovery dashboard, application tracker, and AI interview training features[cite: 17, 18, 22, 24].
* [cite_start]**`community/`**: Managed by Muk Jia Yao and Pan Zhi Heng[cite: 29]. [cite_start]This workspace is for the communication features, including in-app chat, community posts, and live video interview screens[cite: 29, 30, 31, 32].
* [cite_start]**`admin/`**: For the admin moderation features, handling company verification and job listing moderation[cite: 35, 36, 37].

## 📂 `lib/shared_widgets/`
This folder is for reusable UI components. If a UI element is going to be used by more than one person in different modules, build it here.
* **Purpose**: Ensures the app looks consistent and saves us from writing the same code twice.
* *Examples*: `custom_primary_button.dart`, `standard_text_field.dart`, `loading_indicator.dart`.
