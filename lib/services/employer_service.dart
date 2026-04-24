import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company_model.dart';
import '../models/job_model.dart';
import '../models/company_member_model.dart';
import 'dart:io';
import '../core/constants/table_constants.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmployerService {
  // Get the single instance of our Supabase client
  final _supabase = Supabase.instance.client;

  /// Inserts a new job posting into the database.
  /// Returns the newly created JobModel if successful.
  Future<JobModel?> createJobPosting(JobModel newJob) async {
    try {
      // 1. Tell Supabase to go to the 'Job' table
      // 2. Insert the JSON version of our Dart model
      // 3. .select() asks Supabase to hand the newly created row back to us
      final response = await _supabase
          .from(TableConstants.job) // Make sure this matches your exact table name in Supabase
          .insert(newJob.toJson())
          .select()
          .single(); // We only expect one row back

      // Convert the successful database response back into a Dart Model
      return JobModel.fromJson(response);

    } on PostgrestException catch (e) {
      // This catches database-specific errors (like missing foreign keys)
      print('Database Error creating job: ${e.message}');
      return null;
    } catch (e) {
      // This catches general errors (like no internet connection)
      print('Unexpected Error creating job: $e');
      return null;
    }
  }

  /// Registers a new company AND links the creating employer to it.
  Future<CompanyModel?> registerCompany(CompanyModel newCompany, String employerId) async {
    try {
      // 1. Insert the company and get the generated row back
      final response = await _supabase
          .from(TableConstants.company)
          .insert(newCompany.toJson())
          .select()
          .single();

      final createdCompany = CompanyModel.fromJson(response);

      // 2. If successful, immediately link the employer in the CompanyMember table
      if (createdCompany.companyID != null) {
        final newMember = CompanyMemberModel(
          companyID: createdCompany.companyID!,
          employerID: employerId,
          companyRole: 'owner',
        );

        await _supabase
            .from(TableConstants.companyMember)
            .insert(newMember.toJson());
      }

      return createdCompany; // Return the company so the UI can show a success message

    } on PostgrestException catch (e) {
      print('🔥🔥🔥 Database Error registering company: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected Error registering company: $e');
      return null;
    }
  }

  Future<String?> uploadVerificationDocument(File documentFile, String companyName) async {
    try {
      // Create a unique file name using the timestamp to prevent overwriting
      final fileName = '${companyName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Upload to the 'verification_documents' bucket
      await _supabase.storage
          .from('verification_documents')
          .upload(fileName, documentFile);

      // Get the public URL to save in our database
      final publicUrl = _supabase.storage
          .from('verification_documents')
          .getPublicUrl(fileName);

      return publicUrl;

    } catch (e) {
      print('Error uploading document: $e');
      return null;
    }
  }

  /// Fetches companies based on the user's role.
  /// Admins see all companies. Employers only see their own.
  Future<List<CompanyModel>> getCompanies(String userId, String role) async {
    try {
      if (role == 'admin') {
        // Admins fetch everything to moderate
        final response = await _supabase
            .from(TableConstants.company)
            .select()
            .order('createdAt', ascending: false); // Optional: newest first

        return (response as List).map((json) => CompanyModel.fromJson(json)).toList();

      } else if (role == 'employer') {
        // 1. Find all company IDs this specific employer belongs to
        final memberResponse = await _supabase
            .from(TableConstants.companyMember)
            .select('companyID')
            .eq('employerID', userId);

        if (memberResponse.isEmpty) return [];

        // Extract just the IDs into a list
        final List<dynamic> companyIds = memberResponse.map((m) => m['companyID']).toList();

        // 2. Fetch the actual company details for those IDs
        final companyResponse = await _supabase
            .from(TableConstants.company)
            .select()
            .filter('companyID', 'in', companyIds);

        return (companyResponse as List).map((json) => CompanyModel.fromJson(json)).toList();
      }

      return []; // Return empty if role is not recognized
    } catch (e) {
      print('Error fetching companies: $e');
      return [];
    }
  }

  /// Fetches all jobs posted by a specific employer
  Future<List<JobModel>> getEmployerJobs(String employerId) async {
    try {
      final response = await _supabase
          .from(TableConstants.job)
          .select()
          .eq('employerID', employerId)
          .order('createdAt', ascending: false); // Show the newest jobs first

      return (response as List).map((json) => JobModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching jobs: $e');
      return [];
    }
  }

  /// Simulated AI Salary Suggestion
  Future<Map<String, String>> getAiSalarySuggestion(String jobTitle, String jobDescription, int minExperience, String jobType) async {
    try {
      // 1. Retrieve the hidden API key
      final apiKey = 'AIzaSyCPF5BiUdWIoroAWm42IhiUfxDMkQzFJ6U';

      // 2. Initialize the Flash model
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
      );

      String prompt;

      if (jobType == 'Part-time') {
        prompt = '''
        You are an expert HR recruiter in Malaysia. 
        Analyze the following part-time job details and suggest a realistic HOURLY salary rate in RM.
        
        Job Title: "$jobTitle"
        Minimum Experience Required: $minExperience years
        Description: "$jobDescription"
        
        Return ONLY a valid JSON object with the "min" key containing the hourly rate, and the "max" key completely empty.
        Example: {"min": "15", "max": ""}
        ''';
      } else {
        prompt = '''
        You are an expert HR recruiter in Malaysia. 
        Analyze the following full-time job details and suggest a realistic MONTHLY salary range in RM.
        
        Job Title: "$jobTitle"
        Minimum Experience Required: $minExperience years
        Description: "$jobDescription"
        
        Return ONLY a valid JSON object with exactly two keys: "min" and "max". 
        Example: {"min": "4000", "max": "6000"}
        ''';
      }

      // 4. Send to Gemini
      final response = await model.generateContent([Content.text(prompt)]);
      final String? responseText = response.text;

      if (responseText != null && responseText.isNotEmpty) {
        // Parse the JSON string into a Dart Map
        final Map<String, dynamic> jsonMap = jsonDecode(responseText.trim());
        return {
          'min': jsonMap['min'].toString(),
          'max': jsonMap['max'].toString(),
        };
      }
    } catch (e) {
      print('AI Error: $e');
    }

    // 5. Fallback just in case the AI fails or the user has no internet
    return {'min': '3000', 'max': '4500'};
  }
}