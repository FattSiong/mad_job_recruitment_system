import 'package:supabase_flutter/supabase_flutter.dart';

class InterviewService {
  final _supabase = Supabase.instance.client;

  // 👉 1. Fetch the room using the scheduleID
  // The employer clicks "Start Video Call" on a schedule, so we use the scheduleID to find the linked room.
  Future<Map<String, dynamic>?> getRoomByScheduleId(String scheduleID) async {
    try {
      final response = await _supabase
          .from('InterviewRoom') // Make sure this matches your exact table name!
          .select()
          .eq('scheduleID', scheduleID)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching interview room: $e');
      return null;
    }
  }

  // 👉 2. Employer starts the interview
  // This changes the status, records the start time, and generates the unique room code!
  Future<String> startInterview(String interviewRoomID) async {
    try {
      // Generate a unique room code (You can replace this with an Agora token later if needed)
      final generatedRoomCode = 'room_${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('InterviewRoom')
          .update({
        'status': 'active',
        'roomCode': generatedRoomCode,
        'startedAt': DateTime.now().toIso8601String(), // Log exact start time
      })
          .eq('roomID', interviewRoomID);

      return generatedRoomCode;
    } catch (e) {
      print('Error starting interview: $e');
      throw Exception('Failed to start the interview.');
    }
  }

  // 👉 3. Employer or Seeker ends the interview
  Future<void> endInterview(String interviewRoomID) async {
    try {
      await _supabase
          .from('InterviewRoom')
          .update({
        'status': 'completed',
        'endedAt': DateTime.now().toIso8601String(), // Log exact end time
      })
          .eq('roomID', interviewRoomID);
    } catch (e) {
      print('Error ending interview: $e');
    }
  }

  // 👉 4. Real-time listener for the Job Seeker's Lobby
  // The seeker's app will quietly listen to this stream. When the employer triggers
  // startInterview() above, this stream will instantly push the new 'active' status and roomCode!
  Stream<List<Map<String, dynamic>>> listenToInterviewStatus(String interviewRoomID) {
    return _supabase
        .from('InterviewRoom')
        .stream(primaryKey: ['roomID'])
        .eq('roomID', interviewRoomID);
  }

  Future<void> markUserAsJoined(String interviewRoomID, bool isEmployer) async {
    try {
      await _supabase.from('InterviewRoom').update({
        isEmployer ? 'employerHasLeft' : 'seekerHasLeft': false,
      }).eq('interviewRoomID', interviewRoomID);
    } catch (e) {
      print('Error marking user as joined: $e');
    }
  }

  // 👉 REPLACED: Smart leave logic. Only closes the room if BOTH are gone!
  Future<void> leaveInterview(String interviewRoomID, bool isEmployer) async {
    try {
      // 1. Fetch current room state
      final room = await _supabase
          .from('InterviewRoom')
          .select()
          .eq('interviewRoomID', interviewRoomID)
          .single();

      // 2. Determine who is leaving and who has already left
      final bool employerLeft = isEmployer ? true : (room['employerHasLeft'] ?? false);
      final bool seekerLeft = !isEmployer ? true : (room['seekerHasLeft'] ?? false);

      // 3. If BOTH have left, end the interview permanently.
      if (employerLeft && seekerLeft) {
        await _supabase.from('InterviewRoom').update({
          'status': 'completed',
          'employerHasLeft': true,
          'seekerHasLeft': true,
          'endedAt': DateTime.now().toIso8601String(),
        }).eq('interviewRoomID', interviewRoomID);
      } else {
        // 4. Otherwise, just update the flag that THIS specific user left.
        await _supabase.from('InterviewRoom').update({
          isEmployer ? 'employerHasLeft' : 'seekerHasLeft': true,
        }).eq('interviewRoomID', interviewRoomID);
      }
    } catch (e) {
      print('Error leaving interview: $e');
    }
  }
}