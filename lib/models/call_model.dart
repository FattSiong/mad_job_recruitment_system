class CallModel {
  final String callID;
  final String callerID;
  final String receiverID;
  final String roomCode;
  final String status;
  final DateTime startedAt;

  CallModel({
    required this.callID,
    required this.callerID,
    required this.receiverID,
    required this.roomCode,
    required this.status,
    required this.startedAt,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      callID: json['callID'],
      callerID: json['callerID'],
      receiverID: json['receiverID'],
      roomCode: json['roomCode'],
      status: json['status'],
      startedAt: DateTime.parse(json['startedAt']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callerID': callerID,
      'receiverID': receiverID,
      'roomCode': roomCode,
      'status': status,
    };
  }
}