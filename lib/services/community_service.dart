import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_post_model.dart';
import '../models/message_model.dart';
import 'dart:io'; // Make sure this is at the top of the file

class CommunityService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, Map<String, String?>>> _getCommunityUserMeta(
    Iterable<String> rawUserIds,
  ) async {
    final userIds = rawUserIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (userIds.isEmpty) {
      return {};
    }

    final metaByUserId = <String, Map<String, String?>>{};

    try {
      final employerProfiles = await _supabase
          .from('Employer')
          .select('employerID, fullName, profilePictureURL')
          .filter('employerID', 'in', userIds);

      for (final item in employerProfiles) {
        final employerId = item['employerID']?.toString();
        if (employerId == null || employerId.isEmpty) continue;

        metaByUserId[employerId] = {
          'fullName': item['fullName']?.toString(),
          'profilePictureURL': item['profilePictureURL']?.toString(),
        };
      }
    } catch (e) {
      print('Error fetching employer community profile data: $e');
    }

    try {
      final seekerProfiles = await _supabase
          .from('JobSeeker')
          .select('seekerID, fullName, profilePictureURL')
          .filter('seekerID', 'in', userIds);

      for (final item in seekerProfiles) {
        final seekerId = item['seekerID']?.toString();
        if (seekerId == null || seekerId.isEmpty) continue;

        final existingMeta = metaByUserId[seekerId] ?? <String, String?>{};
        final seekerFullName = item['fullName']?.toString();
        final seekerProfilePicture = item['profilePictureURL']?.toString();

        if ((existingMeta['fullName'] ?? '').trim().isEmpty &&
            seekerFullName != null &&
            seekerFullName.trim().isNotEmpty) {
          existingMeta['fullName'] = seekerFullName;
        }

        if ((existingMeta['profilePictureURL'] ?? '').trim().isEmpty &&
            seekerProfilePicture != null &&
            seekerProfilePicture.trim().isNotEmpty) {
          existingMeta['profilePictureURL'] = seekerProfilePicture;
        }

        metaByUserId[seekerId] = existingMeta;
      }
    } catch (e) {
      print('Error fetching job seeker community profile data: $e');
    }

    return metaByUserId;
  }

  // 1. Fetch Chat Rooms for the List Screen
  // This requires a more complex join query in reality to get the latest message and user details
