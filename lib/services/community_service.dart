import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import 'dart:io'; // Make sure this is at the top of the file

class CommunityService {
  final _supabase = Supabase.instance.client;

  // 1. Fetch Chat Rooms for the List Screen
  // This requires a more complex join query in reality to get the latest message and user details
// 1. Fetch Chat Rooms for the List Screen
  Future<List<Map<String, dynamic>>> getChatRooms(String currentUserId) async {
    final response = await _supabase
        .from('ChatRoom')
        .select('''
          roomID,
          User!ChatRoom_user2_ID_fkey(username, role), 
          Message(content, sentAt, isRead)
        ''') // ^^^ CHANGED 'fullName' to 'username' here ^^^
        .eq('user1_ID', currentUserId)
        .order('sentAt', referencedTable: 'Message', ascending: false)
        .limit(1, referencedTable: 'Message');

    return List<Map<String, dynamic>>.from(response);
  }

  // 2. Real-Time Message Stream for the Active Chat Screen
  Stream<List<MessageModel>> getMessagesStream(String roomID) {
    return _supabase
        .from('Message')
        .stream(primaryKey: ['messageID'])
        .eq('roomID', roomID)
        .order('sentAt', ascending: true) // Oldest to newest for chat flow
        .map((maps) => maps.map((map) => MessageModel.fromJson(map)).toList());
  }

  // 3. Send a New Message
  Future<void> sendMessage(MessageModel message) async {
    await _supabase.from('Message').insert(message.toJson());
  }

  // 4. Mark Messages as Read (The double blue ticks)
  Future<void> markMessagesAsRead(String roomID, String otherUserID) async {
    await _supabase
        .from('Message')
        .update({'isRead': true})
        .eq('roomID', roomID)
        .eq('senderID', otherUserID)
        .eq('isRead', false);
  }

  // Add this inside your CommunityService class:

  // 2. Update existing function to accept mediaURL
  Future<void> createCommunityPost({
    required String authorID,
    required String content,
    String? mediaURL, // <-- ADD THIS
  }) async {
    await _supabase.from('CommunityPost').insert({
      'authorID': authorID,
      'content': content,
      'mediaURL': mediaURL, // <-- Save it to the column from your schema
      'status': 'active',
    });
  }

// Add this to your CommunityService class:

