import 'package:flutter/material.dart';

class InterviewScheduleModel {
  final String? scheduleID;
  final String applicantID;
  final DateTime date;
  final TimeOfDay startTime; // 👉 UPGRADED: Now uses TimeOfDay
  final TimeOfDay endTime;   // 👉 UPGRADED: Now uses TimeOfDay
  final String meetingMethod;
  final String? meetingLink;
  final String? interviewNote;

  InterviewScheduleModel({
    this.scheduleID,
    required this.applicantID,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.meetingMethod,
    this.meetingLink,
    this.interviewNote,
  });

  factory InterviewScheduleModel.fromJson(Map<String, dynamic> json) {
    // Helper function to turn Supabase's "14:30:00" into a Flutter TimeOfDay
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return InterviewScheduleModel(
      scheduleID: json['scheduleID'] as String?,
      applicantID: json['applicantID'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: parseTime(json['startTime'] as String), // 👉 Parses the time
      endTime: parseTime(json['endTime'] as String),     // 👉 Parses the time
      meetingMethod: json['meetingMethod'] as String,
      meetingLink: json['meetingLink'] as String?,
      interviewNote: json['interviewNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // Helper function to turn Flutter's TimeOfDay back into Supabase's "14:30:00"
    String formatTime(TimeOfDay time) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
    }

    return {
      if (scheduleID != null) 'scheduleID': scheduleID,
      'applicantID': applicantID,
      'date': date.toIso8601String().split('T')[0],
      'startTime': formatTime(startTime), // 👉 Formats for database
      'endTime': formatTime(endTime),     // 👉 Formats for database
      'meetingMethod': meetingMethod,
      if (meetingLink != null) 'meetingLink': meetingLink,
      if (interviewNote != null) 'interviewNote': interviewNote,
    };
  }
}