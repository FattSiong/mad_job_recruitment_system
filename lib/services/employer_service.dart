import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

      return (response as List).map((json) => JobModel.fromJson(json)).toList();
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

      return (response as List).map((json) => JobModel.fromJson(json)).toList();
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

      return (response as List).map((json) => JobModel.fromJson(json)).toList();
    } catch (e) {
      print('Fetch jobs by company error: $e');
      return [];
    }
  }

  /// Simulated AI Salary Suggestion
  Future<Map<String, String>> getAiSalarySuggestion(
    String jobTitle,
    String jobDescription,
    int minExperience,
    String jobType,
  ) async {
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
        prompt =
            '''
        You are an expert HR recruiter in Malaysia. 
        Analyze the following part-time job details and suggest a realistic HOURLY salary rate in RM.
        
        Job Title: "$jobTitle"
        Minimum Experience Required: $minExperience years
        Description: "$jobDescription"
        
        Return ONLY a valid JSON object with the "min" key containing the hourly rate, and the "max" key completely empty.
        Example: {"min": "15", "max": ""}
        ''';
      } else {
        prompt =
            '''
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

  Future<bool> updateJobStatus(String jobId, String newStatus) async {
    try {
      await _supabase
          .from(
            'Job',
          ) // Or TableConstants.job if you are using your constants file
          .update({'status': newStatus})
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
      // Safety check to ensure we know which row to update
      if (updatedJob.jobID == null) return false;

      await _supabase
          .from('Job') // Use TableConstants.job if you implemented it
          .update(updatedJob.toJson())
          .eq('jobID', updatedJob.jobID!);

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
          .select('*, Company(name)')
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
    String questionType,
  ) async {
    try {
      // 1. Initialize the Model
      // ⚠️ Note for FYP: Hardcoding the API key is fine for testing, but for production
      // or public GitHub repos, it's best to hide this in a .env file using flutter_dotenv!
      final apiKey = 'AIzaSyCPF5BiUdWIoroAWm42IhiUfxDMkQzFJ6U';
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
      );

      // 2. Build a highly specific Prompt
      String prompt =
          '''
            You are an expert HR recruiter. You need to write ONE pre-screening interview question for a candidate applying for the role of "$jobTitle".
          ''';

      // Inject the job description only if the user typed one
      if (jobDesc.isNotEmpty) {
        prompt += 'Here is the job description for context: "$jobDesc"\n\n';
      }

      // Change the AI's goal based on what the employer wants
      if (questionType == 'File') {
        prompt += '''
          The candidate must answer this question by UPLOADING A FILE. 
          Write a professional request asking them to upload a relevant portfolio, document, certificate, or code sample to prove their skills.
        ''';
      } else {
        prompt += '''
          The candidate must answer this question by TYPING TEXT.
          Write a professional interview question to test their experience, situational judgment, or technical knowledge.
        ''';
      }

      // 3. The Constraint Rule (Stops the AI from saying "Here is your question:")
      prompt += '''
          \nCRITICAL INSTRUCTION: Output ONLY the question/request itself. Do not use quotation marks, bullet points, introductory text, or conversational filler.
        ''';

      // 4. Send to Gemini
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      // 5. Clean and return the result
      if (response.text != null && response.text!.isNotEmpty) {
        // .trim() removes extra spaces/newlines, .replaceAll removes accidental quotes
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
      // We use a JOIN to grab the applicant's data AND their JobSeeker profile (for their name)
      final response = await _supabase
          .from('JobApplicant')
          .select('*, JobSeeker(*)')
          .eq('jobID', jobId)
          .order('appliedAt', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Fetch applicants error: $e');
      return [];
    }
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

      // 1. Insert into the InterviewSchedule table AND return the new row
      // We need .select().single() so we can grab the auto-generated scheduleID!
      final scheduleResponse = await _supabase
          .from('InterviewSchedule')
          .insert({
            'applicantID': applicantId,
            'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
            'startTime': startStr,
            'endTime': endStr,
            'meetingMethod': meetingMethod,
            'meetingLink': meetingLink,
          })
          .select('scheduleID')
          .single();

      final generatedScheduleId = scheduleResponse['scheduleID'];

      // 2. 👉 NEW: If it's an internal meeting, create the Waiting Room!
      if (meetingMethod == 'internal') {
        await _supabase.from('InterviewRoom').insert({
          'scheduleID': generatedScheduleId,
          'employerID': currentUser.id,
          'seekerID': seekerId,
          'status': 'pending',
          // roomCode, startedAt, and endedAt will naturally be null upon creation
        });
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
      // Note: This assumes your Supabase Foreign Keys are set up correctly between
      // InterviewSchedule -> JobApplicant -> JobSeeker & JobPost.
      // If your RLS policies are set correctly, this will only return the employer's interviews.
      final response = await _supabase
          .from('InterviewSchedule')
          .select('''
            *,
            JobApplicant (
              applicantID,
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