  Future<List<Map<String, dynamic>>> getCommunityPosts() async {
    final response = await _supabase
        .from('CommunityPost')
        .select('''
          postID,
          authorID,
          content,
          createdAt,
          User: "User"!CommunityPost_authorID_fkey (username, role),
          "PostComment" ("commentID"),
          "PostLike" ("userID"),
          "PostSaved" ("userID")
        ''')
        .eq('status', 'active')
        .order('createdAt', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // --- Add these inside CommunityService ---

  Future<void> toggleLike(String postID, String userID, bool isCurrentlyLiked) async {
    if (isCurrentlyLiked) {
      // If already liked, delete the row
      await _supabase.from('PostLike').delete().match({'postID': postID, 'userID': userID});
    } else {
      // If not liked, insert a new row
      await _supabase.from('PostLike').insert({'postID': postID, 'userID': userID});
    }
  }

  Future<void> toggleSave(String postID, String userID, bool isCurrentlySaved) async {
    if (isCurrentlySaved) {
      await _supabase.from('PostSaved').delete().match({'postID': postID, 'userID': userID});
    } else {
      await _supabase.from('PostSaved').insert({'postID': postID, 'userID': userID});
    }
  }

  // --- ADD THESE TO community_service.dart ---

// 1. Fetch comments for a specific post
  Future<List<Map<String, dynamic>>> getComments(String postID) async {
    final response = await _supabase
        .from('PostComment')
        .select('''
          commentID,
          parentCommentID,
          content,
          createdAt,
          User: "User"!PostComment_userID_fkey (username, role)
        ''')
        .eq('postID', postID)
        .order('createdAt', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }


// 2. Add a new comment (or reply)
  Future<void> addComment({
    required String postID,
    required String userID,
    required String content,
    String? parentCommentID, // <-- NEW: Optional parent ID for replies
  }) async {
    await _supabase.from('PostComment').insert({
      'postID': postID,
      'userID': userID,
      'content': content,
      'parentCommentID': parentCommentID, // <-- NEW: Saves to your database!
      'status': 'active',
    });
  }

  // --- Add this to community_service.dart ---
  Future<void> reportPost({
    required String postID,
    required String reporterID,
    required String category,
    String? details,
  }) async {
    await _supabase.from('ReportedPost').insert({
      'postID': postID,
      'reporterID': reporterID,
      'reportCategory': category,
      'additionalDetails': details,
      'status': 'pending',
    });
  }

  // --- Add this to your CommunityService class ---
  Future<void> reportComment({
    required String commentID,
    required String reporterID,
    required String category,
    String? details,
  }) async {
    await _supabase.from('ReportedComment').insert({
      'commentID': commentID,
      'reporterID': reporterID,
      'reportCategory': category,
      'additionalDetails': details,
      'status': 'pending',
    });
  }

// 1. New function to upload the file to Supabase Storage
  Future<String?> uploadPostMedia(File file, String userID) async {
    try {
      // Create a unique file name using timestamp
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
      final path = '$userID/$fileName'; // Organize by userID folder

      // Upload to the 'post_media' bucket
      await _supabase.storage.from('post_media').upload(path, file);

      // Return the public URL so we can save it in the database
      return _supabase.storage.from('post_media').getPublicUrl(path);
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }


  Future<void> deletePost(String postID) async {
    try {
      final response = await _supabase
          .from('CommunityPost')
          .update({'status': 'deleted'}) // Ensure 'status' is the correct column name
          .eq('postID', postID)
          .select(); // Adding .select() helps verify the update happened

      if (response.isEmpty) {
        throw Exception('No post found with that ID or RLS policy blocked the update.');
      }

      print('SUCCESS: Post status updated to deleted in database.');
    } catch (e) {
      print('Supabase Error: $e');
      throw Exception('Failed to delete post: $e');
    }
  }



  // Add this inside your CommunityService class

  Future<String> getOrCreateChatRoom(String currentUserID, String otherUserID) async {
    try {
      // 1. Check if room exists (current user is user1)
      var response = await _supabase
          .from('ChatRoom')
          .select('roomID')
          .eq('user1_ID', currentUserID)
          .eq('user2_ID', otherUserID)
          .maybeSingle();

      // 2. Check the reverse (current user is user2)
      response ??= await _supabase
            .from('ChatRoom')
            .select('roomID')
            .eq('user1_ID', otherUserID)
            .eq('user2_ID', currentUserID)
            .maybeSingle();

      // If a room was found, return its ID
      if (response != null) {
        return response['roomID'];
      }

      // 3. If no room exists, create a brand new one
      final newRoom = await _supabase
          .from('ChatRoom')
          .insert({
        'user1_ID': currentUserID,
        'user2_ID': otherUserID,
      })
          .select('roomID')
          .single();

      return newRoom['roomID'];
    } catch (e) {
      print('Error finding/creating chat room: $e');
      throw Exception('Could not open chat.');
    }
  }












  Future<String?> uploadChatAttachment(File file, String roomID) async {
    try {
      // Create a unique file name
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
      final path = 'chats/$roomID/$fileName'; // Organize by chat room

      // Upload to a bucket named 'chat_attachments'
      await _supabase.storage.from('chat_attachments').upload(path, file);

      // Return the public URL
      return _supabase.storage.from('chat_attachments').getPublicUrl(path);
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload file.');
    }
  }



  // Add this inside your CommunityService class

  Future<List<Map<String, dynamic>>> getSharedAttachments(String roomID) async {
    try {
      final response = await _supabase
          .from('Message')
          .select()
          .eq('roomID', roomID)
          .not('mediaURL', 'is', null) // Only grab messages that have an attachment
          .order('sentAt', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching attachments: $e');
      return [];
    }
  }

}