import 'package:flutter/material.dart';

class InterviewScheduleModel {
  final String? scheduleID;
  final String applicantID;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String meetingMethod;
  final String? meetingLink;
  final String? interviewNote;
  final String candidateStatus; // 'pending', 'accepted', 'rejected'
  final String? rejectionReason;
  final String? preferredTime;

  InterviewScheduleModel({
    this.scheduleID,
    required this.applicantID,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.meetingMethod,
    this.meetingLink,
    this.interviewNote,
    this.candidateStatus = 'pending',
    this.rejectionReason,
    this.preferredTime,
  });

  factory InterviewScheduleModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return InterviewScheduleModel(
      scheduleID: json['scheduleID'] as String?,
      applicantID: json['applicantID'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: parseTime(json['startTime'] as String),
      endTime: parseTime(json['endTime'] as String),
      meetingMethod: json['meetingMethod'] as String,
      meetingLink: json['meetingLink'] as String?,
      interviewNote: json['interviewNote'] as String?,
      candidateStatus:
          (json['candidateStatus'] ?? json['candidatestatus'] ?? 'pending')
              .toString(),
      rejectionReason:
          (json['rejectionReason'] ?? json['rejectionreason']) as String?,
      preferredTime:
          (json['preferredTime'] ?? json['preferredtime']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    String formatTime(TimeOfDay time) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
    }

    return {
      if (scheduleID != null) 'scheduleID': scheduleID,
      'applicantID': applicantID,
      'date': date.toIso8601String().split('T')[0],
      'startTime': formatTime(startTime),
      'endTime': formatTime(endTime),
      'meetingMethod': meetingMethod,
      if (meetingLink != null) 'meetingLink': meetingLink,
      if (interviewNote != null) 'interviewNote': interviewNote,
      'candidateStatus': candidateStatus,
      'rejectionReason': rejectionReason,
      'preferredTime': preferredTime,
    };
  }
}
