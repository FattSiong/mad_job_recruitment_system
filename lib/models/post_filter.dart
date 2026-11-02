import 'post_topic.dart';

/// Order of the community feed.
enum PostSort {
  newest('newest', 'Newest'),
  mostLiked('most_liked', 'Most liked'),
  mostDiscussed('most_discussed', 'Most discussed');

  const PostSort(this.value, this.label);
  final String value;
  final String label;
}

/// Who wrote the post.
enum PostAuthorFilter {
  everyone(null, 'Everyone'),
  employers('employer', 'Employers'),
  jobSeekers('job_seeker', 'Job seekers');

  const PostAuthorFilter(this.role, this.label);

  /// User.role value, or null for everyone.
  final String? role;
  final String label;
}

/// How recent the post is.
enum PostDateRange {
  anyTime('Any time'),
  today('Today'),
  pastWeek('Past 7 days'),
  pastMonth('Past 30 days');

  const PostDateRange(this.label);
  final String label;

  /// Earliest creation time to include, or null for any time.
  DateTime? since(DateTime now) {
    switch (this) {
      case PostDateRange.anyTime:
        return null;
      case PostDateRange.today:
        return DateTime(now.year, now.month, now.day); // midnight, local time
      case PostDateRange.pastWeek:
        return now.subtract(const Duration(days: 7));
      case PostDateRange.pastMonth:
        return now.subtract(const Duration(days: 30));
    }
  }
}

/// Attachment on the post.
enum PostMediaFilter {
  any(null, 'Any'),
  photos('image', 'With photo'),
  pdfs('pdf', 'With PDF');

  const PostMediaFilter(this.value, this.label);
  final String? value;
  final String label;
}

/// Filter for the My Posts tab (done on the phone: all own posts are loaded).
enum MyPostsStatus { all, visible, removed }

/// Everything that narrows down the community feed.
class PostFilter {
  final String search;
  final PostTopic? topic; // null = all topics
  final PostSort sort;
  final PostAuthorFilter postedBy;
  final PostDateRange date;
  final PostMediaFilter media;

  const PostFilter({
    this.search = '',
    this.topic,
    this.sort = PostSort.newest,
    this.postedBy = PostAuthorFilter.everyone,
    this.date = PostDateRange.anyTime,
    this.media = PostMediaFilter.any,
  });

  static const PostFilter none = PostFilter();

  /// Options set in the filter sheet (sort, posted by, date, attachment).
  int get sheetCount =>
      (sort != PostSort.newest ? 1 : 0) +
      (postedBy != PostAuthorFilter.everyone ? 1 : 0) +
      (date != PostDateRange.anyTime ? 1 : 0) +
      (media != PostMediaFilter.any ? 1 : 0);

  bool get isActive => search.trim().isNotEmpty || topic != null || sheetCount > 0;

  PostFilter copyWith({
    String? search,
    PostTopic? topic,
    bool allTopics = false,
    PostSort? sort,
    PostAuthorFilter? postedBy,
    PostDateRange? date,
    PostMediaFilter? media,
  }) {
    return PostFilter(
      search: search ?? this.search,
      topic: allTopics ? null : (topic ?? this.topic),
      sort: sort ?? this.sort,
      postedBy: postedBy ?? this.postedBy,
      date: date ?? this.date,
      media: media ?? this.media,
    );
  }

  /// Parameters for the `search_community_posts` database function.
  Map<String, dynamic> toParams({required int limit, required int offset, DateTime? now}) {
    final text = search.trim();
    return {
      'p_search': text.isEmpty ? null : text,
      'p_author_role': postedBy.role,
      'p_category': topic?.value,
      'p_since': date.since(now ?? DateTime.now())?.toUtc().toIso8601String(),
      'p_media': media.value,
      'p_sort': sort.value,
      'p_limit': limit,
      'p_offset': offset,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PostFilter &&
      other.search.trim() == search.trim() &&
      other.topic == topic &&
      other.sort == sort &&
      other.postedBy == postedBy &&
      other.date == date &&
      other.media == media;

  @override
  int get hashCode => Object.hash(search.trim(), topic, sort, postedBy, date, media);
}
