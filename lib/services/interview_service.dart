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
        'employerHasLeft': false,
        'seekerHasLeft': false,
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

  // 👉 4. Real-time listener for the Job Seeker's Lobby & Call Screen
  // Filter client-side in Dart to avoid Supabase Realtime camelCase `.eq('roomID', ...)` filter mismatches.
  Stream<List<Map<String, dynamic>>> listenToInterviewStatus(String interviewRoomID) {
    return _supabase
        .from('InterviewRoom')
        .stream(primaryKey: ['roomID'])
        .map(
          (rows) => rows
              .where((row) => row['roomID']?.toString() == interviewRoomID)
              .toList(),
        );
  }

  /// Fetches the latest room record directly from Supabase.
  Future<Map<String, dynamic>?> getRoomById(String interviewRoomID) async {
    try {
      return await _supabase
          .from('InterviewRoom')
          .select()
          .eq('roomID', interviewRoomID)
          .maybeSingle();
    } catch (e) {
      print('Error fetching room by ID: $e');
      return null;
    }
  }

  Future<void> leaveInterview(String currentRoomID, bool isEmployer) async {
    // ⚠️ IMPORTANT: Change 'roomID' below to whatever your primary key column is named in Supabase!
    const String primaryKeyColumn = 'roomID';

    try {
      // 1. Fetch current room state
      final room = await _supabase
          .from('InterviewRoom')
          .select()
          .eq(primaryKeyColumn, currentRoomID)
          .single();

      // 2. Determine who has left
      final bool employerLeft = isEmployer ? true : (room['employerHasLeft'] ?? false);
      final bool seekerLeft = !isEmployer ? true : (room['seekerHasLeft'] ?? false);

      // 3. If BOTH have left, RESET the room so it can be restarted later!
      if (employerLeft && seekerLeft) {
        await _supabase.from('InterviewRoom').update({
          'status': 'waiting', // 👉 Reverts to the starting state instead of 'completed'
          'roomCode': null,    // 👉 Destroys the current meeting link
          'employerHasLeft': true,
          'seekerHasLeft': true,
        }).eq(primaryKeyColumn, currentRoomID);
      } else {
        // 4. Otherwise, just update the flag that THIS specific user left.
        await _supabase.from('InterviewRoom').update({
          isEmployer ? 'employerHasLeft' : 'seekerHasLeft': true,
        }).eq(primaryKeyColumn, currentRoomID);
      }
    } catch (e) {
      print('Error leaving interview: $e');
    }
  }

  // Also update markUserAsJoined just to be safe!
  Future<void> markUserAsJoined(String currentRoomID, bool isEmployer) async {
    const String primaryKeyColumn = 'roomID'; // ⚠️ Change this if needed
    try {
      await _supabase.from('InterviewRoom').update({
        isEmployer ? 'employerHasLeft' : 'seekerHasLeft': false,
      }).eq(primaryKeyColumn, currentRoomID);
    } catch (e) {
      print('Error marking user as joined: $e');
    }
  }

  Future<void> forceEndInterview(String currentRoomID) async {
    // ⚠️ IMPORTANT: Change 'roomID' below to whatever your primary key column is named!
    const String primaryKeyColumn = 'roomID';

    try {
      await _supabase.from('InterviewRoom').update({
        'status': 'waiting', // 👉 Reverts to the starting state
        'roomCode': null,    // 👉 Destroys the current meeting link
        'employerHasLeft': true,
        'seekerHasLeft': true,
      }).eq(primaryKeyColumn, currentRoomID);
    } catch (e) {
      print('Error resetting interview: $e');
    }
  }

  /// Allows a candidate (JobSeeker) to accept or reject a scheduled interview.
  Future<bool> respondToInterviewSchedule({
    required String scheduleID,
    required bool accept,
    String? rejectionReason,
    String? preferredTime,
  }) async {
    try {
      await _supabase
          .from('InterviewSchedule')
          .update({
            'candidateStatus': accept ? 'accepted' : 'rejected',
            'rejectionReason': accept ? null : rejectionReason?.trim(),
            'preferredTime': accept ? null : preferredTime?.trim(),
          })
          .eq('scheduleID', scheduleID);
      return true;
    } catch (e) {
      print('Error responding to interview schedule: $e');
      return false;
    }
  }
}
