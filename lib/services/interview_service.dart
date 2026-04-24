import 'package:supabase_flutter/supabase_flutter.dart';

class InterviewService {
  final _supabase = Supabase.instance.client;

  // 1. Employer starts the interview
  Future<void> startInterview(String interviewID) async {
    await _supabase
        .from('Interviews')
        .update({'status': 'active'})
        .eq('interviewID', interviewID);
  }

  // 2. Employer or Seeker ends the interview
  Future<void> endInterview(String interviewID) async {
    await _supabase
        .from('Interviews')
        .update({'status': 'completed'})
        .eq('interviewID', interviewID);
  }

  // 3. Real-time listener for the Job Seeker's Lobby
  Stream<List<Map<String, dynamic>>> listenToInterviewStatus(String interviewID) {
    return _supabase
        .from('Interviews')
        .stream(primaryKey: ['interviewID'])
        .eq('interviewID', interviewID);
  }


  // Add this inside InterviewService class
  Future<Map<String, dynamic>> getOrCreateInterview(String employerID, String seekerID) async {
    try {
      // 1. Check if there is already an ongoing/waiting interview between them
      var existing = await _supabase
          .from('Interviews')
          .select()
          .eq('employerID', employerID)
          .eq('seekerID', seekerID)
          .neq('status', 'completed') // Ignore old, finished interviews
          .maybeSingle();

      if (existing != null) return existing;

      // 2. If no active interview exists, generate a brand new one
      final newInterview = await _supabase
          .from('Interviews')
          .insert({
        'employerID': employerID,
        'seekerID': seekerID,
        'roomCode': 'room_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'waiting'
      })
          .select()
          .single();

      return newInterview;
    } catch (e) {
      print('Error creating interview: $e');
      throw Exception('Failed to create interview room.');
    }
  }
}