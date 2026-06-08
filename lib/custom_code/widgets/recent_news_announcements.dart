import 'package:flutter/material.dart';
import '/utils/debug_log.dart';
import 'package:intl/intl.dart';

import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/pages/desktop_chat/rest_poll_builder.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';

class RecentNewsAnnouncements extends StatelessWidget {
  const RecentNewsAnnouncements({super.key});

  Widget _buildPostsContent(
    BuildContext context,
    AsyncSnapshot<List<PostsRecord>> snapshot,
    DateTime cutoff,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      );
    }

    if (snapshot.hasError) {
      debugLog('Error loading news: ${snapshot.error}');
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: FlutterFlowTheme.of(context).error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading news',
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      fontFamily: 'Inter',
                      color: FlutterFlowTheme.of(context).error,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: 'Inter',
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (!snapshot.hasData) {
      return _emptyNewsState(context);
    }

    final posts = snapshot.data!
        .where(
          (post) =>
              post.createdAt != null && !post.createdAt!.isBefore(cutoff),
        )
        .take(5)
        .toList();

    if (posts.isEmpty) {
      return _emptyNewsState(context);
    }

    return Column(
      children: posts.map((post) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context)
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.campaign,
                      color: FlutterFlowTheme.of(context).primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'News',
                          style: FlutterFlowTheme.of(context)
                              .titleSmall
                              .override(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          post.createdAt != null
                              ? DateFormat('MMM d, y • h:mm a')
                                  .format(post.createdAt!)
                              : 'Recently',
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                fontFamily: 'Inter',
                                color: FlutterFlowTheme.of(context)
                                    .secondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (post.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  post.text,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Inter',
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyNewsState(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign,
              size: 48,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'No recent news',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    fontFamily: 'Inter',
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'News within last 48 hours will appear here',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    fontFamily: 'Inter',
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 48));

    if (useWindowsFirestoreRest) {
      return RestPollBuilder<List<PostsRecord>>(
        interval: const Duration(seconds: 60),
        fetch: () => fsQueryLatestNewsPosts(limit: 5),
        builder: (context, snapshot) =>
            _buildPostsContent(context, snapshot, cutoff),
      );
    }

    return StreamBuilder<List<PostsRecord>>(
      stream: queryPostsRecord(
        queryBuilder: (posts) => posts
            .where('post_type', isEqualTo: 'News')
            .where('created_at', isGreaterThanOrEqualTo: cutoff)
            .orderBy('created_at', descending: true)
            .limit(5),
      ),
      builder: (context, snapshot) =>
          _buildPostsContent(context, snapshot, cutoff),
    );
  }
}
