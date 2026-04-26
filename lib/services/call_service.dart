import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/call_model.dart';

class CallService {
  final _supabase = Supabase.instance.client;

  // 1. Initiate a new call
  Future<CallModel> initiateCall(String callerID, String receiverID) async {
    try {
      final String roomCode = 'call_${DateTime.now().millisecondsSinceEpoch}';

      final response = await _supabase.from('Calls').insert({
        'callerID': callerID,
        'receiverID': receiverID,
        'roomCode': roomCode,
        'status': 'ringing'
      }).select().single();

      return CallModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to initiate call: $e');
    }
  }

  // 2. Update the status (used to answer, decline, or end)
  Future<void> updateCallStatus(String callID, String newStatus) async {
    try {
      await _supabase.from('Calls').update({'status': newStatus}).eq('callID', callID);
    } catch (e) {
      print('Error updating call status: $e');
    }
  }

  // 3. Listen to a specific call (used by the active call screen)
  Stream<CallModel?> listenToCallStatus(String callID) {
    return _supabase
        .from('Calls')
        .stream(primaryKey: ['callID'])
    // 👇 FIX: Filter out the exact call on the client side using Dart's .where()
        .map((list) {
      final targetCall = list.where((call) => call['callID'] == callID).toList();
      return targetCall.isNotEmpty ? CallModel.fromJson(targetCall.first) : null;
    });
  }

  // 4. Global Listener: Checks if ANYONE is calling YOU
  Stream<List<CallModel>> listenForIncomingCalls(String myUserID) {
    return _supabase
        .from('Calls')
        .stream(primaryKey: ['callID'])
    // 👇 FIX: Filter incoming calls manually in Dart to avoid the SDK error
        .map((list) => list
        .where((call) => call['receiverID'] == myUserID && call['status'] == 'ringing')
        .map((json) => CallModel.fromJson(json))
        .toList());
  }
}