import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company_model.dart';
import '../models/job_model.dart';
import '../models/company_member_model.dart';
import 'dart:io';
import 'dart:typed_data';
import '../core/constants/table_constants.dart';
import '../core/utils/storage_url_helper.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class EmployerService {
  // Get the single instance of our Supabase client
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getEmployerProfile(String employerId) async {
    try {
      return await _supabase
          .from(TableConstants.employer)
          .select('fullName, email, profilePictureURL')
          .eq('employerID', employerId)
          .maybeSingle();
    } catch (e) {
      print('Fetch employer profile error: $e');
      return null;
    }
  }

  /// Inserts a new job posting into the database.
  /// Returns the newly created JobModel if successful.
  Future<JobModel?> createJobPosting(JobModel newJob) async {
    try {
      // 1. Tell Supabase to go to the 'Job' table
      // 2. Insert the JSON version of our Dart model
      // 3. .select() asks Supabase to hand the newly created row back to us
      final response = await _supabase
          .from(
            TableConstants.job,
          ) // Make sure this matches your exact table name in Supabase
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
  Future<CompanyModel?> registerCompany(
    CompanyModel newCompany,
    String employerId,
  ) async {
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

  Future<String?> uploadVerificationDocument(
    File documentFile,
    String companyName,
  ) async {
    try {
      // Create a unique file name using the timestamp to prevent overwriting
      final fileName =
          '${companyName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

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

        return (response as List)
            .map((json) => CompanyModel.fromJson(json))
            .toList();
      } else if (role == 'employer') {
        // 1. Find all company IDs this specific employer belongs to
        final memberResponse = await _supabase
            .from(TableConstants.companyMember)
            .select('companyID')
            .eq('employerID', userId)
            .eq('status', 'active');

        if (memberResponse.isEmpty) return [];

        // Extract just the IDs into a list
        final List<dynamic> companyIds = memberResponse
            .map((m) => m['companyID'])
            .toList();

        // 2. Fetch the actual company details for those IDs
        final companyResponse = await _supabase
            .from(TableConstants.company)
            .select()
            .filter('companyID', 'in', companyIds);

        return (companyResponse as List)
            .map((json) => CompanyModel.fromJson(json))
            .toList();
      }

      return []; // Return empty if role is not recognized
    } catch (e) {
      print('Error fetching companies: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCompanyMembers(String companyId) async {
    try {
      // We query the CompanyMember table and join it with your public Employer profile table
      // Note: Ensure your public profile table is named 'Employer' and has 'name' and 'email'
      final response = await _supabase
          .from('CompanyMember')
          .select(
            'companyRole, status, employerID, Employer(fullName:fullName, email:email, profilePictureURL:profilePictureURL)',
          )
          .eq('companyID', companyId)
          .order(
            'companyRole',
            ascending: false,
          ); // This puts 'owner' at the top of the list!

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Fetch members error: $e');
      return [];
    }
  }

  Future<List<JobModel>> _syncExpiredJobs(List<JobModel> jobs) async {
    final List<JobModel> updatedList = [];
    for (final job in jobs) {
      if (job.status.toLowerCase() == 'active' && job.isExpired) {
        if (job.jobID != null) {
          await updateJobStatus(job.jobID!, 'inactive');
        }
        updatedList.add(job.copyWith(status: 'inactive'));
      } else {
        updatedList.add(job);
      }
    }
    return updatedList;
  }

  Future<List<JobModel>> getEmployerJobs(
    String employerId, {
    bool includeDeleted = false,
  }) async {
    try {
      var query = _supabase
          .from(TableConstants.job)
          .select()
          .eq('employerID', employerId);

      if (!includeDeleted) {
        query = query.neq('status', 'deleted');
      }

      final response = await query.order('createdAt', ascending: false);

      final jobs = (response as List).map((json) => JobModel.fromJson(json)).toList();
      return await _syncExpiredJobs(jobs);
    } catch (e) {
      print('Error fetching jobs: $e');
      return [];
    }
  }

  Future<List<JobModel>> getWorkspaceJobsForEmployer(
    String employerId, {
    bool includeDeleted = false,
  }) async {
    try {
      final memberResponse = await _supabase
          .from(TableConstants.companyMember)
          .select('companyID')
          .eq('employerID', employerId)
          .eq('status', 'active');

      if (memberResponse.isEmpty) return [];

      final companyIds = memberResponse
          .map((item) => item['companyID'])
          .whereType<String>()
          .toSet()
          .toList();

      if (companyIds.isEmpty) return [];

      var query = _supabase
          .from(TableConstants.job)
          .select()
          .filter('companyID', 'in', companyIds);

      if (!includeDeleted) {
        query = query.neq('status', 'deleted');
      }

      final response = await query.order('createdAt', ascending: false);

      final jobs = (response as List).map((json) => JobModel.fromJson(json)).toList();
      return await _syncExpiredJobs(jobs);
    } catch (e) {
      print('Error fetching workspace jobs: $e');
      return [];
    }
  }

  Future<List<CompanyModel>> getMyAcceptedCompanies() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      // Query the CompanyMember table and join the actual Company data
      final response = await _supabase
          .from('CompanyMember')
          .select(
            'status, Company(*)',
          ) // Pulls everything from the linked Company table
          .eq('employerID', currentUser.id)
          .eq('status', 'active'); // 👉 SECURITY CHECK: Must be accepted

      // Parse the joined data back into your CompanyModel list
      final List<CompanyModel> companies = [];
      for (var row in response) {
        if (row['Company'] != null) {
          companies.add(CompanyModel.fromJson(row['Company']));
        }
      }

      return companies;
    } catch (e) {
      print('Fetch accepted companies error: $e');
      return [];
    }
  }

  Future<List<JobModel>> getJobsByCompanyId(
    String companyId, {
    bool includeDeleted = false,
  }) async {
    try {
      var query = _supabase.from('Job').select().eq('companyID', companyId);

      if (!includeDeleted) {
        query = query.neq('status', 'deleted');
      }

      final response = await query.order('createdAt', ascending: false);

      final jobs = (response as List).map((json) => JobModel.fromJson(json)).toList();
      return await _syncExpiredJobs(jobs);
    } catch (e) {
      print('Fetch jobs by company error: $e');
      return [];
    }
  }

  /// AI Salary Suggestion tailored to Malaysian job market and full job context
  Future<Map<String, String>> getAiSalarySuggestion(
    String jobTitle,
    String jobDescription,
    int minExperience,
    String jobType, {
    String workplaceType = 'On-site',
    String workingPeriod = 'Mon - Fri, 9:00 AM - 6:00 PM',
    String qualification = 'No Minimum',
    String? locationName,
  }) async {
    try {
      // 1. Retrieve the hidden API key
      const apiKey = 'AIzaSyCPF5BiUdWIoroAWm42IhiUfxDMkQzFJ6U';

      // 2. Initialize the Flash model with JSON response mime type
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final locationContext =
          (locationName != null && locationName.trim().isNotEmpty)
              ? locationName.trim()
              : 'Malaysia';
      final descContext =
          jobDescription.trim().isEmpty ? 'Not provided' : jobDescription.trim();

      String prompt;

      if (jobType == 'Part-time') {
        prompt = '''
You are a Senior Compensation & Benefits HR Specialist in Malaysia.
Estimate a realistic HOURLY salary rate in Malaysian Ringgit (MYR / RM) based on the following part-time job details:

- Job Title: "$jobTitle"
- Employment Type: Part-time
- Work Arrangement: $workplaceType
- Working Schedule: $workingPeriod
- Minimum Qualification: $qualification
- Minimum Experience Required: $minExperience year(s)
- Work Location: $locationContext
- Job Description: "$descContext"

Guidelines:
1. Base your estimate on current Malaysian part-time market rates (accounting for location, qualification level, and experience).
2. Suggest a realistic integer hourly rate in RM (e.g., 10 to 50) in the "min" key, and leave the "max" key as an empty string "".
3. Return ONLY a valid JSON object with keys "min" and "max" containing numeric strings only (no "RM", commas, or text).
Example: {"min": "15", "max": ""}
''';
      } else {
        prompt = '''
You are a Senior Compensation & Benefits HR Specialist in Malaysia.
Estimate a realistic MONTHLY salary range in Malaysian Ringgit (MYR / RM) based on the following full-time job details:

- Job Title: "$jobTitle"
- Employment Type: Full-time
- Work Arrangement: $workplaceType
- Working Schedule: $workingPeriod
- Minimum Qualification: $qualification
- Minimum Experience Required: $minExperience year(s)
- Work Location: $locationContext
- Job Description: "$descContext"

Guidelines:
1. Base your estimate on current Malaysian full-time job market benchmarks (accounting for location such as Klang Valley vs other states, qualification level, work arrangement, and experience).
2. Respect Malaysia's minimum wage floor (at least RM 1700/month) and round both "min" and "max" to the nearest RM 100, with a realistic 15% to 30% spread between "min" and "max".
3. Return ONLY a valid JSON object with keys "min" and "max" containing numeric strings only (no "RM", commas, or text).
Example: {"min": "4000", "max": "5200"}
''';
      }

      // 4. Send to Gemini
      final response = await model.generateContent([Content.text(prompt)]);
      final String? responseText = response.text;

      if (responseText != null && responseText.isNotEmpty) {
        final cleanedJson = responseText
            .replaceAll(RegExp(r'```json|```'), '')
            .trim();
        final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson);
        return {
          'min': (jsonMap['min'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''),
          'max': (jsonMap['max'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''),
        };
      }
    } catch (e) {
      print('AI Error: $e');
    }

    // 5. Fallback just in case the AI fails or the user has no internet
    return jobType == 'Part-time'
        ? {'min': '15', 'max': ''}
        : {'min': '3000', 'max': '4500'};
  }

  Future<bool> updateJobStatus(
    String jobId,
    String newStatus, {
    DateTime? expiresAt,
  }) async {
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      if (expiresAt != null) {
        updateData['expiresAt'] = expiresAt.toUtc().toIso8601String();
      }

      await _supabase
          .from(TableConstants.job)
          .update(updateData)
          .eq('jobID', jobId);
      return true;
    } catch (e) {
      print('Error updating job status: $e');
      return false;
    }
  }

  /// Updates an existing job posting in the database.
  Future<bool> updateJobPosting(JobModel updatedJob) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      // Safety checks: must have jobID, must be the job owner, and must not be deleted
      if (updatedJob.jobID == null) return false;
      if (updatedJob.employerID != currentUser.id) return false;
      if (updatedJob.status.toLowerCase() == 'deleted') return false;

      await _supabase
          .from(TableConstants.job)
          .update(updatedJob.toJson())
          .eq('jobID', updatedJob.jobID!)
          .eq('employerID', currentUser.id)
          .neq('status', 'deleted');

      return true;
    } catch (e) {
      print('Error updating job: $e');
      return false;
    }
  }

  Future<String> sendInvitation(String companyId, String inviteeEmail) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return 'Not authenticated';

      // Verify the current user is the owner
      final ownerCheck = await _supabase
          .from('CompanyMember')
          .select('companyRole')
          .eq('companyID', companyId)
          .eq('employerID', currentUser.id)
          .maybeSingle();

      if (ownerCheck == null || ownerCheck['companyRole'] != 'owner') {
        return 'Only owners can invite members.';
      }

      // Call the secure database function to check auth.users
      final inviteeId = await _supabase.rpc(
        'get_user_id_by_email',
        params: {'lookup_email': inviteeEmail.trim().toLowerCase()},
      );

      if (inviteeId == null) {
        return 'No account found with this email. They must register first.';
      }

      // Prevent inviting yourself
      if (inviteeId == currentUser.id) {
        return 'You cannot invite yourself.';
      }

      // Check if they are already in the company (accepted or pending)
      final existingMember = await _supabase
          .from('CompanyMember')
          .select('status')
          .eq('companyID', companyId)
          .eq('employerID', inviteeId)
          .maybeSingle();

      if (existingMember != null) {
        return 'This user is already in the company or has a pending invite.';
      }

      // Insert the new member with a 'pending' status
      await _supabase.from('CompanyMember').insert({
        'companyID': companyId,
        'employerID': inviteeId,
        'companyRole': 'member',
        'status': 'pending',
      });

      return 'Success';
    } catch (e) {
      print('Invite error: $e');
      return 'An error occurred. Please try again.';
    }
  }

  /// 2. FETCH PENDING INVITATIONS
  Future<List<Map<String, dynamic>>> getMyPendingInvitations() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final response = await _supabase
          .from('CompanyMember')
          .select('*, Company(*)')
          .eq('employerID', currentUser.id)
          .eq('status', 'pending');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Fetch invites error: $e');
      return [];
    }
  }

  /// 3. RESPOND TO INVITATION
  Future<bool> respondToInvitation(String companyId, bool isAccepted) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      if (isAccepted) {
        await _supabase
            .from('CompanyMember')
            .update({'status': 'active'})
            .eq('companyID', companyId)
            .eq('employerID', currentUser.id);
      } else {
        await _supabase
            .from('CompanyMember')
            .delete()
            .eq('companyID', companyId)
            .eq('employerID', currentUser.id);
      }
      return true;
    } catch (e) {
      print('Respond error: $e');
      return false;
    }
  }

  // 👉 The REAL Gemini AI Question Generator
  Future<String> generateAiQuestion(
    String jobTitle,
    String jobDesc,
    String questionType, {
    String jobType = 'Full-time',
    String workplaceType = 'On-site',
    String workingPeriod = 'Mon - Fri, 9:00 AM - 6:00 PM',
    String qualification = 'No Minimum',
    int minExperience = 0,
    List<String> existingQuestions = const [],
  }) async {
    try {
      // 1. Initialize the Model
      const apiKey = 'AIzaSyCPF5BiUdWIoroAWm42IhiUfxDMkQzFJ6U';
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
      );

      final descContext =
          jobDesc.trim().isEmpty ? 'Not provided' : jobDesc.trim();
      final seniorityNote = minExperience == 0
          ? 'Entry-level / Fresh Graduate (0 years required — focus on foundational skills, projects, coursework, or adaptability rather than years of senior leadership).'
          : 'Requires at least $minExperience year(s) of relevant experience.';

      // 2. Build a rich, context-aware Prompt
      String prompt = '''
You are an expert HR Recruiter in Malaysia creating ONE pre-screening question for candidates applying for the following role:
- Job Title: "$jobTitle"
- Employment Type: $jobType ($workplaceType)
- Working Schedule: $workingPeriod
- Minimum Qualification: $qualification
- Experience Level: $seniorityNote
- Job Description: "$descContext"
''';

      if (questionType == 'File') {
        prompt += '''

Format Required: FILE UPLOAD
Write a clear, professional request (1-2 sentences max) asking the candidate to upload ONE specific, realistic supporting document relevant to "$jobTitle" and their qualification/experience level (for example: a portfolio PDF, project sample, certification, transcript, or work sample).
''';
      } else {
        prompt += '''

Format Required: TEXT ANSWER
Write ONE concise, practical pre-screening question (1-2 sentences max) that a candidate can answer in a short paragraph on a mobile app. Focus on role-specific problem solving, hands-on competency, situational judgment, or readiness for the $workplaceType / $workingPeriod arrangement.
''';
      }

      final nonEmptyExisting = existingQuestions
          .map((q) => q.trim())
          .where((q) => q.isNotEmpty)
          .toList();
      if (nonEmptyExisting.isNotEmpty) {
        prompt += '''

IMPORTANT — Avoid Duplicates:
The form already contains the following pre-screening question(s):
- ${nonEmptyExisting.join('\n- ')}
You MUST generate a completely different question covering a distinct topic or competency.
''';
      }

      // 3. The Constraint Rule (Stops the AI from saying "Here is your question:")
      prompt += '''

CRITICAL INSTRUCTION: Output ONLY the question/request text itself. Do not use quotation marks, numbering, bullet points, or introductory filler.
''';

      // 4. Send to Gemini
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      // 5. Clean and return the result
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim().replaceAll('"', '');
      }

      return '';
    } catch (e) {
      print('Gemini AI Gen Error: $e');
      return '';
    }
  }

  // 2. 👉 UPDATE: Modify the insert method to handle the isAIGenerated flag
  Future<bool> addPreScreeningQuestions(
    String jobId,
    List<Map<String, dynamic>> questionsData,
  ) async {
    try {
      if (questionsData.isEmpty) return true;

      final List<Map<String, dynamic>> dbPayload = questionsData.map((data) {
        return {
          'jobID': jobId,
          'questionText': data['text'],
          'questionType': data['type'],
          'isAIGenerated': data['isAIGenerated'] ?? false, // 👉 Now dynamic!
        };
      }).toList();

      await _supabase.from('PreScreeningQuestion').insert(dbPayload);
      return true;
    } catch (e) {
      print('Error saving questions: $e');
      return false;
    }
  }

  Future<bool> updateCompanyDetails({
    required String companyId,
    required String name,
    required String description,
    File? newLogoFile,
  }) async {
    try {
      String? finalLogoUrl;

      // 1. If they picked a new image, upload it first
      if (newLogoFile != null) {
        final fileExt = newLogoFile.path.split('.').last;
        final fileName =
            'company_$companyId\_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        // Ensure you have a 'company_logos' bucket created in your Supabase Storage!
        await _supabase.storage
            .from('company_logos')
            .upload(fileName, newLogoFile);
        finalLogoUrl = _supabase.storage
            .from('company_logos')
            .getPublicUrl(fileName);
      }

      // 2. Prepare the update payload
      final Map<String, dynamic> updateData = {
        'name': name,
        'description': description,
      };

      // Only update the logo URL if a new one was actually uploaded
      if (finalLogoUrl != null) {
        updateData['companyLogoURL'] =
            finalLogoUrl; // Make sure your DB has a 'logoURL' column!
      }

      // 3. Update the database
      await _supabase
          .from('Company') // Or TableConstants.company
          .update(updateData)
          .eq('companyID', companyId);

      return true;
    } catch (e) {
      print('Update Company Error: $e');
      return false;
    }
  }

  Future<bool> updateEmployerProfile({
    required String employerId,
    required String fullName,
    File? newProfileImage,
  }) async {
    try {
      String? finalProfileImageUrl;

      if (newProfileImage != null) {
        final fileExt = newProfileImage.path.split('.').last;
        final fileName =
            'employer_$employerId\_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await _supabase.storage
            .from('profile_pictures')
            .upload(fileName, newProfileImage);

        finalProfileImageUrl = _supabase.storage
            .from('profile_pictures')
            .getPublicUrl(fileName);
      }

      final Map<String, dynamic> updateData = {'fullName': fullName};

      if (finalProfileImageUrl != null) {
        updateData['profilePictureURL'] = finalProfileImageUrl;
      }

      await _supabase
          .from(TableConstants.employer)
          .update(updateData)
          .eq('employerID', employerId);

      return true;
    } catch (e) {
      print('Update Employer Profile Error: $e');
      return false;
    }
  }

  // 1. Fetch all applicants for a specific job
  Future<List<Map<String, dynamic>>> getJobApplicants(String jobId) async {
    try {
      dynamic response;
      try {
        response = await _supabase
            .from('JobApplicant')
            .select('*, JobSeeker(*, WorkExperience(*), Education(*))')
            .eq('jobID', jobId)
            .order('appliedAt', ascending: false);
      } catch (_) {
        response = await _supabase
            .from('JobApplicant')
            .select('*, JobSeeker(*)')
            .eq('jobID', jobId)
            .order('appliedAt', ascending: false);
      }

      final list = List<Map<String, dynamic>>.from(response);

      // Sort ranked applicants by highest AI match score first; unranked stay below sorted by appliedAt
      list.sort((a, b) {
        final scoreA = (a['aiRankingScore'] as num?)?.toDouble();
        final scoreB = (b['aiRankingScore'] as num?)?.toDouble();

        if (scoreA != null && scoreB != null) {
          final cmp = scoreB.compareTo(scoreA);
          if (cmp != 0) return cmp;
        } else if (scoreA != null) {
          return -1;
        } else if (scoreB != null) {
          return 1;
        }

        final dateA = DateTime.tryParse((a['appliedAt'] ?? '').toString());
        final dateB = DateTime.tryParse((b['appliedAt'] ?? '').toString());
        if (dateA != null && dateB != null) {
          return dateB.compareTo(dateA);
        }
        return 0;
      });

      return list;
    } catch (e) {
      print('Fetch applicants error: $e');
      return [];
    }
  }

  /// Extracts text from PDF bytes using Syncfusion PDF as supplementary context.
  String _extractPdfTextFallback(Uint8List bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text.trim();
    } catch (_) {
      return '';
    }
  }

  /// Evaluates a single applicant against the job requirements using Gemini AI
  /// and saves `aiRankingScore` + `aiFeedback` into `JobApplicant`.
  Future<bool> rankApplicantWithAI({
    required JobModel job,
    required Map<String, dynamic> applicantData,
  }) async {
    try {
      final applicantId = (applicantData['applicantID'] ?? '').toString();
      if (applicantId.isEmpty) return false;

      const apiKey = 'AIzaSyCPF5BiUdWIoroAWm42IhiUfxDMkQzFJ6U';
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
      );

      final seeker =
          (applicantData['JobSeeker'] as Map<String, dynamic>?) ?? {};
      final fullName = (seeker['fullName'] ?? 'Candidate').toString();
      final bio = (seeker['bio'] ?? '').toString().trim();
      final seekerLocation = (seeker['location'] ?? '').toString().trim();

      // Format structured WorkExperience & Education from profile if available
      final experiences = (seeker['WorkExperience'] as List?) ?? const [];
      final educations = (seeker['Education'] as List?) ?? const [];

      final expLines = experiences.map((e) {
        if (e is! Map) return '';
        final role = e['jobTitle'] ?? '';
        final company = e['companyName'] ?? '';
        final start = e['startDate'] ?? '';
        final end = (e['isCurrent'] == true) ? 'Present' : (e['endDate'] ?? '');
        final desc = (e['description'] ?? '').toString().trim();
        return '- $role at $company ($start to $end)${desc.isNotEmpty ? ': $desc' : ''}';
      }).where((s) => s.isNotEmpty).join('\n');

      final eduLines = educations.map((e) {
        if (e is! Map) return '';
        final degree = e['degree'] ?? '';
        final field = e['fieldOfStudy'] ?? '';
        final inst = e['institutionName'] ?? '';
        final start = e['startDate'] ?? '';
        final end = (e['isCurrent'] == true) ? 'Present' : (e['endDate'] ?? '');
        return '- $degree ${field.toString().isNotEmpty ? 'in $field ' : ''}at $inst ($start to $end)';
      }).where((s) => s.isNotEmpty).join('\n');

      // Fetch pre-screening answers
      final answers = await getApplicantAnswers(applicantId);
      final answerLines = answers.map((ans) {
        final q = ans['PreScreeningQuestion'] ?? {};
        final qText = (q['questionText'] ?? 'Question').toString();
        final qType = (q['questionType'] ?? 'Text').toString();
        final aText = (ans['answerText'] ?? '').toString().trim();
        final hasFile =
            (ans['answerFileURL'] ?? '').toString().trim().isNotEmpty;
        final responseDesc = qType == 'File'
            ? (hasFile ? '[Uploaded supporting document]' : '[No file uploaded]')
            : (aText.isNotEmpty ? aText : '[No answer provided]');
        return '- Q: $qText\n  A: $responseDesc';
      }).join('\n');

      // Download submitted resume PDF if available
      final resumeUrl =
          (applicantData['submittedResumeURL'] ?? '').toString().trim();
      Uint8List? resumePdfBytes;
      String extractedResumeText = '';

      if (resumeUrl.isNotEmpty && resumeUrl.startsWith('http')) {
        try {
          // Resumes are private: download through a signed URL
          final response = await http
              .get(Uri.parse(await StorageUrlHelper.resolve(resumeUrl)))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            resumePdfBytes = response.bodyBytes;
            extractedResumeText = _extractPdfTextFallback(resumePdfBytes);
          }
        } catch (e) {
          print('Resume download warning for $applicantId: $e');
        }
      }

      final jobLocation = (job.locationName ?? '').trim().isNotEmpty
          ? job.locationName!.trim()
          : 'Not specified';
      final workingPeriod = (job.workingPeriod ?? '').trim().isNotEmpty
          ? job.workingPeriod!.trim()
          : 'Not specified';

      final promptText = '''
You are an expert AI Technical Recruiter and Talent Evaluator.
Compare the following Job Requirements against the Candidate's Resume, Profile, and Pre-Screening Answers, then calculate an objective Match Score (0 to 100) and concise recruiter feedback.

=== JOB DETAILS & REQUIREMENTS ===
- Job Title: ${job.title}
- Employment Type: ${job.jobType}
- Work Arrangement: ${job.workplaceType}
- Working Schedule: $workingPeriod
- Minimum Qualification: ${job.qualification}
- Minimum Experience Required: ${job.minExperienceYears} year(s)
- Job Location: $jobLocation
- Offered Salary Range: ${job.salaryRange}
- Full Job Description:
${job.description}

=== CANDIDATE INFORMATION ===
- Candidate Name: $fullName
- Candidate Location: ${seekerLocation.isEmpty ? 'Not specified' : seekerLocation}
- Profile Summary / Bio: ${bio.isEmpty ? 'Not provided' : bio}
- Profile Education:
${eduLines.isEmpty ? 'None listed in profile (check attached resume)' : eduLines}
- Profile Work Experience:
${expLines.isEmpty ? 'None listed in profile (check attached resume)' : expLines}
- Pre-Screening Question Responses:
${answerLines.isEmpty ? 'No pre-screening questions for this job' : answerLines}
${extractedResumeText.isNotEmpty ? '\n=== EXTRACTED RESUME TEXT ===\n$extractedResumeText' : ''}

=== SCORING RUBRIC ===
Evaluate across:
1. Skills & Technical/Role Alignment with the Job Title and Description (40%)
2. Relevant Work Experience vs. Minimum Experience Required (${job.minExperienceYears} yrs) (30%)
3. Education / Qualification vs. Minimum Qualification (${job.qualification}) (15%)
4. Pre-Screening Answers & Overall Profile Completeness (15%)

Return ONLY a valid JSON object with the exact following keys (no markdown fences, no extra commentary):
{
  "score": <number from 0 to 100>,
  "feedback": "<2 to 3 concise sentences highlighting key matching strengths and any missing requirements or gaps>"
}
''';

      final List<Part> parts = [TextPart(promptText)];
      if (resumePdfBytes != null &&
          resumeUrl.toLowerCase().split('?').first.endsWith('.pdf')) {
        parts.add(DataPart('application/pdf', resumePdfBytes));
      }

      final aiResponse = await model.generateContent([Content.multi(parts)]);
      final rawText = aiResponse.text?.trim() ?? '';
      if (rawText.isEmpty) return false;

      // Clean potential markdown code fences around JSON
      String cleanedJson = rawText
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
          .trim();

      final startBrace = cleanedJson.indexOf('{');
      final endBrace = cleanedJson.lastIndexOf('}');
      if (startBrace != -1 && endBrace != -1 && endBrace > startBrace) {
        cleanedJson = cleanedJson.substring(startBrace, endBrace + 1);
      }

      final decoded = jsonDecode(cleanedJson) as Map<String, dynamic>;
      final rawScore = (decoded['score'] as num?)?.toDouble() ?? 0.0;
      final clampedScore = rawScore.clamp(0.0, 100.0).roundToDouble();
      final feedback = (decoded['feedback'] ?? '').toString().trim();

      await _supabase
          .from('JobApplicant')
          .update({
            'aiRankingScore': clampedScore,
            'aiFeedback': feedback.isEmpty ? null : feedback,
          })
          .eq('applicantID', applicantId);

      return true;
    } catch (e) {
      print('AI Ranking Error for applicant: $e');
      return false;
    }
  }

  /// Ranks all (or only unranked) candidates for a job and invokes [onProgress]
  /// after each candidate is processed. Returns the number of successfully ranked candidates.
  Future<int> rankJobCandidatesWithAI({
    required JobModel job,
    required List<Map<String, dynamic>> applicants,
    bool onlyUnranked = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    final targets = onlyUnranked
        ? applicants.where((a) => a['aiRankingScore'] == null).toList()
        : applicants;

    final total = targets.length;
    if (total == 0) return 0;

    int successCount = 0;
    int completed = 0;

    for (final applicant in targets) {
      final ok = await rankApplicantWithAI(
        job: job,
        applicantData: applicant,
      );
      if (ok) successCount++;
      completed++;
      onProgress?.call(completed, total);
    }

    return successCount;
  }

  // 2. Fetch the pre-screening answers for a specific applicant
  Future<List<Map<String, dynamic>>> getApplicantAnswers(
    String applicantId,
  ) async {
    try {
      // We JOIN with the PreScreeningQuestion table so we know what question they are answering!
      final response = await _supabase
          .from('ApplicationAnswer')
          .select('*, PreScreeningQuestion(questionText, questionType)')
          .eq('applicantID', applicantId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Fetch answers error: $e');
      return [];
    }
  }

  // 3. Update the candidate's application status
  Future<bool> updateApplicationStatus(
    String applicantId,
    String newStatus,
  ) async {
    try {
      await _supabase
          .from('JobApplicant')
          .update({'applicationStatus': newStatus})
          .eq('applicantID', applicantId);
      return true;
    } catch (e) {
      print('Update status error: $e');
      return false;
    }
  }

  // 👉 NEW: Save the interview schedule and update status
  Future<bool> scheduleInterview({
    required String applicantId,
    required String seekerId, // 👉 NEW: Required to link the room to the seeker
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String meetingMethod,
    String? meetingLink,
  }) async {
    try {
      // Grab the current employer's ID
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      // Format TimeOfDay into standard SQL time format (HH:MM:SS)
      final startStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
      final endStr =
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

      // 1. Check if an InterviewSchedule already exists for this applicant (e.g. rescheduling)
      final existingList = await _supabase
          .from('InterviewSchedule')
          .select('scheduleID')
          .eq('applicantID', applicantId)
          .limit(1);

      String generatedScheduleId;

      if (existingList.isNotEmpty) {
        generatedScheduleId = existingList.first['scheduleID'].toString();
        await _supabase
            .from('InterviewSchedule')
            .update({
              'date': date.toIso8601String().split('T')[0],
              'startTime': startStr,
              'endTime': endStr,
              'meetingMethod': meetingMethod,
              'meetingLink': meetingLink,
              'candidateStatus': 'pending',
              'rejectionReason': null,
              'preferredTime': null,
            })
            .eq('scheduleID', generatedScheduleId);
      } else {
        final scheduleResponse = await _supabase
            .from('InterviewSchedule')
            .insert({
              'applicantID': applicantId,
              'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
              'startTime': startStr,
              'endTime': endStr,
              'meetingMethod': meetingMethod,
              'meetingLink': meetingLink,
              'candidateStatus': 'pending',
              'rejectionReason': null,
              'preferredTime': null,
            })
            .select('scheduleID')
            .single();

        generatedScheduleId = scheduleResponse['scheduleID'].toString();
      }

      // 2. If it's an internal meeting, ensure the Waiting Room exists!
      if (meetingMethod == 'internal') {
        final existingRooms = await _supabase
            .from('InterviewRoom')
            .select('roomID')
            .eq('scheduleID', generatedScheduleId)
            .limit(1);

        if (existingRooms.isEmpty) {
          await _supabase.from('InterviewRoom').insert({
            'scheduleID': generatedScheduleId,
            'employerID': currentUser.id,
            'seekerID': seekerId,
            'status': 'pending',
          });
        } else {
          await _supabase
              .from('InterviewRoom')
              .update({
                'status': 'pending',
                'roomCode': null,
                'employerHasLeft': false,
                'seekerHasLeft': false,
              })
              .eq('scheduleID', generatedScheduleId);
        }
      }

      // 3. Update the JobApplicant status to 'scheduled'
      await updateApplicationStatus(applicantId, 'scheduled');

      return true;
    } catch (e) {
      print('Schedule Interview Error: $e');
      return false;
    }
  }

  // 👉 NEW: Fetch all scheduled interviews with candidate & job details
  Future<List<Map<String, dynamic>>> getScheduledInterviews() async {
    try {
      final response = await _supabase
          .from('InterviewSchedule')
          .select('''
            *,
            JobApplicant (
              applicantID,
              seekerID,
              applicationStatus,
              JobSeeker (fullName, email),
              Job (title, status)
            )
          ''')
          .order('date', ascending: true)
          .order('startTime', ascending: true);

      final rows = List<Map<String, dynamic>>.from(response);

      return rows.where((item) {
        final applicant = item['JobApplicant'] ?? {};
        final job = applicant['Job'] ?? {};
        final jobStatus = (job['status'] ?? '').toString().toLowerCase();

        return jobStatus != 'deleted';
      }).toList();
    } catch (e) {
      print('Error fetching schedule: $e');
      return [];
    }
  }

  Future<bool> markInterviewAsCompleted(
    String applicantId,
    String? scheduleId,
  ) async {
    try {
      // 1. Update the candidate's ATS status to 'interviewed'
      await _supabase
          .from('JobApplicant')
          .update({'applicationStatus': 'interviewed'})
          .eq('applicantID', applicantId);

      // 2. Permanently close the room to prevent anyone from rejoining
      if (scheduleId != null) {
        await _supabase
            .from('InterviewRoom')
            .update({
              'status': 'completed',
              'employerHasLeft': true,
              'seekerHasLeft': true,
              'endedAt': DateTime.now().toIso8601String(),
            })
            .eq('scheduleID', scheduleId);
      }

      return true;
    } catch (e) {
      print('Error marking interview as completed: $e');
      return false;
    }
  }

  Future<CompanyModel?> getCompanyById(String companyId) async {
    try {
      final response = await _supabase
          .from('Company')
          .select()
          .eq('companyID', companyId)
          .single();

      return CompanyModel.fromJson(response);
    } catch (e) {
      print('Fetch company by ID error: $e');
      return null;
    }
  }
}