// 1. Fetch Chat Rooms for the List Screen
  Future<List<Map<String, dynamic>>> getChatRooms(String currentUserId) async {
    final response = await _supabase
        .from('ChatRoom')
        .select('''
          roomID,
          user1_ID,
          user2_ID,
          user1:User!ChatRoom_user1_ID_fkey(username, role),
          user2:User!ChatRoom_user2_ID_fkey(username, role),
          Message(content, sentAt, isRead, senderID)
        ''')
        .or('user1_ID.eq.$currentUserId,user2_ID.eq.$currentUserId')
        .order('sentAt', referencedTable: 'Message', ascending: false)
        .limit(1, referencedTable: 'Message');

    final rooms = List<Map<String, dynamic>>.from(response);
    if (rooms.isEmpty) return rooms;

    final userIds = <String>{};
    final roomIds = <String>[];
    for (final room in rooms) {
      final roomId = room['roomID']?.toString();
      final user1Id = room['user1_ID']?.toString();
      final user2Id = room['user2_ID']?.toString();

      if (roomId != null && roomId.isNotEmpty) {
        roomIds.add(roomId);
      }

      if (user1Id != null && user1Id.isNotEmpty) {
        userIds.add(user1Id);
      }

      if (user2Id != null && user2Id.isNotEmpty) {
        userIds.add(user2Id);
      }
    }

    if (userIds.isEmpty) return rooms;

    try {
      final employerProfiles = await _supabase
          .from('Employer')
          .select('employerID, profilePictureURL')
          .filter('employerID', 'in', userIds.toList());

      final profileMap = <String, String?>{};
      for (final item in employerProfiles) {
        final employerId = item['employerID']?.toString();
        if (employerId == null || employerId.isEmpty) continue;

        profileMap[employerId] = item['profilePictureURL']?.toString();
      }

      for (final room in rooms) {
        final user1Id = room['user1_ID']?.toString();
        final user2Id = room['user2_ID']?.toString();

        final user1 = Map<String, dynamic>.from(room['user1'] ?? {});
        final user2 = Map<String, dynamic>.from(room['user2'] ?? {});

        if (user1Id != null && profileMap.containsKey(user1Id)) {
          user1['profilePictureURL'] = profileMap[user1Id];
        }

        if (user2Id != null && profileMap.containsKey(user2Id)) {
          user2['profilePictureURL'] = profileMap[user2Id];
        }

        room['user1'] = user1;
        room['user2'] = user2;
      }
    } catch (e) {
      print('Error merging employer profile pictures into chat rooms: $e');
    }

    if (roomIds.isNotEmpty) {
      try {
        final unreadRows = await _supabase
            .from('Message')
            .select('roomID')
            .filter('roomID', 'in', roomIds)
            .eq('isRead', false)
            .neq('senderID', currentUserId)
            .or('isDeleted.is.null,isDeleted.eq.false');

        final unreadCountByRoom = <String, int>{};
        for (final row in unreadRows) {
          final roomId = row['roomID']?.toString();
          if (roomId == null || roomId.isEmpty) continue;

          unreadCountByRoom[roomId] = (unreadCountByRoom[roomId] ?? 0) + 1;
        }

        for (final room in rooms) {
          final roomId = room['roomID']?.toString();
          room['unreadCount'] =
              roomId == null ? 0 : (unreadCountByRoom[roomId] ?? 0);
        }
      } catch (e) {
        print('Error fetching unread message counts: $e');
        for (final room in rooms) {
          room['unreadCount'] = 0;
        }
      }
    }

    return rooms;
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
    if (message.messageID.isNotEmpty) {
      await _supabase.from('Message').upsert(
        message.toJson(),
        onConflict: 'messageID',
        ignoreDuplicates: true,
      );
      return;
    }

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

  Future<List<CommunityPostModel>> getCommunityPosts() async {
    final response = await _supabase
        .from('CommunityPost')
        .select('''
          postID,
          authorID,
          content,
          mediaURL,
          createdAt,
          User: "User"!CommunityPost_authorID_fkey (username, role),
          "PostComment" ("commentID"),
          "PostLike" ("userID"),
          "PostSaved" ("userID")
        ''')
        .eq('status', 'active')
        .order('createdAt', ascending: false);

    final posts = response
        .map((data) => Map<String, dynamic>.from(data as Map))
        .toList();
    final userMetaById = await _getCommunityUserMeta(
      posts
          .map((post) => post['authorID']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    );

    for (final post in posts) {
      final authorId = post['authorID']?.toString() ?? '';
      final user = Map<String, dynamic>.from(post['User'] ?? {});
      final userMeta = userMetaById[authorId];

      if (userMeta != null) {
        final username = user['username']?.toString().trim() ?? '';
        final fullName = userMeta['fullName']?.trim() ?? '';
        final profilePictureUrl = userMeta['profilePictureURL']?.trim() ?? '';

        if (username.isEmpty && fullName.isNotEmpty) {
          user['username'] = fullName;
        }

        if (profilePictureUrl.isNotEmpty) {
          user['profilePictureURL'] = profilePictureUrl;
        }
      }

      post['User'] = user;
    }

    return posts.map((data) => CommunityPostModel.fromJson(data)).toList();
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
          userID,
          content,
          createdAt,
          User: "User"!PostComment_userID_fkey (username, role)
        ''')
        .eq('postID', postID)
        .order('createdAt', ascending: true);

    final comments = response
        .map((data) => Map<String, dynamic>.from(data as Map))
        .toList();
    final userMetaById = await _getCommunityUserMeta(
      comments
          .map((comment) => comment['userID']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    );

    for (final comment in comments) {
      final userId = comment['userID']?.toString() ?? '';
      final user = Map<String, dynamic>.from(comment['User'] ?? {});
      final userMeta = userMetaById[userId];

      if (userMeta != null) {
        final username = user['username']?.toString().trim() ?? '';
        final fullName = userMeta['fullName']?.trim() ?? '';
        final profilePictureUrl = userMeta['profilePictureURL']?.trim() ?? '';

        if (username.isEmpty && fullName.isNotEmpty) {
          user['username'] = fullName;
        }

        if (profilePictureUrl.isNotEmpty) {
          user['profilePictureURL'] = profilePictureUrl;
        }
      }

      comment['User'] = user;
    }

    return comments;
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
      // 1. Hard delete all likes associated with this post
      await _supabase.from('PostLike').delete().eq('postID', postID);

      // 2. Hard delete all saves associated with this post
      await _supabase.from('PostSaved').delete().eq('postID', postID);

      // 3. Hard delete all comments associated with this post
      await _supabase.from('PostComment').delete().eq('postID', postID);

      // 4. Finally, hard delete the actual post
      final response = await _supabase
          .from('CommunityPost')
          .delete() // Changed from .update({'status': 'deleted'})
          .eq('postID', postID)
          .select();

      if (response.isEmpty) {
        throw Exception('No post found or RLS policy blocked the deletion.');
      }

      print('SUCCESS: Post and all related data hard deleted from database.');
    } catch (e) {
      print('Supabase Error: $e');
      throw Exception('Failed to completely delete post: $e');
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

  Future<String?> getUserProfilePictureUrl(String userID) async {
    try {
      final employerResponse = await _supabase
          .from('Employer')
          .select('profilePictureURL')
          .eq('employerID', userID)
          .maybeSingle();

      final employerProfilePicture =
          employerResponse?['profilePictureURL']?.toString().trim();
      if (employerProfilePicture != null && employerProfilePicture.isNotEmpty) {
        return employerProfilePicture;
      }
    } catch (e) {
      print('Error fetching employer profile picture: $e');
    }

    try {
      final seekerResponse = await _supabase
          .from('JobSeeker')
          .select('profilePictureURL')
          .eq('seekerID', userID)
          .maybeSingle();

      final seekerProfilePicture =
          seekerResponse?['profilePictureURL']?.toString().trim();
      if (seekerProfilePicture != null && seekerProfilePicture.isNotEmpty) {
        return seekerProfilePicture;
      }
    } catch (e) {
      print('Error fetching job seeker profile picture: $e');
    }

    return null;
  }



  // Add this inside your CommunityService class

  Future<List<Map<String, dynamic>>> getSharedAttachments(String roomID) async {
    try {
      final response = await _supabase
          .from('Message')
          .select()
          .eq('roomID', roomID)
          .or('isDeleted.is.null,isDeleted.eq.false')
          .not('mediaURL', 'is', null) // Only grab messages that have an attachment
          .order('sentAt', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching attachments: $e');
      return [];
    }
  }




  // --- Add this inside your CommunityService class ---
// --- Updated to perform a HARD DELETE ---
  Future<void> softDeleteMessage(String messageID) async {
    try {
      await _supabase
          .from('Message')
          .update({
            'isDeleted': true,
            'content': 'This message was deleted',
            'mediaURL': null,
          })
          .eq('messageID', messageID);
    } catch (e) {
      print('Error deleting message: $e');
      throw Exception('Failed to delete message.');
    }
  }


  // Inside community_service.dart

  // Update this in community_service.dart
  Future<void> editPost(String postID, String newContent, String? finalMediaUrl) async {
    await _supabase.from('CommunityPost').update({
      'content': newContent,
      'mediaURL': finalMediaUrl, // 👈 Now updates the database with the new (or null) URL
      // 'updatedAt': DateTime.now().toIso8601String(), // Uncomment if you have an updatedAt column
    }).eq('postID', postID);
  }

  Future<void> editComment(String commentID, String newContent) async {
    await _supabase.from('PostComment').update({
      'content': newContent,
    }).eq('commentID', commentID);
  }


  // Add this inside CommunityService class
  Future<void> deleteComment(String commentID) async {
    try {
      await _supabase
          .from('PostComment')
          .delete() // This is already a hard delete!
          .eq('commentID', commentID);
    } catch (e) {
      print('Supabase Error: $e');
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Fetch ALL posts for a specific user, including deleted ones
  Future<List<CommunityPostModel>> getMyPostHistory(String userID) async {
    try {
      // 👇 USE THE EXACT SAME .from() AND .select() AS YOUR getCommunityPosts() METHOD!
      final response = await _supabase
          .from('CommunityPost')
          .select('*, User!CommunityPost_authorID_fkey(*), PostLike(*), PostComment(*), PostSaved(*)')
          .eq('authorID', userID) // 👈 Then just add this filter at the end
          .order('createdAt', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => CommunityPostModel.fromJson(json)).toList();

    } catch (e) {
      print('Error: $e');
      // 👇 Change this temporarily so the actual error shows on your screen!
      throw Exception(e.toString());
    }
  }


}
